# Changelog – app_entregas

---
## [Unreleased]
- Em desenvolvimento

---
## [2.1.0] - 2025-12-15
### Added
- Separação de pool de leitura e escrita no banco de dados.
- Finalização segura das conexões via onStop().

### Changed
- Ajuste da configuração de credenciais via .Renviron.
- Refatoração das chamadas ao banco para maior segurança e desempenho.

### Fixed
- Possível vazamento de conexões em reinício do app.

---
## [2.0.0] – 2025-12-13
### Added
- Seletor de ano do ciclo na aba Minhas entregas
- Bloqueio de edição/inserção/remoção quando ano estiver fechado
- Bloqueio de inserção, edição e remoção em anos fechados
- Restrição automática de datas ao ano selecionado
- Indicador visual de status do ano (aberto/fechado)

### Changed
- Restrição de data ao intervalo do ano selecionado
- Ajustes de UI/estado visual (aberto/fechado)

---
## [1.2.0] – 2025-12-12
### Changed
- Migração do acesso ao PostgreSQL para pool de conexões
- Melhoria de estabilidade e gerenciamento de conexões

---
## [1.1.1] – 2025-12-12
### Changed
- Exibição da versão do aplicativo no rodapé

---
## [1.1.0] – 2025-12-12
### Changed
- Ordenação da tabela de entregas agora é decrescente por padrão

---
## [1.0.0] – 2025-12-12
### Added
- Versão inicial funcional do sistema de gestão de entregas
- Integração com PostgreSQL (Render)
- Controle por usuário e perfil (admin/usuário)
- Relatórios com exportação
