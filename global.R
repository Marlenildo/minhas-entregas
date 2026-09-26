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

selo_ano <- function(status) {
  classe <- ifelse(status == "aberto", "selo-aberto", "selo-fechado")
  sprintf('<span class="selo-status %s">%s</span>', classe, htmltools::htmlEscape(status))
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
