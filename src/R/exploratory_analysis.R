##### Análisis De Datos Exploratorio #####

library(ggplot2)
library(ggExtra)
library(GGally)
library(tidyverse)
library(scales)
library(tidyr)
library(dplyr)
library(psych)
library(corrplot)
library(RColorBrewer)

# 1. Distribución y preguntas generales sobre los datos

not_show <- c("POSITION", "PLAYER_NAME", "PLAYER_ID", "SEASON", "TEAM_ABBREVIATION", 
              "SCHOOL", "COUNTRY", "ALL_STAR")

summary(datos_nba[, setdiff(names(datos_nba), not_show)])

matriz_cor <- cor(datos_nba[, setdiff(names(datos_nba), not_show)], use = "complete.obs")

corrplot(matriz_cor, 
         method = "color",
         type = "lower",
         col = colorRampPalette(brewer.pal(8, "RdBu"))(200),
         addCoef.col = "black",         # valores correlación
         tl.col = "black",              # color texto etiquetas
         tl.cex = 0.8,                  # tamaño texto etiquetas,
         number.cex = 0.55             # tamaño valores correlación
)


# 2. SALARIOS


ggplot(datos_nba, aes(x = SALARY)) +
geom_histogram(
  bins = 60, 
  fill = "#408973", 
  color = "black", 
  alpha = 0.8) +
labs(
  title = "Distribución salarios ajustados NBA",
  x = "Salario ajustado por inflación (M$)",
  y = "Número de jugadores"
) +
scale_x_continuous(labels = scales::dollar_format(prefix = "$", suffix = "M", scale = 1e-6)) +
theme_minimal(base_size = 14) +
theme(plot.title = element_text(hjust = 0.5, size = 25, face = "bold"),
      axis.title = element_text(face = "bold", size = 18),
      axis.text = element_text(size = 18))



datos_nba %>%
  filter(!is.na(POSITION), POSITION != "") %>%
  mutate(
    POSITION = recode(
      POSITION,
      "Guard" = "Exteriores (Base/Escolta)",
      "Forward" = "Alas (Alero/ Ala Pívot)",
      "Center" = "Pívot"
    )
  ) %>%
ggplot(aes(x = POSITION, y = SALARY)) +
geom_boxplot(
  fill = "#698bab",
  color = "black",
  outlier.colour = "red"
) +
labs(
  title = "Distribución de Salarios por Posición",
  x = "Posición",
  y = "Salario ajustado (M$)"
) +
scale_y_continuous(
  labels = scales::dollar_format(prefix = "$", suffix = "M", scale = 1e-6)
) +
theme_minimal() +
theme(
  plot.title = element_text(hjust = 0.5, size = 25, face = "bold"),
  axis.title = element_text(face = "bold", size = 18),
  axis.text = element_text(size = 18)
)




exp_vs_salary <- ggplot(datos_nba, aes(x = SEASON_EXP, y = SALARY)) + 
  geom_jitter(width = 0.3, alpha = 0.6, color = "#1f77b4", size = 2) +
  geom_smooth(method = "loess", formula = y ~ x, se = TRUE, color = "#2ca02c", fill = "#2ca02c", alpha = 0.5) +
  labs(
    title = "Experiencia vs Salario NBA",
    x = "Experiencia en la NBA (Años)",
    y = "Salario Anual (M$)",
  ) +
  scale_y_continuous(labels = scales::dollar_format(prefix = "$", suffix = "M", scale = 1e-6)) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold", size = 25),
    axis.title = element_text(face = "bold", size = 18),
    axis.text = element_text(size = 18)
  )

exp_vs_salary <- ggMarginal(exp_vs_salary, type = "boxplot", fill = "#1f77b4", size = 4, alpha = 0.4)
exp_vs_salary




nba_long <- datos_nba %>%
  select(SALARY, MIN, PTS, AST, REB) %>%
  pivot_longer(cols = -SALARY, names_to = "estadistica", values_to = "valor")

ggplot(nba_long, aes(x = valor, y = SALARY)) + 
  geom_point(color = "#3f6280", alpha = 0.4) +
  geom_smooth(method = lm, se = FALSE, color = "darkorange") + 
  facet_wrap(~ estadistica, scales = "free_x") +
  scale_y_continuous(labels = function(x) paste0(scales::dollar(x * 1e-6), "M")) +
  labs(title = "Relación entre Estadísticas Clave y Salario Ajustado", y = "Salary", x = "") +
  scale_y_continuous(labels = scales::dollar_format(prefix = "$", suffix = "M", scale = 1e-6)) +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold", size = 25),
    axis.title = element_text(face = "bold", size = 18),
    axis.text = element_text(size = 18),
    strip.text = element_text(size = 18, face = "bold")
  )



