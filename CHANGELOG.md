# Changelog - Minhas Entregas

Todas as alterações relevantes do Minhas Entregas são documentadas aqui.

---
## [Unreleased]
- Em desenvolvimento.

---
## [3.0.3] - 2026-09-26

### Fixed
- Publicação no Posit Connect Cloud: o `manifest.json` passa a fixar `bcrypt` 1.2.0. A versão 1.2.1 exige `openssl` 2.3.5 ou superior, enquanto o ambiente da plataforma fornece `openssl` 2.1.1, o que fazia a instalação do pacote falhar e abortar a publicação. O formato dos hashes de senha é o mesmo nas duas versões, então as senhas já cadastradas continuam válidas.

### Added
- Documentação das variáveis de ambiente no `RUNBOOK.md`: conteúdo de cada uma, onde encontrar os valores em uso e como cadastrá-las na plataforma de publicação.

---
## [3.0.2] - 2026-09-26

### Removed
- Registro do endereço IP e do navegador (user agent) nos acessos e nas ações administrativas. O sistema passa a guardar apenas o necessário para a finalidade declarada, em linha com o princípio da necessidade da LGPD.

### Changed
- Aviso de privacidade da tela de acesso: passa a declarar que nenhum endereço de rede ou informação de navegador é guardado, e que do acesso fica registrada apenas a data, a hora e se a tentativa deu certo.
- Histórico de ações administrativas deixa de exibir a coluna de IP.

### Note
- As colunas `ip` e `user_agent` continuam existindo em `login_logs` e `audit_logs`, mas não são mais preenchidas. Os valores gravados antes desta versão permanecem no banco e podem ser apagados pelo responsável (ver `RUNBOOK.md`).

---
## [3.0.1] - 2026-09-26

### Added
- `manifest.json` para publicação direta no Posit Connect Cloud, com as instruções de publicação no `README.md` e no `RUNBOOK.md`.

### Changed
- Logo e favicon com traços mais espessos e a mesma espessura nos arcos e no sinal de entrega concluída.

---
## [3.0.0] - 2026-09-26

### Added
- Aviso de privacidade e finalidade na tela de acesso: quais dados são guardados (nome, SIAPE e as entregas registradas), o registro de acessos mantido por segurança e o propósito do sistema.
- Lançamentos apresentados como cartões, agrupados por mês com subtotal de horas e entregas. Clicar no cartão abre a janela de edição, com os botões de editar e remover no próprio cartão.
- Listas de anos do ciclo, atividades e servidores em cartões, com as ações em cada item e formulário em janela, no lugar do formulário fixo acima da tabela.
- Coluna de esforço dos relatórios exibida como barra proporcional.
- Idioma português no calendário do seletor de data, que o Shiny não distribui por padrão.
- Nova identidade visual alinhada ao Croma: paleta azul institucional/verde, painéis, abas, indicadores, tabelas e janelas de confirmação padronizados (`www/css/app.css`).
- Nova logo do Minhas Entregas e favicon, gerados por `scripts/gerar_logo_app.R`: desenho plano, com o anel de esforço por atividade em traços de pontas arredondadas e o sinal de entrega concluída ao centro.
- Tela de acesso dedicada: após o login ela é ocultada e o app mostra o nome do servidor e o botão **Sair**.
- Painel **Esforço do mês** na aba de entregas: horas, entregas, atividades e distribuição percentual das horas por atividade no mês escolhido.
- Indicadores resumidos nos relatórios e na visão administrativa de todas as entregas, com o nome do servidor.
- Coluna "Senha configurada" na administração de servidores (a senha em hash deixa de ser exibida).

### Changed
- Fim das tabelas DataTables nas telas de manutenção: elas permanecem apenas onde servem para explorar e exportar dados (relatórios, todas as entregas e auditoria), agora com colunas secundárias ocultas em telas estreitas.
- Ações passam a ficar junto do registro, em vez de um formulário único no topo da página.
- Relatórios com rótulos em português, nomes dos meses e percentuais com vírgula decimal.
- Ao criar ou abrir um ano de ciclo, os demais são fechados na mesma transação; a criação de ano passa a ser auditada.
- `global.R` deixa de ser carregado mais de uma vez (menos conexões abertas com o banco).

