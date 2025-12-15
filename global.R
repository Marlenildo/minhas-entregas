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
