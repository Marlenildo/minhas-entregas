# Apaga o endereço IP e o navegador (user agent) gravados por versões anteriores
# à 3.0.2 em login_logs e audit_logs. Os registros de acesso e de auditoria são
# preservados: apenas essas duas colunas ficam nulas.
#
# Usa as mesmas variáveis de ambiente do aplicativo, com o usuário de escrita.
# Uso: Rscript scripts/limpar_registros_de_rede.R

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

contar <- function(tabela) {
  linha <- dbGetQuery(con, sprintf(
    "SELECT COUNT(*) FILTER (WHERE ip IS NOT NULL OR user_agent IS NOT NULL) AS com_dados,
            COUNT(*) AS total
     FROM %s", tabela
  ))
  # COUNT vem como bigint (numérico); convertido para inteiro por causa do sprintf
  list(com_dados = as.integer(linha$com_dados), total = as.integer(linha$total))
}

tabelas <- c("login_logs", "audit_logs")

cat("Antes da limpeza:\n")
antes <- lapply(tabelas, contar)
for (i in seq_along(tabelas)) {
  cat(sprintf("  %-12s %d de %d registros com IP ou navegador\n",
              tabelas[i], antes[[i]]$com_dados, antes[[i]]$total))
}

if (sum(vapply(antes, function(x) x$com_dados, integer(1))) == 0) {
  cat("\nNada a limpar.\n")
} else {
  prosseguir <- TRUE
  if (interactive()) {
    resposta <- readline("\nApagar esses valores? Esta ação não pode ser desfeita. (s/N) ")
    prosseguir <- tolower(trimws(resposta)) %in% c("s", "sim")
  }

  if (!prosseguir) {
    cat("Cancelado. Nenhuma alteração foi feita.\n")
  } else {
  dbWithTransaction(con, {
    for (tabela in tabelas) {
      dbExecute(con, sprintf(
        "UPDATE %s SET ip = NULL, user_agent = NULL
         WHERE ip IS NOT NULL OR user_agent IS NOT NULL", tabela
      ))
    }
  })

  cat("\nDepois da limpeza:\n")
  for (tabela in tabelas) {
    depois <- contar(tabela)
    cat(sprintf("  %-12s %d de %d registros com IP ou navegador\n",
                tabela, depois$com_dados, depois$total))
  }
  }
}
