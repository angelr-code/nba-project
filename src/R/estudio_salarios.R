# 1. Selección de variables en vista del Análisis Exploratorio

descartes1 <- c( "PLAYER_ID", "TEAM_ABBREVIATION", "SCHOOL", "COUNTRY")

# Ver qué hacemos con los cambios macroeconómicos

# A continuación se descartan estadísticas aparentemente útiles para el análsis
# pero que debido al uso de otras variables introducen información redundante y/o 
# multicolinealidad.Algunas, como las físicas introducen más ruido al análisis
# que información relevante para el salario. 

descartes2 <- c("WEIGHT", "HEIGHT", "REB", "FGM", "FG3M", "FTM", "PLUS_MINUS", "L", "W_PCT",
                "BLK_A", "PF", "PFD", "BLKA", "NBA_FANTASY_PTS", "POSITION", "DD2", "W", "GP", "AGE")

datos_nba <- datos_nba[, setdiff(names(datos_nba), c(descartes2, descartes1))]

not_show <- c("POSITION", "PLAYER_NAME", "SEASON",  "ALL_STAR")

library(corrplot)
library(RColorBrewer)

matriz_cor <- cor(datos_nba[, setdiff(names(datos_nba), not_show)], use = "complete.obs")

corrplot(matriz_cor, 
         method = "color",
         type = "lower",
         col = colorRampPalette(brewer.pal(8, "RdBu"))(200),
         addCoef.col = "black",         # añade los valores de correlación sobre el plot
         tl.col = "black",              # color del texto de las etiquetas
         tl.cex = 0.8,                  # tamaño del texto de las etiquetas,
         number.cex = 0.55
)

rm(matriz_cor, descartes1, descartes2, not_show)


# Tratamos de filtrar outliers salariales y jugadores residuales

datos_nba <- subset(datos_nba, MIN > 10)

q_low <- quantile(datos_nba$SALARY, 0.01, na.rm = TRUE)
q_high <- quantile(datos_nba$SALARY, 0.99, na.rm = TRUE)
datos_nba <- subset(datos_nba, SALARY >= q_low & SALARY <= q_high)



# 2. XGBoost


datos_nba$SEASON <- as.numeric(substr(datos_nba$SEASON, 1, 4)) + 1
#datos_nba$POSITION <- as.factor(datos_nba$POSITION)
datos_nba$ALL_STAR <- as.factor(datos_nba$ALL_STAR)
#datos_nba <- subset(datos_nba, !is.na(datos_nba$POSITION) & datos_nba$POSITION != "")


library(caret)
library(xgboost)
library(Matrix)


set.seed(1234)
train_index <- sample(1:nrow(datos_nba), 0.95 * nrow(datos_nba))
train_data <- datos_nba[train_index, ]
test_data <- datos_nba[-train_index, ]

# Matrices para XGBoost
X_train <- model.matrix(SALARY ~ . -1, data = train_data[, -c(1)])  # quita PLAYER
y_train <- train_data$SALARY

X_test <- model.matrix(SALARY ~ . -1, data = test_data[, -c(1)])
y_test <- test_data$SALARY

# DMatrix (formato en XGBoost)
dtrain <- xgb.DMatrix(data = X_train, label = y_train)
dtest <- xgb.DMatrix(data = X_test, label = y_test)


# Malla de parámetros base
params <- list(
  booster = "gbtree",
  objective = "reg:squarederror",
  eval_metric = "rmse",   # error medio cuadrático
  eta = 0.1,              # tasa de aprendizaje
  max_depth = 6,          # profundidad del árbol
  subsample = 0.8,        # % de datos usados por árbol
  colsample_bytree = 0.8  # % de variables por árbol
)

# Validación cruzada con early stopping
set.seed(123)
cv_model <- xgb.cv(
  params = params,
  data = dtrain,
  nrounds = 1000,
  nfold = 5,
  early_stopping_rounds = 20,
  verbose = 0
)

# Mejor número de rondas
best_nrounds <- cv_model$best_iteration

# Entrenar el modelo final
modelo_xgb_tuned <- xgboost(
  params = params,
  data = dtrain,
  nrounds = best_nrounds,
  verbose = 0
)

# Predicciones y evaluación
pred_xgb <- predict(modelo_xgb_tuned, dtest)

