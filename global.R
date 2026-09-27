library(shiny)
library(DBI)
library(RPostgres)
library(DT)
library(pool)
library(shinyjs)
library(bcrypt)

# -------------------------------
# Versão do aplicativo
# -------------------------------
APP_VERSION <- tryCatch(
  readLines("VERSION", warn = FALSE)[1],
  error = function(e) "dev"
)

# -------------------------------
# Pool de conexões PostgreSQL
# -------------------------------

# Pool de ESCRITA
pool_write <- dbPool(
  drv      = RPostgres::Postgres(),
  dbname   = Sys.getenv("DB_NAME"),
  host     = Sys.getenv("DB_HOST"),
  port     = Sys.getenv("DB_PORT"),
  user     = Sys.getenv("DB_USER_WRITE"),
  password = Sys.getenv("DB_PASSWORD_WRITE"),
  sslmode  = Sys.getenv("PGSSLMODE")
)

# Pool de LEITURA
pool_read <- dbPool(
  drv      = RPostgres::Postgres(),
  dbname   = Sys.getenv("DB_NAME"),
  host     = Sys.getenv("DB_HOST"),
  port     = Sys.getenv("DB_PORT"),
  user     = Sys.getenv("DB_USER_READ"),
  password = Sys.getenv("DB_PASSWORD_READ"),
  sslmode  = Sys.getenv("PGSSLMODE")
)

onStop(function() {
  try(pool::poolClose(pool_read), silent = TRUE)
  try(pool::poolClose(pool_write), silent = TRUE)
})

# -------------------------------
# Recursos disponíveis no banco
# -------------------------------
# O lançamento mensal depende das colunas criadas por
# scripts/migrar_lancamento_mensal.R. Enquanto elas não existirem, a aba não
# aparece e o restante do aplicativo funciona normalmente.
ESQUEMA_MENSAL <- tryCatch({
  colunas <- DBI::dbGetQuery(
    pool_read,
    "SELECT column_name FROM information_schema.columns
      WHERE table_name = 'entregas' AND column_name IN ('origem', 'envio')"
  )
  nrow(colunas) == 2
}, error = function(e) FALSE)

# -------------------------------
# Identidade visual e formatação
# -------------------------------
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

MESES <- c(
  "01" = "Janeiro", "02" = "Fevereiro", "03" = "Março", "04" = "Abril",
  "05" = "Maio", "06" = "Junho", "07" = "Julho", "08" = "Agosto",
  "09" = "Setembro", "10" = "Outubro", "11" = "Novembro", "12" = "Dezembro"
)

# Mesma família de cores do Croma (azul, verde, âmbar, coral...) para as barras de esforço
CORES_ESFORCO <- c("#2A5C92", "#4D965D", "#C98A2B", "#C0615A", "#7A5EA8", "#2F8F9D", "#173B5B", "#8C9A3A")

STATUS_ENTREGA <- c("Em andamento", "Concluído")

fmt_num <- function(x, digitos = 1) {
  x[is.na(x)] <- 0
  formatC(x, format = "f", digits = digitos, decimal.mark = ",", big.mark = ".")
}

fmt_horas <- function(x) paste0(fmt_num(x, 1), " h")

fmt_data <- function(x) format(as.Date(x), "%d/%m/%Y")

iniciais <- function(nome) {
  partes <- strsplit(trimws(as.character(nome %||% "")), "\\s+")[[1]]
  partes <- partes[nchar(partes) > 2 | length(partes) <= 2]
  if (length(partes) == 0) return("?")
  toupper(paste0(substr(partes[1], 1, 1), if (length(partes) > 1) substr(partes[length(partes)], 1, 1)))
}

selo_status <- function(status) {
  classe <- ifelse(status == "Concluído", "selo-concluido", "selo-andamento")
  sprintf('<span class="selo-status %s">%s</span>', classe, htmltools::htmlEscape(status))
}

selo_origem <- function(origem, envio) {
  selos <- character()
  if (identical(origem, "mensal")) {
    selos <- c(selos, '<span class="selo-status selo-mensal">Mensal</span>')
  }
  if (identical(envio, "rascunho")) {
    selos <- c(selos, '<span class="selo-status selo-rascunho">Rascunho</span>')
  }
  paste(selos, collapse = " ")
}

selo_ano <- function(status) {
  aberto <- status == "aberto"
  sprintf('<span class="selo-status %s">%s</span>',
          ifelse(aberto, "selo-aberto", "selo-fechado"),
          ifelse(aberto, "Aberto", "Fechado"))
}

