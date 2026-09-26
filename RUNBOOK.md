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
- Arquivo `.Renviron` local configurado (ver "Variáveis de ambiente").

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

## Dados pessoais e registros de acesso

O sistema guarda, sobre cada servidor, apenas o **nome**, o **SIAPE** e as **entregas registradas**.

Dos acessos fica registrado somente o SIAPE, o momento e se a tentativa deu certo (`login_logs`).
Das ações administrativas sobre anos de ciclo ficam registrados o usuário, a ação e o ano (`audit_logs`).
A partir da versão 3.0.2 o aplicativo **não grava mais endereço IP nem informações do navegador**.

As colunas `ip` e `user_agent` continuam existindo nas duas tabelas por compatibilidade, porém deixam de
ser preenchidas. Os valores gravados por versões anteriores permanecem no banco. Para eliminá-los,
o responsável pelo banco pode executar, fora do aplicativo:

```sql
UPDATE login_logs SET ip = NULL, user_agent = NULL;
UPDATE audit_logs SET ip = NULL, user_agent = NULL;
```

Se, no futuro, as colunas não forem mais necessárias, elas podem ser removidas do esquema em uma
manutenção planejada.

## Variáveis de ambiente

O aplicativo lê oito variáveis, todas em `global.R`:

| Variável | Conteúdo | Exemplo |
| --- | --- | --- |
| `DB_NAME` | Nome do banco | `neondb` |
| `DB_HOST` | Host do PostgreSQL | `ep-xxxx.sa-east-1.aws.neon.tech` |
| `DB_PORT` | Porta | `5432` |
| `PGSSLMODE` | Modo de SSL exigido pelo provedor | `require` |
| `DB_USER_READ` | Usuário com permissão de leitura | — |
| `DB_PASSWORD_READ` | Senha do usuário de leitura | — |
| `DB_USER_WRITE` | Usuário com permissão de escrita | — |
| `DB_PASSWORD_WRITE` | Senha do usuário de escrita | — |

Onde encontrar os valores em uso:

- No ambiente de desenvolvimento, eles estão no `.Renviron` (do projeto ou do usuário). Para abrir o
  arquivo: `usethis::edit_r_environ()`, ou `file.edit("~/.Renviron")`.
- Para conferir sem expor senhas, liste apenas os nomes preenchidos:

  ```r
  nomes <- c("DB_NAME", "DB_HOST", "DB_PORT", "PGSSLMODE",
             "DB_USER_READ", "DB_PASSWORD_READ", "DB_USER_WRITE", "DB_PASSWORD_WRITE")
  data.frame(variavel = nomes, definida = nzchar(Sys.getenv(nomes)))
  ```

- No provedor do banco, a string de conexão tem o formato
  `postgresql://USUARIO:SENHA@HOST:PORTA/BANCO?sslmode=require`, de onde saem host, porta, banco,
  usuário e senha. Os usuários de leitura e de escrita são cadastrados separadamente no banco.

Nunca versione esses valores. O `.gitignore` já ignora `.Renviron` e `.env`.

## Publicação no Posit Connect Cloud

1. Confirmar que a `main` está com a versão a publicar.
2. Conferir que o `manifest.json` corresponde aos arquivos e pacotes atuais.
3. Publicar a partir do repositório e da branch `main` em [connect.posit.cloud](https://connect.posit.cloud).
4. Cadastrar as oito variáveis de ambiente na própria plataforma, nas configurações do conteúdo
   publicado (seção de variáveis de ambiente), uma a uma, com o mesmo nome usado no `.Renviron`.
   Depois de salvar, reinicie ou republique o conteúdo: as variáveis são lidas na inicialização.
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
