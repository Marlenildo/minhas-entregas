library(shiny)
library(DBI)
library(RPostgres)
library(DT)
library(pool)
library(shinyjs)

# -------------------------------
# Versão do aplicativo
# -------------------------------
APP_VERSION <- tryCatch(
  readLines("VERSION", warn = FALSE),
  error = function(e) "dev"
)
