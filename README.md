# Minhas Entregas

Aplicação Shiny para registro, acompanhamento e administração de entregas por servidor, com autenticação por SIAPE, controle por ciclo anual, relatórios filtráveis e painel administrativo.

## Apresentação

**Minhas Entregas** é o nome oficial do produto. Trata-se de uma aplicação desenvolvida para apoiar o controle operacional de atividades entregues por usuários autenticados, permitindo registrar lançamentos, consolidar informações, administrar dados auxiliares e acompanhar resultados por meio de relatórios.

No contexto técnico deste repositório, alguns arquivos e identificadores internos ainda podem utilizar o nome `app_entregas`, que corresponde ao identificador do projeto no código e em parte da infraestrutura. Sempre que houver diferença entre o nome técnico e o nome do produto, deve prevalecer, para fins de comunicação e apresentação, o nome **Minhas Entregas**.

## Objetivo do sistema

O sistema foi pensado para um contexto institucional, com separação entre perfis de usuário comum e administrador, regras de controle por ano de ciclo e integração com banco de dados PostgreSQL.

Seu objetivo é oferecer uma base confiável para:

- registrar entregas realizadas por servidor;
- consultar históricos individuais ou consolidados;
- administrar dados auxiliares do ambiente;
- acompanhar resultados com filtros e relatórios;
- aplicar regras de governança por ciclo anual.

## Principais funcionalidades

- Autenticação por SIAPE e senha.
- Registro, edição e exclusão de entregas pelo próprio usuário.
- Controle de ano de ciclo com status aberto ou fechado.
- Restrição de edição em anos fechados.
- Relatórios com filtros por ano, mês, servidor e código.
- Exportação de tabelas em formatos suportados pelo DataTables.
- Painel administrativo para gerenciar anos, códigos e servidores.
- Auditoria de ações administrativas sobre anos de ciclo.
- Uso de pools de conexão separados para leitura e escrita no PostgreSQL.

## Perfis de acesso

### Usuário comum

- Consulta as próprias entregas.
- Registra, atualiza e remove lançamentos quando o ano estiver aberto.
- Visualiza relatórios restritos aos próprios dados.

### Administrador

- Visualiza todos os registros do sistema.
- Gerencia anos de ciclo, códigos e servidores.
- Acompanha o histórico de auditoria das ações administrativas.
- Consulta relatórios consolidados do ambiente.

## Estrutura principal do projeto

- `ui.R`: define a interface da aplicação.
- `server.R`: concentra as regras de negócio, autenticação, CRUD e relatórios.
- `global.R`: carrega a versão do aplicativo e configura os pools de conexão.
- `www/`: contém os arquivos estáticos da interface, como CSS e imagens.
- `VERSION`: armazena a versão atual da aplicação.
- `CHANGELOG.md`: registra o histórico de alterações por versão.
- `RUNBOOK.md`: reúne procedimentos operacionais, implantação e suporte.
- `LICENSE`: descreve o regime de proteção jurídica e direitos autorais do projeto.

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

## Requisitos

- R instalado no ambiente.
- Pacotes R exigidos pelo projeto.
- Acesso a uma instância PostgreSQL compatível com a configuração do app.
- Variáveis de ambiente configuradas com as credenciais do banco.

## Configuração de ambiente

O aplicativo utiliza as seguintes variáveis de ambiente:

- `DB_NAME`
- `DB_HOST`
- `DB_PORT`
- `PGSSLMODE`
- `DB_USER_WRITE`
- `DB_PASSWORD_WRITE`
- `DB_USER_READ`
- `DB_PASSWORD_READ`

Recomenda-se manter essas informações em um arquivo `.Renviron` local, fora do versionamento.

## Execução local

No diretório do aplicativo, execute:

```r
shiny::runApp()
```

Ou, pelo terminal:

```powershell
Rscript -e "shiny::runApp('.')"
```

## Banco de dados

O Minhas Entregas utiliza PostgreSQL com separação entre conexão de leitura e conexão de escrita. Essa abordagem contribui para melhor organização das permissões e maior previsibilidade na comunicação com o banco.

## Documentação operacional

As instruções operacionais, de manutenção, validação e suporte foram separadas em `RUNBOOK.md`, para manter este `README.md` mais objetivo e facilitar a consulta no dia a dia.

## Convenção de nomenclatura

Este projeto adota a seguinte convenção:

- **Minhas Entregas**: nome funcional, institucional e de apresentação do sistema.
- `app_entregas`: identificador técnico do repositório, de arquivos legados e de alguns metadados de implantação.

Sempre que novos materiais forem produzidos, a recomendação é priorizar o nome **Minhas Entregas** em interfaces, documentação e comunicação externa.

## Licenciamento e direitos autorais

Este projeto **não é software livre** e **não é open source**.

O código-fonte, os ativos visuais, os arquivos de configuração, a documentação e os demais conteúdos deste repositório pertencem ao autor e estão protegidos por copyright, com **todos os direitos reservados**.

Consulte o arquivo `LICENSE` para os termos completos de uso e restrição.

## Idioma da documentação

Este repositório adota o **português do Brasil** como idioma principal da documentação, por ser o idioma mais adequado ao contexto do projeto, do autor e do uso esperado da aplicação.

Se, no futuro, houver interesse em ampliar o alcance público do projeto, pode ser criada uma versão complementar em inglês, sem substituir a documentação principal em português.

## Autor

**Marlenildo Melo**

## Observação importante

A publicação deste repositório em plataforma pública ou privada não implica concessão automática de licença de uso, redistribuição, modificação ou exploração do software.
