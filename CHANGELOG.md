# Changelog - Minhas Entregas

Todas as alterações relevantes do Minhas Entregas são documentadas aqui.

---
## [Unreleased]
- Em desenvolvimento.

---
## [3.4.0] - 2026-09-27

### Changed
- O **ano do ciclo passa a ser escolhido no cabeçalho**, fora das abas, com o selo de aberto ou fechado ao lado. Antes o seletor vivia dentro da aba "Minhas entregas" e governava também a aba mensal: na matriz aparecia o efeito do ano sem o controle que o define, e trocar de ano exigia sair da aba.
- O relatório passa a usar esse mesmo ano, em lugar do filtro de ano próprio, que começava em "Todos" e criava uma segunda noção de ano na mesma sessão. No lugar dele há a escolha entre **Ano do ciclo** e **Todos os anos**, porque consultar o histórico não exige um ano definido.
- Com um ano em vista, a tabela do relatório passa a conter apenas esse ano: "Exportar a tabela completa" significa o ano inteiro, sem os filtros de mês, servidor e atividade, e não mais a série de todos os anos.
- As opções de mês, servidor e atividade do relatório nascem do ano em vista, para não oferecer filtro que não devolve nada, e ganham rótulo próprio ("Todos os meses", "Todos os servidores", "Todas as atividades").
- Os filtros do relatório passam a usar a mesma barra de filtros das outras abas, com o escopo de anos em chips.
- O administrador também escolhe o ano no cabeçalho. A aba **Todas as entregas** segue mostrando todos os anos: é a visão de detalhe, com busca própria.

---
## [3.3.4] - 2026-09-27

### Changed
- A consulta do lançamento mensal em ano fechado passa a mostrar os dois caminhos de registro, lado a lado em cada mês: o que veio da matriz mensal e o que foi lançado dia a dia. Antes só apareciam os meses com lançamento mensal, e uma atividade registrada apenas no diário parecia vazia.
- O aviso de ano fechado explica que a consulta reúne os dois caminhos e que o consolidado ao final soma os dois.
- Em ano fechado, as etiquetas "Rascunho visível só para você" e "Editável a qualquer momento" deixam de aparecer na aba mensal: nada é editável ali, então elas enganavam.

---
## [3.3.3] - 2026-09-27

### Fixed
- O relatório do administrador voltava um total por servidor em cada linha, e não a soma do mês. A coluna de servidor foi removida e as linhas passam a somar as entregas e as horas de **todos os servidores** em cada atividade e mês, que é o consolidado usado para alimentar a ferramenta oficial.

### Changed
- O filtro de servidor no relatório passa a trocar o escopo do consolidado: com "Todos", soma toda a unidade; com um servidor escolhido, soma apenas o dele. Uma etiqueta no cabeçalho informa qual escopo está em vista e o PDF registra o servidor pelo nome.
- O esforço do mês passa a ser calculado sobre o escopo em vista, e não por servidor dentro do mês.
- A aba **Todas as entregas** segue mostrando cada lançamento com o servidor responsável, diário ou mensal: é lá que fica o detalhe individual.

---
## [3.3.2] - 2026-09-27

### Added
- Textos deixam claro que o lançamento pode ser alterado a qualquer momento, inclusive depois de enviado ao gestor: etiqueta "Editável a qualquer momento" na aba mensal, orientação na tela e aviso na mensagem de envio.
- Legenda visível abaixo da tabela de relatórios explicando o asterisco do esforço estimado, que antes só aparecia como dica ao passar o mouse e ficava invisível no celular. A mesma explicação passa a sair no PDF quando alguma linha exportada está estimada.

### Fixed
- As colunas de apoio usadas para filtrar a tabela (ano, mês, atividade e servidor) estavam saindo no PDF, no Excel e no CSV. A exportação passa a considerar apenas as colunas visíveis.

---
## [3.3.1] - 2026-09-27

### Changed
- Ano de ciclo fechado deixa a tela limpa: os campos de preenchimento e os botões de ação desaparecem, em vez de aparecerem desabilitados. Ficam o aviso do ano fechado e o que já está registrado.
- No lançamento mensal, o ano fechado mostra apenas os meses com valores, em formato de consulta, e avisa se restaram rascunhos que não chegaram ao gestor.
- O texto de orientação da aba mensal muda conforme o ano esteja aberto ou fechado.

