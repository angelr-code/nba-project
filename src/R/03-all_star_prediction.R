# Load necessary libraries
library(dplyr)
library(caret)
library(randomForest)
library(ggplot2)
library(MLmetrics)

# Variable Selection
# Variables to discard
descartes1 <- c( "PLAYER_ID", "TEAM_ABBREVIATION", "SCHOOL", "COUNTRY")

# More variables to discard
descartes2 <- c("WEIGHT", "HEIGHT", "AGE", "REB", "PLUS_MINUS", "L", "W_PCT",
                "PF", "PFD", "BLKA", "W")

# Remove the defined variables from the dataset
datos_nba <- datos_nba[, setdiff(names(datos_nba), c(descartes2, descartes1))]

# Convert variables to factors and filter data
datos_nba$SEASON <- as.factor(datos_nba$SEASON)
datos_nba$POSITION <- as.factor(datos_nba$POSITION)
datos_nba$ALL_STAR <- as.factor(datos_nba$ALL_STAR)
datos_nba <- subset(datos_nba, datos_nba$SEASON != "1998-99" & !is.na(datos_nba$POSITION)
                    & datos_nba$POSITION != "")

# Clean up temporary variables
rm(descartes1, descartes2)

# RANDOM FOREST MODEL
set.seed(123)

# Convert the target variable to a factor with specific labels
datos_nba$ALL_STAR <- factor(datos_nba$ALL_STAR, levels = c(0,1), labels = c("no", "yes"))

# Split the data into training and test sets
trainIndex <- createDataPartition(datos_nba$ALL_STAR, p = 0.80, list = FALSE)
train_data <- datos_nba[trainIndex, -1] # Exclude the PLAYER_NAME column
test_data <- datos_nba[-trainIndex, -1]

# Control settings for cross-validation
control <- trainControl(
  method = "cv",
  number = 5,
  classProbs = TRUE,
  summaryFunction = prSummary,  # Use Precision-Recall summary
  savePredictions = TRUE,
  #sampling = "smote" # Optional for imbalanced datasets
)

# Hyperparameter grid for tuning 'mtry'
tunegrid <- expand.grid(
  mtry = c(2, 4, 6, 8, 10)
)

# Train the model with caret, searching for the best configuration
modelo_rf_tuned <- train(
  ALL_STAR ~ .,
  data = train_data,
  method = "rf",
  metric = "AUC",          # Optimize for AUC
  trControl = control,
  tuneGrid = tunegrid,
  ntree = 250,
  classwt = c("no" = 1, "yes" = 1)
)

# Print the training results
print(modelo_rf_tuned)
ggplot(modelo_rf_tuned) +
  labs(
    title = "AUC Evolution based on the number of selected predictors",
    x = "Number of randomly selected predictors (mtry)",
    y = "AUC (cross-validation)"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold", hjust = 0.5),
    axis.title = element_text(face = "bold")
  )

# Predict using the best model
pred_rf <- predict(modelo_rf_tuned, test_data)
conf_matrix <- confusionMatrix(pred_rf, test_data$ALL_STAR, positive = "yes")

# Print the confusion matrix
conf_matrix

# Calculate Recall, Precision, and F1 for All-Stars
recall <- conf_matrix$byClass["Sensitivity"]
precision <- conf_matrix$byClass["Precision"]
f1 <- 2 * (precision * recall) / (precision + recall)

recall
precision
f1

# Plot feature importance
varImpPlot(modelo_rf_tuned$finalModel,
           type = 1,
           scale = FALSE,
           main = "Importance")


remove(control, test_data, train_data, trainIndex, tunegrid)

# TEST TO DETECT THE BEST PROBABILITY THRESHOLD

# Get the probabilities for the 'yes' class
prob_rf <- predict(modelo_rf_tuned, test_data, type = "prob")[, "yes"]

# Test different thresholds to find the optimal one
thresholds <- seq(0.2, 0.8, by = 0.02)
f1_scores <- sapply(thresholds, function(thresh) {
  preds <- ifelse(prob_rf >= thresh, "yes", "no")
  F1_Score(y_pred = preds, y_true = test_data$ALL_STAR, positive = "yes")
})

# Get the optimal threshold (the one that maximizes F1)
opt_thresh <- thresholds[which.max(f1_scores)]
cat("Optimal threshold:", opt_thresh, "\nMax F1:", max(f1_scores), "\n")

# Make a new prediction with the optimal threshold
pred_rf_opt <- ifelse(prob_rf >= opt_thresh, "yes", "no")
pred_rf_opt <- factor(pred_rf_opt, levels = c("no", "yes"))

# New confusion matrix
conf_matrix_opt <- confusionMatrix(pred_rf_opt, test_data$ALL_STAR, positive = "yes")
print(conf_matrix_opt)

# New calculation of recall, precision, and F1
recall_opt <- conf_matrix_opt$byClass["Sensitivity"]
precision_opt <- conf_matrix_opt$byClass["Precision"]
f1_opt <- 2 * (precision_opt * recall_opt) / (precision_opt + recall_opt)

recall_opt
precision_opt
f1_opt

# Visualize F1 as a function of the threshold
df_umbral <- data.frame(
  Threshold = thresholds,
  F1_Score = f1_scores
)

ggplot(df_umbral, aes(x = Threshold, y = F1_Score)) +
  geom_line(size = 1.2, color = "steelblue") +
  geom_vline(xintercept = opt_thresh, linetype = "dashed", color = "red") +
  labs(
    title = "F1 Score Evolution as a function of the classification threshold",
    x = "Probability Threshold to predict All-Star",
    y = "F1 Score"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold", hjust = 0.5),
    axis.title = element_text(face = "bold")
  )
