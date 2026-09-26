# SERVER ----
# global.R é carregado automaticamente pelo Shiny antes de ui.R e server.R

function(input, output, session) {

  # 1. SESSÃO E PERFIL ----
  usuario      <- reactiveVal(NULL)
  nome_usuario <- reactiveVal(NULL)

  # O perfil é decidido só no servidor; a interface nunca é a barreira de acesso.
  eh_admin    <- reactive(identical(usuario(), "admin"))
  eh_servidor <- reactive(!is.null(usuario()) && !eh_admin())

  entregas_refresh <- reactiveVal(0L)
  admin_refresh    <- reactiveVal(0L)
  marcar <- function(contador) contador(isolate(contador()) + 1L)

  # 2. HELPERS ----
  # 2.1 Confirmação padronizada para ações que alteram dados
  confirm_action <- function(id_confirm,
                             title = "Confirmação",
                             message,
                             label_confirm = "Confirmar",
                             class_confirm = "btn-remover",
                             icon_confirm = icon("check")) {
    showModal(modalDialog(
      title = title,
      message,
      easyClose = TRUE,
      footer = tagList(
        modalButton("Cancelar"),
        actionButton(id_confirm, label_confirm, class = class_confirm, icon = icon_confirm)
      )
    ))
  }

  # 2.2 Auditoria: try(..., silent = TRUE) garante que a auditoria nunca derruba o app
  registrar_auditoria <- function(acao, entidade, referencia = NULL) {
    try({
      dbExecute(
        pool_write,
        "INSERT INTO audit_logs (usuario, acao, entidade, referencia, ip, user_agent)
         VALUES ($1, $2, $3, $4, $5, $6)",
        params = list(
          usuario(), acao, entidade, referencia,
          session$request$REMOTE_ADDR, session$request$HTTP_USER_AGENT
        )
      )
    }, silent = TRUE)
  }

  registrar_login <- function(siape, sucesso) {
    try({
      dbExecute(
        pool_write,
        "INSERT INTO login_logs (siape, momento, sucesso, ip, user_agent)
         VALUES ($1, now(), $2, $3, $4)",
        params = list(siape, sucesso, session$request$REMOTE_ADDR, session$request$HTTP_USER_AGENT)
      )
    }, silent = TRUE)
  }

  # 2.3 Escrita no banco com mensagem amigável em caso de falha
  gravar <- function(expr, sucesso) {
    ok <- tryCatch({
      force(expr)
      TRUE
    }, error = function(e) {
      showNotification("Não foi possível salvar a alteração. Tente novamente em instantes.", type = "error")
      FALSE
    })
    if (ok) showNotification(sucesso, type = "message")
    ok
  }

  texto_limpo <- function(x) trimws(x %||% "")


  # 3. ACESSO ----
  aviso_login   <- reactiveVal("")
  tentativas    <- reactiveVal(0L)
  bloqueado_ate <- reactiveVal(NULL)

  output$out_aviso_login <- renderText(aviso_login())

  observeEvent(input$login_tentativa, {
    if (!is.null(usuario())) return()
    tentativa <- input$login_tentativa

    agora <- Sys.time()
    if (!is.null(bloqueado_ate()) && agora < bloqueado_ate()) {
      restante <- ceiling(as.numeric(difftime(bloqueado_ate(), agora, units = "secs")))
      aviso_login(sprintf("Muitas tentativas sem sucesso. Aguarde %d segundos.", restante))
      return()
    }

    siape <- texto_limpo(as.character(tentativa$siape %||% "")[1])
    senha <- as.character(tentativa$senha %||% "")[1]

    if (!nzchar(siape) || !nzchar(senha)) {
      aviso_login("Informe SIAPE e senha.")
      return()
    }

    dados <- tryCatch(
      dbGetQuery(pool_read, "SELECT siape, nome, senha_hash FROM servidores WHERE siape = $1", params = list(siape)),
      error = function(e) NULL
    )
    if (is.null(dados)) {
      aviso_login("Não foi possível conectar ao banco de dados. Tente novamente em instantes.")
      return()
    }

    ok <- FALSE
    if (nrow(dados) == 1) {
      if (is.na(dados$senha_hash[1]) || dados$senha_hash[1] == "") {
        aviso_login("Usuário sem senha configurada. Contate o administrador.")
        return()
      }
      ok <- isTRUE(tryCatch(bcrypt::checkpw(senha, dados$senha_hash[1]), error = function(e) FALSE))
    }

    registrar_login(siape = siape, sucesso = ok)
    updateTextInput(session, "in_senha", value = "")

    if (!ok) {
      falhas <- tentativas() + 1L
      if (falhas >= 5) {
        tentativas(0L)
        bloqueado_ate(agora + 60)
        aviso_login("Muitas tentativas sem sucesso. Aguarde 1 minuto.")
      } else {
        tentativas(falhas)
        aviso_login("SIAPE ou senha incorretos.")
      }
      return()
    }

    tentativas(0L)
    aviso_login("")
    usuario(dados$siape[1])
    nome_usuario(dados$nome[1])

    shinyjs::hide("tela_login")
    shinyjs::show("tela_app")
    showNotification(paste0("Bem-vindo(a), ", dados$nome[1], "!"), type = "message")
  })

  # Sair recarrega a sessão: todo o estado do usuário é descartado
  observeEvent(input$btn_sair, session$reload())

  output$out_usuario <- renderUI({
    req(usuario())
    div(
      class = "chip-usuario",
      div(class = "avatar", iniciais(nome_usuario())),
      div(
        div(class = "usuario-nome", nome_usuario()),
        div(class = "usuario-papel", if (eh_admin()) "Administrador" else paste("SIAPE", usuario()))
      )
    )
  })


  # 4. DADOS AUXILIARES ----
  anos_disponiveis <- reactive({
    req(usuario())
    admin_refresh()
    dbGetQuery(pool_read, "SELECT ano, status FROM anos_ciclo ORDER BY ano DESC")
  })

  codigos_validos <- reactive({
    req(usuario())
    admin_refresh()
    dados <- dbGetQuery(pool_read, "SELECT codigo, descricao FROM codigos_entrega ORDER BY codigo")
    paste(dados$codigo, "-", dados$descricao)
  })

  ano_padrao <- function(anos) {
    ano_aberto <- anos$ano[anos$status == "aberto"][1]
    if (!is.na(ano_aberto)) ano_aberto else max(anos$ano, na.rm = TRUE)
  }

  ano_ciclo <- reactive({
    req(input$in_ano_ciclo)
    as.integer(input$in_ano_ciclo)
  })

  ano_esta_aberto <- reactive({
    dados <- anos_disponiveis()
    isTRUE(dados$status[dados$ano == ano_ciclo()][1] == "aberto")
  })

  data_padrao_ciclo <- function(ano) {
    hoje <- Sys.Date()
    if (format(hoje, "%Y") == as.character(ano)) hoje else as.Date(paste0(ano, "-01-01"))
  }

  nomes_servidores <- reactive({
    req(eh_admin())
    admin_refresh()
    dbGetQuery(pool_read, "SELECT siape, nome FROM servidores")
  })

  # Entregas visíveis: o admin vê todas; o servidor, apenas as próprias
  entregas_visiveis <- reactive({
    req(usuario())
    entregas_refresh()
    if (eh_admin()) {
      dados <- dbGetQuery(pool_read, "SELECT * FROM entregas")
      nomes <- nomes_servidores()
      dados$nome_servidor <- nomes$nome[match(as.character(dados$servidor), as.character(nomes$siape))]
      dados
    } else {
      dbGetQuery(pool_read, "SELECT * FROM entregas WHERE servidor = $1", params = list(usuario()))
    }
  })


  # 5. CONTEÚDO PRINCIPAL ----
  output$out_conteudo <- renderUI({
    req(usuario())

    isolate({
      anos <- anos_disponiveis()
      admin <- eh_admin()

      aba_relatorios <- tabPanel(
        tagList(icon("chart-column"), "Relatórios"),
        div(
          class = "painel painel-azul",
          cabecalho_secao("chart-column", "Relatório de esforço", "Horas e entregas por mês"),
          p(
            class = "explicacao",
            if (admin) "Consolidado de todas as entregas registradas. Filtre por ano, mês, servidor ou atividade; o esforço mostra a participação de cada atividade nas horas do mês."
            else "Consolidado das suas entregas. Filtre por ano, mês ou atividade; o esforço mostra a participação de cada atividade nas suas horas do mês."
          ),
          fluidRow(
            column(3, selectInput("in_filtro_ano", "Ano", choices = "Todos", width = "100%")),
            column(3, selectInput("in_filtro_mes", "Mês", choices = "Todos", width = "100%")),
            if (admin) column(3, selectInput("in_filtro_servidor", "Servidor", choices = "Todos", width = "100%")),
            column(if (admin) 3 else 6, selectInput("in_filtro_codigo", "Atividade", choices = "Todos", width = "100%"))
          ),
          uiOutput("out_kpis_relatorio"),
          DTOutput("out_tabela_relatorio")
        )
      )

      if (!admin) {
        abas <- list(
          tabPanel(
            tagList(icon("list-check"), "Minhas entregas"),
            ## Esforço do mês ----
            div(
              class = "painel painel-azul",
              cabecalho_secao("gauge-high", "Esforço do mês", "Atualiza a cada lançamento"),
              fluidRow(
                column(3, selectInput("in_ano_ciclo", "Ano do ciclo", choices = anos$ano,
                                      selected = if (nrow(anos)) ano_padrao(anos), width = "100%")),
                column(3, selectInput("in_mes_resumo", "Mês", choices = setNames(names(MESES), MESES),
                                      selected = format(Sys.Date(), "%m"), width = "100%")),
                column(6, uiOutput("out_status_ano"))
              ),
              uiOutput("out_kpis_mes"),
              div(class = "titulo-bloco", "Distribuição das horas por atividade"),
              uiOutput("out_esforco_mes")
            ),
            ## Lançamentos ----
            div(
              class = "painel painel-verde",
              cabecalho_secao("pen-to-square", "Lançamentos do ano", "Somente você vê estes dados", "tag-verde"),
              p(
                class = "explicacao",
                "Escolha a atividade, informe as entregas e as horas dedicadas. Para editar ou remover, selecione o lançamento na tabela. As alterações só são permitidas enquanto o ano do ciclo estiver aberto."
              ),
              div(
                id = "caixa_formulario",
                class = "caixa-formulario",
                uiOutput("out_modo_formulario"),
                fluidRow(
                  column(2, dateInput("in_data", "Data", value = data_padrao_ciclo(ano_padrao(anos)),
                                      format = "dd/mm/yyyy", language = "pt-BR", weekstart = 1, width = "100%")),
                  column(4, selectInput("in_codigo", "Atividade", choices = codigos_validos(), width = "100%")),
                  column(2, numericInput("in_entregas", "Entregas", 0, min = 0, step = 1, width = "100%")),
                  column(2, numericInput("in_horas", "Horas dedicadas", 0, min = 0, step = 0.5, width = "100%")),
                  column(2, selectInput("in_status", "Situação", STATUS_ENTREGA, width = "100%"))
                ),
                div(
                  class = "barra-acoes",
                  actionButton("btn_add", "Adicionar", icon = icon("plus"), class = "btn-adicionar"),
                  actionButton("btn_update", "Salvar alterações", icon = icon("floppy-disk"), class = "btn-salvar"),
                  actionButton("btn_delete", "Remover", icon = icon("trash"), class = "btn-remover"),
                  actionButton("btn_limpar", "Novo lançamento", icon = icon("eraser"), class = "btn-neutro")
                )
              ),
              DTOutput("out_tabela_entregas")
            )
          ),
          aba_relatorios
        )
      } else {
        abas <- list(
          aba_relatorios,
          ## Admin -> Todas as entregas ----
          tabPanel(
            tagList(icon("table-list"), "Todas as entregas"),
            div(
              class = "painel painel-navy",
              cabecalho_secao("table-list", "Todas as entregas", "Administração"),
              p(class = "explicacao", "Todas as entregas registradas no sistema, com o nome do servidor responsável."),
              uiOutput("out_kpis_todos"),
              DTOutput("out_tabela_todos")
            )
          ),
          ## Admin -> Anos do ciclo ----
          tabPanel(
            tagList(icon("calendar-check"), "Anos do ciclo"),
            div(
              class = "painel painel-navy",
              cabecalho_secao("calendar-check", "Anos do ciclo", "Apenas um ano aberto"),
              p(class = "explicacao", "Crie, abra ou feche anos de ciclo. Ao abrir um ano, os demais são fechados automaticamente. Anos com entregas não podem ser removidos."),
              div(
                class = "caixa-formulario",
                fluidRow(
                  column(3, numericInput("in_ano", "Ano", value = as.integer(format(Sys.Date(), "%Y")), min = 2000, max = 2100, width = "100%")),
                  column(3, selectInput("in_status_ano", "Situação", choices = c("Aberto" = "aberto", "Fechado" = "fechado"), width = "100%"))
                ),
                div(
                  class = "barra-acoes",
                  actionButton("btn_add_ano", "Adicionar", icon = icon("plus"), class = "btn-adicionar"),
                  actionButton("btn_edit_ano", "Alterar situação", icon = icon("floppy-disk"), class = "btn-salvar"),
                  actionButton("btn_del_ano", "Remover", icon = icon("trash"), class = "btn-remover")
                )
              ),
              DTOutput("out_tabela_anos"),
              tags$hr(),
              div(class = "titulo-bloco", "Histórico de ações administrativas"),
              p(class = "explicacao", "Registro das alterações realizadas nos anos de ciclo (criar, abrir, fechar, remover)."),
              DTOutput("out_tabela_audit_anos")
            )
          ),
          ## Admin -> Atividades (códigos) ----
          tabPanel(
            tagList(icon("tags"), "Atividades"),
            div(
              class = "painel painel-navy",
              cabecalho_secao("tags", "Atividades disponíveis", "Códigos de entrega"),
              p(class = "explicacao", "Códigos de entrega que os servidores escolhem ao registrar suas atividades."),
              div(
                class = "caixa-formulario",
                fluidRow(
                  column(3, textInput("in_codigo_id", "Código", width = "100%")),
                  column(9, textInput("in_codigo_desc", "Descrição", width = "100%"))
                ),
                div(
                  class = "barra-acoes",
                  actionButton("btn_add_codigo", "Adicionar", icon = icon("plus"), class = "btn-adicionar"),
                  actionButton("btn_edit_codigo", "Salvar alterações", icon = icon("floppy-disk"), class = "btn-salvar"),
                  actionButton("btn_del_codigo", "Remover", icon = icon("trash"), class = "btn-remover")
                )
              ),
              DTOutput("out_tabela_codigos")
            )
          ),
          ## Admin -> Servidores ----
          tabPanel(
            tagList(icon("users"), "Servidores"),
            div(
              class = "painel painel-navy",
              cabecalho_secao("users", "Servidores", "Acesso ao sistema"),
              p(class = "explicacao", "Cadastre servidores ou atualize nome e SIAPE. Servidores com entregas registradas não podem ser removidos. As senhas nunca são exibidas."),
              div(
                class = "caixa-formulario",
                fluidRow(
                  column(3, textInput("in_servidor_siape", "SIAPE", width = "100%")),
                  column(9, textInput("in_servidor_nome", "Nome", width = "100%"))
                ),
                div(
                  class = "barra-acoes",
                  actionButton("btn_add_servidor", "Adicionar", icon = icon("plus"), class = "btn-adicionar"),
                  actionButton("btn_edit_servidor", "Salvar alterações", icon = icon("floppy-disk"), class = "btn-salvar"),
                  actionButton("btn_del_servidor", "Remover", icon = icon("trash"), class = "btn-remover")
                )
              ),
              DTOutput("out_tabela_servidores")
            )
          )
        )
      }

      do.call(tabsetPanel, c(list(id = "abas"), abas))
    })
  })


  # 6. TABELAS ----
  tabela_padrao <- function(dados, selection = "single", escape = TRUE, pageLength = 15, ordem = list()) {
    datatable(
      dados,
      extensions = "Buttons",
      selection = selection,
      rownames = FALSE,
      escape = escape,
      options = list(
        dom = "Blfrtip",
        buttons = c("copy", "excel", "pdf", "print"),
        pageLength = pageLength,
        order = ordem,
        lengthMenu = list(c(5, 10, 15, 25, 50, 100), c("5", "10", "15", "25", "50", "100")),
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
          paginate = list(first = "Primeiro", previous = "Anterior", `next` = "Próximo", last = "Último"),
          buttons = list(copy = "Copiar", excel = "Excel", pdf = "PDF", print = "Imprimir")
        )
      )
    )
  }

  # Índice da coluna (base 0 no DataTables) que não deve ser escapada
  sem_escape <- function(dados, coluna) setdiff(seq_along(dados), match(coluna, names(dados)))


  # 7. SERVIDOR: MINHAS ENTREGAS ----
  minhas_entregas <- reactive({
    req(eh_servidor(), ano_ciclo())
    entregas_refresh()
    dbGetQuery(
      pool_read,
      "SELECT * FROM entregas WHERE servidor = $1 AND ano = $2 ORDER BY data DESC, id DESC",
      params = list(usuario(), ano_ciclo())
    )
  })

  output$out_status_ano <- renderUI({
    req(eh_servidor(), input$in_ano_ciclo)
    if (ano_esta_aberto()) {
      div(class = "status-ano aberto", icon("lock-open"), "Ano aberto: lançamentos liberados")
    } else {
      div(class = "status-ano fechado", icon("lock"), "Ano fechado: apenas consulta")
    }
  })

  ## Ao trocar o ano: limita a data ao ano e escolhe o mês do resumo ----
  observeEvent(input$in_ano_ciclo, {
    req(eh_servidor())
    ano <- ano_ciclo()
    updateDateInput(
      session, "in_data",
      value = data_padrao_ciclo(ano),
      min   = as.Date(paste0(ano, "-01-01")),
      max   = as.Date(paste0(ano, "-12-31"))
    )
    dados <- minhas_entregas()
    mes <- if (format(Sys.Date(), "%Y") == as.character(ano)) {
      format(Sys.Date(), "%m")
    } else if (nrow(dados) > 0) {
      max(format(as.Date(dados$data), "%m"))
    } else {
      "01"
    }
    updateSelectInput(session, "in_mes_resumo", selected = mes)
  })

  entregas_do_mes <- reactive({
    req(input$in_mes_resumo)
    dados <- minhas_entregas()
    dados[format(as.Date(dados$data), "%m") == input$in_mes_resumo, , drop = FALSE]
  })

  output$out_kpis_mes <- renderUI({
    dados <- entregas_do_mes()
    ano <- minhas_entregas()
    nome_mes <- MESES[[input$in_mes_resumo]]

    concluidos <- sum(dados$status == "Concluído", na.rm = TRUE)
    horas_ano <- sum(ano$horas, na.rm = TRUE)
    meses_com_registro <- length(unique(format(as.Date(ano$data), "%m")))

    principal <- if (nrow(dados) > 0) {
      por_codigo <- tapply(dados$horas, dados$codigo, sum, na.rm = TRUE)
      names(por_codigo)[which.max(por_codigo)]
    }

    div(
      class = "grade-kpi",
      kpi(paste("Horas em", nome_mes), fmt_horas(sum(dados$horas, na.rm = TRUE)),
          paste(nrow(dados), if (nrow(dados) == 1) "lançamento" else "lançamentos"), destaque = TRUE),
      kpi("Entregas no mês", fmt_num(sum(dados$entregas, na.rm = TRUE), 0),
          paste(concluidos, "concluídas ·", nrow(dados) - concluidos, "em andamento")),
      kpi("Atividades no mês", length(unique(dados$codigo)),
          if (!is.null(principal)) paste("Maior esforço:", sub(" - .*", "", principal)) else "Nenhuma atividade registrada"),
      kpi(paste("Horas em", ano_ciclo()), fmt_horas(horas_ano),
          if (meses_com_registro > 0) paste("Média de", fmt_horas(horas_ano / meses_com_registro), "por mês com registro") else "Sem lançamentos no ano")
    )
  })

  output$out_esforco_mes <- renderUI({
    dados <- entregas_do_mes()
    if (nrow(dados) == 0) {
      return(div(class = "nenhum-registro", paste("Nenhum lançamento em", MESES[[input$in_mes_resumo]], "de", ano_ciclo(), ".")))
    }

    horas <- tapply(dados$horas, dados$codigo, sum, na.rm = TRUE)
    entregas <- tapply(dados$entregas, dados$codigo, sum, na.rm = TRUE)
    ordem <- order(horas, decreasing = TRUE)
    total <- sum(horas)

    div(
      class = "lista-esforco",
      lapply(seq_along(ordem), function(i) {
        codigo <- names(horas)[ordem[i]]
        percentual <- if (total > 0) horas[[codigo]] / total * 100 else 0
        div(
          class = "item-esforco",
          div(class = "esforco-nome", title = codigo, codigo),
          div(
            class = "esforco-valores",
            tags$b(paste0(fmt_num(percentual, 1), "%")), " · ", fmt_horas(horas[[codigo]]),
            " · ", fmt_num(entregas[[codigo]], 0), if (entregas[[codigo]] == 1) " entrega" else " entregas"
          ),
          div(class = "barra-esforco",
              tags$span(style = sprintf("width:%.1f%%; background:%s;", percentual,
                                        CORES_ESFORCO[(i - 1) %% length(CORES_ESFORCO) + 1])))
        )
      })
    )
  })

  ## Tabela e seleção ----
  output$out_tabela_entregas <- renderDT({
    dados <- minhas_entregas()
    exibir <- data.frame(
      Data = fmt_data(dados$data),
      Atividade = dados$codigo,
      Entregas = dados$entregas,
      Horas = dados$horas,
      `Situação` = selo_status(dados$status),
      check.names = FALSE
    )
    tabela_padrao(exibir, selection = "single", escape = sem_escape(exibir, "Situação"))
  })

  proxy_entregas <- dataTableProxy("out_tabela_entregas")

  entrega_selecionada <- reactive({
    sel <- input$out_tabela_entregas_rows_selected
    dados <- minhas_entregas()
    if (length(sel) != 1 || sel > nrow(dados)) return(NULL)
    dados[sel, , drop = FALSE]
  })

  observeEvent(entrega_selecionada(), {
    linha <- entrega_selecionada()
    updateDateInput(session, "in_data", value = as.Date(linha$data))
    updateSelectInput(session, "in_codigo",
                      choices = union(codigos_validos(), linha$codigo), selected = linha$codigo)
    updateNumericInput(session, "in_entregas", value = linha$entregas)
    updateNumericInput(session, "in_horas", value = linha$horas)
    updateSelectInput(session, "in_status", selected = linha$status)
  })

  output$out_modo_formulario <- renderUI({
    linha <- entrega_selecionada()
    div(
      class = "modo-formulario",
      if (is.null(linha)) tagList(icon("circle-plus"), "Novo lançamento")
      else tagList(icon("pen"), paste("Editando o lançamento de", fmt_data(linha$data)))
    )
  })

  limpar_formulario <- function() {
    selectRows(proxy_entregas, NULL)
    updateDateInput(session, "in_data", value = data_padrao_ciclo(ano_ciclo()))
    updateSelectInput(session, "in_codigo", choices = codigos_validos(), selected = codigos_validos()[1])
    updateNumericInput(session, "in_entregas", value = 0)
    updateNumericInput(session, "in_horas", value = 0)
    updateSelectInput(session, "in_status", selected = "Em andamento")
  }

  observeEvent(input$btn_limpar, {
    req(eh_servidor())
    limpar_formulario()
  })

  ## Bloqueio visual quando o ano está fechado ou sem seleção ----
  observe({
    req(eh_servidor(), input$in_ano_ciclo)
    aberto <- ano_esta_aberto()
    selecionada <- !is.null(entrega_selecionada())

    for (id in c("in_data", "in_codigo", "in_entregas", "in_horas", "in_status", "btn_add", "btn_limpar")) {
      shinyjs::toggleState(id, condition = aberto)
    }
    shinyjs::toggleState("btn_update", condition = aberto && selecionada)
    shinyjs::toggleState("btn_delete", condition = aberto && selecionada)
    shinyjs::toggleClass("caixa_formulario", "editando", condition = selecionada)
  })

  ## Validação no servidor (vale mesmo se o navegador for manipulado) ----
  validar_lancamento <- function(codigo_atual = NULL) {
    data <- input$in_data
    entregas <- input$in_entregas
    horas <- input$in_horas

    if (length(data) != 1 || is.na(data)) return("Informe a data do lançamento.")
    if (format(as.Date(data), "%Y") != as.character(ano_ciclo()))
      return(paste("A data deve estar dentro do ano do ciclo", ano_ciclo(), "."))
    if (!(input$in_codigo %in% c(codigos_validos(), codigo_atual))) return("Selecione uma atividade válida.")
    if (!is.numeric(entregas) || length(entregas) != 1 || is.na(entregas) || entregas < 0 || entregas != round(entregas))
      return("Informe a quantidade de entregas (número inteiro, zero ou maior).")
    if (!is.numeric(horas) || length(horas) != 1 || is.na(horas) || horas < 0 || horas > 744)
      return("Informe as horas dedicadas (entre 0 e 744).")
    if (entregas == 0 && horas == 0) return("Informe as horas dedicadas ou a quantidade de entregas.")
    if (!(input$in_status %in% STATUS_ENTREGA)) return("Selecione a situação da entrega.")
    NULL
  }

  ## Adicionar ----
  observeEvent(input$btn_add, {
    req(eh_servidor(), ano_ciclo())

    if (!ano_esta_aberto()) {
      showNotification("Ano fechado. Não é possível inserir entregas.", type = "error")
      return()
    }
    erro <- validar_lancamento()
    if (!is.null(erro)) {
      showNotification(erro, type = "warning")
      return()
    }

    ok <- gravar(
      dbExecute(
        pool_write,
        "INSERT INTO entregas (data, ano, codigo, entregas, horas, status, servidor)
         VALUES ($1, $2, $3, $4, $5, $6, $7)",
        params = list(
          as.character(input$in_data), ano_ciclo(), input$in_codigo,
          input$in_entregas, input$in_horas, input$in_status, usuario()
        )
      ),
      "Entrega adicionada."
    )
    if (ok) {
      marcar(entregas_refresh)
      limpar_formulario()
    }
  })

  ## Editar (com confirmação) ----
  id_pendente <- reactiveVal(NULL)

  observeEvent(input$btn_update, {
    req(eh_servidor())
    linha <- entrega_selecionada()
    req(linha)
    erro <- validar_lancamento(codigo_atual = linha$codigo)
    if (!is.null(erro)) {
      showNotification(erro, type = "warning")
      return()
    }
    id_pendente(linha$id)
    confirm_action(
      "confirm_update_entrega",
      message = paste("Salvar as alterações no lançamento de", fmt_data(linha$data), "?"),
      label_confirm = "Salvar alterações",
      class_confirm = "btn-salvar",
      icon_confirm = icon("floppy-disk")
    )
  })

  observeEvent(input$confirm_update_entrega, {
    removeModal()
    req(eh_servidor(), id_pendente())

    if (!ano_esta_aberto()) {
      showNotification("Ano fechado. Não é possível editar entregas.", type = "error")
      return()
    }

    ok <- gravar(
      dbExecute(
        pool_write,
        "UPDATE entregas SET data = $1, codigo = $2, entregas = $3, horas = $4, status = $5
         WHERE id = $6 AND servidor = $7",
        params = list(
          as.character(input$in_data), input$in_codigo, input$in_entregas,
          input$in_horas, input$in_status, id_pendente(), usuario()
        )
      ),
      "Entrega atualizada."
    )
    id_pendente(NULL)
    if (ok) {
      marcar(entregas_refresh)
      limpar_formulario()
    }
  })

  ## Remover (com confirmação) ----
  observeEvent(input$btn_delete, {
    req(eh_servidor())
    linha <- entrega_selecionada()
    req(linha)
    id_pendente(linha$id)
    confirm_action(
      "confirm_delete_entrega",
      message = paste0("Remover o lançamento de ", fmt_data(linha$data), " (", linha$codigo, ")? Esta ação não pode ser desfeita."),
      label_confirm = "Remover",
      icon_confirm = icon("trash")
    )
  })

  observeEvent(input$confirm_delete_entrega, {
    removeModal()
    req(eh_servidor(), id_pendente())

    if (!ano_esta_aberto()) {
      showNotification("Ano fechado. Não é possível remover entregas.", type = "error")
      return()
    }

    ok <- gravar(
      dbExecute(pool_write, "DELETE FROM entregas WHERE id = $1 AND servidor = $2",
                params = list(id_pendente(), usuario())),
      "Entrega removida."
    )
    id_pendente(NULL)
    if (ok) {
      marcar(entregas_refresh)
      limpar_formulario()
    }
  })


  # 8. RELATÓRIOS ----
  ## Opções dos filtros, preservando a escolha atual ----
  atualizar_filtro <- function(id, opcoes) {
    atual <- isolate(input[[id]])
    updateSelectInput(session, id, choices = c("Todos" = "Todos", opcoes),
                      selected = if (!is.null(atual) && atual %in% c("Todos", opcoes)) atual else "Todos")
  }

  observe({
    dados <- entregas_visiveis()
    req(input$in_filtro_ano)
    datas <- as.Date(dados$data)

    atualizar_filtro("in_filtro_ano", sort(unique(format(datas, "%Y")), decreasing = TRUE))
    meses <- sort(unique(format(datas, "%m")))
    atualizar_filtro("in_filtro_mes", setNames(meses, MESES[meses]))
    atualizar_filtro("in_filtro_codigo", sort(unique(dados$codigo)))

    if (eh_admin()) {
      siapes <- sort(unique(as.character(dados$servidor)))
      nomes <- dados$nome_servidor[match(siapes, as.character(dados$servidor))]
      atualizar_filtro("in_filtro_servidor", setNames(siapes, ifelse(is.na(nomes), siapes, paste0(nomes, " (", siapes, ")"))))
    }
  })

  dados_relatorio <- reactive({
    dados <- entregas_visiveis()
    datas <- as.Date(dados$data)
    manter <- rep(TRUE, nrow(dados))

    if (!is.null(input$in_filtro_ano) && input$in_filtro_ano != "Todos")
      manter <- manter & format(datas, "%Y") == input$in_filtro_ano
    if (!is.null(input$in_filtro_mes) && input$in_filtro_mes != "Todos")
      manter <- manter & format(datas, "%m") == input$in_filtro_mes
    if (eh_admin() && !is.null(input$in_filtro_servidor) && input$in_filtro_servidor != "Todos")
      manter <- manter & as.character(dados$servidor) == input$in_filtro_servidor
    if (!is.null(input$in_filtro_codigo) && input$in_filtro_codigo != "Todos")
      manter <- manter & dados$codigo == input$in_filtro_codigo

    dados[manter, , drop = FALSE]
  })

  output$out_kpis_relatorio <- renderUI({
    dados <- dados_relatorio()
    meses <- length(unique(format(as.Date(dados$data), "%Y-%m")))
    horas <- sum(dados$horas, na.rm = TRUE)

    div(
      class = "grade-kpi",
      kpi("Horas no período", fmt_horas(horas), paste(meses, if (meses == 1) "mês com registro" else "meses com registro"), destaque = TRUE),
      kpi("Entregas", fmt_num(sum(dados$entregas, na.rm = TRUE), 0), paste(nrow(dados), "lançamentos")),
      kpi("Atividades", length(unique(dados$codigo)), "códigos distintos"),
      if (eh_admin()) kpi("Servidores", length(unique(dados$servidor)), "com lançamentos no filtro")
      else kpi("Média mensal", fmt_horas(if (meses > 0) horas / meses else 0), "horas por mês com registro")
    )
  })

  output$out_tabela_relatorio <- renderDT({
    dados <- dados_relatorio()

    if (nrow(dados) == 0) {
      return(tabela_padrao(
        data.frame(Mensagem = "Nenhum registro encontrado para os filtros selecionados."),
        selection = "none"
      ))
    }

    dados$ano <- format(as.Date(dados$data), "%Y")
    dados$mes <- format(as.Date(dados$data), "%m")

    # Esforço = participação de cada atividade nas horas do mês
    resumo <- aggregate(cbind(entregas, horas) ~ ano + mes + codigo, data = dados, FUN = sum)
    total_mes <- aggregate(horas ~ ano + mes, data = dados, FUN = sum)
    total <- total_mes$horas[match(paste(resumo$ano, resumo$mes), paste(total_mes$ano, total_mes$mes))]
    resumo$percentual <- ifelse(total > 0, round(resumo$horas / total * 100, 1), 0)
    resumo <- resumo[order(resumo$ano, resumo$mes, -resumo$horas, decreasing = c(TRUE, TRUE, FALSE), method = "radix"), ]

    exibir <- data.frame(
      Ano = resumo$ano,
      `Mês` = unname(MESES[resumo$mes]),
      Atividade = resumo$codigo,
      Entregas = resumo$entregas,
      Horas = resumo$horas,
      `Esforço no mês (%)` = resumo$percentual,
      check.names = FALSE
    )
    formatRound(tabela_padrao(exibir, selection = "none"), c("Horas", "Esforço no mês (%)"),
                digits = 1, mark = ".", dec.mark = ",")
  })


  # 9. ADMINISTRAÇÃO ----
  # Toda saída e ação administrativa exige eh_admin() no servidor.

  ## Todas as entregas ----
  output$out_kpis_todos <- renderUI({
    req(eh_admin())
    dados <- entregas_visiveis()
    div(
      class = "grade-kpi",
      kpi("Lançamentos", fmt_num(nrow(dados), 0), "em todos os anos", destaque = TRUE),
      kpi("Horas registradas", fmt_horas(sum(dados$horas, na.rm = TRUE))),
      kpi("Entregas", fmt_num(sum(dados$entregas, na.rm = TRUE), 0)),
      kpi("Servidores", length(unique(dados$servidor)), "com lançamentos")
    )
  })

  output$out_tabela_todos <- renderDT({
    req(eh_admin())
    dados <- entregas_visiveis()
    dados <- dados[order(as.Date(dados$data), decreasing = TRUE), , drop = FALSE]
    exibir <- data.frame(
      Data = fmt_data(dados$data),
      Servidor = ifelse(is.na(dados$nome_servidor), "", dados$nome_servidor),
      SIAPE = dados$servidor,
      Atividade = dados$codigo,
      Entregas = dados$entregas,
      Horas = dados$horas,
      `Situação` = selo_status(dados$status),
      Ano = dados$ano,
      check.names = FALSE
    )
    tabela_padrao(exibir, selection = "none", escape = sem_escape(exibir, "Situação"))
  })

  ## Anos do ciclo ----
  tb_anos <- reactive({
    req(eh_admin())
    admin_refresh()
    dbGetQuery(pool_read, "SELECT * FROM anos_ciclo ORDER BY ano DESC")
  })

  output$out_tabela_anos <- renderDT({
    dados <- tb_anos()
    exibir <- dados
    exibir$ano <- as.character(exibir$ano)
    exibir$status <- selo_ano(exibir$status)
    names(exibir)[names(exibir) == "ano"] <- "Ano"
    names(exibir)[names(exibir) == "status"] <- "Situação"
    tabela_padrao(exibir, escape = sem_escape(exibir, "Situação"), pageLength = 10)
  })

  ano_selecionado <- reactive({
    sel <- input$out_tabela_anos_rows_selected
    dados <- tb_anos()
    if (length(sel) != 1 || sel > nrow(dados)) return(NULL)
    dados[sel, , drop = FALSE]
  })

  observeEvent(ano_selecionado(), {
    linha <- ano_selecionado()
    updateNumericInput(session, "in_ano", value = linha$ano)
    updateSelectInput(session, "in_status_ano", selected = linha$status)
  })

  observe({
    req(eh_admin())
    selecionado <- !is.null(ano_selecionado())
    shinyjs::toggleState("btn_edit_ano", condition = selecionado)
    shinyjs::toggleState("btn_del_ano", condition = selecionado)
  })

  output$out_tabela_audit_anos <- renderDT({
    req(eh_admin())
    admin_refresh()
    dados <- dbGetQuery(
      pool_read,
      "SELECT momento, usuario, acao, referencia AS ano, ip
       FROM audit_logs
       WHERE entidade = 'ano_ciclo'
       ORDER BY momento DESC"
    )
    if (nrow(dados) > 0) dados$momento <- format(as.POSIXct(dados$momento), "%d/%m/%Y %H:%M")
    names(dados) <- c("Momento", "Usuário", "Ação", "Ano", "IP")[seq_along(dados)]
    tabela_padrao(dados, selection = "none", pageLength = 10)
  })

  # Ao abrir um ano, os demais são fechados na mesma transação (só um ano aberto)
  definir_status_ano <- function(con, ano, status) {
    if (status == "aberto") {
      dbExecute(con, "UPDATE anos_ciclo SET status = 'fechado' WHERE ano <> $1", params = list(ano))
    }
    dbExecute(con, "UPDATE anos_ciclo SET status = $1 WHERE ano = $2", params = list(status, ano))
  }

  observeEvent(input$btn_add_ano, {
    req(eh_admin())
    ano <- input$in_ano
    status <- input$in_status_ano
    if (!is.numeric(ano) || is.na(ano) || ano < 2000 || ano > 2100 || ano != round(ano)) {
      showNotification("Informe um ano válido.", type = "warning")
      return()
    }
    req(status %in% c("aberto", "fechado"))

    existe <- dbGetQuery(pool_read, "SELECT COUNT(*) FROM anos_ciclo WHERE ano = $1", params = list(ano))
    if (existe[1, 1] > 0) {
      showNotification("Este ano já existe.", type = "warning")
      return()
    }

    ok <- gravar(
      pool::poolWithTransaction(pool_write, function(con) {
        dbExecute(con, "INSERT INTO anos_ciclo (ano, status) VALUES ($1, 'fechado')", params = list(ano))
        definir_status_ano(con, ano, status)
      }),
      "Ano adicionado."
    )
    if (ok) {
      registrar_auditoria(paste("criou ano com status", status), "ano_ciclo", as.character(ano))
      marcar(admin_refresh)
    }
  })

  ano_pendente <- reactiveVal(NULL)

  observeEvent(input$btn_edit_ano, {
    req(eh_admin())
    linha <- ano_selecionado()
    req(linha)
    req(input$in_status_ano %in% c("aberto", "fechado"))
    ano_pendente(list(ano = linha$ano, status = input$in_status_ano))
    confirm_action(
      "confirm_edit_ano",
      message = paste0(
        "Alterar a situação do ano ", linha$ano, " para \"", input$in_status_ano, "\"?",
        if (input$in_status_ano == "aberto") " Os demais anos serão fechados." else ""
      ),
      label_confirm = "Alterar situação",
      class_confirm = "btn-salvar",
      icon_confirm = icon("floppy-disk")
    )
  })

  observeEvent(input$confirm_edit_ano, {
    removeModal()
    req(eh_admin(), ano_pendente())
    alvo <- ano_pendente()
    ano_pendente(NULL)

    ok <- gravar(
      pool::poolWithTransaction(pool_write, function(con) definir_status_ano(con, alvo$ano, alvo$status)),
      "Situação do ano atualizada."
    )
    if (ok) {
      registrar_auditoria(paste("alterou status para", alvo$status), "ano_ciclo", as.character(alvo$ano))
      marcar(admin_refresh)
    }
  })

  # Nunca permitir apagar ano que tenha entregas
  observeEvent(input$btn_del_ano, {
    req(eh_admin())
    linha <- ano_selecionado()
    req(linha)

    qtd <- dbGetQuery(pool_read, "SELECT COUNT(*) FROM entregas WHERE ano = $1", params = list(linha$ano))
    if (qtd[1, 1] > 0) {
      showNotification("Este ano possui entregas registradas e não pode ser removido.", type = "error")
      return()
    }
    ano_pendente(list(ano = linha$ano))
    confirm_action(
      "confirm_delete_ano",
      message = paste("Remover o ano", linha$ano, "? Esta ação não pode ser desfeita."),
      label_confirm = "Remover",
      icon_confirm = icon("trash")
    )
  })

  observeEvent(input$confirm_delete_ano, {
    removeModal()
    req(eh_admin(), ano_pendente())
    alvo <- ano_pendente()
    ano_pendente(NULL)

    ok <- gravar(
      dbExecute(pool_write, "DELETE FROM anos_ciclo WHERE ano = $1", params = list(alvo$ano)),
      "Ano removido."
    )
    if (ok) {
      registrar_auditoria("removeu ano", "ano_ciclo", as.character(alvo$ano))
      marcar(admin_refresh)
    }
  })

  ## Atividades (códigos) ----
  tb_codigos <- reactive({
    req(eh_admin())
    admin_refresh()
    dbGetQuery(pool_read, "SELECT * FROM codigos_entrega ORDER BY codigo")
  })

  output$out_tabela_codigos <- renderDT({
    dados <- tb_codigos()
    exibir <- dados[, intersect(c("codigo", "descricao"), names(dados)), drop = FALSE]
    names(exibir) <- c("Código", "Descrição")[seq_along(exibir)]
    tabela_padrao(exibir)
  })

  codigo_selecionado <- reactive({
    sel <- input$out_tabela_codigos_rows_selected
    dados <- tb_codigos()
    if (length(sel) != 1 || sel > nrow(dados)) return(NULL)
    dados[sel, , drop = FALSE]
  })

  observeEvent(codigo_selecionado(), {
    linha <- codigo_selecionado()
    updateTextInput(session, "in_codigo_id", value = linha$codigo)
    updateTextInput(session, "in_codigo_desc", value = linha$descricao)
  })

  observe({
    req(eh_admin())
    selecionado <- !is.null(codigo_selecionado())
    shinyjs::toggleState("btn_edit_codigo", condition = selecionado)
    shinyjs::toggleState("btn_del_codigo", condition = selecionado)
  })

  observeEvent(input$btn_add_codigo, {
    req(eh_admin())
    codigo <- texto_limpo(input$in_codigo_id)
    descricao <- texto_limpo(input$in_codigo_desc)
    if (!nzchar(codigo) || !nzchar(descricao)) {
      showNotification("Informe o código e a descrição.", type = "warning")
      return()
    }

    existe <- dbGetQuery(pool_read, "SELECT COUNT(*) FROM codigos_entrega WHERE codigo = $1", params = list(codigo))
    if (existe[1, 1] > 0) {
      showNotification("Este código já está cadastrado.", type = "warning")
      return()
    }

    ok <- gravar(
      dbExecute(pool_write, "INSERT INTO codigos_entrega (codigo, descricao) VALUES ($1, $2)",
                params = list(codigo, descricao)),
      "Atividade adicionada."
    )
    if (ok) {
      marcar(admin_refresh)
      updateTextInput(session, "in_codigo_id", value = "")
      updateTextInput(session, "in_codigo_desc", value = "")
    }
  })

  codigo_pendente <- reactiveVal(NULL)

  observeEvent(input$btn_edit_codigo, {
    req(eh_admin())
    linha <- codigo_selecionado()
    req(linha)
    codigo <- texto_limpo(input$in_codigo_id)
    descricao <- texto_limpo(input$in_codigo_desc)
    if (!nzchar(codigo) || !nzchar(descricao)) {
      showNotification("Informe o código e a descrição.", type = "warning")
      return()
    }
    codigo_pendente(list(id = linha$id, codigo = codigo, descricao = descricao))
    confirm_action(
      "confirm_edit_codigo",
      message = paste0("Salvar as alterações na atividade ", linha$codigo, "?"),
      label_confirm = "Salvar alterações",
      class_confirm = "btn-salvar",
      icon_confirm = icon("floppy-disk")
    )
  })

  observeEvent(input$confirm_edit_codigo, {
    removeModal()
    req(eh_admin(), codigo_pendente())
    alvo <- codigo_pendente()
    codigo_pendente(NULL)

    existe <- dbGetQuery(
      pool_read,
      "SELECT COUNT(*) FROM codigos_entrega WHERE codigo = $1 AND id != $2",
      params = list(alvo$codigo, alvo$id)
    )
    if (existe[1, 1] > 0) {
      showNotification("Já existe uma atividade com este código.", type = "warning")
      return()
    }

    ok <- gravar(
      dbExecute(pool_write, "UPDATE codigos_entrega SET codigo = $1, descricao = $2 WHERE id = $3",
                params = list(alvo$codigo, alvo$descricao, alvo$id)),
      "Atividade atualizada."
    )
    if (ok) marcar(admin_refresh)
  })

  observeEvent(input$btn_del_codigo, {
    req(eh_admin())
    linha <- codigo_selecionado()
    req(linha)
    codigo_pendente(list(id = linha$id))
    confirm_action(
      "confirm_delete_codigo",
      message = paste0("Remover a atividade ", linha$codigo, " - ", linha$descricao, "? Os lançamentos já registrados não são alterados."),
      label_confirm = "Remover",
      icon_confirm = icon("trash")
    )
  })

  observeEvent(input$confirm_delete_codigo, {
    removeModal()
    req(eh_admin(), codigo_pendente())
    alvo <- codigo_pendente()
    codigo_pendente(NULL)

    ok <- gravar(
      dbExecute(pool_write, "DELETE FROM codigos_entrega WHERE id = $1", params = list(alvo$id)),
      "Atividade removida."
    )
    if (ok) {
      marcar(admin_refresh)
      updateTextInput(session, "in_codigo_id", value = "")
      updateTextInput(session, "in_codigo_desc", value = "")
    }
  })

  ## Servidores ----
  tb_servidores <- reactive({
    req(eh_admin())
    admin_refresh()
    dbGetQuery(pool_read, "SELECT * FROM servidores ORDER BY nome")
  })

  output$out_tabela_servidores <- renderDT({
    dados <- tb_servidores()
    # A senha (mesmo em hash) nunca sai do servidor
    exibir <- data.frame(
      SIAPE = dados$siape,
      Nome = dados$nome,
      `Senha configurada` = ifelse(is.na(dados$senha_hash) | dados$senha_hash == "", "Não", "Sim"),
      check.names = FALSE
    )
    tabela_padrao(exibir)
  })

  servidor_selecionado <- reactive({
    sel <- input$out_tabela_servidores_rows_selected
    dados <- tb_servidores()
    if (length(sel) != 1 || sel > nrow(dados)) return(NULL)
    dados[sel, c("siape", "nome"), drop = FALSE]
  })

  observeEvent(servidor_selecionado(), {
    linha <- servidor_selecionado()
    updateTextInput(session, "in_servidor_siape", value = linha$siape)
    updateTextInput(session, "in_servidor_nome", value = linha$nome)
  })

  observe({
    req(eh_admin())
    selecionado <- !is.null(servidor_selecionado())
    shinyjs::toggleState("btn_edit_servidor", condition = selecionado)
    shinyjs::toggleState("btn_del_servidor", condition = selecionado)
  })

  observeEvent(input$btn_add_servidor, {
    req(eh_admin())
    siape <- texto_limpo(input$in_servidor_siape)
    nome <- texto_limpo(input$in_servidor_nome)
    if (!nzchar(siape) || !nzchar(nome)) {
      showNotification("Informe o SIAPE e o nome.", type = "warning")
      return()
    }

    existe <- dbGetQuery(pool_read, "SELECT COUNT(*) FROM servidores WHERE siape = $1", params = list(siape))
    if (existe[1, 1] > 0) {
      showNotification("Este servidor já está cadastrado.", type = "warning")
      return()
    }

    ok <- gravar(
      dbExecute(pool_write, "INSERT INTO servidores (siape, nome) VALUES ($1, $2)", params = list(siape, nome)),
      "Servidor adicionado."
    )
    if (ok) {
      marcar(admin_refresh)
      updateTextInput(session, "in_servidor_siape", value = "")
      updateTextInput(session, "in_servidor_nome", value = "")
    }
  })

  servidor_pendente <- reactiveVal(NULL)

  observeEvent(input$btn_edit_servidor, {
    req(eh_admin())
    linha <- servidor_selecionado()
    req(linha)
    siape <- texto_limpo(input$in_servidor_siape)
    nome <- texto_limpo(input$in_servidor_nome)
    if (!nzchar(siape) || !nzchar(nome)) {
      showNotification("Informe o SIAPE e o nome.", type = "warning")
      return()
    }
    servidor_pendente(list(siape_atual = linha$siape, siape = siape, nome = nome))
    confirm_action(
      "confirm_edit_servidor",
      message = paste0("Salvar as alterações no cadastro de ", linha$nome, "?"),
      label_confirm = "Salvar alterações",
      class_confirm = "btn-salvar",
      icon_confirm = icon("floppy-disk")
    )
  })

  observeEvent(input$confirm_edit_servidor, {
    removeModal()
    req(eh_admin(), servidor_pendente())
    alvo <- servidor_pendente()
    servidor_pendente(NULL)

    existe <- dbGetQuery(
      pool_read,
      "SELECT COUNT(*) FROM servidores WHERE siape = $1 AND siape != $2",
      params = list(alvo$siape, alvo$siape_atual)
    )
    if (existe[1, 1] > 0) {
      showNotification("Já existe um servidor com este SIAPE.", type = "warning")
      return()
    }

    ok <- gravar(
      dbExecute(pool_write, "UPDATE servidores SET siape = $1, nome = $2 WHERE siape = $3",
                params = list(alvo$siape, alvo$nome, alvo$siape_atual)),
      "Servidor atualizado."
    )
    if (ok) {
      marcar(admin_refresh)
      marcar(entregas_refresh)
    }
  })

  observeEvent(input$btn_del_servidor, {
    req(eh_admin())
    linha <- servidor_selecionado()
    req(linha)

    entregas <- dbGetQuery(pool_read, "SELECT COUNT(*) FROM entregas WHERE servidor = $1", params = list(linha$siape))
    if (entregas[1, 1] > 0) {
      showNotification("Este servidor possui entregas registradas. Remova as entregas antes de excluir.", type = "error")
      return()
    }
    servidor_pendente(list(siape_atual = linha$siape))
    confirm_action(
      "confirm_delete_servidor",
      message = paste0("Remover o servidor ", linha$nome, " (SIAPE ", linha$siape, ")? Esta ação não pode ser desfeita."),
      label_confirm = "Remover",
      icon_confirm = icon("trash")
    )
  })

  observeEvent(input$confirm_delete_servidor, {
    removeModal()
    req(eh_admin(), servidor_pendente())
    alvo <- servidor_pendente()
    servidor_pendente(NULL)

    ok <- gravar(
      dbExecute(pool_write, "DELETE FROM servidores WHERE siape = $1", params = list(alvo$siape_atual)),
      "Servidor removido."
    )
    if (ok) {
      marcar(admin_refresh)
      updateTextInput(session, "in_servidor_siape", value = "")
      updateTextInput(session, "in_servidor_nome", value = "")
    }
  })
}
