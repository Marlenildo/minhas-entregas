# Minhas Entregas

Aplicação Shiny para registro, acompanhamento e administração de entregas por servidor, com autenticação por SIAPE, controle por ciclo anual, relatórios filtráveis e painel administrativo.

## Apresentação

**Minhas Entregas** é o nome oficial do produto e deve ser utilizado como referência principal em interface, documentação, materiais de apoio e comunicação com usuários.

Trata-se de uma aplicação desenvolvida para apoiar o controle operacional de atividades entregues por usuários autenticados, permitindo registrar lançamentos, consolidar informações, administrar dados auxiliares e acompanhar resultados por meio de relatórios.

## Objetivo do sistema

O sistema foi pensado para um contexto institucional, com separação entre perfis de usuário comum e administrador, regras de controle por ano de ciclo e integração com banco de dados PostgreSQL.

Seu objetivo é oferecer uma base confiável para:

- registrar entregas realizadas por servidor;
- consultar históricos individuais ou consolidados;
- administrar dados auxiliares do ambiente;
- acompanhar resultados com filtros e relatórios;
- aplicar regras de governança por ciclo anual.

## Principais funcionalidades

- Tela de acesso dedicada, com aviso sobre os dados guardados e a finalidade do sistema.
- Autenticação por SIAPE e senha, com limite de tentativas sem sucesso.
- Registro, edição e exclusão de entregas pelo próprio usuário, em cartões com ação direta e confirmação.
- Lançamento mensal em matriz: uma atividade por vez, com as entregas e as horas de cada mês do ano, guardadas como rascunho até o envio ao gestor.
- Controle de ano de ciclo com status aberto ou fechado.
- Restrição de edição em anos fechados.
- Painel de esforço do mês, com a distribuição das horas por atividade.
- Filtros de mês, atividade e situação na lista de lançamentos.
- Ano do ciclo escolhido no cabeçalho, válido para todas as abas: lançamento, matriz mensal e relatório usam o mesmo ano, e o relatório permite abrir a série completa com "Todos os anos".
- Relatórios com filtros por mês, servidor e código. Para o administrador, o relatório soma as entregas de todos os servidores em cada atividade e mês; o detalhe individual fica na visão de todas as entregas.
- Exportação das tabelas em PDF, Excel e CSV, com escolha entre os registros filtrados e a tabela completa, que ignora os filtros da tela. O PDF sai com cabeçalho, identificação do conteúdo e rodapé com data e hora da emissão.
- Painel administrativo para gerenciar anos, códigos e servidores.
- Auditoria de ações administrativas sobre anos de ciclo.
- Uso de pools de conexão separados para leitura e escrita no PostgreSQL.
- Interface responsiva, adequada ao uso em computador e em celular.

## Dados pessoais

O sistema guarda apenas o nome, o SIAPE e as entregas registradas por cada servidor. Dos acessos fica
registrado somente o momento e se a tentativa deu certo, para a segurança da conta. Não são coletados
endereço de rede, informações de navegador ou qualquer outro dado pessoal. A finalidade do tratamento
é exclusivamente apoiar o servidor na organização das suas entregas e do esforço dedicado a elas.

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
- `www/css/app.css`: estilos da interface, na mesma identidade visual do Croma.
- `www/img/`: logo do aplicativo, favicon e logo do rodapé.
- `www/js/exportacao.js`: montagem do PDF de exportação e utilidades das tabelas.
- `scripts/gerar_logo_app.R`: gera a logo e o favicon a partir de cores CIELCH (`Rscript scripts/gerar_logo_app.R`).
- `scripts/limpar_registros_de_rede.R`: manutenção pontual, descrita no `RUNBOOK.md`.
- `scripts/migrar_lancamento_mensal.R`: prepara o banco para o lançamento mensal.
- `VERSION`: armazena a versão atual da aplicação.
- `manifest.json`: descreve o ambiente R para publicação no Posit Connect Cloud.
- `.Renviron.example`: modelo das variáveis de ambiente, sem valores reais.
- `CHANGELOG.md`: registra o histórico de alterações por versão.
- `RUNBOOK.md`: reúne procedimentos operacionais, implantação e suporte.
- `LICENSE`: descreve o regime de proteção jurídica e os direitos autorais do projeto.

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
- Acesso a uma instância PostgreSQL compatível com a configuração do sistema.
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

O repositório traz um modelo em `.Renviron.example`. Copie-o e preencha com os valores do seu ambiente:

```r
file.copy(".Renviron.example", ".Renviron")
```

O `.Renviron` real fica fora do versionamento (o `.gitignore` já ignora `.Renviron` e `.env`). O R lê o
arquivo ao iniciar a sessão, então reinicie o R depois de alterá-lo.

Na publicação, as mesmas variáveis são cadastradas nas configurações do conteúdo dentro da plataforma,
nunca no repositório. O `RUNBOOK.md` detalha o conteúdo de cada variável e onde encontrar os valores
em uso.

## Execução local

No diretório do aplicativo, execute:

```r
shiny::runApp()
```

Ou, pelo terminal:

```powershell
Rscript -e "shiny::runApp('.')"
```

## Publicação no Posit Connect Cloud

O repositório inclui um `manifest.json`, então o aplicativo pode ser publicado direto do GitHub em
[connect.posit.cloud](https://connect.posit.cloud) (**Publish → Shiny → repositório `Marlenildo/minhas-entregas`,
branch `main`**).

Antes da primeira publicação, cadastre as variáveis de ambiente do banco na própria plataforma
(`DB_NAME`, `DB_HOST`, `DB_PORT`, `PGSSLMODE`, `DB_USER_WRITE`, `DB_PASSWORD_WRITE`, `DB_USER_READ`,
`DB_PASSWORD_READ`). Elas não ficam no repositório.

Ao adicionar ou atualizar pacotes, regenere o manifesto no ambiente em que o app roda:

```r
rsconnect::writeManifest(
  appDir   = ".",
  appFiles = c("global.R", "ui.R", "server.R", "VERSION",
               list.files("www", recursive = TRUE, full.names = TRUE))
)
```

O manifesto fixa a versão do R e a versão de cada pacote usada na geração. Regenerá-lo na máquina de
desenvolvimento mantém a publicação alinhada ao ambiente em que o aplicativo foi testado.

## Banco de dados

O Minhas Entregas utiliza PostgreSQL com separação entre conexão de leitura e conexão de escrita. Essa abordagem contribui para melhor organização das permissões e maior previsibilidade na comunicação com o banco.

## Documentação operacional

As instruções operacionais, de manutenção, validação e suporte foram separadas em `RUNBOOK.md`, para manter este `README.md` mais objetivo e facilitar a consulta no dia a dia.

## Identidade do produto

O nome oficial do sistema é **Minhas Entregas**.

Quando existir algum identificador legado em infraestrutura, rotas ou serviços externos, ele deve ser tratado apenas como detalhe técnico de compatibilidade, sem substituir o nome institucional do produto.

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
