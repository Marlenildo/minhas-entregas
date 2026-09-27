# Prepara o banco para o lançamento mensal (versão 3.3.0).
#
# Acrescenta duas colunas a `entregas` e um índice. Nada é apagado e nenhum
# registro existente muda de comportamento: os padrões reproduzem o que já valia
# antes (lançamento diário, já enviado ao gestor).
#
#   origem  'diario' (padrão) ou 'mensal'
#   envio   'enviado' (padrão) ou 'rascunho'
#
# O índice impede que a mesma atividade seja registrada duas vezes no mesmo mês
# pela matriz. Os lançamentos mensais sempre usam o dia 1º do mês.
#
# Uso: Rscript scripts/migrar_lancamento_mensal.R

library(DBI)
library(RPostgres)

con <- dbConnect(
  RPostgres::Postgres(),
  dbname   = Sys.getenv("DB_NAME"),
  host     = Sys.getenv("DB_HOST"),
  port     = Sys.getenv("DB_PORT"),
  user     = Sys.getenv("DB_USER_WRITE"),
  password = Sys.getenv("DB_PASSWORD_WRITE"),
  sslmode  = Sys.getenv("PGSSLMODE")
)
on.exit(dbDisconnect(con), add = TRUE)

comandos <- c(
  "ALTER TABLE entregas ADD COLUMN IF NOT EXISTS origem text NOT NULL DEFAULT 'diario'",
  "ALTER TABLE entregas ADD COLUMN IF NOT EXISTS envio  text NOT NULL DEFAULT 'enviado'",
  "CREATE UNIQUE INDEX IF NOT EXISTS entregas_mensal_unica
     ON entregas (servidor, codigo, data) WHERE origem = 'mensal'"
)

invisible(dbWithTransaction(con, {
  for (comando in comandos) dbExecute(con, comando)
}))

colunas <- dbGetQuery(
  con,
  "SELECT column_name, column_default
     FROM information_schema.columns
    WHERE table_name = 'entregas' AND column_name IN ('origem', 'envio')
    ORDER BY column_name"
)
indice <- dbGetQuery(
  con,
  "SELECT indexname FROM pg_indexes
    WHERE tablename = 'entregas' AND indexname = 'entregas_mensal_unica'"
)

cat("Colunas criadas:\n")
if (nrow(colunas) == 0) cat("  nenhuma\n") else
  for (i in seq_len(nrow(colunas))) {
    cat(sprintf("  %-8s padrão %s\n", colunas$column_name[i], colunas$column_default[i]))
  }
cat("Índice entregas_mensal_unica:", if (nrow(indice) > 0) "criado" else "ausente", "\n")
cat("\nBanco pronto para o lançamento mensal.\n")
