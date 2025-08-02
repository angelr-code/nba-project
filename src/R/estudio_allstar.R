# Selección de variables

descartes1 <- c( "PLAYER_ID", "TEAM_ABBREVIATION", "SCHOOL", "COUNTRY")

descartes2 <- c("WEIGHT", "HEIGHT", "AGE", "REB", "PLUS_MINUS", "L", "W_PCT",
                "PF", "PFD", "BLKA", "W")

datos_nba <- datos_nba[, setdiff(names(datos_nba), c(descartes2, descartes1))]

datos_nba$SEASON <- as.factor(datos_nba$SEASON)
datos_nba$POSITION <- as.factor(datos_nba$POSITION)
datos_nba$ALL_STAR <- as.factor(datos_nba$ALL_STAR)
datos_nba <- subset(datos_nba, datos_nba$SEASON != "1998-99" & !is.na(datos_nba$POSITION) 
                    & datos_nba$POSITION != "")

rm(descartes1, descartes2)

# RANDOM FOREST
library(caret)
library(randomForest)

set.seed(123)

datos_nba$ALL_STAR <- factor(datos_nba$ALL_STAR, levels = c(0,1), labels = c("no", "yes"))

trainIndex <- createDataPartition(datos_nba$ALL_STAR, p = 0.80, list = FALSE)
train_data <- datos_nba[trainIndex, -1]
test_data <- datos_nba[-trainIndex, -1]

# Control para cross-validation
control <- trainControl(
  method = "cv",
  number = 5,
  classProbs = TRUE,
  summaryFunction = prSummary,  # Precision-Recall
  savePredictions = TRUE,
  #sampling = "smote"
)

# Malla de hiperparámetros
tunegrid <- expand.grid(
  mtry = c(2, 4, 6, 8, 10)
)

# Entrenar con caret buscando la mejor configuración en la malla
modelo_rf_tuned <- train(
  ALL_STAR ~ .,
  data = train_data,
  method = "rf",
  metric = "AUC",       # optimizamos AUC.
  trControl = control,
  tuneGrid = tunegrid,
  ntree = 250,
  classwt = c("no" = 1, "yes" = 1)
)

print(modelo_rf_tuned)
ggplot(modelo_rf_tuned) +
  labs(
    title = "Evolución del AUC en función del número de predictores seleccionados",
    x = "Número de predictores seleccionados aleatoriamente (mtry)",
    y = "AUC (validación cruzada)"
  ) +
  theme_minimal(base_size = 14) +  # Aumenta el tamaño de fuente
  theme(
    plot.title = element_text(face = "bold", hjust = 0.5),
    axis.title = element_text(face = "bold")
  )

# Predecir con el mejor modelo
pred_rf <- predict(modelo_rf_tuned, test_data)
conf_matrix <- confusionMatrix(pred_rf, test_data$ALL_STAR, positive = "yes")

conf_matrix

# Calculamos Recall, Precision y F1 para los All-Star
recall <- conf_matrix$byClass["Sensitivity"]
precision <- conf_matrix$byClass["Precision"]
f1 <- 2 * (precision * recall) / (precision + recall)

recall
precision
f1

varImpPlot(modelo_rf_tuned,
           type = 1,
           scale = FALSE,
           main = "Importancia")


remove(control, test_data, train_data, trainIndex, tunegrid)

# PRUEBA PARA DETECTAR EL MEJOR UMBRAL DE PROBABILIDAD


library(MLmetrics)
prob_rf <- predict(modelo_rf_tuned, test_data, type = "prob")[, "yes"]

# Probar distintos umbrales
thresholds <- seq(0.2, 0.8, by = 0.02)
f1_scores <- sapply(thresholds, function(thresh) {
  preds <- ifelse(prob_rf >= thresh, "yes", "no")
  F1_Score(y_pred = preds, y_true = test_data$ALL_STAR, positive = "yes")
})

# Umbral óptimo (el que maximiza F1)
opt_thresh <- thresholds[which.max(f1_scores)]
cat("Umbral óptimo:", opt_thresh, "\nF1 máximo:", max(f1_scores), "\n")

# Nueva predicción con umbral óptimo
pred_rf_opt <- ifelse(prob_rf >= opt_thresh, "yes", "no")
pred_rf_opt <- factor(pred_rf_opt, levels = c("no", "yes"))

# Nueva matriz de confusión
conf_matrix_opt <- confusionMatrix(pred_rf_opt, test_data$ALL_STAR, positive = "yes")
print(conf_matrix_opt)

# Nuevo cálculo de recall, precision y F1
recall_opt <- conf_matrix_opt$byClass["Sensitivity"]
precision_opt <- conf_matrix_opt$byClass["Precision"]
f1_opt <- 2 * (precision_opt * recall_opt) / (precision_opt + recall_opt)

recall_opt
precision_opt
f1_opt

# Visualizar F1 en función del umbral
library(ggplot2)
df_umbral <- data.frame(
  Umbral = thresholds,
  F1_Score = f1_scores
)

ggplot(df_umbral, aes(x = Umbral, y = F1_Score)) +
  geom_line(size = 1.2, color = "steelblue") +
  geom_vline(xintercept = opt_thresh, linetype = "dashed", color = "red") +
  labs(
    title = "Evolución del F1 Score en función del umbral de clasificación",
    x = "Umbral de probabilidad para predecir All-Star",
    y = "F1 Score"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold", hjust = 0.5),
    axis.title = element_text(face = "bold")
  )