# Cartão de um lançamento: clicar no cartão abre a janela de edição.
# O clique é enviado ao servidor por id, que confere o dono do registro antes de qualquer ação.
cartao_entrega <- function(linha, editavel) {
  data <- as.Date(linha$data)
  mensal <- identical(linha$origem %||% "diario", "mensal")
  partes <- strsplit(as.character(linha$codigo), "-", fixed = TRUE)[[1]]
  codigo <- trimws(partes[1])
  descricao <- trimws(paste(partes[-1], collapse = "-"))
  if (!nzchar(descricao)) descricao <- as.character(linha$codigo)

  evento <- function(nome) sprintf("Shiny.setInputValue('%s', %s, {priority: 'event'});", nome, linha$id)
  botao <- function(nome, rotulo, icone, classe) tags$button(
    type = "button", class = paste("btn-icone", classe), title = rotulo, `aria-label` = rotulo,
    onclick = paste("event.stopPropagation();", evento(nome)),
    icon(icone)
  )

  div(
    class = paste("cartao-entrega", if (!editavel) "somente-leitura"),
    tabindex = "0", role = "button",
    onclick = evento("abrir_entrega"),
    onkeydown = sprintf(
      "if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); %s }",
      evento("abrir_entrega")
    ),
    div(
      class = paste("cartao-dia", if (mensal) "cartao-dia-mensal"),
      # O lançamento mensal não tem dia: o bloco mostra o mês e o ano
      span(class = "dia", if (mensal) toupper(substr(MESES[[format(data, "%m")]], 1, 3)) else format(data, "%d")),
      span(class = "mes", if (mensal) format(data, "%Y") else toupper(substr(MESES[[format(data, "%m")]], 1, 3)))
    ),
    div(
      class = "cartao-info",
      div(class = "cartao-atividade",
          span(class = "cartao-codigo", codigo),
          span(class = "cartao-descricao", descricao)),
      div(class = "cartao-meta",
          HTML(selo_status(linha$status)),
          HTML(selo_origem(linha$origem %||% "diario", linha$envio %||% "enviado")),
          span(class = "cartao-data",
               if (mensal) paste("Mês de", MESES[[format(data, "%m")]]) else fmt_data(data)))
    ),
    div(
      class = "cartao-numeros",
      div(class = "numero",
          span(class = "numero-valor", fmt_num(linha$horas, 1)),
          span(class = "numero-rotulo", "horas")),
      div(class = "numero",
          span(class = "numero-valor", fmt_num(linha$entregas, 0)),
          span(class = "numero-rotulo", if (isTRUE(linha$entregas == 1)) "entrega" else "entregas"))
    ),
    div(
      class = "cartao-acoes",
      if (editavel) botao("abrir_entrega", "Editar lançamento", "pen", "btn-icone-editar"),
      if (editavel) botao("remover_entrega", "Remover lançamento", "trash", "btn-icone-remover"),
      if (!editavel) span(class = "cartao-bloqueado", title = "Ano fechado", icon("lock"))
    )
  )
}

# Valor seguro para interpolar em um atributo JavaScript
js_valor <- function(x) {
  if (is.numeric(x)) return(as.character(x))
  paste0("'", gsub("'", "\\\\'", gsub("\\\\", "\\\\\\\\", as.character(x))), "'")
}

# Botão redondo que envia um evento ao servidor com o identificador do registro
botao_evento <- function(nome, valor, rotulo, icone, classe = "", parar_propagacao = TRUE) {
  tags$button(
    type = "button", class = paste("btn-icone", classe), title = rotulo, `aria-label` = rotulo,
    onclick = paste0(
      if (parar_propagacao) "event.stopPropagation(); ",
      sprintf("Shiny.setInputValue('%s', %s, {priority: 'event'});", nome, js_valor(valor))
    ),
    icon(icone)
  )
}

# Linha de uma lista administrativa (anos, atividades, servidores)
linha_registro <- function(destaque, titulo, subtitulo = NULL, selo = NULL, acoes = NULL,
                           evento = NULL, valor = NULL) {
  clicavel <- !is.null(evento)
  chamada <- if (clicavel) sprintf("Shiny.setInputValue('%s', %s, {priority: 'event'});", evento, js_valor(valor))

  div(
    class = paste("linha-registro", if (clicavel) "clicavel"),
    tabindex = if (clicavel) "0",
    role = if (clicavel) "button",
    onclick = chamada,
    onkeydown = if (clicavel) sprintf(
      "if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); %s }", chamada
    ),
    div(class = "registro-destaque", destaque),
    div(
      class = "registro-texto",
      div(class = "registro-titulo", titulo),
      if (!is.null(subtitulo)) div(class = "registro-subtitulo", subtitulo)
    ),
    if (!is.null(selo)) div(class = "registro-selo", selo),
    div(class = "registro-acoes", acoes)
  )
}

# Valor de filtro entre barras verticais: a busca por "|A01|" não alcança "|A01 - interno|"
marca <- function(x) paste0("|", x, "|")

# Barra proporcional usada nos relatórios (percentual do esforço do mês)
barra_percentual <- function(percentual, cor = "#2A5C92", estimado = FALSE) {
  sprintf(
    '<div class="celula-barra"%s><span class="celula-valor">%s%%%s</span><span class="barra-mini"><span style="width:%.1f%%; background:%s;"></span></span></div>',
    if (isTRUE(estimado)) ' title="Estimado pela quantidade de entregas: o mês não tem horas informadas."' else "",
    formatC(percentual, format = "f", digits = 1, decimal.mark = ","),
    if (isTRUE(estimado)) "*" else "",
    min(percentual, 100), cor
  )
}

