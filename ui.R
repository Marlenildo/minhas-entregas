#' Data da última atualização: [02/12/2025]

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
fluidPage(
  tags$head(
    includeCSS("www/estilo.css")
  ),
  
  ## Cabeçalho----
  div(
    class = "top-panel",
    style = "justify-content: center;",
    img(src = "logo_app_entregas.png"),
    span("App Entregas")
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
    img(src = "logo_ufpb_sisdip.png", height = "60px", style = "vertical-align: middle; margin-right: 8px;"),
    "© 2025 - Desenvolvido por Marlenildo Melo. Todos os direitos reservados."
  )
)
