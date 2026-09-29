# global.R é carregado automaticamente pelo Shiny antes de ui.R e server.R

# UI ----
fluidPage(
  shinyjs::useShinyjs(),
  tags$head(
    tags$script(async = NA, src = "https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-3130340973057636", crossorigin = "anonymous"),
    tags$link(rel = "stylesheet", type = "text/css", href = "css/app.css"),
    tags$link(rel = "icon", type = "image/png", href = "img/favicon.png"),
    tags$meta(name = "author", content = "Marlenildo Melo"),
    tags$meta(name = "description", content = "Minhas Entregas: registro de entregas e cálculo do esforço mensal dos servidores técnico-administrativos."),
    tags$title("Minhas Entregas · Esforço e entregas"),
    # Bibliotecas e rotinas de exportação das tabelas (PDF, Excel, CSV)
    dependencias_exportacao(),
    tags$script(src = "js/exportacao.js"),
    if (!is.null(LOGO_PDF)) tags$script(HTML(sprintf("window.ME_LOGO = '%s';", LOGO_PDF))),
    # O seletor de data só existe dentro da janela de lançamento; sem isto,
    # a biblioteca do calendário não é carregada com a página e ele falha lá.
    htmltools::findDependencies(dateInput("dep_calendario", NULL)),
    # O Shiny não distribui o idioma do calendário, então ele é definido aqui
    tags$script(HTML(
      "$(function() {
         if (!$.fn.bsDatepicker) return;
         $.fn.bsDatepicker.dates['pt-BR'] = {
           days: ['Domingo','Segunda','Terça','Quarta','Quinta','Sexta','Sábado'],
           daysShort: ['Dom','Seg','Ter','Qua','Qui','Sex','Sáb'],
           daysMin: ['D','S','T','Q','Q','S','S'],
           months: ['Janeiro','Fevereiro','Março','Abril','Maio','Junho','Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'],
           monthsShort: ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'],
           today: 'Hoje', clear: 'Limpar', monthsTitle: 'Meses',
           format: 'dd/mm/yyyy', weekStart: 1
         };
       });"
    )),
    # SIAPE e senha seguem juntos no mesmo envio (evita corrida com o texto
    # ainda não sincronizado ao colar a senha e apertar Enter logo em seguida)
    tags$script(HTML(
      "function enviarLogin() {
         Shiny.setInputValue('login_tentativa',
           { siape: $('#in_siape').val(), senha: $('#in_senha').val() },
           { priority: 'event' });
       }
       $(document).on('click', '#btn_entrar', enviarLogin);
       $(document).on('keydown', '#in_siape, #in_senha', function(e) {
         if (e.key === 'Enter') { e.preventDefault(); enviarLogin(); }
       });"
    ))
  ),

  ## Tela de acesso ----
  div(
    id = "tela_login",
    class = "tela-login",
    div(
      class = "cartao-login",
      div(
        class = "login-marca",
        tags$img(src = "img/logo_app.png", class = "logo-app", alt = "Logo do Minhas Entregas"),
        div(class = "titulo", "Minhas Entregas"),
        div(class = "descricao-app", "Esforço e entregas do servidor"),
        div(class = "subtitulo", "Registre suas atividades e acompanhe o esforço de cada mês.")
      ),
      textInput("in_siape", "SIAPE", width = "100%", placeholder = "Seu número SIAPE"),
      passwordInput("in_senha", "Senha", width = "100%", placeholder = "Sua senha"),
      actionButton("btn_entrar", "Entrar", icon = icon("right-to-bracket"), class = "btn-entrar"),
      div(class = "aviso-login", textOutput("out_aviso_login", inline = TRUE)),
      div(
        class = "nota-privacidade",
        icon("lock"),
        span("Cada servidor vê e altera apenas as próprias entregas. Seus registros não ficam visíveis para outros servidores.")
      ),
      div(
        class = "aviso-dados",
        div(class = "aviso-titulo", "Privacidade e finalidade"),
        tags$ul(
          tags$li(HTML("Guardamos apenas o seu <b>nome</b>, o seu <b>SIAPE</b> e as <b>entregas que você registra</b>, dentro das atividades definidas pelo gestor da unidade.")),
          tags$li("Nenhum outro dado pessoal é coletado. Não guardamos o seu endereço de rede nem informações do seu navegador ou dispositivo."),
          tags$li("Para a segurança da sua conta, fica registrada a data e a hora de cada tentativa de acesso ao seu SIAPE, com a informação de ter dado certo ou não."),
          tags$li("O sistema serve apenas para ajudar você a organizar suas entregas e o esforço dedicado a elas na unidade.")
        )
      )
    )
  ),

  ## Área autenticada ----
  shinyjs::hidden(div(
    id = "tela_app",
    div(
      class = "cabecalho-app",
      tags$img(src = "img/logo_app.png", class = "logo-app", alt = "Logo do Minhas Entregas"),
      div(
        class = "titulo-area",
        div(class = "titulo", "Minhas Entregas"),
        div(class = "descricao-app", "Esforço e entregas do servidor"),
        div(class = "subtitulo", "Registre suas atividades, informe as horas dedicadas e acompanhe o esforço de cada mês.")
      ),
      div(
        class = "area-usuario",
        # O ano do ciclo vale para todas as abas, então o seletor vive no cabeçalho
        div(
          class = "ano-global",
          uiOutput("out_ano_global"),
          uiOutput("out_status_ano")
        ),
        uiOutput("out_usuario"),
        actionButton("btn_sair", "Sair", icon = icon("right-from-bracket"), class = "btn-sair")
      )
    ),
    uiOutput("out_conteudo")
  )),

  ## Rodapé ----
  div(
    class = "rodape-app",
    span("Desenvolvido por"),
    tags$img(src = "img/logo_marlenildo.png", class = "logo-rodape", alt = "Marlenildo Soluções em Curso"),
    span(class = "versao-app", paste0("Minhas Entregas v", APP_VERSION)),
    div(class = "direitos-app", "© 2025-2026 Marlenildo Melo · Todos os direitos reservados · Licença proprietária")
  )
)
