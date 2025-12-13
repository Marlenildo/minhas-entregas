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

# -------------------------------
# Pool de conexões PostgreSQL
# -------------------------------
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
