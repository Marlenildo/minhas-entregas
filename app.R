#' Tendo criado o banco no Railway com Postgres SQL
#' Rodar esse app para atualizar os dados
#' Data da última atualização: [25/09/2025]

library(shiny)
library(DBI)
library(RPostgres)
library(DT)

# Conexão com PostgreSQL ----
con <- dbConnect(
  RPostgres::Postgres(),
  dbname   = Sys.getenv("DB_NAME"),
  host     = Sys.getenv("DB_HOST"),
  port     = Sys.getenv("DB_PORT"),
  user     = Sys.getenv("DB_USER"),
  password = Sys.getenv("DB_PASSWORD"),
  sslmode  = Sys.getenv("PGSSLMODE")
)


# UI ----
ui <- fluidPage(
  tags$head(
    includeCSS("www/estilo.css")
  ),
  
  ## Cabeçalho----
  div(
    class = "top-panel",
    style = "justify-content: center;",
    img(src = "logo_ufpb_sisdip.png"),
    span("Gestão de Entregas - SISDIP")
  ),
  
  ## Login----
  # div(
  #   style = "display:flex; flex-direction:column; align-items:center; margin-top:50px;",
  #   textInput("in_siape", "Digite seu SIAPE:"),
  #   actionButton("btn_entrar", "Entrar", class = "btn-primary")
  # ),
  div(
    style = "display:flex; flex-direction:column; align-items:center; margin-top:50px;",
    textInput("in_siape", "Digite seu SIAPE:"),
    passwordInput("in_senha", "Senha:"),                # <- novo campo
    actionButton("btn_entrar", "Entrar", class = "btn-primary")
  ),
  
  br(), hr(),
  
  ## Conteúdo principal----
  uiOutput("out_conteudo"),
  br(), br(), br(), hr(),
  
  ## Rodapé ----
  tags$footer(
    style = "text-align: center; padding: 10px; font-size: 14px; color: #6c757d;",
    img(src = "logo_index.png", height = "60px", style = "vertical-align: middle; margin-right: 8px;"),
    "© 2025 Marlenildo Melo - Todos os direitos reservados."
  )
)

