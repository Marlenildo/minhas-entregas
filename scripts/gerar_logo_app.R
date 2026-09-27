# Gera a logo do Minhas Entregas (www/img/logo_app.png e www/img/favicon.png).
# Desenho plano, sem sombras nem degradês: um anel com as fatias de esforço do mês
# (cores CIELCH, pontas arredondadas) e, ao centro, o sinal de entrega concluída.
# Arcos e sinal têm a mesma espessura; `escala` a ajusta ao tamanho da imagem (1 = 512 px).
# Uso: Rscript scripts/gerar_logo_app.R

library(colorspace)

# Fatias do anel: proporção do esforço e matiz de cada atividade
FATIAS <- c(.34, .27, .22, .17)
MATIZES <- c(250, 148, 78, 28)

arco <- function(raio, de, ate, cor, espessura) {
  angulo <- seq(de, ate, length.out = 120)
  lines(raio * cos(angulo), raio * sin(angulo),
        col = cor, lwd = espessura, lend = "round", ljoin = "round")
}

desenhar_logo <- function(escala = 1) {
  par(mar = c(0, 0, 0, 0), bg = "transparent")
  plot.new(); plot.window(c(-1, 1), c(-1, 1), asp = 1)

  espessura <- 70 * escala
  folga <- 22 * pi / 180
  inicio <- pi / 2

  for (i in seq_along(FATIAS)) {
    fim <- inicio - FATIAS[i] * 2 * pi
    cor <- hex(polarLAB(L = if (MATIZES[i] > 200) 54 else 64,
                        C = if (MATIZES[i] > 200) 34 else 42, H = MATIZES[i]), fixup = TRUE)
    arco(.82, inicio - folga / 2, fim + folga / 2, cor, espessura)
    inicio <- fim
  }

  # Sinal de entrega concluída, em azul institucional
  lines(c(-.32, -.09, .34), c(.02, -.23, .27),
        col = "#173B5B", lwd = espessura, lend = "round", ljoin = "round")
}

tipo <- if (capabilities("aqua")) "quartz" else "cairo"
dir.create("www/img", showWarnings = FALSE, recursive = TRUE)
png("www/img/logo_app.png", width = 512, height = 512, bg = "transparent", type = tipo)
desenhar_logo(); dev.off()
png("www/img/favicon.png", width = 64, height = 64, bg = "transparent", type = tipo)
desenhar_logo(escala = 64 / 512); dev.off()
