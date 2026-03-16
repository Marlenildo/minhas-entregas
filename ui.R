#' Data da última atualização: [13/12/2025]

library(shiny)
library(DBI)
library(RPostgres)
library(DT)
library(pool)
library(shinyjs)


source("global.R")

# UI ----
fluidPage(
  shinyjs::useShinyjs(),
  tags$head(includeCSS("www/estilo.css")),
  
  ## Cabeçalho----
  div(
    class = "top-panel",
    style = "justify-content: center;",
    img(src = "logo_minhas_entregas.png"),
    span("Minhas Entregas")
  ),
  
  ## Login----
  div(
    style = "display:flex; flex-direction:column; align-items:center; margin-top:50px;",
    textInput("in_siape", "Digite seu SIAPE:"),
    passwordInput("in_senha", "Senha:"),
    actionButton("btn_entrar", "Entrar", class = "btn-primary")
  ),
  
  br(),
  hr(),
  
  ## Conteúdo principal----
  uiOutput("out_conteudo"),
  br(),
  br(),
  br(),
  hr(),
  
  ## Rodapé ----
  tags$footer(
    class = "footer",
    # Logos
    div(img(src = "logo_index.png")),
    
    div(
      class = "footer-version",
      paste0(
        "Minhas Entregas © 2025-2026 Marlenildo Melo | Todos os direitos reservados | Licença proprietária | Versão ",
        APP_VERSION
      )
    )
  )
  
)