# SERVER ----
server <- function(input, output, session) {
  
  
  usuario      <- reactiveVal(NULL)
  nome_usuario <- reactiveVal(NULL)

  registrar_login <- function(siape, sucesso, ip = NULL, user_agent = NULL) {
    try({
      dbExecute(con, 
                "INSERT INTO login_logs (siape, momento, sucesso, ip, user_agent)
               VALUES ($1, now(), $2, $3, $4)",
                params = list(siape, sucesso, ip, user_agent))
    }, silent = TRUE)
  }
  
  ## LOGIN ----
  observeEvent(input$btn_entrar, {
    siape <- input$in_siape
    senha  <- input$in_senha
    if (!nzchar(siape) || !nzchar(senha)) {
      showNotification("Informe SIAPE e senha.", type = "error")
      return()
    }
    
    # busca o usuário na tabela servidores
    dados <- dbGetQuery(con,
                        "SELECT siape, nome, senha_hash FROM servidores WHERE siape = $1",
                        params = list(siape))
    if (nrow(dados) == 1) {
      # se não houver senha cadastrada, nega (ou permitir login sem senha se quiser — mas não recomendado)
      if (is.na(dados$senha_hash) || dados$senha_hash == "") {
        showNotification("Usuário sem senha configurada. Contate o administrador.",
                         type = "error")
        return()
      }
      # verifica a senha usando bcrypt::checkpw
      ok <- FALSE
      # bcrypt::checkpw espera (plaintext, hash)
      try({
        ok <- bcrypt::checkpw(senha, dados$senha_hash[1])
      }, silent = TRUE)
      
      if (isTRUE(ok)) {
        usuario(dados$siape[1])
        nome_usuario(dados$nome[1])
        showNotification(paste("Bem-vindo,", dados$nome[1]), type = "message")
      } else {
        showNotification("SIAPE ou senha incorretos.", type = "error")
      }
    } else {
      showNotification("SIAPE não encontrado.", type = "error")
    }
  })
  
  ## Dados auxiliares----
  codigos_validos <- reactive({
    dados <- dbGetQuery(con, "SELECT codigo, descricao FROM codigos_entrega")
    paste(dados$codigo, "-", dados$descricao)
  })
  
  dados_entregas   <- reactiveVal(data.frame())
  dados_servidores <- reactiveVal(data.frame())
  dados_codigos    <- reactiveVal(data.frame())
  
  ## Atualização ao logar----
  
  observe({
    req(usuario())
    
    if (usuario() == "admin") {
      todos_dados <- dbGetQuery(con, "SELECT * FROM entregas")
    } else {
      todos_dados <- dbGetQuery(con, "SELECT * FROM entregas WHERE servidor = $1", 
                                params = list(usuario()))
    }
    
    updateSelectInput(session, "in_filtro_ano",
                      choices = c("Todos", sort(unique(format(as.Date(todos_dados$data), "%Y")))))
    updateSelectInput(session, "in_filtro_mes",
                      choices = c("Todos", sort(unique(format(as.Date(todos_dados$data), "%m")))))
    updateSelectInput(session, "in_filtro_codigo",
                      choices = c("Todos", sort(unique(todos_dados$codigo))))
    
    # Só mostra filtro de servidor se for admin
    if (usuario() == "admin") {
      updateSelectInput(session, "in_filtro_servidor",
                        choices = c("Todos", sort(unique(todos_dados$servidor))))
    }
    
    dados_entregas(dbGetQuery(con, "SELECT * FROM entregas WHERE servidor = $1", 
                              params = list(usuario())))
    
    if (usuario() == "admin") {
      dados_servidores(dbGetQuery(con, "SELECT * FROM servidores"))
      dados_codigos(dbGetQuery(con, "SELECT * FROM codigos_entrega"))
    }
  })
  
  
  ## UI dinâmica ----
  output$out_conteudo <- renderUI({
    req(usuario())
    
    abas <- list(
      tabPanel("Relatórios",
               br(),
               p("Nesta aba você pode visualizar relatórios das entregas, filtrando por ano, mês, servidor ou código.", class = "texto-explicativo"),
               br(),
               fluidRow(
                 column(3, selectInput("in_filtro_ano", "Ano:", choices = NULL)),
                 column(3, selectInput("in_filtro_mes", "Mês:", choices = NULL)),
                 # Só renderiza este filtro se for admin
                 if (usuario() == "admin") column(3, selectInput("in_filtro_servidor", "Servidor:", choices = NULL)),
                 column(3, selectInput("in_filtro_codigo", "Código:", choices = NULL))
               ),
               br(),
               DTOutput("out_tabela_relatorio")
      )
      
    )
    
    ## Minhas entregas----
    if (usuario() != "admin") {
      abas <- c(list(
        tabPanel("Minhas entregas",
                 br(),
                 p("Nesta aba você pode registrar, atualizar ou remover suas entregas.", class = "texto-explicativo"),
                 br(),
                 DTOutput("out_tabela_entregas"),
                 br(),
                 fluidRow(
                   column(2, dateInput("in_data", "Data")),
                   column(4, selectInput("in_codigo", "Código:", choices = codigos_validos(), width = "100%")),
                   column(2, numericInput("in_entregas", "Entregas", 0, min = 0)),
                   column(2, numericInput("in_horas", "Horas", 0, min = 0, step = 0.5)),
                   column(2, selectInput("in_status", "Status", c("Em andamento", "Concluído")))
                 ),
                 actionButton("btn_add", label = " Adicionar", icon = icon("plus"), class = "btn-success"),
                 actionButton("btn_update", label = " Editar", icon = icon("pen-to-square"), class = "btn-warning"),
                 actionButton("btn_delete", label = "Remover", icon = icon("trash"), class = "btn-danger")
        )
      ), abas)
    }
    
    ## Administração----
    if (usuario() == "admin") {
      abas <- c(abas, list(
        tabPanel("Todos os dados", 
                 br(),
                 p("Aqui você, como administrador, pode visualizar todas as entregas registradas no sistema.", class = "texto-explicativo"),
                 br(),
                 DTOutput("out_tabela_todos")),

        #' -------------------
        # UI (Admin -> Gerenciar Códigos)----
        #' -------------------
        tabPanel("Gerenciar Códigos",
                 br(),
                 p("Nesta aba você pode adicionar, atualizar ou remover códigos de entrega disponíveis para os servidores.", class = "texto-explicativo"),
                 br(),
                 DTOutput("out_tabela_codigos"),
                 br(),
                 fluidRow(
                   column(3,textInput("in_codigo_id", "ID do Código:")),
                   column(9, textInput("in_codigo_desc", "Descrição:"))),
                 actionButton("btn_add_codigo", "Adicionar", icon = icon("plus"),  class = "btn-success"),
                 actionButton("btn_edit_codigo", "Editar", icon = icon("pen-to-square"),  class = "btn-warning"),
                 actionButton("btn_del_codigo", "Remover", icon = icon("trash"), class = "btn-danger")
                 ),

        #' -------------------
        # UI (Admin -> Gerenciar Servidores)----
        #' -------------------
        tabPanel("Gerenciar Servidores",
                 br(),
                 p("Aqui você pode adicionar novos servidores ou remover servidores existentes que não possuam entregas registradas.", class = "texto-explicativo"),
                 br(),
                 DTOutput("out_tabela_servidores"),
                 br(),
                 fluidRow(
                   column(3,textInput("in_servidor_siape", "SIAPE:")),
                   column(9, textInput("in_servidor_nome", "Nome:"))),
                 actionButton("btn_add_servidor", "Adicionar",  icon = icon("plus"), class = "btn-success"),
                 actionButton("btn_edit_servidor", "Editar", icon = icon("pen-to-square"),  class = "btn-warning"),
                 actionButton("btn_del_servidor", "Remover", icon = icon("trash"), class = "btn-danger")
                 )
        )
      )
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
        pageLength = 10,
        lengthMenu = list(c(5, 10, 25, 50, 100), c('5', '10', '25', '50', '100')),
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
    dados_todos <- dbGetQuery(con, "SELECT * FROM entregas")
    tabela_padrao(dados_todos)
  })
  
  output$out_tabela_servidores <- renderDT({
    dados_servidores <- dbGetQuery(con, "SELECT * FROM servidores")
    tabela_padrao(dados_servidores)
  }, selection = "single")
  
  output$out_tabela_codigos <- renderDT({
    dados_codigos <- dbGetQuery(con, "SELECT * FROM codigos_entrega")
    tabela_padrao(dados_codigos)
  }, selection = "single")
  
  # --- CRUD entregas -----
  #### --- Adicionar entrega ---
  observeEvent(input$btn_add, {
    req(usuario())
    # Inserir no banco
    dbExecute(con, "INSERT INTO entregas (data, codigo, entregas, horas, status, servidor) VALUES ($1, $2, $3, $4, $5, $6)",
              params = list(as.character(input$in_data), input$in_codigo, input$in_entregas, input$in_horas, input$in_status, usuario()))
    
    #### Atualizar dados e tabela---
    dados_entregas(dbGetQuery(con, "SELECT * FROM entregas WHERE servidor = $1", params = list(usuario())))
    
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
    showModal(modalDialog(
      title = "Confirmação",
      "Você tem certeza que deseja atualizar esta entrega?",
      footer = tagList(
        modalButton("Cancelar"),  # Fecha modal sem ação
        actionButton("confirm_update_entrega", "Editar",  icon = icon("pen-to-square"),  class = "btn-warning")
      )
    ))
  })
  
  # Executa atualização após confirmação
  observeEvent(input$confirm_update_entrega, {
    removeModal()  # Fecha o modal
    linha <- dados_entregas()[input$out_tabela_entregas_rows_selected, ]
    
    dbExecute(con, "UPDATE entregas SET data=$1, codigo=$2, entregas=$3, horas=$4, status=$5 
                  WHERE id=$6 AND servidor=$7",
              params = list(
                as.character(input$in_data), input$in_codigo, input$in_entregas, 
                input$in_horas, input$in_status, linha$id, usuario()
              ))
    
    # Atualiza dados e tabela
    dados_entregas(dbGetQuery(con, "SELECT * FROM entregas WHERE servidor=$1", params = list(usuario())))
    output$out_tabela_entregas <- renderDT({
      tabela_padrao(dados_entregas(), selection = "single")
    })
    
    showNotification("✏️ Entrega atualizada com sucesso!", type = "message")
  })
  
  # --- Remover entrega com confirmação ---
  observeEvent(input$btn_delete, {
    req(usuario(), input$out_tabela_entregas_rows_selected)
    
    showModal(modalDialog(
      title = "Confirmação",
      "Você tem certeza que deseja remover esta entrega?",
      footer = tagList(
        modalButton("Cancelar"),
        actionButton("confirm_delete_entrega", "Remover", icon = icon("trash"), class = "btn-danger")
      )
    ))
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
    linha <- dados_entregas()[input$out_tabela_entregas_rows_selected, ]
    
    dbExecute(con, "DELETE FROM entregas WHERE id=$1 AND servidor=$2", params = list(linha$id, usuario()))
    
    # Atualiza dados e tabela
    dados_entregas(dbGetQuery(con, "SELECT * FROM entregas WHERE servidor=$1", params = list(usuario())))
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
    tabela <- dbGetQuery(con, "SELECT * FROM codigos_entrega")
    linha <- tabela[sel, ]
    updateTextInput(session, "in_codigo_id", value = linha$codigo)
    updateTextInput(session, "in_codigo_desc", value = linha$descricao)
  })
  
  # --- Adicionar código ---
  observeEvent(input$btn_add_codigo, {
    req(input$in_codigo_id, input$in_codigo_desc)
    
    existe <- dbGetQuery(con, "SELECT COUNT(*) FROM codigos_entrega WHERE codigo = $1",
                         params = list(input$in_codigo_id))
    
    if (existe[1,1] > 0) {
      showNotification("⚠️ Este código já está cadastrado!", type = "warning")
    } else {
      dbExecute(con, "INSERT INTO codigos_entrega (codigo, descricao) VALUES ($1, $2)",
                params = list(input$in_codigo_id, input$in_codigo_desc))
      output$out_tabela_codigos <- renderDT({
        dbGetQuery(con, "SELECT * FROM codigos_entrega")
      }, selection="single", rownames = FALSE)
      showNotification("✅ Código adicionado com sucesso!", type = "message")
    }
  })
  
  # --- Editar código com confirmação ---
  observeEvent(input$btn_edit_codigo, {
    sel <- input$out_tabela_codigos_rows_selected
    req(sel, input$in_codigo_id, input$in_codigo_desc)
    
    showModal(modalDialog(
      title = "Confirmação",
      "Você tem certeza que deseja atualizar este código?",
      footer = tagList(
        modalButton("Cancelar"),
        actionButton("confirm_edit_codigo", "Editar", icon = icon("pen-to-square"),   class = "btn-warning")
      )
    ))
  })
  
  observeEvent(input$confirm_edit_codigo, {
    removeModal()
    sel <- input$out_tabela_codigos_rows_selected
    dados <- dbGetQuery(con, "SELECT * FROM codigos_entrega")
    id <- dados$id[sel]
    
    existe <- dbGetQuery(con, "SELECT COUNT(*) FROM codigos_entrega WHERE codigo = $1 AND id != $2",
                         params = list(input$in_codigo_id, id))
    
    if (existe[1,1] > 0) {
      showNotification("⚠️ Já existe um código com este ID!", type = "warning")
    } else {
      dbExecute(con, "UPDATE codigos_entrega SET codigo=$1, descricao=$2 WHERE id=$3",
                params = list(input$in_codigo_id, input$in_codigo_desc, id))
      output$out_tabela_codigos <- renderDT({
        dbGetQuery(con, "SELECT * FROM codigos_entrega")
      }, selection="single", rownames = FALSE)
      showNotification("✏️ Código atualizado com sucesso!", type = "message")
    }
  })
  
  # --- Remover código com confirmação ---
  observeEvent(input$btn_del_codigo, {
    sel <- input$out_tabela_codigos_rows_selected
    req(sel)
    
    showModal(modalDialog(
      title = "Confirmação",
      "Você tem certeza que deseja remover este código?",
      footer = tagList(
        modalButton("Cancelar"),
        actionButton("confirm_delete_codigo", "Remover", icon = icon("trash"), class = "btn-danger")
      )
    ))
  })
  
  observeEvent(input$confirm_delete_codigo, {
    removeModal()
    sel <- input$out_tabela_codigos_rows_selected
    tabela <- dbGetQuery(con, "SELECT * FROM codigos_entrega")
    id <- tabela$id[sel]
    
    dbExecute(con, "DELETE FROM codigos_entrega WHERE id=$1", params = list(id))
    
    output$out_tabela_codigos <- renderDT({
      dbGetQuery(con, "SELECT * FROM codigos_entrega")
    }, selection="single", rownames = FALSE)
    
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
    tabela <- dbGetQuery(con, "SELECT * FROM servidores")
    linha <- tabela[sel, ]
    updateTextInput(session, "in_servidor_siape", value = linha$siape)
    updateTextInput(session, "in_servidor_nome", value = linha$nome)
  })
  
  # --- Adicionar servidor ---
  observeEvent(input$btn_add_servidor, {
    req(input$in_servidor_siape, input$in_servidor_nome)
    
    existe <- dbGetQuery(con, "SELECT COUNT(*) FROM servidores WHERE siape = $1",
                         params = list(input$in_servidor_siape))
    
    if (existe[1,1] > 0) {
      showNotification("⚠️ Este servidor já está cadastrado!", type = "warning")
    } else {
      dbExecute(con, "INSERT INTO servidores (siape, nome) VALUES ($1, $2)",
                params = list(input$in_servidor_siape, input$in_servidor_nome))
      output$out_tabela_servidores <- renderDT({
        dbGetQuery(con, "SELECT * FROM servidores")
      }, selection="single", rownames = FALSE)
      showNotification("✅ Servidor adicionado com sucesso!", type = "message")
    }
  })
  
  # --- Editar servidor com confirmação ---
  observeEvent(input$btn_edit_servidor, {
    sel <- input$out_tabela_servidores_rows_selected
    req(sel, input$in_servidor_siape, input$in_servidor_nome)
    
    showModal(modalDialog(
      title = "Confirmação",
      "Você tem certeza que deseja atualizar este servidor?",
      footer = tagList(
        modalButton("Cancelar"),
        actionButton("confirm_edit_servidor", "Editar", icon = icon("pen-to-square"),   class = "btn-warning")
      )
    ))
  })
  
  observeEvent(input$confirm_edit_servidor, {
    removeModal()
    sel <- input$out_tabela_servidores_rows_selected
    dados <- dbGetQuery(con, "SELECT * FROM servidores")
    siape_sel <- dados$siape[sel]
    
    existe <- dbGetQuery(con, "SELECT COUNT(*) FROM servidores WHERE siape = $1 AND siape != $2",
                         params = list(input$in_servidor_siape, siape_sel))
    
    if (existe[1,1] > 0) {
      showNotification("⚠️ Já existe um servidor com este SIAPE!", type = "warning")
    } else {
      dbExecute(con, "UPDATE servidores SET siape=$1, nome=$2 WHERE siape=$3",
                params = list(input$in_servidor_siape, input$in_servidor_nome, siape_sel))
      output$out_tabela_servidores <- renderDT({
        dbGetQuery(con, "SELECT * FROM servidores")
      }, selection="single", rownames = FALSE)
      showNotification("✏️ Servidor atualizado com sucesso!", type = "message")
    }
  })
  
  # --- Remover servidor com confirmação ---
  observeEvent(input$btn_del_servidor, {
    sel <- input$out_tabela_servidores_rows_selected
    req(sel)
    
    tabela <- dbGetQuery(con, "SELECT * FROM servidores")
    siape_sel <- tabela$siape[sel]
    
    entregas <- dbGetQuery(con, "SELECT COUNT(*) FROM entregas WHERE servidor=$1", params = list(siape_sel))
    
    if (entregas[1,1] > 0) {
      showNotification("❌ Este servidor possui entregas registradas. Remova as entregas antes de excluir.", type="error")
    } else {
      showModal(modalDialog(
        title = "Confirmação",
        "Você tem certeza que deseja remover este servidor?",
        footer = tagList(
          modalButton("Cancelar"),
          actionButton("confirm_delete_servidor", "Remover", icon = icon("trash"), class = "btn-danger")
        )
      ))
    }
  })
  
  observeEvent(input$confirm_delete_servidor, {
    removeModal()
    sel <- input$out_tabela_servidores_rows_selected
    tabela <- dbGetQuery(con, "SELECT * FROM servidores")
    siape_sel <- tabela$siape[sel]
    
    dbExecute(con, "DELETE FROM servidores WHERE siape=$1", params = list(siape_sel))
    
    output$out_tabela_servidores <- renderDT({
      dbGetQuery(con, "SELECT * FROM servidores")
    }, selection="single", rownames = FALSE)
    
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
      dados <- dbGetQuery(con, "SELECT * FROM entregas")
    } else {
      dados <- dbGetQuery(con, "SELECT * FROM entregas WHERE servidor = $1",
                          params = list(usuario()))
    }
    
    # Aplicar filtros
    if (!is.null(input$in_filtro_ano) && input$in_filtro_ano != "Todos") 
      dados <- subset(dados, format(as.Date(data), "%Y") == input$in_filtro_ano)
    if (!is.null(input$in_filtro_mes) && input$in_filtro_mes != "Todos") 
      dados <- subset(dados, format(as.Date(data), "%m") == input$in_filtro_mes)
    if (!is.null(input$in_filtro_servidor) && input$in_filtro_servidor != "Todos") 
      dados <- subset(dados, servidor == input$in_filtro_servidor)
    if (!is.null(input$in_filtro_codigo) && input$in_filtro_codigo != "Todos") 
      dados <- subset(dados, codigo == input$in_filtro_codigo)
    
    # Sem registros
    if (nrow(dados) == 0) {
      return(
        tabela_padrao(
          data.frame(Mensagem = "Nenhum registro encontrado para os filtros selecionados."),
          selection = "none"
        )
      )
    }
    
    # Criar colunas de ano e mês
    dados$ano <- format(as.Date(dados$data), "%Y")
    dados$mes <- format(as.Date(dados$data), "%m")
    
    # Resumo diferente para admin e servidor
    if (usuario() == "admin") {
      # Admin -> resumo sem servidor
      resumo <- aggregate(cbind(entregas, horas) ~ ano + mes + codigo,
                          data = dados, FUN = sum)
      total_mes <- aggregate(horas ~ ano + mes, data = dados, FUN = sum)
      
      resumo$percentual <- round((resumo$horas / total_mes$horas[
        match(paste(resumo$ano, resumo$mes),
              paste(total_mes$ano, total_mes$mes))
      ]) * 100, 1)
      
      # Renderiza
      tabela_padrao(
        resumo[, c("ano", "mes", "codigo", "entregas", "horas", "percentual")]
      )
      
    } else {
      # Servidor -> resumo incluindo servidor
      resumo <- aggregate(cbind(entregas, horas) ~ servidor + ano + mes + codigo,
                          data = dados, FUN = sum)
      total_mes <- aggregate(horas ~ servidor + ano + mes, data = dados, FUN = sum)
      
      resumo$percentual <- round((resumo$horas / total_mes$horas[
        match(paste(resumo$servidor, resumo$ano, resumo$mes),
              paste(total_mes$servidor, total_mes$ano, total_mes$mes))
      ]) * 100, 1)
      
      # Renderiza
      tabela_padrao(
        resumo[, c("servidor", "ano", "mes", "codigo", "entregas", "horas", "percentual")]
      )
    }
  })
  
}

shinyApp(ui, server)
