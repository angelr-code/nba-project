library(dplyr)
library(factoextra)
library(corrplot)
library(RColorBrewer)

# Create advanced variables
player_stats <- player_stats %>%
  mutate(
    # Shooting proportions
    FGA_per_MIN = FGA / MIN,
    FG3A_rate = FG3A / FGA,  # % of shots that are from 3-point range
    FTA_rate = FTA / FGA,    # % of shots that lead to free throws
    
    # Rebounding distribution
    OREB_rate = OREB / (OREB + DREB),  # % of offensive rebounds
    
    # Play style
    AST_per_MIN = AST / MIN,
    TOV_per_MIN = TOV / MIN,
    AST_TOV_ratio = AST / pmax(TOV, 1),  # Assists/turnovers ratio
    
    # Defensive contribution
    STL_per_MIN = STL / MIN,
    BLK_per_MIN = BLK / MIN,
    
    # Corrected usage rate (WITH assists)
    Usage_rate = (FGA + 0.44 * FTA + AST + TOV) / MIN
  )

# Filter players with at least 15 min PER GAME
filtered_stats <- player_stats %>%
  filter(MIN >= 15)

clustering_data <- filtered_stats[, c("FG_PCT", "FG3_PCT", "FT_PCT",
                                      "FG3A_rate", "FTA_rate",
                                      "OREB_rate", "AST_per_MIN",
                                      "TOV_per_MIN", "AST_TOV_ratio",
                                      "STL_per_MIN", "BLK_per_MIN", "Usage_rate")]

clustering_data[is.na(clustering_data) | is.infinite(as.matrix(clustering_data))] <- 0

scaled_data <- as.data.frame(scale(clustering_data)) # Scaling

# Correlation matrix
correlation_matrix <- cor(clustering_data, use = "complete.obs")
corrplot(correlation_matrix,
         method = "color",
         type = "lower",
         col = colorRampPalette(brewer.pal(8, "RdBu"))(200),
         addCoef.col = "black",
         tl.col = "black",
         tl.cex = 1.1,
         number.cex = 1)

# PCA

pca <- prcomp(scaled_data, center = FALSE, scale. = FALSE)

fviz_eig(pca, addlabels = TRUE, barfill = "#00AFBB", barcolor = "black") +
  labs(title = "Variance Explained by Principal Component",
       x = "Principal Components",
       y = "Percentage of Variance") +
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
  labs(title = "Contribution of Variables to Principal Components") +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold", size = 25),
    axis.title = element_text(size = 18),
    axis.text = element_text(size = 18),
    legend.title = element_text(size = 16),
    legend.text = element_text(size = 16)
  )


# Determine the optimal number of clusters
pca_components <- as.data.frame(pca$x[, 1:3])

fviz_nbclust(pca_components, kmeans, method = "wss") +
  labs(
    title = "Optimal Number of Clusters Selection",
    x = "Number of Clusters (k)",
    y = "Within-Cluster Sum of Squares (WSS)"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 25, face = "bold"),
    axis.title = element_text(size = 18),
    axis.text = element_text(size = 18)
  )


# CLUSTERING
k <- 5
kmeans_model <- kmeans(pca_components, centers = k, nstart = 50, iter.max = 100)

# VISUALIZATION
pca_components$cluster <- as.numeric(kmeans_model$cluster)

fviz_cluster(kmeans_model, data = pca_components,
             geom = "point",
             ellipse.type = "convex",
             palette = "Set1",
             main = "NBA Player Profiles") +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 25, face = "bold"),
    axis.title = element_text(size = 18),
    axis.text = element_text(size = 18)
  )

filtered_stats$CLUSTER <- pca_components$cluster


# Comparisons
stats_by_cluster <- filtered_stats %>%
  group_by(CLUSTER) %>%
  summarise(across(where(is.numeric), mean, na.rm = TRUE))

# Format in long format and translate labels
long_cluster_data <- stats_by_cluster %>%
  select(CLUSTER, PTS, AST, REB, BLK, STL, FG_PCT, FG3_PCT, FT_PCT) %>%
  pivot_longer(cols = -CLUSTER, names_to = "statistic", values_to = "value") %>%
  mutate(
    CLUSTER = paste("Group", CLUSTER),
    statistic = case_when(
      statistic == "PTS" ~ "Points per game",
      statistic == "AST" ~ "Assists per game",
      statistic == "REB" ~ "Rebounds per game",
      statistic == "BLK" ~ "Blocks per game",
      statistic == "STL" ~ "Steals per game",
      statistic == "FG_PCT" ~ "Field Goal %",
      statistic == "FG3_PCT" ~ "Three Point %",
      statistic == "FT_PCT" ~ "Free Throw %",
      TRUE ~ statistic
    )
  )

cluster_colors <- c(
  "Group 1" = "#FF6B6B",    # Coral red
  "Group 2" = "#4ECDC4",    # Soft turquoise
  "Group 3" = "#FFD93D",    # Warm yellow
  "Group 4" = "#A29BFE",    # Light violet
  "Group 5" = "#45B7D1"     # Sky blue
)


ggplot(long_cluster_data, aes(x = CLUSTER, y = value, fill = CLUSTER)) +
  geom_col(alpha = 0.8, width = 0.7) +
  facet_wrap(~statistic, scales = "free_y", ncol = 4) +
  labs(
    title = "Mean Statistics by NBA Player Group",
    subtitle = "Comparison between the 5 archetypes found via clustering",
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
  scale_fill_manual(values = cluster_colors)

subset(filtered_stats, filtered_stats$CLUSTER == 1)$PLAYER_NAME
subset(filtered_stats, filtered_stats$CLUSTER == 2)$PLAYER_NAME
subset(filtered_stats, filtered_stats$CLUSTER == 3)$PLAYER_NAME
subset(filtered_stats, filtered_stats$CLUSTER == 4)$PLAYER_NAME
subset(filtered_stats, filtered_stats$CLUSTER == 5)$PLAYER_NAME
