# SERVER ----
library(shiny)
library(DBI)
library(RPostgres)
library(DT)
library(pool)
library(shinyjs)
library(bcrypt)

source("global.R")


function(input, output, session) {
  # CRIAR O HELPER confirm_action()
  # 📌 O que isso resolve
  # Elimina duplicação de modalDialog
  # Centraliza UX
  # Facilita mudar texto/cores depois
  confirm_action <- function(id_confirm,
                             title = "Confirmação",
                             message,
                             label_confirm = "Confirmar",
                             class_confirm = "btn-danger",
                             icon_confirm = icon("check")) {
    showModal(
      modalDialog(
        title = title,
        message,
        footer = tagList(
          modalButton("Cancelar"),
          actionButton(
            id_confirm,
            label_confirm,
            class = class_confirm,
            icon = icon_confirm
          )
        )
      )
    )
  }
  

    usuario      <- reactiveVal(NULL)
  nome_usuario <- reactiveVal(NULL)
  
  registrar_login <- function(siape,
                              sucesso,
                              ip = NULL,
                              user_agent = NULL) {
    try({
      dbExecute(
        pool_write,
        "INSERT INTO login_logs (siape, momento, sucesso, ip, user_agent)
   VALUES ($1, now(), $2, $3, $4)",
        params = list(siape, sucesso, ip, user_agent)
      )
    }, silent = TRUE)
  }
  
  
  ## LOGIN ----
  observeEvent(input$btn_entrar, {
    
    siape <- input$in_siape
    senha <- input$in_senha
    
    if (!nzchar(siape) || !nzchar(senha)) {
      showNotification("Informe SIAPE e senha.", type = "error")
      return()
    }
    
    dados <- dbGetQuery(
      pool_read,
      "SELECT siape, nome, senha_hash FROM servidores WHERE siape = $1",
      params = list(siape)
    )
    
    if (nrow(dados) == 1) {
      
      if (is.na(dados$senha_hash) || dados$senha_hash == "") {
        showNotification(
          "Usuário sem senha configurada. Contate o administrador.",
          type = "error"
        )
        return()
      }
      
      ok <- FALSE
      try({
        ok <- bcrypt::checkpw(senha, dados$senha_hash[1])
      }, silent = TRUE)
      
      if (isTRUE(ok)) {
        
        usuario(dados$siape[1])
        nome_usuario(dados$nome[1])
        
        registrar_login(
          siape = siape,
          sucesso = TRUE,
          ip = session$request$REMOTE_ADDR,
          user_agent = session$request$HTTP_USER_AGENT
        )
        
        showNotification(
          paste("Bem-vindo,", dados$nome[1]),
          type = "message"
        )
        
      } else {
        
        registrar_login(
          siape = siape,
          sucesso = FALSE,
          ip = session$request$REMOTE_ADDR,
          user_agent = session$request$HTTP_USER_AGENT
        )
        
        showNotification("SIAPE ou senha incorretos.", type = "error")
      }
      
    } else {
      
      registrar_login(
        siape = siape,
        sucesso = FALSE,
        ip = session$request$REMOTE_ADDR,
        user_agent = session$request$HTTP_USER_AGENT
      )
      
      showNotification("SIAPE ou senha incorretos.", type = "error")
    }
    
  })
  
  
  ## Dados auxiliares----
  codigos_validos <- reactive({
    dados <- dbGetQuery(pool_read, "SELECT codigo, descricao FROM codigos_entrega")
    paste(dados$codigo, "-", dados$descricao)
  })
  
  dados_entregas   <- reactiveVal(data.frame())
  dados_servidores <- reactiveVal(data.frame())
  dados_codigos    <- reactiveVal(data.frame())
  
  ## ---- Ano de ciclo ----
  anos_disponiveis <- reactive({
    dbGetQuery(pool_read, "SELECT ano, status FROM anos_ciclo ORDER BY ano DESC")
  })
  
  ano_ciclo <- reactive({
    req(input$in_ano_ciclo)
    as.integer(input$in_ano_ciclo)
  })
  
  ano_esta_aberto <- reactive({
    dados <- anos_disponiveis()
    dados$status[dados$ano == ano_ciclo()] == "aberto"
  })
  
  
  output$out_status_ano <- renderUI({
    req(input$in_ano_ciclo)
    
    if (isTRUE(ano_esta_aberto())) {
      div(
        class = "status-ano aberto",
        "🟢 Ano aberto — edição liberada"
      )
    } else {
      div(
        class = "status-ano fechado",
        "🔒 Ano fechado — apenas visualização"
      )
    }
  })

      
  ## Bloqueio visual quando ano fechado ----
  observe({
    req(input$in_ano_ciclo)
    
    estado <- isTRUE(ano_esta_aberto())
    
    shinyjs::toggleState("btn_add", condition = estado)
    shinyjs::toggleState("btn_update", condition = estado)
    shinyjs::toggleState("btn_delete", condition = estado)
    
    shinyjs::toggleState("in_data", condition = estado)
    shinyjs::toggleState("in_codigo", condition = estado)
    shinyjs::toggleState("in_entregas", condition = estado)
    shinyjs::toggleState("in_horas", condition = estado)
    shinyjs::toggleState("in_status", condition = estado)
  })
  
  ## restringir data ao ano selecionado ----
  observeEvent(input$in_ano_ciclo, {
    req(input$in_ano_ciclo)
    
    ano <- ano_ciclo()
    hoje <- Sys.Date()
    
    data_padrao <- if (format(hoje, "%Y") == as.character(ano)) {
      hoje
    } else {
      as.Date(paste0(ano, "-01-01"))
    }
    
    updateDateInput(
      session,
      "in_data",
      value = data_padrao,
      min   = as.Date(paste0(ano, "-01-01")),
      max   = as.Date(paste0(ano, "-12-31"))
    )
  })
  
  
  ## atualizar entregas ao trocar ano ----
  observeEvent(input$in_ano_ciclo, {
    req(usuario(), ano_ciclo())
    
    dados_entregas(
      dbGetQuery(
        pool_read,
        "SELECT * FROM entregas
   WHERE servidor = $1 AND ano = $2
   ORDER BY id DESC",
        params = list(usuario(), ano_ciclo())
      )
    )
  })
  
  
  ## Atualização ao logar----
  
  observe({
    req(usuario(), anos_disponiveis())
    
    if (usuario() == "admin") {
      todos_dados <- dbGetQuery(pool_read, "SELECT * FROM entregas")
    } else {
      todos_dados <- dbGetQuery(pool_read,
                                "SELECT * FROM entregas WHERE servidor = $1",
                                params = list(usuario()))
    }
    
    updateSelectInput(session, "in_filtro_ano", choices = c("Todos", sort(unique(
      format(as.Date(todos_dados$data), "%Y")
    ))))
    updateSelectInput(session, "in_filtro_mes", choices = c("Todos", sort(unique(
      format(as.Date(todos_dados$data), "%m")
    ))))
    updateSelectInput(session, "in_filtro_codigo", choices = c("Todos", sort(unique(
      todos_dados$codigo
    ))))
    
    # Só mostra filtro de servidor se for admin
    if (usuario() == "admin") {
      updateSelectInput(session, "in_filtro_servidor", choices = c("Todos", sort(unique(
        todos_dados$servidor
      ))))
    }
    
    if (usuario() == "admin") {
      dados_servidores(dbGetQuery(pool_read, "SELECT * FROM servidores"))
      dados_codigos(dbGetQuery(pool_read, "SELECT * FROM codigos_entrega"))
    }
    
    anos <- anos_disponiveis()
    
    updateSelectInput(session,
                      "in_ano_ciclo",
                      choices = anos$ano,
                      selected = anos$ano[anos$status == "aberto"][1])
    
    
  })
  
  
  ## UI dinâmica ----
  output$out_conteudo <- renderUI({
    req(usuario())
    
    abas <- list(tabPanel(
      "Relatórios",
      br(),
      p(
        "Nesta aba você pode visualizar relatórios das entregas, filtrando por ano, mês, servidor ou código.",
        class = "texto-explicativo"
      ),
      br(),
      fluidRow(
        column(3, selectInput("in_filtro_ano", "Ano:", choices = NULL)),
        column(3, selectInput("in_filtro_mes", "Mês:", choices = NULL)),
        # Só renderiza este filtro se for admin
        if (usuario() == "admin")
          column(
            3,
            selectInput("in_filtro_servidor", "Servidor:", choices = NULL)
          ),
        column(
          3,
          selectInput("in_filtro_codigo", "Código:", choices = NULL)
        )
      ),
      br(),
      DTOutput("out_tabela_relatorio")
    ))
    
    ## Minhas entregas----
    if (usuario() != "admin") {
      abas <- c(list(
        tabPanel(
          "Minhas entregas",
          br(),
          p(
            "Nesta aba você pode registrar, atualizar ou remover suas entregas.",
            class = "texto-explicativo"
          ),
          br(),
          # selectInput("in_ano_ciclo", "Ano do ciclo:", choices = NULL),
          # uiOutput("out_status_ano"),
          # 
          
          fluidRow(
            column(
              3,
              selectInput("in_ano_ciclo", "Ano do ciclo:", choices = NULL)
            ),
            column(
              9,
              div(
                class = "status-ano-wrapper",
                uiOutput("out_status_ano")
              )
            )
          ),

                    br(),
          DTOutput("out_tabela_entregas"),
          br(),
          fluidRow(
            column(2, dateInput("in_data", "Data")),
            column(
              4,
              selectInput(
                "in_codigo",
                "Código:",
                choices = codigos_validos(),
                width = "100%"
              )
            ),
            column(2, numericInput("in_entregas", "Entregas", 0, min = 0)),
            column(2, numericInput(
              "in_horas", "Horas", 0, min = 0, step = 0.5
            )),
            column(2, selectInput(
              "in_status", "Status", c("Em andamento", "Concluído")
            ))
          ),
          actionButton(
            "btn_add",
            label = "Adicionar",
            icon = icon("plus"),
            class = "btn-success"
          ),
          actionButton(
            "btn_update",
            label = "Editar",
            icon = icon("pen-to-square"),
            class = "btn-warning"
          ),
          actionButton(
            "btn_delete",
            label = "Remover",
            icon = icon("trash"),
            class = "btn-danger"
          )
        )
      ), abas)
    }
    
    ## Administração----
    if (usuario() == "admin") {
      abas <- c(abas, list(
        tabPanel(
          "Gerenciar Anos",
          br(),
          p(
            "Aqui você pode criar, abrir ou fechar anos de ciclo do sistema.",
            class = "texto-explicativo"
          ),
          br(),
          DTOutput("out_tabela_anos"),
          br(),
          fluidRow(column(
            4, numericInput("in_ano", "Ano:", value = as.integer(format(
              Sys.Date(), "%Y"
            )))
          ), column(
            4, selectInput(
              "in_status_ano",
              "Status:",
              choices = c("aberto", "fechado")
            )
          )),
          actionButton(
            "btn_add_ano",
            "Adicionar",
            class = "btn-success",
            icon = icon("plus")
          ),
          actionButton(
            "btn_edit_ano",
            "Editar",
            class = "btn-warning",
            icon = icon("pen-to-square")
          ),
          actionButton(
            "btn_del_ano",
            "Remover",
            class = "btn-danger",
            icon = icon("trash")
          )
        ),
        
        tabPanel(
          "Todos os dados",
          br(),
          p(
            "Aqui você, como administrador, pode visualizar todas as entregas registradas no sistema.",
            class = "texto-explicativo"
          ),
          br(),
          DTOutput("out_tabela_todos")
        ),
        
        #' -------------------
        # UI (Admin -> Gerenciar Códigos)----
        #' -------------------
        tabPanel(
          "Gerenciar Códigos",
          br(),
          p(
            "Nesta aba você pode adicionar, atualizar ou remover códigos de entrega disponíveis para os servidores.",
            class = "texto-explicativo"
          ),
          br(),
          DTOutput("out_tabela_codigos"),
          br(),
          fluidRow(column(
            3, textInput("in_codigo_id", "ID do Código:")
          ), column(
            9, textInput("in_codigo_desc", "Descrição:")
          )),
          actionButton(
            "btn_add_codigo",
            "Adicionar",
            icon = icon("plus"),
            class = "btn-success"
          ),
          actionButton(
            "btn_edit_codigo",
            "Editar",
            icon = icon("pen-to-square"),
            class = "btn-warning"
          ),
          actionButton(
            "btn_del_codigo",
            "Remover",
            icon = icon("trash"),
            class = "btn-danger"
          )
        ),
        
        #' -------------------
        # UI (Admin -> Gerenciar Servidores)----
        #' -------------------
        tabPanel(
          "Gerenciar Servidores",
          br(),
          p(
            "Aqui você pode adicionar novos servidores ou remover servidores existentes que não possuam entregas registradas.",
            class = "texto-explicativo"
          ),
          br(),
          DTOutput("out_tabela_servidores"),
          br(),
          fluidRow(column(
            3, textInput("in_servidor_siape", "SIAPE:")
          ), column(
            9, textInput("in_servidor_nome", "Nome:")
          )),
          actionButton(
            "btn_add_servidor",
            "Adicionar",
            icon = icon("plus"),
            class = "btn-success"
          ),
          actionButton(
            "btn_edit_servidor",
            "Editar",
            icon = icon("pen-to-square"),
            class = "btn-warning"
          ),
          actionButton(
            "btn_del_servidor",
            "Remover",
            icon = icon("trash"),
            class = "btn-danger"
          )
        )
      ))
    }
    
    do.call(tabsetPanel, abas)
  })
  
  # Tabelas----
  tabela_padrao <- function(dados, selection = "single") {
    datatable(
      dados,
      extensions = 'Buttons',
      selection = selection,
      rownames = FALSE,
      options = list(
        dom = 'Blfrtip',
        buttons = c('copy', 'excel', 'pdf', 'print'),
        pageLength = 15,
        lengthMenu = list(c(5, 10, 15, 25, 50, 100), c('5', '10', '15', '25', '50', '100')),
        language = list(
          decimal = ",",
          thousands = ".",
          processing = "Processando...",
          search = "Pesquisar:",
          lengthMenu = "Mostrar _MENU_ registros",
          info = "Mostrando de _START_ até _END_ de _TOTAL_ registros",
          infoEmpty = "Mostrando 0 até 0 de 0 registros",
          infoFiltered = "(filtrado de _MAX_ registros no total)",
          loadingRecords = "Carregando...",
          zeroRecords = "Nenhum registro encontrado",
          emptyTable = "Nenhum dado disponível na tabela",
          paginate = list(
            first = "Primeiro",
            previous = "Anterior",
            `next` = "Proximo",
            last = "Último"
          ),
          buttons = list(
            copy = "Copiar",
            excel = "Excel",
            pdf = "PDF",
            print = "Imprimir"
          )
        )
      )
    )
  }
  
  ## --- Aplicando nas tabelas ---
  output$out_tabela_entregas <- renderDT({
    tabela_padrao(dados_entregas(), selection = "single")
  })
  
  output$out_tabela_todos <- renderDT({
    dados_todos <- dbGetQuery(pool_read, "SELECT * FROM entregas")
    tabela_padrao(dados_todos)
  })
  
  output$out_tabela_servidores <- renderDT({
    dados_servidores <- dbGetQuery(pool_read, "SELECT * FROM servidores")
    tabela_padrao(dados_servidores)
  }, selection = "single")
  
  output$out_tabela_codigos <- renderDT({
    dados_codigos <- dbGetQuery(pool_read, "SELECT * FROM codigos_entrega")
    tabela_padrao(dados_codigos)
  }, selection = "single")
  
  output$out_tabela_anos <- renderDT({
    dados_anos <- dbGetQuery(pool_read, "SELECT * FROM anos_ciclo ORDER BY ano DESC")
    tabela_padrao(dados_anos)
  }, selection = "single")
  
  
  # --- CRUD anos -----
  observeEvent(input$out_tabela_anos_rows_selected, {
    sel <- input$out_tabela_anos_rows_selected
    req(sel)
    
    dados <- dbGetQuery(pool_read, "SELECT * FROM anos_ciclo ORDER BY ano DESC")
    linha <- dados[sel, ]
    
    updateNumericInput(session, "in_ano", value = linha$ano)
    updateSelectInput(session, "in_status_ano", selected = linha$status)
  })
  
  # ADICIONAR ANO
  observeEvent(input$btn_add_ano, {
    req(input$in_ano, input$in_status_ano)
    
    existe <- dbGetQuery(pool_read,
                         "SELECT COUNT(*) FROM anos_ciclo WHERE ano = $1",
                         params = list(input$in_ano))
    
    if (existe[1, 1] > 0) {
      showNotification("⚠️ Este ano já existe.", type = "warning")
      return()
    }
    
    dbExecute(
      pool_write,
      "INSERT INTO anos_ciclo (ano, status) VALUES ($1, $2)",
      params = list(input$in_ano, input$in_status_ano)
    )
    
    showNotification("✅ Ano adicionado com sucesso!", type = "message")
    
    output$out_tabela_anos <- renderDT({
      tabela_padrao(dbGetQuery(pool_read, "SELECT * FROM anos_ciclo ORDER BY ano DESC"))
    })
  })
  
  
  # EDITAR ANO (ABRIR / FECHAR)
  # ⚠️ Regra importante: só pode existir 1 ano aberto.
  # EDITAR ANO (CONFIRMAÇÃO)
  observeEvent(input$btn_edit_ano, {
    req(input$out_tabela_anos_rows_selected)
    
    confirm_action(
      id_confirm   = "confirm_edit_ano",
      message      = paste("Deseja realmente alterar o status do ano", input$in_ano, "?"),
      label_confirm = "Editar",
      class_confirm = "btn-warning",
      icon_confirm  = icon("pen-to-square")
    )
    
  })
  observeEvent(input$confirm_edit_ano, {
    removeModal()
    
    if (input$in_status_ano == "aberto") {
      dbExecute(pool_write, "UPDATE anos_ciclo SET status = 'fechado'")
    }
    
    dbExecute(
      pool_write,
      "UPDATE anos_ciclo SET status = $1 WHERE ano = $2",
      params = list(input$in_status_ano, input$in_ano)
    )
    
    showNotification("✏️ Ano atualizado com sucesso!", type = "message")
    
    output$out_tabela_anos <- renderDT({
      tabela_padrao(dbGetQuery(pool_read, "SELECT * FROM anos_ciclo ORDER BY ano DESC"))
    })
  })
  
  # REMOVER ANO (COM SEGURANÇA)
  # Nunca permitir apagar ano que tenha entregas.
  # REMOVER ANO (CONFIRMAÇÃO)
  # REMOVER ANO (CONFIRMAÇÃO)
  observeEvent(input$btn_del_ano, {
    req(input$out_tabela_anos_rows_selected)
    
    qtd <- dbGetQuery(
      pool_read,
      "SELECT COUNT(*) FROM entregas WHERE ano = $1",
      params = list(input$in_ano)
    )
    
    if (qtd[1, 1] > 0) {
      showNotification("❌ Este ano possui entregas registradas.", type = "error")
      return()
    }
    confirm_action(
      id_confirm   = "confirm_delete_ano",
      message      = paste("Deseja realmente remover o ano", input$in_ano, "?"),
      label_confirm = "Remover",
      class_confirm = "btn-danger",
      icon_confirm  = icon("trash")
    )
  })
  observeEvent(input$confirm_delete_ano, {
    removeModal()
    
    dbExecute(
      pool_write,
      "DELETE FROM anos_ciclo WHERE ano = $1",
      params = list(input$in_ano)
    )
    
    showNotification("🗑️ Ano removido com sucesso!", type = "message")
    
    output$out_tabela_anos <- renderDT({
      tabela_padrao(dbGetQuery(pool_read, "SELECT * FROM anos_ciclo ORDER BY ano DESC"))
    })
  })
  
  
  
  
  # --- CRUD entregas -----
  #### --- Adicionar entrega ---
  
  observeEvent(input$btn_add, {
    req(usuario(), ano_ciclo())
    
    if (!ano_esta_aberto()) {
      showNotification("🔒 Ano fechado. Não é possível inserir entregas.", type = "error")
      return()
    }
    
    # Inserir no banco
    dbExecute(
      pool_write,
      "INSERT INTO entregas 
   (data, ano, codigo, entregas, horas, status, servidor) 
   VALUES ($1, $2, $3, $4, $5, $6, $7)",
      params = list(
        as.character(input$in_data),
        ano_ciclo(),
        input$in_codigo,
        input$in_entregas,
        input$in_horas,
        input$in_status,
        usuario()
      )
    )
    
    
    #### Atualizar dados e tabela---
    dados_entregas(
      dbGetQuery(
        pool_read,
        "SELECT * FROM entregas 
     WHERE servidor = $1 AND ano = $2
     ORDER BY id DESC",
        params = list(usuario(), ano_ciclo())
      )
    )
    
    
    
    output$out_tabela_entregas <- renderDT({
      tabela_padrao(dados_entregas(), selection = "single")
    })
    
    #### Limpar inputs---
    updateDateInput(session, "in_data", value = Sys.Date())
    updateSelectInput(session, "in_codigo", selected = codigos_validos()[1])
    updateNumericInput(session, "in_entregas", value = 0)
    updateNumericInput(session, "in_horas", value = 0)
    updateSelectInput(session, "in_status", selected = "Em andamento")
    
    # Notificação
    showNotification("✅ Entrega adicionada com sucesso!", type = "message")
  })
  
  # --- Atualizar entrega com confirmação ---
  observeEvent(input$btn_update, {
    req(usuario(), input$out_tabela_entregas_rows_selected)
    
    # Mostra modal de confirmação
    showModal(
      modalDialog(
        title = "Confirmação",
        "Você tem certeza que deseja atualizar esta entrega?",
        footer = tagList(
          modalButton("Cancelar"),
          # Fecha modal sem ação
          actionButton(
            "confirm_update_entrega",
            "Editar",
            icon = icon("pen-to-square"),
            class = "btn-warning"
          )
        )
      )
    )
  })
  
  # Executa atualização após confirmação
  observeEvent(input$confirm_update_entrega, {
    removeModal()  # Fecha o modal
    
    if (!ano_esta_aberto()) {
      showNotification("🔒 Ano fechado. Não é possível editar entregas.", type = "error")
      return()
    }
    
    
    linha <- dados_entregas()[input$out_tabela_entregas_rows_selected, ]
    
    dbExecute(
      pool_write,
      "UPDATE entregas SET data=$1, codigo=$2, entregas=$3, horas=$4, status=$5
                  WHERE id=$6 AND servidor=$7",
      params = list(
        as.character(input$in_data),
        input$in_codigo,
        input$in_entregas,
        input$in_horas,
        input$in_status,
        linha$id,
        usuario()
      )
    )
    
    # Atualiza dados e tabela
    dados_entregas(
      dbGetQuery(
        pool_read,
        "SELECT * FROM entregas WHERE servidor = $1 AND ano = $2 ORDER BY id DESC",
        params = list(usuario(), ano_ciclo())
        
      )
    )
    
    
    output$out_tabela_entregas <- renderDT({
      tabela_padrao(dados_entregas(), selection = "single")
    })
    
    showNotification("✏️ Entrega atualizada com sucesso!", type = "message")
  })
  
  # --- Remover entrega com confirmação ---
  observeEvent(input$btn_delete, {
    req(usuario(), input$out_tabela_entregas_rows_selected)
    
    showModal(
      modalDialog(
        title = "Confirmação",
        "Você tem certeza que deseja remover esta entrega?",
        footer = tagList(
          modalButton("Cancelar"),
          actionButton(
            "confirm_delete_entrega",
            "Remover",
            icon = icon("trash"),
            class = "btn-danger"
          )
        )
      )
    )
  })
  
  # --- Preencher inputs ao selecionar uma linha da tabela de entregas ---
  observeEvent(input$out_tabela_entregas_rows_selected, {
    sel <- input$out_tabela_entregas_rows_selected
    req(sel)  # garante que há uma linha selecionada
    
    linha <- dados_entregas()[sel, ]
    
    updateDateInput(session, "in_data", value = as.Date(linha$data))
    updateSelectInput(session, "in_codigo", selected = linha$codigo)
    updateNumericInput(session, "in_entregas", value = linha$entregas)
    updateNumericInput(session, "in_horas", value = linha$horas)
    updateSelectInput(session, "in_status", selected = linha$status)
  })
  
  
  observeEvent(input$confirm_delete_entrega, {
    removeModal()
    req(input$out_tabela_entregas_rows_selected)
    
    if (!ano_esta_aberto()) {
      showNotification("🔒 Ano fechado. Não é possível remover entregas.", type = "error")
      return()
    }
    
    linha <- dados_entregas()[input$out_tabela_entregas_rows_selected, ]
    
    dbExecute(
      pool_write,
      "DELETE FROM entregas WHERE id=$1 AND servidor=$2",
      params = list(linha$id, usuario())
    )
    
    # Atualiza dados e tabela
    dados_entregas(
      dbGetQuery(
        pool_read,
        "SELECT * FROM entregas WHERE servidor = $1 AND ano = $2 ORDER BY id DESC",
        params = list(usuario(), ano_ciclo())
        
      )
    )
    
    
    output$out_tabela_entregas <- renderDT({
      tabela_padrao(dados_entregas(), selection = "single")
    })
    
    # Limpar inputs
    updateDateInput(session, "in_data", value = Sys.Date())
    updateSelectInput(session, "in_codigo", selected = codigos_validos()[1])
    updateNumericInput(session, "in_entregas", value = 0)
    updateNumericInput(session, "in_horas", value = 0)
    updateSelectInput(session, "in_status", selected = "Em andamento")
    
    showNotification("🗑️ Entrega removida com sucesso!", type = "message")
  })
  
  
  
  # --- CRUD Códigos ----
  # --- Preencher inputs ao selecionar linha ---
  observeEvent(input$out_tabela_codigos_rows_selected, {
    sel <- input$out_tabela_codigos_rows_selected
    req(sel)
    tabela <- dbGetQuery(pool_read, "SELECT * FROM codigos_entrega")
    linha <- tabela[sel, ]
    updateTextInput(session, "in_codigo_id", value = linha$codigo)
    updateTextInput(session, "in_codigo_desc", value = linha$descricao)
  })
  
  # --- Adicionar código ---
  observeEvent(input$btn_add_codigo, {
    req(input$in_codigo_id, input$in_codigo_desc)
    
    existe <- dbGetQuery(
      pool_read,
      "SELECT COUNT(*) FROM codigos_entrega WHERE codigo = $1",
      params = list(input$in_codigo_id)
    )
    
    if (existe[1, 1] > 0) {
      showNotification("⚠️ Este código já está cadastrado!", type = "warning")
    } else {
      dbExecute(
        pool_write,
        "INSERT INTO codigos_entrega (codigo, descricao) VALUES ($1, $2)",
        params = list(input$in_codigo_id, input$in_codigo_desc)
      )
      output$out_tabela_codigos <- renderDT({
        dbGetQuery(pool_read, "SELECT * FROM codigos_entrega")
      }, selection = "single", rownames = FALSE)
      showNotification("✅ Código adicionado com sucesso!", type = "message")
    }
  })
  
  # --- Editar código com confirmação ---
  observeEvent(input$btn_edit_codigo, {
    sel <- input$out_tabela_codigos_rows_selected
    req(sel, input$in_codigo_id, input$in_codigo_desc)
    
    showModal(
      modalDialog(
        title = "Confirmação",
        "Você tem certeza que deseja atualizar este código?",
        footer = tagList(
          modalButton("Cancelar"),
          actionButton(
            "confirm_edit_codigo",
            "Editar",
            icon = icon("pen-to-square"),
            class = "btn-warning"
          )
        )
      )
    )
  })
  
  observeEvent(input$confirm_edit_codigo, {
    removeModal()
    sel <- input$out_tabela_codigos_rows_selected
    dados <- dbGetQuery(pool_read, "SELECT * FROM codigos_entrega")
    id <- dados$id[sel]
    
    existe <- dbGetQuery(
      pool_read,
      "SELECT COUNT(*) FROM codigos_entrega WHERE codigo = $1 AND id != $2",
      params = list(input$in_codigo_id, id)
    )
    
    if (existe[1, 1] > 0) {
      showNotification("⚠️ Já existe um código com este ID!", type = "warning")
    } else {
      dbExecute(
        pool_write,
        "UPDATE codigos_entrega SET codigo=$1, descricao=$2 WHERE id=$3",
        params = list(input$in_codigo_id, input$in_codigo_desc, id)
      )
      output$out_tabela_codigos <- renderDT({
        dbGetQuery(pool_read, "SELECT * FROM codigos_entrega")
      }, selection = "single", rownames = FALSE)
      showNotification("✏️ Código atualizado com sucesso!", type = "message")
    }
  })
  
  # --- Remover código com confirmação ---
  observeEvent(input$btn_del_codigo, {
    sel <- input$out_tabela_codigos_rows_selected
    req(sel)
    
    showModal(
      modalDialog(
        title = "Confirmação",
        "Você tem certeza que deseja remover este código?",
        footer = tagList(
          modalButton("Cancelar"),
          actionButton(
            "confirm_delete_codigo",
            "Remover",
            icon = icon("trash"),
            class = "btn-danger"
          )
        )
      )
    )
  })
  
  observeEvent(input$confirm_delete_codigo, {
    removeModal()
    sel <- input$out_tabela_codigos_rows_selected
    tabela <- dbGetQuery(pool_read, "SELECT * FROM codigos_entrega")
    id <- tabela$id[sel]
    
    dbExecute(pool_write, "DELETE FROM codigos_entrega WHERE id=$1", params = list(id))
    
    output$out_tabela_codigos <- renderDT({
      dbGetQuery(pool_read, "SELECT * FROM codigos_entrega")
    }, selection = "single", rownames = FALSE)
    
    # Limpar inputs
    updateTextInput(session, "in_codigo_id", value = "")
    updateTextInput(session, "in_codigo_desc", value = "")
    
    showNotification("🗑️ Código removido com sucesso!", type = "message")
  })
  
  
  
  # --- CRUD Servidores ----
  # --- Preencher inputs ao selecionar linha ---
  observeEvent(input$out_tabela_servidores_rows_selected, {
    sel <- input$out_tabela_servidores_rows_selected
    req(sel)
    tabela <- dbGetQuery(pool_read, "SELECT * FROM servidores")
    linha <- tabela[sel, ]
    updateTextInput(session, "in_servidor_siape", value = linha$siape)
    updateTextInput(session, "in_servidor_nome", value = linha$nome)
  })
  
  # --- Adicionar servidor ---
  observeEvent(input$btn_add_servidor, {
    req(input$in_servidor_siape, input$in_servidor_nome)
    
    existe <- dbGetQuery(
      pool_read,
      "SELECT COUNT(*) FROM servidores WHERE siape = $1",
      params = list(input$in_servidor_siape)
    )
    
    if (existe[1, 1] > 0) {
      showNotification("⚠️ Este servidor já está cadastrado!", type = "warning")
    } else {
      dbExecute(
        pool_write,
        "INSERT INTO servidores (siape, nome) VALUES ($1, $2)",
        params = list(input$in_servidor_siape, input$in_servidor_nome)
      )
      output$out_tabela_servidores <- renderDT({
        dbGetQuery(pool_read, "SELECT * FROM servidores")
      }, selection = "single", rownames = FALSE)
      showNotification("✅ Servidor adicionado com sucesso!", type = "message")
    }
  })
  
  # --- Editar servidor com confirmação ---
  observeEvent(input$btn_edit_servidor, {
    sel <- input$out_tabela_servidores_rows_selected
    req(sel, input$in_servidor_siape, input$in_servidor_nome)
    
    showModal(
      modalDialog(
        title = "Confirmação",
        "Você tem certeza que deseja atualizar este servidor?",
        footer = tagList(
          modalButton("Cancelar"),
          actionButton(
            "confirm_edit_servidor",
            "Editar",
            icon = icon("pen-to-square"),
            class = "btn-warning"
          )
        )
      )
    )
  })
  
  observeEvent(input$confirm_edit_servidor, {
    removeModal()
    sel <- input$out_tabela_servidores_rows_selected
    dados <- dbGetQuery(pool_read, "SELECT * FROM servidores")
    siape_sel <- dados$siape[sel]
    
    existe <- dbGetQuery(
      pool_read,
      "SELECT COUNT(*) FROM servidores WHERE siape = $1 AND siape != $2",
      params = list(input$in_servidor_siape, siape_sel)
    )
    
    if (existe[1, 1] > 0) {
      showNotification("⚠️ Já existe um servidor com este SIAPE!", type = "warning")
    } else {
      dbExecute(
        pool_write,
        "UPDATE servidores SET siape=$1, nome=$2 WHERE siape=$3",
        params = list(
          input$in_servidor_siape,
          input$in_servidor_nome,
          siape_sel
        )
      )
      output$out_tabela_servidores <- renderDT({
        dbGetQuery(pool_read, "SELECT * FROM servidores")
      }, selection = "single", rownames = FALSE)
      showNotification("✏️ Servidor atualizado com sucesso!", type = "message")
    }
  })
  
  # --- Remover servidor com confirmação ---
  observeEvent(input$btn_del_servidor, {
    sel <- input$out_tabela_servidores_rows_selected
    req(sel)
    
    tabela <- dbGetQuery(pool_read, "SELECT * FROM servidores")
    siape_sel <- tabela$siape[sel]
    
    entregas <- dbGetQuery(pool_read,
                           "SELECT COUNT(*) FROM entregas WHERE servidor=$1",
                           params = list(siape_sel))
    
    if (entregas[1, 1] > 0) {
      showNotification(
        "❌ Este servidor possui entregas registradas. Remova as entregas antes de excluir.",
        type = "error"
      )
    } else {
      showModal(
        modalDialog(
          title = "Confirmação",
          "Você tem certeza que deseja remover este servidor?",
          footer = tagList(
            modalButton("Cancelar"),
            actionButton(
              "confirm_delete_servidor",
              "Remover",
              icon = icon("trash"),
              class = "btn-danger"
            )
          )
        )
      )
    }
  })
  
  observeEvent(input$confirm_delete_servidor, {
    removeModal()
    sel <- input$out_tabela_servidores_rows_selected
    tabela <- dbGetQuery(pool_read, "SELECT * FROM servidores")
    siape_sel <- tabela$siape[sel]
    
    dbExecute(pool_write,
              "DELETE FROM servidores WHERE siape=$1",
              params = list(siape_sel))
    
    output$out_tabela_servidores <- renderDT({
      dbGetQuery(pool_read, "SELECT * FROM servidores")
    }, selection = "single", rownames = FALSE)
    
    # Limpar inputs
    updateTextInput(session, "in_servidor_siape", value = "")
    updateTextInput(session, "in_servidor_nome", value = "")
    
    showNotification("🗑️ Servidor removido com sucesso!", type = "message")
  })
  
  
  
  # --- Relatório ----
  output$out_tabela_relatorio <- renderDT({
    req(usuario())
    
    # Dados brutos: admin vê todos, servidor vê apenas os seus
    if (usuario() == "admin") {
      dados <- dbGetQuery(pool_read, "SELECT * FROM entregas")
    } else {
      dados <- dbGetQuery(pool_read,
                          "SELECT * FROM entregas WHERE servidor = $1",
                          params = list(usuario()))
    }
    
    # Aplicar filtros
    if (!is.null(input$in_filtro_ano) &&
        input$in_filtro_ano != "Todos")
      dados <- subset(dados, format(as.Date(data), "%Y") == input$in_filtro_ano)
    if (!is.null(input$in_filtro_mes) &&
        input$in_filtro_mes != "Todos")
      dados <- subset(dados, format(as.Date(data), "%m") == input$in_filtro_mes)
    if (!is.null(input$in_filtro_servidor) &&
        input$in_filtro_servidor != "Todos")
      dados <- subset(dados, servidor == input$in_filtro_servidor)
    if (!is.null(input$in_filtro_codigo) &&
        input$in_filtro_codigo != "Todos")
      dados <- subset(dados, codigo == input$in_filtro_codigo)
    
    # Sem registros
    if (nrow(dados) == 0) {
      return(tabela_padrao(
        data.frame(Mensagem = "Nenhum registro encontrado para os filtros selecionados."),
        selection = "none"
      ))
    }
    
    # Criar colunas de ano e mês
    dados$ano <- format(as.Date(dados$data), "%Y")
    dados$mes <- format(as.Date(dados$data), "%m")
    
    # Resumo diferente para admin e servidor
    if (usuario() == "admin") {
      # Admin -> resumo sem servidor
      resumo <- aggregate(cbind(entregas, horas) ~ ano + mes + codigo,
                          data = dados,
                          FUN = sum)
      total_mes <- aggregate(horas ~ ano + mes, data = dados, FUN = sum)
      
      resumo$percentual <- round((resumo$horas / total_mes$horas[match(paste(resumo$ano, resumo$mes),
                                                                       paste(total_mes$ano, total_mes$mes))]) * 100, 1)
      
      # Renderiza
      tabela_padrao(resumo[, c("ano", "mes", "codigo", "entregas", "horas", "percentual")])
      
    } else {
      # Servidor -> resumo incluindo servidor
      resumo <- aggregate(
        cbind(entregas, horas) ~ servidor + ano + mes + codigo,
        data = dados,
        FUN = sum
      )
      total_mes <- aggregate(horas ~ servidor + ano + mes,
                             data = dados,
                             FUN = sum)
      
      resumo$percentual <- round((resumo$horas / total_mes$horas[match(
        paste(resumo$servidor, resumo$ano, resumo$mes),
        paste(total_mes$servidor, total_mes$ano, total_mes$mes)
      )]) * 100, 1)
      
      # Renderiza
      tabela_padrao(resumo[, c("servidor",
                               "ano",
                               "mes",
                               "codigo",
                               "entregas",
                               "horas",
                               "percentual")])
    }
  })
  

}