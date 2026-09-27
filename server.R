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

  # 2.2 Auditoria das ações administrativas.
  # Guardamos apenas quem fez, o que fez e sobre qual registro: nada de endereço
  # de rede ou navegador, para coletar somente o necessário (LGPD, art. 6º, III).
  # try(..., silent = TRUE) garante que a auditoria nunca derruba o app.
  registrar_auditoria <- function(acao, entidade, referencia = NULL) {
    try({
      dbExecute(
        pool_write,
        "INSERT INTO audit_logs (usuario, acao, entidade, referencia)
         VALUES ($1, $2, $3, $4)",
        params = list(usuario(), acao, entidade, referencia)
      )
    }, silent = TRUE)
  }

  # Registro de acesso: SIAPE, momento e se a tentativa deu certo.
  registrar_login <- function(siape, sucesso) {
    try({
      dbExecute(
        pool_write,
        "INSERT INTO login_logs (siape, momento, sucesso)
         VALUES ($1, now(), $2)",
        params = list(siape, sucesso)
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
      # Rascunhos do lançamento mensal ficam reservados até o servidor enviar
      dados <- if (ESQUEMA_MENSAL) {
        dbGetQuery(pool_read, "SELECT * FROM entregas WHERE envio = 'enviado'")
      } else {
        dbGetQuery(pool_read, "SELECT * FROM entregas")
      }
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
        tagList(icon("chart-column"), "Relatórios"), value = "Relatórios",
        div(
          class = "painel painel-azul",
          div(
            class = "cabecalho-secao",
            h4(icon("chart-column"), "Relatório de esforço"),
            uiOutput("out_escopo_relatorio", inline = TRUE)
          ),
          p(
            class = "explicacao",
            if (admin) paste("Soma das entregas de todos os servidores em cada atividade e mês, que é o consolidado usado para alimentar a ferramenta oficial.",
                             "Escolha um servidor no filtro para ver o consolidado apenas dele; o detalhe de cada lançamento fica na aba Todas as entregas.")
            else "Consolidado das suas entregas. Filtre por ano, mês ou atividade; o esforço mostra a participação de cada atividade nas suas horas do mês."
          ),
          fluidRow(
            column(3, selectInput("in_filtro_ano", "Ano", choices = "Todos", width = "100%")),
            column(3, selectInput("in_filtro_mes", "Mês", choices = "Todos", width = "100%")),
            if (admin) column(3, selectInput("in_filtro_servidor", "Servidor", choices = "Todos", width = "100%")),
            column(if (admin) 3 else 6, selectInput("in_filtro_codigo", "Atividade", choices = "Todos", width = "100%"))
          ),
          uiOutput("out_kpis_relatorio"),
          DTOutput("out_tabela_relatorio"),
          uiOutput("out_nota_relatorio")
        )
      )

      aba_lancamento_mensal <- if (!admin && ESQUEMA_MENSAL) tabPanel(
        tagList(icon("table-cells"), "Lançamento mensal"), value = "Lançamento mensal",
        div(
          class = "painel painel-azul",
          div(
            class = "cabecalho-secao",
            h4(icon("table-cells"), "Lançamento mensal"),
            div(
              class = "acoes-secao",
              div(class = "tag-secao tag-verde", "Rascunho visível só para você"),
              div(class = "tag-secao", "Editável a qualquer momento"),
              uiOutput("out_mm_status", inline = TRUE)
            )
          ),
          uiOutput("out_mm_explicacao"),
          fluidRow(
            column(4, selectInput("in_mm_codigo", "Atividade", choices = NULL, width = "100%")),
            column(8, uiOutput("out_mm_resumo_atividade"))
          ),
          uiOutput("out_mm_matriz"),
          div(
            id = "acoes_mensais",
            class = "barra-acoes",
            actionButton("btn_mm_guardar", "Guardar rascunho", icon = icon("floppy-disk"), class = "btn-salvar"),
            actionButton("btn_mm_enviar", "Enviar ao gestor", icon = icon("paper-plane"), class = "btn-adicionar"),
            actionButton("btn_mm_recarregar", "Descartar alterações", icon = icon("rotate-left"), class = "btn-neutro")
          )
        ),
        div(
          class = "painel painel-verde",
          cabecalho_secao("table-list", "Consolidado do ano", "Atividades por mês", "tag-verde"),
          p(class = "explicacao",
            "Todas as entregas do ano, somando o lançamento diário e o mensal."),
          uiOutput("out_mm_consolidado")
        )
      )

      if (!admin) {
        abas <- list(
          tabPanel(
            tagList(icon("list-check"), "Minhas entregas"), value = "Minhas entregas",
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
              div(class = "titulo-bloco", "Distribuição do esforço por atividade"),
              uiOutput("out_esforco_mes")
            ),
            ## Lançamentos ----
            div(
              class = "painel painel-verde",
              div(
                class = "cabecalho-secao",
                h4(icon("pen-to-square"), "Lançamentos do ano"),
                div(
                  class = "acoes-secao",
                  div(class = "tag-secao tag-verde", "Somente você vê estes dados"),
                  actionButton("btn_novo", "Novo lançamento", icon = icon("plus"), class = "btn-adicionar")
                )
              ),
              p(
                class = "explicacao",
                "Cada lançamento é um cartão. Clique no cartão para editar ou remover quando quiser, com confirmação. As alterações são livres enquanto o ano do ciclo estiver aberto."
              ),
              div(
                class = "barra-filtros",
                div(class = "filtro",
                    selectInput("in_f_mes", "Mês", choices = c("Todos os meses" = "Todos"), width = "100%")),
                div(class = "filtro filtro-largo",
                    selectInput("in_f_codigo", "Atividade", choices = c("Todas as atividades" = "Todos"), width = "100%")),
                div(class = "filtro filtro-chips",
                    radioButtons("in_f_status", "Situação", inline = TRUE, selected = "Todas",
                                 choices = c("Todas", "Em andamento", "Concluído"))),
                div(class = "filtro filtro-acao",
                    actionButton("btn_limpar_filtros", "Limpar filtros",
                                 icon = icon("filter-circle-xmark"), class = "btn-neutro"))
              ),
              uiOutput("out_lista_entregas")
            )
          ),
          if (ESQUEMA_MENSAL) aba_lancamento_mensal,
          aba_relatorios
        )
        abas <- abas[!vapply(abas, is.null, logical(1))]
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
              div(
                class = "cabecalho-secao",
                h4(icon("calendar-check"), "Anos do ciclo"),
                div(
                  class = "acoes-secao",
                  div(class = "tag-secao", "Apenas um ano aberto"),
                  actionButton("btn_novo_ano", "Novo ano", icon = icon("plus"), class = "btn-adicionar")
                )
              ),
              p(class = "explicacao", "Ao abrir um ano, os demais são fechados automaticamente. Anos com entregas registradas não podem ser removidos."),
              uiOutput("out_lista_anos"),
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
              div(
                class = "cabecalho-secao",
                h4(icon("tags"), "Atividades disponíveis"),
                div(
                  class = "acoes-secao",
                  div(class = "tag-secao", "Códigos de entrega"),
                  actionButton("btn_nova_atividade", "Nova atividade", icon = icon("plus"), class = "btn-adicionar")
                )
              ),
              p(class = "explicacao", "Atividades que os servidores escolhem ao registrar suas entregas. Clique em uma atividade para editar ou remover."),
              uiOutput("out_lista_codigos")
            )
          ),
          ## Admin -> Servidores ----
          tabPanel(
            tagList(icon("users"), "Servidores"),
            div(
              class = "painel painel-navy",
              div(
                class = "cabecalho-secao",
                h4(icon("users"), "Servidores"),
                div(
                  class = "acoes-secao",
                  div(class = "tag-secao", "Acesso ao sistema"),
                  actionButton("btn_novo_servidor", "Novo servidor", icon = icon("plus"), class = "btn-adicionar")
                )
              ),
              p(class = "explicacao", "Clique em um servidor para editar nome e SIAPE. Servidores com entregas registradas não podem ser removidos. As senhas nunca são exibidas."),
              uiOutput("out_lista_servidores")
            )
          )
        )
      }

      do.call(tabsetPanel, c(list(id = "abas"), abas))
    })
  })


  # 6. TABELAS ----
  # `ocultar_mobile`: colunas secundárias, escondidas em telas estreitas pelo CSS.
  # `titulo`/`chave`: quando informados, a tabela ganha o menu de exportação.
  tabela_padrao <- function(dados, selection = "single", escape = TRUE, pageLength = 15,
                            ordem = list(), ocultar_mobile = character(), alinhar_direita = character(),
                            titulo = NULL, chave = "", ocultar = character()) {
    indices <- function(nomes) match(intersect(nomes, names(dados)), names(dados)) - 1L
    coluna <- function(nomes) as.list(match(intersect(nomes, names(dados)), names(dados)) - 1L)
    definicoes <- c(
      lapply(coluna(ocultar_mobile), function(i) list(targets = i, className = "ocultar-mobile")),
      lapply(coluna(alinhar_direita), function(i) list(targets = i, className = "dt-right")),
      # Colunas de apoio: invisíveis na tela e na exportação, mas pesquisáveis,
      # o que permite aplicar os filtros como busca da própria tabela
      lapply(coluna(ocultar), function(i) list(targets = i, visible = FALSE, searchable = TRUE))
    )

    datatable(
      dados,
      extensions = "Buttons",
      selection = selection,
      rownames = FALSE,
      escape = escape,
      options = list(
        dom = if (is.null(titulo)) "lfrtip" else "Blfrtip",
        buttons = if (is.null(titulo)) list() else botoes_exportacao(
          titulo, chave,
          direita = indices(alinhar_direita),
          # A coluna mais descritiva fica com a largura flexível no PDF
          flexivel = indices("Atividade")
        ),
        pageLength = pageLength,
        order = ordem,
        columnDefs = definicoes,
        autoWidth = FALSE,
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
          paginate = list(first = "Primeiro", previous = "Anterior", `next` = "Próximo", last = "Último")
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

  ## Ao trocar o ano, o resumo vai para o mês mais relevante ----
  observeEvent(input$in_ano_ciclo, {
    req(eh_servidor())
    ano <- ano_ciclo()
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

  observe({
    req(eh_servidor(), input$in_ano_ciclo)
    shinyjs::toggle("btn_novo", condition = ano_esta_aberto())
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

    # Sem horas informadas no mês, o esforço é estimado pelas entregas
    estimado <- sum(horas, na.rm = TRUE) == 0
    base <- if (estimado) entregas else horas
    ordem <- order(base, decreasing = TRUE)
    total <- sum(base, na.rm = TRUE)

    tagList(
    if (estimado) div(class = "aviso-estimado", icon("circle-info"),
                      "Sem horas informadas neste mês: o esforço está estimado pela quantidade de entregas."),
    div(
      class = "lista-esforco",
      lapply(seq_along(ordem), function(i) {
        codigo <- names(base)[ordem[i]]
        percentual <- if (total > 0) base[[codigo]] / total * 100 else 0
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
    ))
  })

  ## Filtros da lista de lançamentos ----
  observe({
    req(eh_servidor())
    dados <- minhas_entregas()

    meses <- sort(unique(format(as.Date(dados$data), "%m")), decreasing = TRUE)
    atual_mes <- isolate(input$in_f_mes)
    updateSelectInput(
      session, "in_f_mes",
      choices = c("Todos os meses" = "Todos", setNames(meses, MESES[meses])),
      selected = if (!is.null(atual_mes) && atual_mes %in% c("Todos", meses)) atual_mes else "Todos"
    )

    codigos <- sort(unique(dados$codigo))
    atual_codigo <- isolate(input$in_f_codigo)
    updateSelectInput(
      session, "in_f_codigo",
      choices = c("Todas as atividades" = "Todos", setNames(codigos, codigos)),
      selected = if (!is.null(atual_codigo) && atual_codigo %in% c("Todos", codigos)) atual_codigo else "Todos"
    )
  })

  observeEvent(input$btn_limpar_filtros, {
    req(eh_servidor())
    updateSelectInput(session, "in_f_mes", selected = "Todos")
    updateSelectInput(session, "in_f_codigo", selected = "Todos")
    updateRadioButtons(session, "in_f_status", selected = "Todas")
  })

  filtros_ativos <- reactive({
    ativos <- c(
      if (!is.null(input$in_f_mes) && input$in_f_mes != "Todos") MESES[[input$in_f_mes]],
      if (!is.null(input$in_f_codigo) && input$in_f_codigo != "Todos") input$in_f_codigo,
      if (!is.null(input$in_f_status) && input$in_f_status != "Todas") input$in_f_status
    )
    ativos
  })

  entregas_filtradas <- reactive({
    dados <- minhas_entregas()
    if (nrow(dados) == 0) return(dados)

    manter <- rep(TRUE, nrow(dados))
    if (!is.null(input$in_f_mes) && input$in_f_mes != "Todos")
      manter <- manter & format(as.Date(dados$data), "%m") == input$in_f_mes
    if (!is.null(input$in_f_codigo) && input$in_f_codigo != "Todos")
      manter <- manter & dados$codigo == input$in_f_codigo
    if (!is.null(input$in_f_status) && input$in_f_status != "Todas")
      manter <- manter & dados$status == input$in_f_status

    dados[manter, , drop = FALSE]
  })

  ## Lista de lançamentos em cartões ----
  output$out_lista_entregas <- renderUI({
    todos <- minhas_entregas()
    dados <- entregas_filtradas()
    aberto <- ano_esta_aberto()

    if (nrow(todos) == 0) {
      return(div(
        class = "nenhum-registro",
        paste0("Nenhum lançamento em ", ano_ciclo(), "."),
        if (aberto) tagList(br(), "Use \u201cNovo lançamento\u201d para registrar o primeiro.")
      ))
    }

    if (nrow(dados) == 0) {
      return(div(
        class = "nenhum-registro",
        "Nenhum lançamento corresponde aos filtros escolhidos.",
        br(), "Use \u201cLimpar filtros\u201d para ver todos os ", nrow(todos), " lançamentos do ano."
      ))
    }

    resumo_filtro <- if (length(filtros_ativos()) > 0) {
      div(
        class = "resumo-filtro",
        icon("filter"),
        sprintf("Mostrando %d de %d lançamentos do ano · %s",
                nrow(dados), nrow(todos), paste(filtros_ativos(), collapse = " · "))
      )
    }

    meses <- format(as.Date(dados$data), "%m")
    tagList(
    resumo_filtro,
    div(
      class = "lista-entregas",
      lapply(sort(unique(meses), decreasing = TRUE), function(mes) {
        grupo <- dados[meses == mes, , drop = FALSE]
        tagList(
          div(
            class = "grupo-mes",
            span(class = "grupo-nome", MESES[[mes]]),
            span(
              class = "grupo-resumo",
              fmt_horas(sum(grupo$horas, na.rm = TRUE)), " · ",
              fmt_num(sum(grupo$entregas, na.rm = TRUE), 0), " entregas · ",
              nrow(grupo), if (nrow(grupo) == 1) " lançamento" else " lançamentos"
            )
          ),
          lapply(seq_len(nrow(grupo)), function(i) cartao_entrega(grupo[i, , drop = FALSE], aberto))
        )
      })
    ))
  })

  ## Formulário em janela (mesma janela serve para criar e editar) ----
  entrega_em_edicao <- reactiveVal(NULL)

  buscar_entrega <- function(id) {
    dados <- minhas_entregas()
    linha <- dados[as.character(dados$id) == as.character(id), , drop = FALSE]
    if (nrow(linha) != 1) NULL else linha
  }

  form_entrega <- function(linha = NULL) {
    codigos <- codigos_validos()
    if (!is.null(linha)) codigos <- union(codigos, linha$codigo)
    ano <- ano_ciclo()

    showModal(modalDialog(
      title = if (is.null(linha)) tagList(icon("circle-plus"), " Novo lançamento")
              else tagList(icon("pen"), " Editar lançamento"),
      easyClose = TRUE,
      div(
        class = "form-entrega",
        fluidRow(
          column(6, dateInput(
            "in_data", "Data",
            value = if (is.null(linha)) data_padrao_ciclo(ano) else as.Date(linha$data),
            min = as.Date(paste0(ano, "-01-01")), max = as.Date(paste0(ano, "-12-31")),
            format = "dd/mm/yyyy", language = "pt-BR", weekstart = 1, width = "100%"
          )),
          column(6, selectInput("in_status", "Situação", STATUS_ENTREGA,
                                selected = linha$status %||% "Em andamento", width = "100%"))
        ),
        selectInput("in_codigo", "Atividade", choices = codigos,
                    selected = linha$codigo %||% codigos[1], width = "100%"),
        fluidRow(
          column(6, numericInput("in_entregas", "Entregas", value = linha$entregas %||% 0,
                                 min = 0, step = 1, width = "100%")),
          column(6, numericInput("in_horas", "Horas dedicadas", value = linha$horas %||% 0,
                                 min = 0, step = 0.5, width = "100%"))
        )
      ),
      footer = tagList(
        if (!is.null(linha)) actionButton("btn_remover_form", "Remover", icon = icon("trash"),
                                          class = "btn-remover acao-esquerda"),
        modalButton("Cancelar"),
        actionButton(
          "btn_salvar_form",
          if (is.null(linha)) "Adicionar" else "Salvar alterações",
          icon = icon(if (is.null(linha)) "plus" else "floppy-disk"),
          class = if (is.null(linha)) "btn-adicionar" else "btn-salvar"
        )
      )
    ))
  }

  observeEvent(input$btn_novo, {
    req(eh_servidor(), ano_ciclo())
    if (!ano_esta_aberto()) {
      showNotification("Ano fechado. Não é possível inserir entregas.", type = "error")
      return()
    }
    entrega_em_edicao(NULL)
    form_entrega(NULL)
  })

  observeEvent(input$abrir_entrega, {
    req(eh_servidor())
    linha <- buscar_entrega(input$abrir_entrega)
    req(linha)
    if (!ano_esta_aberto()) {
      showNotification("Ano fechado. Este lançamento só pode ser consultado.", type = "warning")
      return()
    }

    # Um lançamento mensal é editado na matriz, que é onde ele foi criado
    if (ESQUEMA_MENSAL && identical(linha$origem, "mensal")) {
      updateSelectInput(session, "in_mm_codigo", selected = linha$codigo)
      updateTabsetPanel(session, "abas", selected = "Lançamento mensal")
      showNotification(
        paste0("Editando ", linha$codigo, " na matriz do ano. Altere os meses e guarde."),
        type = "message"
      )
      return()
    }

    entrega_em_edicao(linha$id)
    form_entrega(linha)
  })

  ## Validação no servidor (vale mesmo se o navegador for manipulado) ----
  validar_lancamento <- function(codigo_atual = NULL) {
    data <- input$in_data
    entregas <- input$in_entregas
    horas <- input$in_horas

    if (length(data) != 1 || is.na(data)) return("Informe a data do lançamento.")
    if (format(as.Date(data), "%Y") != as.character(ano_ciclo()))
      return(paste0("A data deve estar dentro do ano do ciclo ", ano_ciclo(), "."))
    if (!(input$in_codigo %in% c(codigos_validos(), codigo_atual))) return("Selecione uma atividade válida.")
    if (!is.numeric(entregas) || length(entregas) != 1 || is.na(entregas) || entregas < 0 || entregas != round(entregas))
      return("Informe a quantidade de entregas (número inteiro, zero ou maior).")
    if (!is.numeric(horas) || length(horas) != 1 || is.na(horas) || horas < 0 || horas > 744)
      return("Informe as horas dedicadas (entre 0 e 744).")
    if (entregas == 0 && horas == 0) return("Informe as horas dedicadas ou a quantidade de entregas.")
    if (!(input$in_status %in% STATUS_ENTREGA)) return("Selecione a situação da entrega.")
    NULL
  }

  ## Gravar (inclusão ou edição) ----
  observeEvent(input$btn_salvar_form, {
    req(eh_servidor(), ano_ciclo())

    if (!ano_esta_aberto()) {
      showNotification("Ano fechado. Não é possível alterar entregas.", type = "error")
      removeModal()
      return()
    }

    id <- entrega_em_edicao()
    linha <- if (!is.null(id)) buscar_entrega(id)
    if (!is.null(id) && is.null(linha)) {
      showNotification("Este lançamento não está mais disponível.", type = "warning")
      removeModal()
      return()
    }

    erro <- validar_lancamento(codigo_atual = linha$codigo)
    if (!is.null(erro)) {
      showNotification(erro, type = "warning")
      return()
    }

    ok <- if (is.null(id)) {
      gravar(
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
    } else {
      gravar(
        dbExecute(
          pool_write,
          "UPDATE entregas SET data = $1, codigo = $2, entregas = $3, horas = $4, status = $5
           WHERE id = $6 AND servidor = $7",
          params = list(
            as.character(input$in_data), input$in_codigo, input$in_entregas,
            input$in_horas, input$in_status, id, usuario()
          )
        ),
        "Entrega atualizada."
      )
    }

    if (ok) {
      removeModal()
      entrega_em_edicao(NULL)
      marcar(entregas_refresh)
    }
  })

  ## Remover (com confirmação) ----
  id_pendente <- reactiveVal(NULL)

  pedir_remocao <- function(linha) {
    id_pendente(linha$id)
    confirm_action(
      "confirm_delete_entrega",
      message = paste0("Remover o lançamento de ", fmt_data(linha$data), " (", linha$codigo,
                       ")? Esta ação não pode ser desfeita."),
      label_confirm = "Remover",
      icon_confirm = icon("trash")
    )
  }

  observeEvent(input$remover_entrega, {
    req(eh_servidor())
    linha <- buscar_entrega(input$remover_entrega)
    req(linha)
    if (!ano_esta_aberto()) {
      showNotification("Ano fechado. Não é possível remover entregas.", type = "error")
      return()
    }
    pedir_remocao(linha)
  })

  observeEvent(input$btn_remover_form, {
    req(eh_servidor(), entrega_em_edicao())
    linha <- buscar_entrega(entrega_em_edicao())
    req(linha)
    pedir_remocao(linha)
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
    entrega_em_edicao(NULL)
    if (ok) marcar(entregas_refresh)
  })


  # 7.1 LANÇAMENTO MENSAL ----
  # Uma linha por atividade e mês, sempre no dia 1º, com origem = "mensal".
  # O esforço continua sendo horas da atividade ÷ horas do mês: lançar o mês de
  # uma vez ou dia a dia leva ao mesmo percentual.

  mensais_do_ano <- reactive({
    dados <- minhas_entregas()
    if (nrow(dados) == 0 || is.null(dados$origem)) return(dados[0, , drop = FALSE])
    dados[dados$origem == "mensal", , drop = FALSE]
  })

  diarias_do_ano <- reactive({
    dados <- minhas_entregas()
    if (nrow(dados) == 0) return(dados)
    if (is.null(dados$origem)) return(dados)
    dados[dados$origem != "mensal", , drop = FALSE]
  })

  ## Atividades disponíveis, somadas às que já foram usadas no ano ----
  observe({
    req(eh_servidor(), ESQUEMA_MENSAL)
    usadas <- unique(mensais_do_ano()$codigo)
    opcoes <- union(codigos_validos(), usadas)
    atual <- isolate(input$in_mm_codigo)
    updateSelectInput(session, "in_mm_codigo", choices = opcoes,
                      selected = if (!is.null(atual) && atual %in% opcoes) atual else opcoes[1])
  })

  output$out_mm_status <- renderUI({
    req(eh_servidor(), input$in_ano_ciclo)
    pendentes <- sum(mensais_do_ano()$envio == "rascunho")
    tagList(
      if (ano_esta_aberto()) span(class = "status-ano aberto", icon("lock-open"), paste("Ano", ano_ciclo(), "aberto"))
      else span(class = "status-ano fechado", icon("lock"), paste("Ano", ano_ciclo(), "fechado")),
      if (pendentes > 0) span(class = "status-ano rascunho", icon("pen-clip"),
                              paste(pendentes, if (pendentes == 1) "mês em rascunho" else "meses em rascunho"))
    )
  })

  output$out_mm_explicacao <- renderUI({
    req(eh_servidor(), input$in_ano_ciclo)
    p(
      class = "explicacao",
      if (ano_esta_aberto())
        paste("Escolha uma atividade e informe, de uma vez, as entregas e as horas de cada mês do ano.",
              "Deixe em branco os meses sem entrega: em branco não registra nada.",
              "Guarde quantas atividades quiser e, quando terminar, envie tudo ao gestor.",
              "Nada fica travado: você pode voltar aqui e alterar qualquer mês quando quiser,",
              "inclusive depois de enviar, e o gestor passa a ver a versão atual.")
      else
        paste0("O ano ", ano_ciclo(), " está fechado. Os lançamentos ficam disponíveis para consulta, ",
               "e o consolidado abaixo continua somando o lançamento diário e o mensal.")
    )
  })

  ## Matriz de meses da atividade escolhida ----
  matriz_recarregar <- reactiveVal(0L)

  output$out_mm_matriz <- renderUI({
    req(eh_servidor(), input$in_mm_codigo, ano_ciclo())
    matriz_recarregar()
    codigo <- input$in_mm_codigo
    aberto <- ano_esta_aberto()

    mensais <- mensais_do_ano()
    mensais <- mensais[mensais$codigo == codigo, , drop = FALSE]
    diarias <- diarias_do_ano()
    diarias <- diarias[diarias$codigo == codigo, , drop = FALSE]

    valor_mes <- function(dados, mes, coluna) {
      if (nrow(dados) == 0) return(NULL)
      linhas <- dados[format(as.Date(dados$data), "%m") == mes, , drop = FALSE]
      if (nrow(linhas) == 0) NULL else sum(linhas[[coluna]], na.rm = TRUE)
    }

    # Ano fechado: nada de campos nem botões, apenas o que já está registrado
    if (!aberto) {
      registrados <- mensais[order(as.Date(mensais$data)), , drop = FALSE]
      return(div(
        class = "matriz-mensal somente-leitura",
        div(class = "aviso-matriz", icon("lock"),
            paste0("Ano ", ano_ciclo(), " fechado: os lançamentos podem ser consultados, mas não alterados.",
                   local({
                     rascunhos <- sum(mensais_do_ano()$envio == "rascunho")
                     if (rascunhos == 1) " Restou 1 mês em rascunho, que não chegou ao gestor."
                     else if (rascunhos > 1)
                       sprintf(" Restaram %d meses em rascunho, que não chegaram ao gestor.", rascunhos)
                     else ""
                   }))),
        if (nrow(registrados) == 0) {
          div(class = "nenhum-registro", "Nenhum lançamento mensal nesta atividade.")
        } else {
          tagList(
            div(class = "matriz-cabecalho",
                span("Mês"), span("Entregas"), span("Horas"), span(class = "mm-info", "Já lançado no diário")),
            lapply(seq_len(nrow(registrados)), function(i) {
              mes <- format(as.Date(registrados$data[i]), "%m")
              d_ent <- valor_mes(diarias, mes, "entregas")
              d_hrs <- valor_mes(diarias, mes, "horas")
              div(
                class = "matriz-linha preenchida",
                div(class = "mm-rotulo", MESES[[mes]]),
                div(class = "mm-valor", fmt_num(registrados$entregas[i], 0)),
                div(class = "mm-valor", fmt_horas(registrados$horas[i])),
                div(class = "mm-info",
                    if (!is.null(d_ent)) sprintf("%s %s · %s", fmt_num(d_ent, 0),
                                                 if (isTRUE(d_ent == 1)) "entrega" else "entregas",
                                                 fmt_horas(d_hrs %||% 0)) else "—")
              )
            })
          )
        }
      ))
    }

    div(
      class = "matriz-mensal",
      div(
        class = "matriz-cabecalho",
        span("Mês"), span("Entregas"), span("Horas"), span(class = "mm-info", "Já lançado no diário")
      ),
      lapply(names(MESES), function(mes) {
        entregas <- valor_mes(mensais, mes, "entregas")
        horas <- valor_mes(mensais, mes, "horas")
        d_ent <- valor_mes(diarias, mes, "entregas")
        d_hrs <- valor_mes(diarias, mes, "horas")

        div(
          class = paste("matriz-linha", if (!is.null(entregas)) "preenchida"),
          div(class = "mm-rotulo", MESES[[mes]]),
          div(class = "mm-campo",
              span(class = "mm-legenda", "Entregas"),
              numericInput(paste0("mm_ent_", mes), NULL, value = entregas, min = 0, step = 1, width = "100%")),
          div(class = "mm-campo",
              span(class = "mm-legenda", "Horas"),
              numericInput(paste0("mm_hrs_", mes), NULL, value = horas, min = 0, step = 0.5, width = "100%")),
          div(class = "mm-info",
              if (!is.null(d_ent)) sprintf("%s %s · %s", fmt_num(d_ent, 0),
                                          if (isTRUE(d_ent == 1)) "entrega" else "entregas",
                                          fmt_horas(d_hrs %||% 0)) else "—")
        )
      })
    )
  })

  observe({
    req(eh_servidor(), ESQUEMA_MENSAL, input$in_ano_ciclo)
    shinyjs::toggle("acoes_mensais", condition = ano_esta_aberto())
  })

  output$out_mm_resumo_atividade <- renderUI({
    req(eh_servidor(), input$in_mm_codigo)
    dados <- minhas_entregas()
    dados <- dados[dados$codigo == input$in_mm_codigo, , drop = FALSE]
    div(
      class = "resumo-atividade",
      div(span(class = "resumo-valor", fmt_num(sum(dados$entregas, na.rm = TRUE), 0)),
          span(class = "resumo-rotulo", "entregas no ano")),
      div(span(class = "resumo-valor", fmt_horas(sum(dados$horas, na.rm = TRUE))),
          span(class = "resumo-rotulo", "horas no ano")),
      div(span(class = "resumo-valor", length(unique(format(as.Date(dados$data), "%m")))),
          span(class = "resumo-rotulo", "meses com registro"))
    )
  })

  observeEvent(input$btn_mm_recarregar, {
    req(eh_servidor())
    matriz_recarregar(isolate(matriz_recarregar()) + 1L)
    showNotification("Alterações descartadas.", type = "message")
  })

  ## Leitura e validação da matriz ----
  ler_matriz <- function() {
    linhas <- lapply(names(MESES), function(mes) {
      entregas <- input[[paste0("mm_ent_", mes)]]
      horas <- input[[paste0("mm_hrs_", mes)]]
      data.frame(
        mes = mes,
        entregas = if (is.null(entregas) || is.na(entregas)) NA_real_ else as.numeric(entregas),
        horas = if (is.null(horas) || is.na(horas)) NA_real_ else as.numeric(horas),
        stringsAsFactors = FALSE
      )
    })
    do.call(rbind, linhas)
  }

  validar_matriz <- function(matriz) {
    for (i in seq_len(nrow(matriz))) {
      entregas <- matriz$entregas[i]
      horas <- matriz$horas[i]
      nome_mes <- MESES[[matriz$mes[i]]]

      if (!is.na(entregas)) {
        if (entregas < 0 || entregas != round(entregas))
          return(paste0("Em ", nome_mes, ", informe a quantidade de entregas como número inteiro."))
        if (entregas == 0 && is.na(horas))
          return(paste0("Em ", nome_mes, ", zero não precisa ser registrado: deixe o campo em branco."))
      }
      if (!is.na(horas)) {
        if (horas < 0 || horas > 8784)
          return(paste0("Em ", nome_mes, ", informe as horas entre 0 e 8784."))
        if (is.na(entregas) || entregas == 0)
          return(paste0("Em ", nome_mes, ", informe também a quantidade de entregas."))
      }
    }
    NULL
  }

  # Grava a atividade escolhida: insere, atualiza ou remove cada mês da matriz
  gravar_matriz <- function(enviar_agora = FALSE) {
    codigo <- input$in_mm_codigo
    ano <- ano_ciclo()
    matriz <- ler_matriz()

    erro <- validar_matriz(matriz)
    if (!is.null(erro)) {
      showNotification(erro, type = "warning")
      return(NULL)
    }

    existentes <- mensais_do_ano()
    existentes <- existentes[existentes$codigo == codigo, , drop = FALSE]
    mes_existente <- if (nrow(existentes)) format(as.Date(existentes$data), "%m") else character()

    gravados <- 0L; removidos <- 0L

    ok <- gravar(
      pool::poolWithTransaction(pool_write, function(con) {
        for (i in seq_len(nrow(matriz))) {
          mes <- matriz$mes[i]
          entregas <- matriz$entregas[i]
          horas <- if (is.na(matriz$horas[i])) 0 else matriz$horas[i]
          data_mes <- paste0(ano, "-", mes, "-01")
          indice <- match(mes, mes_existente)

          if (!is.na(entregas) && entregas > 0) {
            if (is.na(indice)) {
              dbExecute(
                con,
                "INSERT INTO entregas (data, ano, codigo, entregas, horas, status, servidor, origem, envio)
                 VALUES ($1, $2, $3, $4, $5, 'Concluído', $6, 'mensal', $7)",
                params = list(data_mes, ano, codigo, entregas, horas, usuario(),
                              if (enviar_agora) "enviado" else "rascunho")
              )
            } else {
              # Um mês já enviado permanece enviado: o gestor passa a ver a versão atual
              dbExecute(
                con,
                "UPDATE entregas SET entregas = $1, horas = $2, envio = $3
                  WHERE id = $4 AND servidor = $5 AND origem = 'mensal'",
                params = list(entregas, horas,
                              if (enviar_agora || identical(existentes$envio[indice], "enviado")) "enviado" else "rascunho",
                              existentes$id[indice], usuario())
              )
            }
            gravados <<- gravados + 1L
          } else if (!is.na(indice)) {
            dbExecute(con, "DELETE FROM entregas WHERE id = $1 AND servidor = $2 AND origem = 'mensal'",
                      params = list(existentes$id[indice], usuario()))
            removidos <<- removidos + 1L
          }
        }
      }),
      sprintf("%s %s%s.",
              if (gravados == 0) "Nenhum mês" else gravados,
              if (gravados == 1) "mês gravado" else "meses gravados",
              if (removidos > 0) sprintf(" · %d removido%s", removidos, if (removidos > 1) "s" else "") else "")
    )

    if (ok) marcar(entregas_refresh)
    ok
  }

  observeEvent(input$btn_mm_guardar, {
    req(eh_servidor(), ano_ciclo())
    if (!ano_esta_aberto()) {
      showNotification("Ano fechado. Não é possível alterar lançamentos.", type = "error")
      return()
    }
    gravar_matriz(enviar_agora = FALSE)
  })

  ## Envio ao gestor: manda tudo que estiver em rascunho no ano ----
  observeEvent(input$btn_mm_enviar, {
    req(eh_servidor(), ano_ciclo())
    if (!ano_esta_aberto()) {
      showNotification("Ano fechado. Não é possível alterar lançamentos.", type = "error")
      return()
    }
    if (is.null(gravar_matriz(enviar_agora = FALSE))) return()

    pendentes <- mensais_do_ano()
    pendentes <- pendentes[pendentes$envio == "rascunho", , drop = FALSE]

    if (nrow(pendentes) == 0) {
      showNotification("Não há rascunhos para enviar: tudo já está com o gestor.", type = "message")
      return()
    }

    confirm_action(
      "confirm_mm_enviar",
      message = sprintf(
        "Enviar ao gestor %d %s de %d %s, referentes a %s? Depois de enviado você ainda pode editar, e o gestor passa a ver a versão atual.",
        nrow(pendentes), if (nrow(pendentes) == 1) "mês" else "meses",
        length(unique(pendentes$codigo)),
        if (length(unique(pendentes$codigo)) == 1) "atividade" else "atividades",
        ano_ciclo()
      ),
      label_confirm = "Enviar ao gestor",
      class_confirm = "btn-adicionar",
      icon_confirm = icon("paper-plane")
    )
  })

  observeEvent(input$confirm_mm_enviar, {
    removeModal()
    req(eh_servidor(), ano_ciclo())

    ok <- gravar(
      dbExecute(
        pool_write,
        "UPDATE entregas SET envio = 'enviado'
          WHERE servidor = $1 AND ano = $2 AND origem = 'mensal' AND envio = 'rascunho'",
        params = list(usuario(), ano_ciclo())
      ),
      "Lançamentos enviados ao gestor. Você pode continuar editando quando quiser."
    )
    if (ok) marcar(entregas_refresh)
  })

  ## Consolidado do ano: atividades nas linhas, meses nas colunas ----
  output$out_mm_consolidado <- renderUI({
    req(eh_servidor(), ano_ciclo())
    dados <- minhas_entregas()

    if (nrow(dados) == 0) {
      return(div(class = "nenhum-registro", paste0("Nenhum lançamento em ", ano_ciclo(), ".")))
    }

    dados$mes <- format(as.Date(dados$data), "%m")
    meses <- sort(unique(dados$mes))
    atividades <- sort(unique(dados$codigo))
    total_por <- function(codigo, mes) sum(dados$entregas[dados$codigo == codigo & dados$mes == mes], na.rm = TRUE)

    tags$div(
      class = "tabela-consolidado",
      tags$table(
        tags$thead(tags$tr(
          tags$th("Atividade"),
          lapply(meses, function(mes) tags$th(class = "num", substr(MESES[[mes]], 1, 3))),
          tags$th(class = "num total", "Ano")
        )),
        tags$tbody(
          lapply(atividades, function(codigo) {
            valores <- vapply(meses, function(mes) total_por(codigo, mes), numeric(1))
            tags$tr(
              tags$td(codigo),
              lapply(seq_along(meses), function(i) {
                tags$td(class = "num", if (valores[i] > 0) fmt_num(valores[i], 0) else "–")
              }),
              tags$td(class = "num total", fmt_num(sum(valores), 0))
            )
          })
        ),
        tags$tfoot(tags$tr(
          tags$th("Total do mês"),
          lapply(meses, function(mes) {
            tags$th(class = "num", fmt_num(sum(dados$entregas[dados$mes == mes], na.rm = TRUE), 0))
          }),
          tags$th(class = "num total", fmt_num(sum(dados$entregas, na.rm = TRUE), 0))
        ))
      )
    )
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

  ## Contexto das exportações: identifica no PDF o que está sendo baixado ----
  observe({
    req(usuario())

    filtros <- c(
      if (!is.null(input$in_filtro_ano) && input$in_filtro_ano != "Todos")
        paste("Ano", input$in_filtro_ano),
      if (!is.null(input$in_filtro_mes) && input$in_filtro_mes != "Todos")
        MESES[[input$in_filtro_mes]],
      if (!is.null(servidor_do_relatorio())) local({
        nomes <- nomes_servidores()
        nome <- nomes$nome[match(servidor_do_relatorio(), as.character(nomes$siape))]
        paste("Servidor:", if (is.na(nome)) servidor_do_relatorio() else nome)
      }),
      if (!is.null(input$in_filtro_codigo) && input$in_filtro_codigo != "Todos")
        input$in_filtro_codigo
    )

    session$sendCustomMessage("me_contexto", list(
      servidor = if (eh_admin()) "Administração" else paste0(nome_usuario(), " · SIAPE ", usuario()),
      versao = APP_VERSION,
      tabelas = list(
        relatorio = list(filtros = if (length(filtros)) paste(filtros, collapse = " · ") else NULL)
      )
    ))
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

  # O relatório é montado com todos os registros visíveis ao usuário; os filtros
  # do topo são aplicados como busca da própria tabela. Assim o esforço de cada
  # mês é sempre calculado sobre o mês inteiro, e a exportação pode escolher
  # entre o que está filtrado e a tabela completa.
  # O relatório soma as entregas de todos os servidores em cada atividade e mês:
  # é esse consolidado que alimenta a ferramenta oficial. O detalhe por servidor
  # fica na aba "Todas as entregas". Quando o administrador escolhe um servidor no
  # filtro, o consolidado passa a ser daquele servidor.
  servidor_do_relatorio <- reactive({
    if (!eh_admin()) return(NULL)
    escolhido <- input$in_filtro_servidor
    if (is.null(escolhido) || escolhido == "Todos") NULL else escolhido
  })

  resumo_relatorio <- reactive({
    dados <- entregas_visiveis()

    escolhido <- servidor_do_relatorio()
    if (!is.null(escolhido)) {
      dados <- dados[as.character(dados$servidor) == escolhido, , drop = FALSE]
    }
    if (nrow(dados) == 0) return(dados[0, , drop = FALSE])

    dados$ano <- format(as.Date(dados$data), "%Y")
    dados$mes <- format(as.Date(dados$data), "%m")

    resumo <- aggregate(cbind(entregas, horas) ~ ano + mes + codigo, data = dados, FUN = sum)
    total_mes <- aggregate(horas ~ ano + mes, data = dados, FUN = sum)
    total_entregas <- aggregate(entregas ~ ano + mes, data = dados, FUN = sum)

    identificar <- function(d) paste(d$ano, d$mes)
    chave <- identificar(resumo)

    # Esforço = horas da atividade ÷ horas do mês. Quando o mês não tem horas
    # informadas, o percentual é estimado pela participação nas entregas.
    total_h <- total_mes$horas[match(chave, identificar(total_mes))]
    total_e <- total_entregas$entregas[match(chave, identificar(total_entregas))]

    resumo$estimado <- !(total_h > 0)
    resumo$percentual <- ifelse(
      total_h > 0,
      round(resumo$horas / total_h * 100, 1),
      ifelse(total_e > 0, round(resumo$entregas / total_e * 100, 1), 0)
    )

    resumo[order(resumo$ano, resumo$mes, -resumo$horas,
                 decreasing = c(TRUE, TRUE, FALSE), method = "radix"), , drop = FALSE]
  })

  output$out_tabela_relatorio <- renderDT(server = FALSE, {
    resumo <- resumo_relatorio()

    if (nrow(resumo) == 0) {
      return(tabela_padrao(
        data.frame(Mensagem = "Nenhum lançamento registrado até o momento."),
        selection = "none"
      ))
    }

    # O esforço aparece como barra proporcional, mais legível que o número sozinho
    cores <- CORES_ESFORCO[(match(resumo$codigo, sort(unique(resumo$codigo))) - 1) %% length(CORES_ESFORCO) + 1]

    exibir <- data.frame(
      `Período` = paste(unname(MESES[resumo$mes]), resumo$ano),
      Atividade = resumo$codigo,
      Entregas = fmt_num(resumo$entregas, 0),
      Horas = fmt_horas(resumo$horas),
      `Esforço no mês` = mapply(barra_percentual, resumo$percentual, cores, resumo$estimado),
      check.names = FALSE
    )
    # Colunas de apoio, invisíveis: guardam o valor exato de cada filtro entre
    # barras verticais, para que a busca por um código não alcance outro que o contenha
    exibir$f_ano <- marca(resumo$ano)
    exibir$f_mes <- marca(resumo$mes)
    exibir$f_codigo <- marca(resumo$codigo)

    tabela_padrao(exibir, selection = "none", escape = sem_escape(exibir, "Esforço no mês"),
                  alinhar_direita = c("Entregas", "Horas"),
                  ocultar = c("f_ano", "f_mes", "f_codigo"),
                  titulo = "Relatório de esforço", chave = "relatorio")
  })

  output$out_escopo_relatorio <- renderUI({
    req(usuario())
    escolhido <- servidor_do_relatorio()
    if (is.null(escolhido)) {
      div(class = "tag-secao", if (eh_admin()) "Soma de toda a unidade" else "Horas e entregas por mês")
    } else {
      nomes <- nomes_servidores()
      nome <- nomes$nome[match(escolhido, as.character(nomes$siape))]
      div(class = "tag-secao tag-verde", paste("Consolidado de", if (is.na(nome)) escolhido else nome))
    }
  })

  # A explicação do asterisco fica visível na tela, e não apenas como dica do mouse
  output$out_nota_relatorio <- renderUI({
    req(usuario())
    resumo <- resumo_relatorio()
    if (nrow(resumo) == 0 || !any(resumo$estimado)) return(NULL)

    div(
      class = "nota-tabela",
      span(class = "nota-marca", "*"),
      span(
        "Esforço estimado pela quantidade de entregas, porque o mês não tem horas informadas. ",
        "Informe as horas do mês para que o percentual passe a ser calculado por elas."
      )
    )
  })

  ## Os filtros do topo viram busca por coluna na tabela já montada ----
  observe({
    req(usuario(), input$in_filtro_ano)
    resumo_relatorio()

    busca <- function(valor) if (is.null(valor) || valor == "Todos") "" else marca(valor)
    colunas <- c(
      "", "", "", "", "",            # Período, Atividade, Entregas, Horas, Esforço
      busca(input$in_filtro_ano),
      busca(input$in_filtro_mes),
      busca(input$in_filtro_codigo)
    )
    session$sendCustomMessage("me_filtrar_tabela", list(
      id = "out_tabela_relatorio", colunas = as.list(colunas)
    ))
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

  # server = FALSE mantém a tabela inteira no navegador: sem isso, a busca e a
  # exportação enxergariam apenas a página carregada no momento.
  output$out_tabela_todos <- renderDT(server = FALSE, {
    req(eh_admin())
    dados <- entregas_visiveis()
    dados <- dados[order(as.Date(dados$data), decreasing = TRUE), , drop = FALSE]
    exibir <- data.frame(
      Data = fmt_data(dados$data),
      Servidor = ifelse(is.na(dados$nome_servidor), "", dados$nome_servidor),
      SIAPE = dados$servidor,
      Atividade = dados$codigo,
      Entregas = fmt_num(dados$entregas, 0),
      Horas = fmt_horas(dados$horas),
      `Situação` = selo_status(dados$status),
      check.names = FALSE
    )
    tabela_padrao(exibir, selection = "none", escape = sem_escape(exibir, "Situação"),
                  ocultar_mobile = "SIAPE", alinhar_direita = c("Entregas", "Horas"),
                  titulo = "Todas as entregas", chave = "todas")
  })

  ## Anos do ciclo ----
  tb_anos <- reactive({
    req(eh_admin())
    admin_refresh()
    dbGetQuery(pool_read, "SELECT * FROM anos_ciclo ORDER BY ano DESC")
  })

  output$out_lista_anos <- renderUI({
    dados <- tb_anos()
    if (nrow(dados) == 0) {
      return(div(class = "nenhum-registro", "Nenhum ano de ciclo cadastrado."))
    }

    div(
      class = "lista-registros",
      lapply(seq_len(nrow(dados)), function(i) {
        linha <- dados[i, , drop = FALSE]
        aberto <- identical(linha$status, "aberto")
        linha_registro(
          destaque = icon(if (aberto) "lock-open" else "lock"),
          titulo = as.character(linha$ano),
          subtitulo = if (aberto) "Lançamentos liberados para os servidores" else "Apenas consulta",
          selo = HTML(selo_ano(linha$status)),
          acoes = tagList(
            botao_evento("alternar_ano", linha$ano,
                         if (aberto) "Fechar este ano" else "Abrir este ano",
                         if (aberto) "lock" else "lock-open", "btn-icone-editar"),
            botao_evento("remover_ano", linha$ano, "Remover este ano", "trash", "btn-icone-remover")
          )
        )
      })
    )
  })

  # server = FALSE mantém a tabela inteira no navegador: sem isso, a busca e a
  # exportação enxergariam apenas a página carregada no momento.
  output$out_tabela_audit_anos <- renderDT(server = FALSE, {
    req(eh_admin())
    admin_refresh()
    dados <- dbGetQuery(
      pool_read,
      "SELECT momento, usuario, acao, referencia AS ano
       FROM audit_logs
       WHERE entidade = 'ano_ciclo'
       ORDER BY momento DESC"
    )
    if (nrow(dados) > 0) dados$momento <- format(as.POSIXct(dados$momento), "%d/%m/%Y %H:%M")
    names(dados) <- c("Momento", "Usuário", "Ação", "Ano")[seq_along(dados)]
    tabela_padrao(dados, selection = "none", pageLength = 10, ocultar_mobile = "Usuário",
                  titulo = "Histórico de ações administrativas", chave = "auditoria")
  })

  # Ao abrir um ano, os demais são fechados na mesma transação (só um ano aberto)
  definir_status_ano <- function(con, ano, status) {
    if (status == "aberto") {
      dbExecute(con, "UPDATE anos_ciclo SET status = 'fechado' WHERE ano <> $1", params = list(ano))
    }
    dbExecute(con, "UPDATE anos_ciclo SET status = $1 WHERE ano = $2", params = list(status, ano))
  }

  observeEvent(input$btn_novo_ano, {
    req(eh_admin())
    showModal(modalDialog(
      title = tagList(icon("circle-plus"), " Novo ano de ciclo"),
      easyClose = TRUE,
      numericInput("in_ano", "Ano", value = as.integer(format(Sys.Date(), "%Y")),
                   min = 2000, max = 2100, step = 1, width = "100%"),
      selectInput("in_status_ano", "Situação", choices = c("Aberto" = "aberto", "Fechado" = "fechado"),
                  selected = "fechado", width = "100%"),
      div(class = "explicacao", "Ao criar um ano já aberto, os demais são fechados automaticamente."),
      footer = tagList(
        modalButton("Cancelar"),
        actionButton("btn_add_ano", "Adicionar", icon = icon("plus"), class = "btn-adicionar")
      )
    ))
  })

  observeEvent(input$btn_add_ano, {
    req(eh_admin())
    ano <- input$in_ano
    status <- input$in_status_ano
    if (!is.numeric(ano) || length(ano) != 1 || is.na(ano) || ano < 2000 || ano > 2100 || ano != round(ano)) {
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
      removeModal()
      registrar_auditoria(paste("criou ano com status", status), "ano_ciclo", as.character(ano))
      marcar(admin_refresh)
    }
  })

  ano_pendente <- reactiveVal(NULL)

  buscar_ano <- function(ano) {
    dados <- tb_anos()
    linha <- dados[as.character(dados$ano) == as.character(ano), , drop = FALSE]
    if (nrow(linha) != 1) NULL else linha
  }

  observeEvent(input$alternar_ano, {
    req(eh_admin())
    linha <- buscar_ano(input$alternar_ano)
    req(linha)
    novo_status <- if (identical(linha$status, "aberto")) "fechado" else "aberto"
    ano_pendente(list(ano = linha$ano, status = novo_status))

    confirm_action(
      "confirm_edit_ano",
      message = paste0(
        if (novo_status == "aberto") "Abrir" else "Fechar", " o ano ", linha$ano, "?",
        if (novo_status == "aberto") " Os demais anos serão fechados e os servidores poderão lançar entregas neste ano."
        else " Os servidores deixarão de poder lançar ou alterar entregas deste ano."
      ),
      label_confirm = if (novo_status == "aberto") "Abrir ano" else "Fechar ano",
      class_confirm = "btn-salvar",
      icon_confirm = icon(if (novo_status == "aberto") "lock-open" else "lock")
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
  observeEvent(input$remover_ano, {
    req(eh_admin())
    linha <- buscar_ano(input$remover_ano)
    req(linha)

    qtd <- dbGetQuery(pool_read, "SELECT COUNT(*) FROM entregas WHERE ano = $1", params = list(linha$ano))
    if (qtd[1, 1] > 0) {
      showNotification("Este ano possui entregas registradas e não pode ser removido.", type = "error")
      return()
    }
    ano_pendente(list(ano = linha$ano))
    confirm_action(
      "confirm_delete_ano",
      message = paste0("Remover o ano ", linha$ano, "? Esta ação não pode ser desfeita."),
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

  output$out_lista_codigos <- renderUI({
    dados <- tb_codigos()
    if (nrow(dados) == 0) {
      return(div(class = "nenhum-registro", "Nenhuma atividade cadastrada."))
    }

    div(
      class = "lista-registros",
      lapply(seq_len(nrow(dados)), function(i) {
        linha <- dados[i, , drop = FALSE]
        linha_registro(
          destaque = span(class = "etiqueta-codigo", linha$codigo),
          titulo = linha$descricao,
          subtitulo = paste("Código", linha$codigo),
          acoes = tagList(
            botao_evento("abrir_codigo", linha$id, "Editar atividade", "pen", "btn-icone-editar"),
            botao_evento("remover_codigo", linha$id, "Remover atividade", "trash", "btn-icone-remover")
          ),
          evento = "abrir_codigo", valor = linha$id
        )
      })
    )
  })

  codigo_em_edicao <- reactiveVal(NULL)

  form_codigo <- function(linha = NULL) {
    showModal(modalDialog(
      title = if (is.null(linha)) tagList(icon("circle-plus"), " Nova atividade")
              else tagList(icon("pen"), " Editar atividade"),
      easyClose = TRUE,
      textInput("in_codigo_id", "Código", value = linha$codigo %||% "", width = "100%"),
      textInput("in_codigo_desc", "Descrição", value = linha$descricao %||% "", width = "100%"),
      footer = tagList(
        if (!is.null(linha)) actionButton("btn_del_codigo", "Remover", icon = icon("trash"),
                                          class = "btn-remover acao-esquerda"),
        modalButton("Cancelar"),
        actionButton("btn_salvar_codigo",
                     if (is.null(linha)) "Adicionar" else "Salvar alterações",
                     icon = icon(if (is.null(linha)) "plus" else "floppy-disk"),
                     class = if (is.null(linha)) "btn-adicionar" else "btn-salvar")
      )
    ))
  }

  buscar_codigo <- function(id) {
    dados <- tb_codigos()
    linha <- dados[as.character(dados$id) == as.character(id), , drop = FALSE]
    if (nrow(linha) != 1) NULL else linha
  }

  observeEvent(input$btn_nova_atividade, {
    req(eh_admin())
    codigo_em_edicao(NULL)
    form_codigo(NULL)
  })

  observeEvent(input$abrir_codigo, {
    req(eh_admin())
    linha <- buscar_codigo(input$abrir_codigo)
    req(linha)
    codigo_em_edicao(linha$id)
    form_codigo(linha)
  })

  observeEvent(input$btn_salvar_codigo, {
    req(eh_admin())
    codigo <- texto_limpo(input$in_codigo_id)
    descricao <- texto_limpo(input$in_codigo_desc)
    if (!nzchar(codigo) || !nzchar(descricao)) {
      showNotification("Informe o código e a descrição.", type = "warning")
      return()
    }

    id <- codigo_em_edicao()
    duplicado <- if (is.null(id)) {
      dbGetQuery(pool_read, "SELECT COUNT(*) FROM codigos_entrega WHERE codigo = $1", params = list(codigo))
    } else {
      dbGetQuery(pool_read, "SELECT COUNT(*) FROM codigos_entrega WHERE codigo = $1 AND id != $2",
                 params = list(codigo, id))
    }
    if (duplicado[1, 1] > 0) {
      showNotification("Já existe uma atividade com este código.", type = "warning")
      return()
    }

    ok <- if (is.null(id)) {
      gravar(
        dbExecute(pool_write, "INSERT INTO codigos_entrega (codigo, descricao) VALUES ($1, $2)",
                  params = list(codigo, descricao)),
        "Atividade adicionada."
      )
    } else {
      gravar(
        dbExecute(pool_write, "UPDATE codigos_entrega SET codigo = $1, descricao = $2 WHERE id = $3",
                  params = list(codigo, descricao, id)),
        "Atividade atualizada."
      )
    }
    if (ok) {
      removeModal()
      codigo_em_edicao(NULL)
      marcar(admin_refresh)
    }
  })

  codigo_pendente <- reactiveVal(NULL)

  pedir_remocao_codigo <- function(linha) {
    codigo_pendente(linha$id)
    confirm_action(
      "confirm_delete_codigo",
      message = paste0("Remover a atividade ", linha$codigo, " - ", linha$descricao,
                       "? Os lançamentos já registrados não são alterados."),
      label_confirm = "Remover",
      icon_confirm = icon("trash")
    )
  }

  observeEvent(input$remover_codigo, {
    req(eh_admin())
    linha <- buscar_codigo(input$remover_codigo)
    req(linha)
    pedir_remocao_codigo(linha)
  })

  observeEvent(input$btn_del_codigo, {
    req(eh_admin(), codigo_em_edicao())
    linha <- buscar_codigo(codigo_em_edicao())
    req(linha)
    pedir_remocao_codigo(linha)
  })

  observeEvent(input$confirm_delete_codigo, {
    removeModal()
    req(eh_admin(), codigo_pendente())
    id <- codigo_pendente()
    codigo_pendente(NULL)
    codigo_em_edicao(NULL)

    ok <- gravar(
      dbExecute(pool_write, "DELETE FROM codigos_entrega WHERE id = $1", params = list(id)),
      "Atividade removida."
    )
    if (ok) marcar(admin_refresh)
  })

  ## Servidores ----
  tb_servidores <- reactive({
    req(eh_admin())
    admin_refresh()
    dbGetQuery(pool_read, "SELECT * FROM servidores ORDER BY nome")
  })

  output$out_lista_servidores <- renderUI({
    dados <- tb_servidores()
    if (nrow(dados) == 0) {
      return(div(class = "nenhum-registro", "Nenhum servidor cadastrado."))
    }

    div(
      class = "lista-registros",
      lapply(seq_len(nrow(dados)), function(i) {
        linha <- dados[i, , drop = FALSE]
        # A senha, mesmo em hash, nunca sai do servidor: apenas se existe ou não
        tem_senha <- !is.na(linha$senha_hash) && nzchar(linha$senha_hash)
        linha_registro(
          destaque = div(class = "avatar", iniciais(linha$nome)),
          titulo = linha$nome,
          subtitulo = paste("SIAPE", linha$siape),
          selo = span(class = paste("selo-status", if (tem_senha) "selo-concluido" else "selo-andamento"),
                      if (tem_senha) "Senha configurada" else "Sem senha"),
          acoes = tagList(
            botao_evento("abrir_servidor", linha$siape, "Editar servidor", "pen", "btn-icone-editar"),
            botao_evento("remover_servidor", linha$siape, "Remover servidor", "trash", "btn-icone-remover")
          ),
          evento = "abrir_servidor", valor = linha$siape
        )
      })
    )
  })

  servidor_em_edicao <- reactiveVal(NULL)

  buscar_servidor <- function(siape) {
    dados <- tb_servidores()
    linha <- dados[as.character(dados$siape) == as.character(siape), , drop = FALSE]
    if (nrow(linha) != 1) NULL else linha
  }

  form_servidor <- function(linha = NULL) {
    showModal(modalDialog(
      title = if (is.null(linha)) tagList(icon("user-plus"), " Novo servidor")
              else tagList(icon("pen"), " Editar servidor"),
      easyClose = TRUE,
      textInput("in_servidor_siape", "SIAPE", value = linha$siape %||% "", width = "100%"),
      textInput("in_servidor_nome", "Nome", value = linha$nome %||% "", width = "100%"),
      div(class = "explicacao", "A senha é definida diretamente no banco de dados e não é exibida aqui."),
      footer = tagList(
        if (!is.null(linha)) actionButton("btn_del_servidor", "Remover", icon = icon("trash"),
                                          class = "btn-remover acao-esquerda"),
        modalButton("Cancelar"),
        actionButton("btn_salvar_servidor",
                     if (is.null(linha)) "Adicionar" else "Salvar alterações",
                     icon = icon(if (is.null(linha)) "plus" else "floppy-disk"),
                     class = if (is.null(linha)) "btn-adicionar" else "btn-salvar")
      )
    ))
  }

  observeEvent(input$btn_novo_servidor, {
    req(eh_admin())
    servidor_em_edicao(NULL)
    form_servidor(NULL)
  })

  observeEvent(input$abrir_servidor, {
    req(eh_admin())
    linha <- buscar_servidor(input$abrir_servidor)
    req(linha)
    servidor_em_edicao(linha$siape)
    form_servidor(linha)
  })

  observeEvent(input$btn_salvar_servidor, {
    req(eh_admin())
    siape <- texto_limpo(input$in_servidor_siape)
    nome <- texto_limpo(input$in_servidor_nome)
    if (!nzchar(siape) || !nzchar(nome)) {
      showNotification("Informe o SIAPE e o nome.", type = "warning")
      return()
    }

    siape_atual <- servidor_em_edicao()
    duplicado <- if (is.null(siape_atual)) {
      dbGetQuery(pool_read, "SELECT COUNT(*) FROM servidores WHERE siape = $1", params = list(siape))
    } else {
      dbGetQuery(pool_read, "SELECT COUNT(*) FROM servidores WHERE siape = $1 AND siape != $2",
                 params = list(siape, siape_atual))
    }
    if (duplicado[1, 1] > 0) {
      showNotification("Já existe um servidor com este SIAPE.", type = "warning")
      return()
    }

    ok <- if (is.null(siape_atual)) {
      gravar(
        dbExecute(pool_write, "INSERT INTO servidores (siape, nome) VALUES ($1, $2)",
                  params = list(siape, nome)),
        "Servidor adicionado."
      )
    } else {
      gravar(
        dbExecute(pool_write, "UPDATE servidores SET siape = $1, nome = $2 WHERE siape = $3",
                  params = list(siape, nome, siape_atual)),
        "Servidor atualizado."
      )
    }
    if (ok) {
      removeModal()
      servidor_em_edicao(NULL)
      marcar(admin_refresh)
      marcar(entregas_refresh)
    }
  })

  servidor_pendente <- reactiveVal(NULL)

  pedir_remocao_servidor <- function(linha) {
    entregas <- dbGetQuery(pool_read, "SELECT COUNT(*) FROM entregas WHERE servidor = $1",
                           params = list(linha$siape))
    if (entregas[1, 1] > 0) {
      showNotification("Este servidor possui entregas registradas. Remova as entregas antes de excluir.",
                       type = "error")
      return()
    }
    servidor_pendente(linha$siape)
    confirm_action(
      "confirm_delete_servidor",
      message = paste0("Remover o servidor ", linha$nome, " (SIAPE ", linha$siape,
                       ")? Esta ação não pode ser desfeita."),
      label_confirm = "Remover",
      icon_confirm = icon("trash")
    )
  }

  observeEvent(input$remover_servidor, {
    req(eh_admin())
    linha <- buscar_servidor(input$remover_servidor)
    req(linha)
    pedir_remocao_servidor(linha)
  })

  observeEvent(input$btn_del_servidor, {
    req(eh_admin(), servidor_em_edicao())
    linha <- buscar_servidor(servidor_em_edicao())
    req(linha)
    pedir_remocao_servidor(linha)
  })

  observeEvent(input$confirm_delete_servidor, {
    removeModal()
    req(eh_admin(), servidor_pendente())
    siape <- servidor_pendente()
    servidor_pendente(NULL)
    servidor_em_edicao(NULL)

    ok <- gravar(
      dbExecute(pool_write, "DELETE FROM servidores WHERE siape = $1", params = list(siape)),
      "Servidor removido."
    )
    if (ok) marcar(admin_refresh)
  })
}
