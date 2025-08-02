library(dplyr)
library(tidyr)
library(xgboost)
library(caret)  

set.seed(123)  

# PREPROCESAMIENTO



# variable binaria de éxito
ncaa_exp$exito_nba <- ifelse(ncaa_exp$SEASON_EXP >= 5, 1, 0) # más de 5 años en la liga

ncaa_exp <- ncaa_exp %>%
  filter(as.numeric(substr(Season, 1, 4)) + 1 <= 2017)

# Variables a usar
vars_usar <- c(
  "exito_nba", "PTS.1", "AST", "ORB", "DRB", "STL", "BLK", "TOV", 
  "FG.", "X3P.", "FT.", "TS.", "eFG.", "Pos", "Round", 
  "Class"
)

draft_model <- ncaa_exp %>%
  select(all_of(vars_usar)) %>%
  filter(!is.na(exito_nba)) %>%
  mutate(
    PTS.1 = as.numeric(as.character(PTS.1)),
    AST = as.numeric(as.character(AST)),
    ORB = as.numeric(as.character(ORB)),
    DRB = as.numeric(as.character(DRB)),
    STL = as.numeric(as.character(STL)),
    BLK = as.numeric(as.character(BLK)),
    TOV = as.numeric(as.character(TOV)),
    FG. = as.numeric(as.character(FG.)),
    X3P. = as.numeric(as.character(X3P.)),
    FT. = as.numeric(as.character(FT.)),
    TS. = as.numeric(as.character(TS.)),
    eFG. = as.numeric(as.character(eFG.)),
    Round = factor(Round),
    Pos = factor(Pos),
    Class = factor(Class),
    exito_nba = factor(exito_nba, levels = c(0, 1), labels = c("No", "Si"))
  )



# MODELO



# validación cruzada

train_index <- sample(seq_len(nrow(draft_model)), size = 0.8 * nrow(draft_model))
train_data <- draft_model[train_index, ]
test_data <- draft_model[-train_index, ]

control <- trainControl(
  method = "cv",
  number = 5,
  classProbs = TRUE,
  summaryFunction = twoClassSummary,
  verboseIter = FALSE,
  allowParallel = FALSE
)

grid <- expand.grid(
  nrounds = c(50, 100, 150),
  max_depth = c(4, 6, 8),
  eta = c(0.05, 0.1, 0.3),
  gamma = 0,
  colsample_bytree = c(0.6, 0.8),
  min_child_weight = 1,
  subsample = c(0.7, 0.9)
)

xgb_model <- train(
  exito_nba ~ .,
  data = train_data,
  method = "xgbTree",
  metric = "ROC",
  trControl = control,
  tuneGrid = grid,
  na.action = na.pass
)

print(xgb_model$bestTune)


#Defino el modelo con el paquete xgboost porque caret no soporta datos faltantes
# usamos los mejores parámetros obtenidos


X_train <- data.matrix(train_data %>% select(-exito_nba))
y_train <- ifelse(train_data$exito_nba == "Si", 1, 0)

X_test <- data.matrix(test_data %>% select(-exito_nba))
y_test <- test_data$exito_nba

dtrain <- xgb.DMatrix(data = X_train, label = y_train, missing = NA)
dtest  <- xgb.DMatrix(data = X_test, missing = NA)


modelo_optimo <- xgboost(
  data = dtrain,
  objective = "binary:logistic",
  nrounds = 50,
  max_depth = 4,
  eta = 0.05,
  gamma = 0,
  colsample_bytree = 0.6,
  min_child_weight = 1,
  subsample = 0.9,
  eval_metric = "auc",
  verbose = 0
)


# Predecir en test
pred_probs <- predict(modelo_optimo, newdata = X_test)
pred_class <- as.factor(ifelse(pred_probs >= 0.5, "Si", "No"))

conf_mat <- confusionMatrix(pred_class, y_test, positive = "Si")
print(conf_mat)


importance <- xgb.importance(model = modelo_optimo)
print(importance)

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

recall <- conf_mat$byClass["Sensitivity"]
precision <- conf_mat$byClass["Precision"]
f1 <- 2 * (precision * recall) / (precision + recall)

recall
precision
f1
