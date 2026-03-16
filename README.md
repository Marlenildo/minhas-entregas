# App Entregas

Aplicacao Shiny para registro, consulta e administracao de entregas por servidor, com controle por ciclo anual, autenticacao por SIAPE, relatorios agregados e painel administrativo.

## Visao geral

O App Entregas foi desenvolvido para organizar o lancamento e o acompanhamento de entregas realizadas por usuarios autenticados. O sistema permite registrar atividades, consolidar relatorios e administrar a base de apoio do aplicativo.

## Principais funcionalidades

- Login por SIAPE e senha.
- Registro, edicao e exclusao de entregas pelo proprio usuario.
- Controle de ciclo anual com anos abertos e fechados.
- Relatorios com filtros por ano, mes, servidor e codigo.
- Exportacao das tabelas via DataTables.
- Painel administrativo para gerenciar anos, codigos e servidores.
- Auditoria de acoes administrativas sobre anos de ciclo.
- Separacao entre conexoes de leitura e escrita no PostgreSQL.

## Tecnologias utilizadas

- R
- Shiny
- DBI
- RPostgres
- pool
- DT
- shinyjs
- bcrypt
- PostgreSQL

## Estrutura principal

- `ui.R`: interface da aplicacao.
- `server.R`: regras de negocio, CRUD, login e relatorios.
- `global.R`: versao do app e pools de conexao com o banco.
- `www/estilo.css`: estilos da interface.
- `VERSION`: versao atual.
- `CHANGELOG.md`: historico de alteracoes.

## Perfis de uso

- Usuario comum: registra e consulta as proprias entregas.
- Administrador: visualiza todos os dados e gerencia anos, codigos, servidores e auditoria.

## Configuracao de ambiente

O app espera as seguintes variaveis de ambiente:

- `DB_NAME`
- `DB_HOST`
- `DB_PORT`
- `PGSSLMODE`
- `DB_USER_WRITE`
- `DB_PASSWORD_WRITE`
- `DB_USER_READ`
- `DB_PASSWORD_READ`

Essas credenciais nao devem ser versionadas no repositorio. O uso recomendado e um arquivo `.Renviron` local.

## Como executar localmente

1. Instale as dependencias do app no R.
2. Configure as variaveis de ambiente do banco.
3. No diretorio do projeto, execute:

```r
shiny::runApp()
```

Se preferir pelo terminal:

```powershell
Rscript -e "shiny::runApp('caminho/do/app_entregas')"
```

## Banco de dados

O aplicativo usa PostgreSQL com pools separados para leitura e escrita. Isso melhora a organizacao das credenciais e ajuda na estabilidade das conexoes.

## Direitos autorais e licenciamento

Este projeto nao e open source.

O codigo e os demais arquivos do repositorio pertencem ao autor e estao protegidos por copyright, com todos os direitos reservados. Consulte o arquivo `LICENSE` para os termos completos.

## Autor

Marlenildo Melo

## Observacao

Se este repositorio estiver publicado no GitHub, isso nao significa concessao de permissao para uso, redistribuicao ou modificacao fora das condicoes expressamente autorizadas pelo autor.