---
## [3.3.0] - 2026-09-27

### Added
- **Lançamento mensal**: nova aba onde o servidor escolhe uma atividade e informa, de uma vez, as entregas e as horas de cada mês do ano. Mês deixado em branco não registra nada. Atende a prática real de consolidar o ano inteiro em vez de lançar todo dia.
- **Rascunho e envio ao gestor**: o que é digitado na matriz nasce como rascunho, visível apenas para o servidor. O botão "Enviar ao gestor" envia todos os rascunhos do ano. Depois de enviado, o lançamento continua editável e o administrador passa a ver a versão atual.
- Consolidado do ano na aba de lançamento mensal, com atividades nas linhas, meses nas colunas e totais.
- Coluna "já lançado no diário" na matriz, ao lado de cada mês, para evitar contar duas vezes a mesma entrega.
- `scripts/migrar_lancamento_mensal.R`, que prepara o banco para o recurso.

### Changed
- O esforço continua sendo horas da atividade ÷ horas do mês: lançar o mês de uma vez ou dia a dia leva ao mesmo percentual. Quando o mês não tem horas informadas, o percentual é estimado pela participação nas entregas e marcado com asterisco, com aviso na tela.
- Cartões de lançamento mensal mostram o mês no lugar do dia, com as etiquetas "Mensal" e "Rascunho". Clicar neles abre a matriz na atividade correspondente.
- O administrador deixa de ver lançamentos mensais ainda em rascunho.

### Note
- O recurso depende de duas colunas em `entregas` (`origem` e `envio`) e de um índice. Enquanto a migração não for executada, a aba não aparece e o restante do aplicativo funciona normalmente. Os registros existentes passam a valer como diários e já enviados, exatamente o comportamento anterior.

---
## [3.2.0] - 2026-09-27

### Changed
- **Exportar a tabela completa** passa a ignorar também os filtros de ano, mês, servidor e atividade, baixando todos os registros do relatório. **Exportar o que está filtrado** continua respeitando os filtros e a busca da tabela.
- O relatório passa a ser montado com todos os registros visíveis ao usuário, e os filtros da tela são aplicados como busca da própria tabela. Com isso, o esforço de cada mês é sempre calculado sobre o mês inteiro: filtrar por uma atividade deixa de exibir 100% para ela.
- O relatório do administrador ganha a coluna de servidor, e o esforço passa a ser calculado por servidor dentro de cada mês.
- As tabelas passam a ser processadas no navegador (`server = FALSE`), condição para que busca e exportação enxerguem todos os registros e não apenas a página carregada.

### Fixed
- Paginação das tabelas: o número da página atual aparecia escuro sobre fundo azul, quase ilegível. Os botões passam a seguir a identidade visual, com a página atual em azul institucional e número branco.

---
## [3.1.0] - 2026-09-27

### Added
- Filtros na lista de lançamentos: mês, atividade e situação, com resumo do que está sendo mostrado e botão para limpar. Facilita localizar um lançamento antes de editar ou remover.
- Menu de exportação nas tabelas, com PDF, Excel, CSV e cópia, permitindo escolher entre o que está filtrado e a tabela completa.
- PDF de exportação com a identidade do aplicativo: cabeçalho claro com a logo, bloco que identifica servidor, escopo, filtros e número de registros, tabela formatada e rodapé com direitos autorais, data e hora da emissão e versão. Página A4 em retrato.

### Changed
- Relatórios passam a mostrar a quantidade de entregas também em telas estreitas, junto das horas e do esforço.
- Seletores, campos de busca e controles das tabelas padronizados na identidade visual; a situação do lançamento passa a ser escolhida em etiquetas.
- Logo com os arcos mais afastados entre si.

### Fixed
- Correção da falha de JavaScript (`andSelf`) na versão do DataTables Buttons distribuída com o pacote DT, que impedia parte das exportações.

### Added
- `.Renviron.example`: modelo das variáveis de ambiente, com valores de exemplo e comentários sobre a origem de cada uma. O `.Renviron` real continua fora do versionamento.
- `scripts/limpar_registros_de_rede.R`: apaga o IP e o navegador gravados por versões anteriores à 3.0.2 em `login_logs` e `audit_logs`, preservando os registros de acesso e de auditoria. O script não faz parte do pacote publicado e não altera a versão do aplicativo.

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
