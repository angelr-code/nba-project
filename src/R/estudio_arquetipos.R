library(dplyr)
library(factoextra)
library(corrplot)
library(RColorBrewer)

# Crear variables avanzadas
estadisticas <- estadisticas %>%
  mutate(
    # Proporciones de tiro 
    FGA_per_MIN = FGA / MIN,
    FG3A_rate = FG3A / FGA,  # % de tiros que son de 3
    FTA_rate = FTA / FGA,    # % de tiros que generan tiros libres
    
    # Distribución de rebotes
    OREB_rate = OREB / (OREB + DREB),  # % de rebotes ofensivos
    
    # Estilo de juego
    AST_per_MIN = AST / MIN,
    TOV_per_MIN = TOV / MIN,
    AST_TOV_ratio = AST / pmax(TOV, 1),  # Ratio asistencias/pérdidas
    
    # Contribución defensiva
    STL_per_MIN = STL / MIN,
    BLK_per_MIN = BLK / MIN,
    
    # Usage rate corregido (CON asistencias)
    Usage_rate = (FGA + 0.44 * FTA + AST + TOV) / MIN
  )

# Filtrar jugadores con al menos 15 min POR PARTIDO
estadisticas_filtradas <- estadisticas %>%
  filter(MIN >= 15) 

datos_clustering <- estadisticas_filtradas[, c("FG_PCT", "FG3_PCT", "FT_PCT",           
                                               "FG3A_rate", "FTA_rate",                
                                               "OREB_rate", "AST_per_MIN", 
                                               "TOV_per_MIN", "AST_TOV_ratio", 
                                               "STL_per_MIN", "BLK_per_MIN", "Usage_rate")]

datos_clustering[is.na(datos_clustering) | is.infinite(as.matrix(datos_clustering))] <- 0

datos_esc <- as.data.frame(scale(datos_clustering)) # Escalado

# Matriz de correlaciones
matriz_cor <- cor(datos_clustering, use = "complete.obs")
corrplot(matriz_cor, 
         method = "color",
         type = "lower",
         col = colorRampPalette(brewer.pal(8, "RdBu"))(200),
         addCoef.col = "black",
         tl.col = "black",
         tl.cex = 1.1,
         number.cex = 1)

# PCA

pca <- prcomp(datos_esc, center = FALSE, scale. = FALSE)

fviz_eig(pca, addlabels = TRUE, barfill = "#00AFBB", barcolor = "black") +
  labs(title = "Varianza explicada por componente principal",
       x = "Componentes principales",
       y = "Porcentaje de varianza") +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 25, face = "bold"),
    axis.title = element_text(size = 18),
    axis.text = element_text(size = 18)
  )

fviz_pca_var(
  pca,
  col.var = "contrib",
  gradient.cols = c("#00AFBB", "#E7B800", "#FC4E07"),
  repel = TRUE,
  labelsize = 8
) +
  labs(title = "Contribución de variables a las componentes principales") +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold", size = 25),
    axis.title = element_text(size = 18),
    axis.text = element_text(size = 18),
    legend.title = element_text(size = 16),
    legend.text = element_text(size = 16)
  )


# Determinar número óptimo de clusters
componentes_pca <- as.data.frame(pca$x[, 1:3])

fviz_nbclust(componentes_pca, kmeans, method = "wss") +
  labs(
    title = "Selección del número óptimo de clusters",
    x = "Número de clusters (k)",
    y = "Suma de cuadrados intra-cluster (WSS)"
  ) +
  theme_minimal() + 
  theme(
    plot.title = element_text(hjust = 0.5, size = 25, face = "bold"),
    axis.title = element_text(size = 18),
    axis.text = element_text(size = 18)
  )


# CLUSTERING
k <- 5
kmedias <- kmeans(componentes_pca, centers = k, nstart = 50, iter.max = 100)

# VISUALIZACIÓN
componentes_pca$cluster <- as.numeric(kmedias$cluster)

fviz_cluster(kmedias, data = componentes_pca,
             geom = "point",
             ellipse.type = "convex",
             palette = "Set1",
             main = "Perfiles de Jugadores NBA") +
  theme_minimal() + 
  theme(
    plot.title = element_text(hjust = 0.5, size = 25, face = "bold"),
    axis.title = element_text(size = 18),
    axis.text = element_text(size = 18)
    )

estadisticas_filtradas$CLUSTER <- componentes_pca$cluster


#Comparaciones
estadisticas_por_cluster <- estadisticas_filtradas %>%
  group_by(CLUSTER) %>%
  summarise(across(where(is.numeric), mean, na.rm = TRUE))

# Formatear en formato largo y traducir etiquetas
datos_long_cluster <- estadisticas_por_cluster %>%
  select(CLUSTER, PTS, AST, REB, BLK, STL, FG_PCT, FG3_PCT, FT_PCT) %>%
  pivot_longer(cols = -CLUSTER, names_to = "estadistica", values_to = "valor") %>%
  mutate(
    CLUSTER = paste("Grupo", CLUSTER),
    estadistica = case_when(
      estadistica == "PTS" ~ "Puntos por partido",
      estadistica == "AST" ~ "Asistencias por partido",
      estadistica == "REB" ~ "Rebotes por partido", 
      estadistica == "BLK" ~ "Tapones por partido",
      estadistica == "STL" ~ "Robos por partido",
      estadistica == "FG_PCT" ~ "% Tiros de campo",
      estadistica == "FG3_PCT" ~ "% Triples",
      estadistica == "FT_PCT" ~ "% Tiros libres",
      TRUE ~ estadistica
    )
  )

colores_cluster <- c(
  "Grupo 1" = "#FF6B6B",   # rojo coral
  "Grupo 2" = "#4ECDC4",   # turquesa suave
  "Grupo 3" = "#FFD93D",   # amarillo cálido
  "Grupo 4" = "#A29BFE",   # violeta claro
  "Grupo 5" = "#45B7D1"    # azul cielo
)


ggplot(datos_long_cluster, aes(x = CLUSTER, y = valor, fill = CLUSTER)) +
  geom_col(alpha = 0.8, width = 0.7) +
  facet_wrap(~estadistica, scales = "free_y", ncol = 4) +
  labs(
    title = "Estadísticas medias por Grupo de Jugadores NBA",
    subtitle = "Comparación entre los 5 arquetipos encontrados vía clustering",
    x = "",
    y = "",
    fill = ""
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 18),
    axis.text.y = element_text(size = 18),
    strip.text = element_text(size = 18, face = "bold"),
    plot.title = element_text(size = 20, face = "bold", hjust = 0.5),
    plot.subtitle = element_text(size = 15, hjust = 0.5),
    legend.position = "bottom",
    legend.text = element_text(size = 18),
    panel.grid.minor = element_blank()
  ) +
  scale_fill_manual(values = colores_cluster)

subset(estadisticas_filtradas, estadisticas_filtradas$CLUSTER == 1)$PLAYER_NAME
subset(estadisticas_filtradas, estadisticas_filtradas$CLUSTER == 2)$PLAYER_NAME
subset(estadisticas_filtradas, estadisticas_filtradas$CLUSTER == 3)$PLAYER_NAME
subset(estadisticas_filtradas, estadisticas_filtradas$CLUSTER == 4)$PLAYER_NAME
subset(estadisticas_filtradas, estadisticas_filtradas$CLUSTER == 5)$PLAYER_NAME
