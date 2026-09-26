# Runbook do Minhas Entregas

Este documento reúne orientações operacionais para execução, manutenção, versionamento e suporte do **Minhas Entregas**.

## Finalidade

Fornecer um guia prático para:

- execução local;
- conferência de configuração;
- validação básica após alterações;
- publicação de novas versões;
- diagnóstico inicial de falhas;
- alinhamento entre documentação, versão e entrega em produção.

## Nome oficial do sistema

O nome oficial do sistema é **Minhas Entregas** e deve ser priorizado em:

- interface visível do aplicativo;
- documentação funcional;
- comunicação com usuários;
- materiais institucionais e operacionais.

Identificadores legados de infraestrutura podem ser mantidos apenas quando houver motivo técnico, como preservação de link público já conhecido pelos usuários.

## Pré-requisitos

- R instalado no ambiente.
- Dependências R do projeto instaladas.
- Credenciais válidas de acesso ao banco PostgreSQL.
- Arquivo `.Renviron` local configurado.

## Variáveis de ambiente esperadas

- `DB_NAME`
- `DB_HOST`
- `DB_PORT`
- `PGSSLMODE`
- `DB_USER_WRITE`
- `DB_PASSWORD_WRITE`
- `DB_USER_READ`
- `DB_PASSWORD_READ`

## Inicialização local

No diretório do app:

```r
shiny::runApp()
```

Ou pelo terminal:

```powershell
Rscript -e "shiny::runApp('.')"
```

## Validação mínima após alterações

Após mudanças em código, configuração, identidade do produto ou documentação:

1. Confirmar que o app inicia sem erro de sintaxe.
2. Validar login com um usuário conhecido.
3. Testar o fluxo de inclusão de entrega.
4. Confirmar atualização da tabela de entregas.
5. Confirmar atualização da aba de relatórios.
6. Validar os textos visíveis do sistema quando houver alteração de nomenclatura.
7. Se a alteração envolver administração, validar também os painéis administrativos.
8. Confirmar que, após o login, a tela de acesso some e o botão **Sair** encerra a sessão.
9. Confirmar que um servidor comum vê apenas as próprias entregas e nenhuma aba administrativa.
10. Confirmar, em tela de celular, que as listas não exigem rolagem lateral e que as janelas de lançamento abrem corretamente.

## Fluxo recomendado de versionamento

1. Atualizar os arquivos alterados do projeto.
2. Revisar `VERSION`.
3. Registrar a mudança em `CHANGELOG.md`.
4. Validar o comportamento principal do app.
5. Revisar o estado do git.
6. Criar commit com mensagem clara.
7. Enviar o branch para o repositório remoto.

## Procedimento de release

Ao preparar uma nova versão:

1. Incrementar a versão em `VERSION`.
2. Registrar as mudanças em `CHANGELOG.md`.
3. Confirmar coerência entre `README.md`, `RUNBOOK.md`, `LICENSE` e interface visível do sistema.
4. Confirmar que o repositório está limpo antes do commit final.
5. Criar commit de release, quando aplicável.
6. Publicar no remoto.
7. Regenerar o `manifest.json` quando houver mudança de pacotes.
8. Executar o procedimento de deploy adotado pelo projeto.

## Publicação no Posit Connect Cloud

1. Confirmar que a `main` está com a versão a publicar.
2. Conferir que o `manifest.json` corresponde aos arquivos e pacotes atuais.
3. Publicar a partir do repositório e da branch `main` em [connect.posit.cloud](https://connect.posit.cloud).
4. Conferir as variáveis de ambiente do banco cadastradas na plataforma.
5. Validar o acesso de um servidor comum e de um administrador após a publicação.

Observações:

- O `manifest.json` fixa a versão do R e as versões dos pacotes do ambiente onde foi gerado. Se a
  publicação falhar ao instalar alguma dependência, regenere o manifesto na máquina de desenvolvimento
  com `rsconnect::writeManifest()` e publique novamente.
- O ambiente de publicação precisa usar UTF-8, pois rótulos e cabeçalhos da interface têm acentos.

## Verificações operacionais úteis

### Conectividade com o banco

- Confirmar se as variáveis de ambiente foram carregadas corretamente.
- Verificar host, porta, usuário e modo SSL.
- Confirmar se a credencial de leitura está funcional.
- Confirmar se a credencial de escrita está funcional.

### Problemas comuns

#### O app abre, mas não autentica

- Verificar se o SIAPE existe na tabela de servidores.
- Confirmar se o usuário possui `senha_hash` válido.
- Revisar conectividade com o banco.

#### A entrega aparece na tabela, mas não no relatório

- Verificar se o registro foi gravado com o ano esperado.
- Conferir os filtros ativos da aba de relatórios.
- Confirmar se a sessão foi atualizada após o CRUD.

#### Não é possível editar ou excluir lançamentos

- Confirmar se o ano do ciclo está com status `aberto`.
- Verificar se o usuário está tentando alterar registros permitidos para o próprio perfil.

## Boas práticas

- Não versionar `.Renviron` nem credenciais.
- Não publicar senhas ou chaves em commits.
- Evitar arquivos duplicados desnecessários no diretório `www/`.
- Registrar mudanças funcionais relevantes no `CHANGELOG.md`.
- Manter a documentação alinhada com a versão publicada.
- Tratar **Minhas Entregas** como nome padrão de apresentação do sistema.

## Governança

Este aplicativo é proprietário. Mudanças estruturais, ajustes de licenciamento e publicações devem respeitar a autoria e a governança definidas pelo responsável pelo projeto.