rmse_xgb_tuned <- sqrt(mean((pred_xgb - y_test)^2))
r2_xgb_tuned <- 1 - sum((pred_xgb - y_test)^2) / sum((y_test - mean(y_test))^2)
error_medio <- mean(abs(pred_xgb - y_test))

cat("RMSE ajustado:", rmse_xgb_tuned, "\n")
cat("R² ajustado:", r2_xgb_tuned, "\n")
cat("Error medio ajustado:", error_medio, "\n")


importance <- xgb.importance(model = modelo_xgb_tuned)

# Graficar con ggplot2
ggplot(importance, aes(x = reorder(Feature, Gain), y = Gain)) +
  geom_col(fill = "#1D428A") +  # Azul NBA
  coord_flip() +
  ggtitle("Importancia de las variables (XGBoost)") +
  xlab("Variable") +
  ylab("Ganancia (Gain)") +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(size = 20, face = "bold", hjust = 0.5),
    axis.text = element_text(size = 18),
    axis.title = element_text(size = 18)
  )


# Visualización real vs predicho
library(ggplot2)

# Convertir a millones
df_test <- data.frame(
  Real = y_test / 1e6,
  Predicho = pred_xgb / 1e6
)

ggplot(df_test, aes(x = Real, y = Predicho)) +
  geom_point(color = "#1D428A", alpha = 0.6) +
  geom_abline(slope = 1, intercept = 0, color = "red", linetype = "dashed") +
  labs(
    title = "Salarios Reales vs Predichos (Conjunto Test)",
    x = "Salario real (M$)",
    y = "Salario predicho (M$)"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(size = 25, face = "bold", hjust = 0.5),
    axis.text = element_text(size = 18),
    axis.title = element_text(size = 18)
  )


# ¿Regresión?

# Cargar paquetes
library(glmnet)
library(Matrix)
library(caret)

# Convertir variables categóricas a factor si no lo están
datos_nba$SEASON <- as.numeric(substr(datos_nba$SEASON, 1, 4)) + 1  # o factor si prefieres
datos_nba$ALL_STAR <- as.factor(datos_nba$ALL_STAR)

# Dividir en train/test
set.seed(123)
train_index <- sample(1:nrow(datos_nba), 0.8 * nrow(datos_nba))
train_data <- datos_nba[train_index, ]
test_data <- datos_nba[-train_index, ]

# Codificar variables (dummies + numéricas)
X_train <- model.matrix(SALARY ~ . - 1, data = train_data[, -1])  # quita PLAYER si sigue
y_train <- train_data$SALARY

X_test <- model.matrix(SALARY ~ . - 1, data = test_data[, -1])
y_test <- test_data$SALARY

# RIDGE REGRESSION (alpha = 0)
cv_ridge <- cv.glmnet(X_train, y_train, alpha = 0, standardize = TRUE)
ridge_best_lambda <- cv_ridge$lambda.min
ridge_model <- glmnet(X_train, y_train, alpha = 0, lambda = ridge_best_lambda)

# LASSO REGRESSION (alpha = 1)
cv_lasso <- cv.glmnet(X_train, y_train, alpha = 1, standardize = TRUE)
lasso_best_lambda <- cv_lasso$lambda.min
lasso_model <- glmnet(X_train, y_train, alpha = 1, lambda = lasso_best_lambda)

# PREDICCIONES
pred_ridge <- predict(ridge_model, s = ridge_best_lambda, newx = X_test)
pred_lasso <- predict(lasso_model, s = lasso_best_lambda, newx = X_test)

# MÉTRICAS DE EVALUACIÓN
rmse_ridge <- sqrt(mean((pred_ridge - y_test)^2))
r2_ridge <- 1 - sum((pred_ridge - y_test)^2) / sum((y_test - mean(y_test))^2)
mae_ridge <- mean(abs(pred_ridge - y_test))

rmse_lasso <- sqrt(mean((pred_lasso - y_test)^2))
r2_lasso <- 1 - sum((pred_lasso - y_test)^2) / sum((y_test - mean(y_test))^2)
mae_lasso <- mean(abs(pred_lasso - y_test))

# RESULTADOS
cat("----- RIDGE -----\n")
cat("RMSE:", rmse_ridge, "\nR²:", r2_ridge, "\nMAE:", mae_ridge, "\n\n")

cat("----- LASSO -----\n")
cat("RMSE:", rmse_lasso, "\nR²:", r2_lasso, "\nMAE:", mae_lasso, "\n")


