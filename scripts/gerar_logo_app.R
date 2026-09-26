# Gera a logo do Minhas Entregas (www/img/logo_app.png e www/img/favicon.png)
# na mesma linguagem visual do Croma: anel com cores CIELCH reais
# dividido como a distribuição do esforço do mês entre atividades, disco azul
# institucional ao centro, marcações de horas e o sinal de entrega concluída.
# `escala` ajusta a espessura das linhas ao tamanho da imagem (1 = 512 px).
# Uso: Rscript scripts/gerar_logo_app.R

library(colorspace)

desenhar_logo <- function(escala = 1) {
  par(mar = c(0, 0, 0, 0), bg = "transparent")
  plot.new(); plot.window(c(-1, 1), c(-1, 1), asp = 1)

  # Anel de esforço: cada arco é a fatia de horas de uma atividade no mês
  fatias <- c(.38, .27, .20, .15)
  matizes <- c(262, 146, 78, 28)
  folga <- 4 * pi / 180
  inicio <- pi / 2
  for (i in seq_along(fatias)) {
    fim <- inicio - fatias[i] * 2 * pi
    t <- seq(inicio - folga / 2, fim + folga / 2, length.out = 120)
    cor <- hex(polarLAB(L = if (matizes[i] > 200) 50 else 66, C = if (matizes[i] > 200) 40 else 46, H = matizes[i]), fixup = TRUE)
    polygon(c(.98 * cos(t), rev(.66 * cos(t))), c(.98 * sin(t), rev(.66 * sin(t))),
            col = cor, border = cor, lwd = .6 * escala)
    inicio <- fim
  }

  # Disco central com borda branca (fica igual sobre qualquer fundo)
  t <- seq(0, 2 * pi, length.out = 300)
  polygon(.66 * cos(t), .66 * sin(t), col = "#FFFFFF", border = NA)
  polygon(.61 * cos(t), .61 * sin(t), col = "#173B5B", border = NA)

  # Marcações das horas (relógio)
  for (k in 0:11) {
    a <- k * pi / 6
    comprimento <- if (k %% 3 == 0) .1 else .06
    segments(.5 * cos(a), .5 * sin(a), (.5 - comprimento) * cos(a), (.5 - comprimento) * sin(a),
             col = adjustcolor("#FFFFFF", if (k %% 3 == 0) .45 else .25), lwd = 4 * escala, lend = "round")
  }

  # Entrega concluída
  lines(c(-.26, -.07, .29), c(.01, -.19, .21), col = "#FFFFFF", lwd = 36 * escala, lend = "round", ljoin = "round")
  lines(c(-.26, -.07, .29), c(.01, -.19, .21),
        col = hex(polarLAB(L = 80, C = 44, H = 146), fixup = TRUE), lwd = 20 * escala, lend = "round", ljoin = "round")
}

tipo <- if (capabilities("aqua")) "quartz" else "cairo"
dir.create("www/img", showWarnings = FALSE, recursive = TRUE)
png("www/img/logo_app.png", width = 512, height = 512, bg = "transparent", type = tipo)
desenhar_logo(); dev.off()
png("www/img/favicon.png", width = 64, height = 64, bg = "transparent", type = tipo)
desenhar_logo(escala = 64 / 512); dev.off()
