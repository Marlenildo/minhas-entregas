/* Exportação das tabelas do Minhas Entregas.
   O PDF segue a identidade do aplicativo: cabeçalho claro com a logo, bloco de
   identificação do que está sendo exportado e rodapé com direitos e emissão. */

window.ME_CONTEXTO = {};

/* A versão do Buttons distribuída com o DT ainda usa andSelf(), removido no jQuery 3 */
if (window.jQuery && !jQuery.fn.andSelf) jQuery.fn.andSelf = jQuery.fn.addBack;

$(function () {
  if (window.Shiny) {
    Shiny.addCustomMessageHandler("me_contexto", function (x) {
      window.ME_CONTEXTO = x || {};
    });
  }
});

/* Células exportadas saem sem marcação: selos e barras viram apenas texto. */
window.meTexto = function (valor) {
  if (valor === null || valor === undefined) return "";
  return String(valor)
    .replace(/<[^>]*>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/\s+/g, " ")
    .trim();
};

window.meAgora = function () {
  var d = new Date();
  var p = function (n) { return String(n).padStart(2, "0"); };
  return p(d.getDate()) + "/" + p(d.getMonth() + 1) + "/" + d.getFullYear() +
         " às " + p(d.getHours()) + ":" + p(d.getMinutes());
};

window.meNomeArquivo = function (base) {
  var d = new Date();
  var p = function (n) { return String(n).padStart(2, "0"); };
  return base + "-" + d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate());
};

window.mePdf = function (doc, opcoes) {
  var ctx = window.ME_CONTEXTO || {};
  var filtros = ((ctx.tabelas || {})[opcoes.chave] || {}).filtros;
  var direita = opcoes.direita || [];
  var flexivel = opcoes.flexivel || [];
  var NAVY = "#173B5B", AZUL = "#2A5C92", LINHA = "#D9E3EB", TINTA = "#263B4D", SUAVE = "#627589";
  var LARGURA = 531; // A4 retrato menos as margens laterais

  doc.pageSize = "A4";
  doc.pageOrientation = "portrait";
  doc.pageMargins = [32, 92, 32, 54];
  doc.defaultStyle = { fontSize: 8.5, color: TINTA };

  // O título que o Buttons acrescenta serve só para nomear o arquivo:
  // no PDF, quem identifica a exportação é o bloco montado abaixo.
  doc.content = doc.content.filter(function (parte) { return parte.table; });

  var tabela = doc.content[0];
  var linhas = 0;

  if (tabela && tabela.table) {
    tabela.table.headerRows = 1;
    tabela.table.widths = tabela.table.body[0].map(function (celula, c) {
      return flexivel.indexOf(c) >= 0 ? "*" : "auto";
    });
    linhas = tabela.table.body.length - 1;

    tabela.table.body.forEach(function (linha, i) {
      linha.forEach(function (celula, c) {
        celula.margin = [5, 5, 5, 5];
        celula.alignment = direita.indexOf(c) >= 0 ? "right" : "left";
        if (i === 0) {
          celula.fillColor = NAVY;
          celula.color = "#FFFFFF";
          celula.bold = true;
          celula.fontSize = 8;
        } else {
          celula.fontSize = 8.5;
        }
      });
    });

    tabela.layout = {
      hLineWidth: function (i, node) { return i === 0 || i === 1 || i === node.table.body.length ? 0.8 : 0.5; },
      vLineWidth: function () { return 0; },
      hLineColor: function (i) { return i <= 1 ? NAVY : "#E7EEF4"; },
      fillColor: function (i) { return i > 0 && i % 2 === 0 ? "#F7FAFC" : null; }
    };
  }

  /* Bloco que identifica o conteúdo exportado */
  var detalhes = [];
  if (ctx.servidor) detalhes.push(ctx.servidor);
  detalhes.push(opcoes.escopo);
  if (filtros) detalhes.push("Filtros: " + filtros);
  detalhes.push(linhas + (linhas === 1 ? " registro" : " registros"));

  doc.content.unshift({
    margin: [0, 0, 0, 12],
    stack: [
      { text: opcoes.titulo, fontSize: 14, bold: true, color: NAVY, margin: [0, 0, 0, 3] },
      { text: detalhes.join("  ·  "), fontSize: 8.5, color: SUAVE }
    ]
  });

  doc.header = function (pagina, paginas) {
    var marca = [];
    if (window.ME_LOGO) marca.push({ image: window.ME_LOGO, width: 30 });
    marca.push({
      width: "*",
      margin: [window.ME_LOGO ? 9 : 0, 3, 0, 0],
      stack: [
        { text: "Minhas Entregas", fontSize: 12, bold: true, color: NAVY },
        { text: "Esforço e entregas do servidor", fontSize: 7.5, color: AZUL, bold: true }
      ]
    });
    marca.push({
      width: "auto",
      margin: [0, 8, 0, 0],
      text: "Página " + pagina + " de " + paginas,
      fontSize: 7.5,
      color: SUAVE,
      alignment: "right"
    });

    return {
      margin: [32, 22, 32, 0],
      stack: [
        { columns: marca, columnGap: 0 },
        { canvas: [{ type: "line", x1: 0, y1: 10, x2: LARGURA, y2: 10, lineWidth: 2, lineColor: NAVY }] }
      ]
    };
  };

  doc.footer = function () {
    return {
      margin: [32, 6, 32, 0],
      stack: [
        { canvas: [{ type: "line", x1: 0, y1: 0, x2: LARGURA, y2: 0, lineWidth: 0.6, lineColor: LINHA }] },
        {
          margin: [0, 6, 0, 0],
          columns: [
            {
              text: "© 2025-2026 Marlenildo Melo · Todos os direitos reservados · Licença proprietária",
              fontSize: 7,
              color: SUAVE
            },
            {
              text: "Gerado em " + window.meAgora() + (ctx.versao ? " · Minhas Entregas v" + ctx.versao : ""),
              fontSize: 7,
              color: SUAVE,
              alignment: "right"
            }
          ]
        }
      ]
    };
  };
};
