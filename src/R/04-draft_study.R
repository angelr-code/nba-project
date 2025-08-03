library(dplyr)
library(tidyr)
library(xgboost)
library(caret)

set.seed(123)

# PREPROCESSING

# Create a binary success variable
ncaa_exp$nba_success <- ifelse(ncaa_exp$SEASON_EXP >= 5, 1, 0) # more than 5 years in the league

# Filter the data
ncaa_exp <- ncaa_exp %>%
  filter(as.numeric(substr(Season, 1, 4)) + 1 <= 2017)

# Variables to use
vars_to_use <- c(
  "nba_success", "PTS.1", "AST", "ORB", "DRB", "STL", "BLK", "TOV",
  "FG.", "X3P.", "FT.", "TS.", "eFG.", "Pos", "Round",
  "Class"
)

draft_model <- ncaa_exp %>%
  select(all_of(vars_to_use)) %>%
  filter(!is.na(nba_success)) %>%
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
    nba_success = factor(nba_success, levels = c(0, 1), labels = c("No", "Yes"))
  )

# MODEL

# Cross-validation
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
  nba_success ~ .,
  data = train_data,
  method = "xgbTree",
  metric = "ROC",
  trControl = control,
  tuneGrid = grid,
  na.action = na.pass
)

print(xgb_model$bestTune)

# Define the model with the xgboost package directly, as caret might not fully support missing data
# Use the best parameters obtained from tuning

X_train <- data.matrix(train_data %>% select(-nba_success))
y_train <- ifelse(train_data$nba_success == "Yes", 1, 0)

X_test <- data.matrix(test_data %>% select(-nba_success))
y_test <- test_data$nba_success

dtrain <- xgb.DMatrix(data = X_train, label = y_train, missing = NA)
dtest <- xgb.DMatrix(data = X_test, missing = NA)

optimal_model <- xgboost(
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

# Predict on the test set
pred_probs <- predict(optimal_model, newdata = dtest)
pred_class <- as.factor(ifelse(pred_probs >= 0.5, "Yes", "No"))

conf_mat <- confusionMatrix(pred_class, y_test, positive = "Yes")
print(conf_mat)

# Feature importance
importance <- xgb.importance(model = optimal_model)
print(importance)

ggplot(importance, aes(x = reorder(Feature, Gain), y = Gain)) +
  geom_col(fill = "#1D428A") +  # NBA Blue
  coord_flip() +
  ggtitle("Variable Importance (XGBoost)") +
  xlab("Variable") +
  ylab("Gain") +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(size = 20, face = "bold", hjust = 0.5),
    axis.text = element_text(size = 18),
    axis.title = element_text(size = 18)
  )

# Calculate and print metrics
recall <- conf_mat$byClass["Sensitivity"]
precision <- conf_mat$byClass["Precision"]
f1 <- 2 * (precision * recall) / (precision + recall)

recall
precision
f1
