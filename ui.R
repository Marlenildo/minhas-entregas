#' Data da última atualização: [02/12/2025]

library(shiny)
library(DBI)
library(RPostgres)
library(DT)
library(pool)


# Conexão com PostgreSQL ----
pool <- dbPool(
  drv      = RPostgres::Postgres(),
  dbname   = Sys.getenv("DB_NAME"),
  host     = Sys.getenv("DB_HOST"),
  port     = Sys.getenv("DB_PORT"),
  user     = Sys.getenv("DB_USER"),
  password = Sys.getenv("DB_PASSWORD"),
  sslmode  = Sys.getenv("PGSSLMODE"),
  minSize  = 1,
  maxSize  = 10
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
    class = "footer",
    # Logos
    div(
      img(src = "logo_index.png")
    ),
    
    div(
      class = "footer-version",
      paste0(
        "Desenvolvido por Marlenildo Melo © 2025 | App Entregas • Versão ",
        APP_VERSION
      )
    )
  )
  
)
