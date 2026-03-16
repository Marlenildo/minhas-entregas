# Changelog - Minhas Entregas

Todas as alterações relevantes do Minhas Entregas são documentadas aqui.

---
## [Unreleased]
- Em desenvolvimento.

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