top25 <- datos_nba %>%
  filter(SEASON == "2018-19") %>%
  arrange(desc(SALARY)) %>%
  slice(1:25)

ggplot(top25, aes(x = reorder(PLAYER_NAME, SALARY), y = SALARY, fill = NBA_FANTASY_PTS)) +
  geom_col() +
  coord_flip() +
  scale_fill_gradient(low = "#B3CDE3", high = "#08306B") +
  labs(
    title = "Top 25 salarios NBA (2018-19) y Puntos NBA Fantasy",
    x = "Jugador", y = "Salario ajustado ($M)",
    fill = "NBA Fantasy"
  ) +
  scale_y_continuous(labels = scales::dollar_format(prefix = "$", suffix = "M", scale = 1e-6)) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold", size = 25),
    axis.title = element_text(face = "bold", size = 18),
    axis.text = element_text(size = 18)
  )



datos_nba %>%
  mutate(SEASON = as.numeric(as.character(sub("-.*", "", SEASON)))) %>%
  group_by(SEASON) %>%
  summarise(media_salarial = mean(SALARY)) %>%
  
ggplot(aes(x = SEASON, y = media_salarial)) +
geom_line(color = "#2C3E50", size = 1) +
geom_point(size = 2, color = "#2980B9", fill = "white", stroke = 1.2) +
labs(
  title = "Evolución de la media salarial ajustada de la NBA",
  x = "Temporada",
  y = "Salario Medio (M$)"
) +
scale_y_continuous(labels = scales::dollar_format(prefix = "$", suffix = "M", scale = 1e-6)) +
theme_minimal(base_size = 14) +
theme(
  plot.title = element_text(hjust = 0.5, face = "bold", size = 25),
  axis.title = element_text(face = "bold", size = 20),
  axis.text = element_text(size = 18)
)



# ALL - STAR

nba_allstar <- subset(datos_nba, datos_nba$SEASON != "1998-99")

nba_allstar$TS_PCT <- nba_allstar$PTS / (2 * (nba_allstar$FGA + 0.44 * nba_allstar$FTA)) * 100

nombre_estadisticas <- c(
  PTS = "Puntos",
  REB = "Rebotes",
  AST = "Asistencias",
  MIN = "Minutos por Partido",
  TOV = "Pérdidas",
  TS_PCT = "True Shooting"
)

nba_allstar %>%
  select(ALL_STAR, PTS, REB, AST, MIN, TOV, TS_PCT) %>%
  pivot_longer(cols = -ALL_STAR, names_to = "estadistica", values_to = "valor") %>%
  mutate(
    ALL_STAR = factor(ALL_STAR, levels = c(0, 1), labels = c("No All-Star", "All-Star")),
    estadistica = factor(nombre_estadisticas[estadistica], levels = nombre_estadisticas)
  ) %>%
  
  ggplot(aes(x = ALL_STAR, y = valor, fill = ALL_STAR)) + 
  geom_boxplot(alpha = 0.7, outlier.shape = NA, color = "black") + 
  facet_wrap(~ estadistica, scales = "free", ncol = 3) +
  labs(
    title = "Comparativa de estadísticas: All-Star vs No All-Star",
    x = "",
    y = ""
  ) + 
  scale_fill_manual(values = c("No All-Star" = "#bdbdbd", "All-Star" = "#d7191c")) + 
  theme_minimal() + 
  theme(
    legend.position = "none",
    strip.text = element_text(face = "bold", hjust = 0.5, size = 18),  # Centrado
    plot.title = element_text(hjust = 0.5, size = 25, face = "bold"),
    axis.text = element_text(size = 18)
  )
rm(nombre_estadisticas)

# Cambiar la escala al true shooting???


datos_nba %>%
  filter(ALL_STAR == 1, !is.na(POSITION), POSITION != "") %>%
  count(POSITION) %>%
  mutate(POSITION = recode(POSITION,
                           "Guard" = "Exteriores (Base/Escolta)",
                           "Forward" = "Alas (Alero/ Ala Pívot)",
                           "Center" = "Pívot"
  ), 
  porcentaje = n / sum(n),
  etiqueta = paste0(POSITION, " (", round(porcentaje* 100), "%)")) %>%
  ggplot(aes(x = "", y = porcentaje, fill = POSITION)) +
  geom_col(width = 1, color = "white") + 
  coord_polar(theta = "y") + 
  geom_text(aes(label = etiqueta), position = position_stack(vjust = 0.5), size = 4) + 
  labs(title = "Distribución de posiciones en el All-Star") + 
  theme_void() +
  theme(
    legend.position = "none",
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold")  
  )