# -------------------------------
# Exportação das tabelas
# -------------------------------

# A logo viaja embutida no PDF, gerado no navegador pelo pdfmake
LOGO_PDF <- tryCatch(
  base64enc::dataURI(file = "www/img/logo_app.png", mime = "image/png"),
  error = function(e) NULL
)

# As bibliotecas de exportação só são incluídas automaticamente pelo DT quando os
# botões são declarados de forma simples; com a configuração detalhada abaixo,
# elas precisam ser anexadas à página.
dependencias_exportacao <- function() {
  pasta <- system.file("htmlwidgets/lib/datatables-extensions/Buttons/js", package = "DT")
  if (!nzchar(pasta)) return(NULL)
  versao <- as.character(utils::packageVersion("DT"))
  list(
    htmltools::htmlDependency("jszip", versao, src = c(file = pasta), script = "jszip.min.js"),
    htmltools::htmlDependency("pdfmake", versao, src = c(file = pasta),
                              script = c("pdfmake.js", "vfs_fonts.js"))
  )
}

js_txt <- function(x) {
  escapado <- gsub("\\", "\\\\", x, fixed = TRUE)
  paste0('"', gsub('"', '\\"', escapado, fixed = TRUE), '"')
}

# Menu de exportação: cada formato pode sair com o que está filtrado ou com a
# tabela inteira. `chave` liga a tabela ao texto de filtros enviado pelo servidor.
botoes_exportacao <- function(titulo, chave, direita = integer(), flexivel = integer()) {
  sem_marcacao <- list(
    body = JS("function(d) { return meTexto(d); }"),
    header = JS("function(d) { return meTexto(d); }")
  )
  opcoes <- function(filtrado) list(
    # ":visible" impede que as colunas de apoio, usadas apenas como chave de
    # filtro, apareçam no PDF, no Excel ou no CSV
    columns = ":visible",
    modifier = list(search = if (filtrado) "applied" else "none", order = "applied", page = "all"),
    format = sem_marcacao
  )
  # Esta versão do Buttons deriva o nome do arquivo do título, então ele carrega
  # o nome do sistema, o da tabela e a data da exportação.
  nome_arquivo <- paste("Minhas Entregas -", titulo, "-", format(Sys.Date(), "%d-%m-%Y"))
  lista_js <- function(x) paste0("[", paste(as.integer(x), collapse = ", "), "]")
  escopo <- function(filtrado) {
    if (filtrado) "Somente os registros filtrados" else "Tabela completa, sem filtros"
  }

  botao <- function(tipo, rotulo, filtrado, extra = list()) {
    c(list(
      extend = tipo, text = rotulo, title = nome_arquivo,
      exportOptions = opcoes(filtrado)
    ), extra)
  }
  pdf <- function(rotulo, filtrado) botao("pdfHtml5", rotulo, filtrado, list(
    pageSize = "A4", orientation = "portrait",
    customize = JS(sprintf(
      "function(doc) { mePdf(doc, { titulo: %s, escopo: %s, chave: %s, filtrado: %s, direita: %s, flexivel: %s }); }",
      js_txt(titulo), js_txt(escopo(filtrado)), js_txt(chave),
      if (filtrado) "true" else "false", lista_js(direita), lista_js(flexivel)
    ))
  ))

  list(
    list(
      extend = "collection", className = "btn-exportar",
      text = "<i class=\"fa fa-file-arrow-down\"></i> Exportar o que está filtrado",
      buttons = list(
        pdf("PDF", TRUE),
        botao("excelHtml5", "Excel", TRUE),
        botao("csvHtml5", "CSV", TRUE),
        botao("copyHtml5", "Copiar", TRUE)
      )
    ),
    list(
      extend = "collection", className = "btn-exportar btn-exportar-tudo",
      text = "<i class=\"fa fa-database\"></i> Exportar a tabela completa",
      buttons = list(
        pdf("PDF", FALSE),
        botao("excelHtml5", "Excel", FALSE),
        botao("csvHtml5", "CSV", FALSE)
      )
    ),
    list(extend = "print", text = "<i class=\"fa fa-print\"></i> Imprimir", className = "btn-exportar",
         title = nome_arquivo, exportOptions = opcoes(TRUE))
  )
}

kpi <- function(rotulo, valor, detalhe = NULL, destaque = FALSE) {
  div(
    class = paste("kpi", if (destaque) "kpi-destaque"),
    div(class = "kpi-rotulo", rotulo),
    div(class = "kpi-valor", valor),
    if (!is.null(detalhe)) div(class = "kpi-detalhe", detalhe)
  )
}

cabecalho_secao <- function(icone, titulo, tag = NULL, classe_tag = NULL) {
  div(
    class = "cabecalho-secao",
    h4(icon(icone), titulo),
    if (!is.null(tag)) div(class = paste("tag-secao", classe_tag), tag)
  )
}