### Security
- Todas as saídas e ações administrativas passam a exigir o perfil de administrador no servidor, não apenas na interface.
- Validação no servidor de data, atividade, horas, entregas e situação antes de gravar.
- Limite de 5 tentativas de login sem sucesso por sessão, com espera de 1 minuto.
- SIAPE e senha são enviados juntos no login, evitando falhas ao colar a senha e apertar Enter.
- Edição e remoção usam o registro confirmado na janela de confirmação, e não a seleção atual da tabela.

---
## [2.2.5] - 2026-03-16

### Changed
- Padronização visual do campo de data da aba de entregas para o formato brasileiro `dd/mm/yyyy`.
- Ajuste do seletor de data para exibir calendário em português e início da semana na segunda-feira.
- Padronização da data inicial e do reset do formulário conforme o ano de ciclo selecionado, priorizando a data atual quando o ciclo corresponde ao ano corrente.

---
## [2.2.4] - 2026-03-16

### Changed
- Refinamento institucional do rodapé da interface, com referência explícita a direitos reservados, licença proprietária e versão do sistema.
- Consolidação do nome **Minhas Entregas** como referência pública principal do produto na documentação.
- Ajuste do `README.md` e do `RUNBOOK.md` para reduzir o uso de nomenclaturas técnicas legadas fora de contexto operacional.

---
## [2.2.3] - 2026-03-16

### Changed
- Padronização do nome do produto para **Minhas Entregas** na documentação principal e na interface visível do aplicativo.
- Refinamento do `README.md` para refletir o nome oficial do sistema e separar melhor a documentação institucional da operacional.
- Atualização do `RUNBOOK.md` e da `LICENSE` para manter alinhamento com a identidade do produto.

---
## [2.2.2] - 2026-03-16

### Fixed
- Atualização reativa do relatório após adicionar, editar ou remover entregas.
- Sincronização dos filtros e das tabelas derivadas com as alterações feitas em `entregas` na mesma sessão.

---
## [2.2.1] - 2025-12-16

### Added
- Auditoria administrativa para ações sobre anos de ciclo.
- Visualização do histórico de auditoria no painel do administrador.

### Changed
- Reorganização da ordem das abas no painel administrativo.
- Seleção automática do ano aberto ou mais recente na aba “Minhas entregas”.

### Fixed
- Ajustes de governança no controle de anos e permissões.

---
## [2.2.0] - 2025-12-16

### Adicionado
- Confirmação obrigatória para edição e remoção de anos de ciclo.
- Auditoria administrativa para ações sobre anos, incluindo abrir, fechar e remover.
- Visualização do histórico de auditoria no painel administrativo.

### Refatorado
- Padronização de modais de confirmação por meio de helper genérico.

---
## [2.1.1] - 2025-12-16

### Corrigido
- Correção crítica no `INSERT` da tabela `entregas`, passando explicitamente a coluna `ano`.
- Ajuste para compatibilidade com a trigger `bloquear_ano_fechado`.
- Eliminação do erro `Ano <NULL> não está cadastrado em anos_ciclo`.
- Estabilização do uso de `pool_read` e `pool_write` após falha de trigger.

---
## [2.1.0] - 2025-12-15

### Added
- Separação de pool de leitura e escrita no banco de dados.
- Finalização segura das conexões via `onStop()`.

### Changed
- Ajuste da configuração de credenciais via `.Renviron`.
- Refatoração das chamadas ao banco para maior segurança e desempenho.

### Fixed
- Possível vazamento de conexões em reinício do app.

---
## [2.0.0] - 2025-12-13

### Added
- Seletor de ano do ciclo na aba Minhas entregas.
- Bloqueio de edição, inserção e remoção quando o ano estiver fechado.
- Restrição automática de datas ao ano selecionado.
- Indicador visual de status do ano, aberto ou fechado.

### Changed
- Restrição de data ao intervalo do ano selecionado.
- Ajustes de interface e estado visual conforme o status do ano.

---
## [1.2.0] - 2025-12-12

### Changed
- Migração do acesso ao PostgreSQL para pool de conexões.
- Melhoria de estabilidade e gerenciamento de conexões.

---
## [1.1.1] - 2025-12-12

### Changed
- Exibição da versão do aplicativo no rodapé.

---
## [1.1.0] - 2025-12-12

### Changed
- Ordenação da tabela de entregas em ordem decrescente por padrão.

---
## [1.0.0] - 2025-12-12

### Added
- Versão inicial funcional do sistema de gestão de entregas.
- Integração com PostgreSQL.
- Controle por usuário e perfil, com diferenciação entre administrador e usuário comum.
- Relatórios com exportação.