# ARQUETIPOS

library(fmsb)

stats <- c("PTS", "AST", "REB", "BLK", "STL", "TOV", "FG_PCT", "FG3_PCT", "FT_PCT")

datos_radar <- datos_nba %>%
  filter(POSITION %in% c("Guard", "Forward", "Center")) %>%
  group_by(POSITION) %>%
  summarise(across(all_of(stats), mean, na.rm = TRUE)) %>%
  mutate(POSITION = recode(POSITION,
                         "Guard" = "Exteriores",
                         "Forward" = "Alas",
                         "Center" = "Pívot")) %>% 
  as.data.frame()
  
valores_minimos <- c(5, 0, 2, 0, 0, 0, 0.30, 0, 0.6)
valores_maximos <- c(9.1, 3, 5.5, 	
                     0.8846228, 1, 1.5, 0.50, 0.35, 0.8)

colors_borders <- c("blue", "forestgreen", "darkorange")
colors_in <- adjustcolor(colors_borders, alpha.f = 0.3)

radar_ready <- rbind(valores_maximos, valores_minimos, datos_radar[, -1])
rownames(radar_ready) <- c("Max", "Min", datos_radar$POSITION)


radarchart(
  radar_ready,
  axistype = 1,
  pcol = colors_borders,
  pfcol = colors_in,
  plwd = 2,
  plty = 1,
  cglcol = "grey70",
  cglty = 1,
  axislabcol = NA,
  cglwd = 0.8,
  vlcex = 1.5,
)

legend("topright", legend = datos_radar$POSITION,
       bty = "n", pch = 20, col = colors_borders,
       text.col = "black", cex = 2, pt.cex = 2.5) 


datos_posicion <- datos_nba %>%
  filter(!is.na(POSITION) & POSITION != "") %>%
  group_by(POSITION) %>%
  summarise(
    puntos = mean(PTS, na.rm = TRUE),
    asistencias = mean(AST, na.rm = TRUE),
    rebotes = mean(REB, na.rm = TRUE),
    tapones = mean(BLK, na.rm = TRUE),
    robos = mean(STL, na.rm = TRUE),
    pct_campo = mean(FG_PCT, na.rm = TRUE),
    pct_triples = mean(FG3_PCT, na.rm = TRUE),
    pct_libres = mean(FT_PCT, na.rm = TRUE)
  )

datos_long <- datos_posicion %>%
  pivot_longer(cols = c(puntos, asistencias, rebotes, tapones, robos, pct_campo, pct_triples, pct_libres),
               names_to = "estadistica",
               values_to = "valor") %>%
  # Traducir posiciones al español
  mutate(POSITION = case_when(
    POSITION == "Guard" ~ "Exteriores",
    POSITION == "Forward" ~ "Alas", 
    POSITION == "Center" ~ "Pívots",
    TRUE ~ POSITION
  )) %>%
  # Traducir y mejorar nombres de estadísticas
  mutate(estadistica = case_when(
    estadistica == "puntos" ~ "Puntos por partido",
    estadistica == "asistencias" ~ "Asistencias por partido",
    estadistica == "rebotes" ~ "Rebotes por partido", 
    estadistica == "tapones" ~ "Tapones por partido",
    estadistica == "robos" ~ "Robos por partido",
    estadistica == "pct_campo" ~ "% Tiros de campo",
    estadistica == "pct_triples" ~ "% Triples",
    estadistica == "pct_libres" ~ "% Tiros libres",
    TRUE ~ estadistica
  ))

# Crear el gráfico con facets
ggplot(datos_long, aes(x = POSITION, y = valor, fill = POSITION)) +
  geom_col(alpha = 0.8, width = 0.7) +
  facet_wrap(~estadistica, scales = "free_y", ncol = 4) +
  labs(title = "Estadísticas medias por Posición en la NBA",
       subtitle = "Comparación detallada entre Exteriores, Alas y Pívots",
       x = "",
       y = "",
       fill = "") +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 18),
    axis.text.y = element_text(size = 18),
    strip.text = element_text(size = 18, face = "bold"),
    plot.title = element_text(size = 20, face = "bold", hjust = 0.5),
    plot.subtitle = element_text(size = 15, hjust = 0.5),
    legend.position = "bottom",
    axis.text = element_text(size = 15),
    legend.text = element_text(size = 18),
    panel.grid.minor = element_blank()
  ) +
  scale_fill_manual(values = c("Exteriores" = "#FF6B6B", 
                               "Alas" = "#4ECDC4", 
                               "Pívots" = "#45B7D1"))


# NCAA


universidades <- ncaa_exp %>%
  filter(!is.na(Draft.College), Draft.College != "", !is.na(Pick)) %>%
  group_by(Draft.College) %>%
  summarise(
    jugadores = n(),
    pick_medio = round(mean(as.numeric(Pick), na.rm = TRUE))
  ) %>%
  arrange(jugadores)

universidades <- universidades[-6,]

library(tidygeocoder)

universidades_coords <- universidades %>%
  mutate(query = paste(Draft.College, "University", "USA")) %>%
  geocode(address = query, method = "osm", lat = lat, long = lon)


library(maps)
library(ggrepel)

df_mapa <- universidades_coords %>% 
  filter(!is.na(lat), jugadores >= 5)

mapa_usa <- map_data("state")

ggplot() +
  geom_polygon(data = mapa_usa, aes(x = long, y = lat, group = group),
               
               fill = "#f5f5f5", color = "white") +
  geom_point(data = df_mapa,
             
             aes(x = lon, y = lat, size = jugadores, color = pick_medio),
             
             alpha = 0.8, stroke = 0.2) +
  geom_text_repel(
    data = df_mapa,
    aes(x = lon, y = lat, label = Draft.College),
    size = 4.5,  # Aumenta tamaño de texto
    max.overlaps = 10
  ) +
  scale_size_continuous(
    name = "Jugadores Aportados",
    range = c(2, 12),
    guide = guide_legend(title.theme = element_text(size = 18), label.theme = element_text(size = 14))
  ) +
  scale_color_viridis_c(
    name = "Pick medio",
    direction = -1,
    guide = guide_colorbar(title.theme = element_text(size = 18), label.theme = element_text(size = 14))
  ) +
  coord_fixed(1.3) +
  theme_minimal() +
  labs(
    title = "Universidades NCAA que más talento aportan a la NBA",
    x = "",
    y = ""
  ) +
  theme(legend.position = "right",
        panel.grid = element_blank(),
        axis.text = element_blank(),
        axis.ticks = element_blank(),
        axis.title = element_blank(),
        plot.title = element_text(face = "bold", size = 25, hjust = 0.5),
        legend.text = element_text(size = 16)
        )





draft <- ncaa_exp %>%
  filter(Draft.Year >= 2001 & Draft.Year <= 2003) %>%
  mutate(
    Pick = as.numeric(Pick),
    Round = ifelse(Pick <= 30, "Primera ronda", "Segunda ronda")
  )


ggplot(draft, aes(x = Pick, y = SEASON_EXP, color = Round)) +
  geom_point(alpha = 0.7, size = 2.5) +
  scale_x_continuous(breaks = seq(1, 60, by = 2)) +
  scale_color_manual(values = c("Primera ronda" = "#1f77b4", "Segunda ronda" = "#ff7f0e")) +
  labs(
    title = "Duración de carrera según pick del draft (2001-2003)",
    x = "Número del pick",
    y = "Años de experiencia en la NBA",
    color = "Ronda del draft"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", hjust = 0.5, size = 25),
    legend.position = "right",
    panel.grid = element_blank(),
    axis.title = element_text(size = 18),
    axis.text = element_text(size = 15),
    legend.title = element_text(size = 18),
    legend.text = element_text(size = 18)
  )



ncaa_exp %>%
  filter(!is.na(Class), Class != "") %>%
  count(Class) %>%
  mutate(
    Class_full = recode(Class,
                        "FR" = "Freshman",
                        "SO" = "Sophomore",
                        "JR" = "Junior",
                        "SR" = "Senior",
                        .default = Class),
    porcentaje = n / sum(n),
    etiqueta = paste0(Class_full, " (", round(porcentaje * 100), "%)")
  ) %>%
  ggplot(aes(x = "", y = porcentaje, fill = Class_full)) +
  geom_col(width = 1, color = "white") +
  coord_polar(theta = "y") +
  geom_text(aes(label = etiqueta), position = position_stack(vjust = 0.5), size = 4.7) +
  scale_fill_brewer(palette = "Set2") + # Paleta de color
  labs(title = "Distribución por clase académica en el Draft de la NBA") +
  theme_void() +
  theme(
    legend.position = "none",
    plot.title = element_text(hjust = 0.5, size = 25, face = "bold")
  )


por_clase <- ncaa_exp %>%
  group_by(Class) %>%
  summarise(mean(x = SEASON_EXP))
  as.data.frame()
  