# Load necessary libraries
library(dplyr)
library(caret)
library(randomForest)
library(ggplot2)
library(MLmetrics)

# ----------------------------------------------------
# 1. DATA PREPROCESSING
# ----------------------------------------------------

# Variable Selection
# Variables to discard
vars_to_discard1 <- c("PLAYER_ID", "TEAM_ABBREVIATION", "SCHOOL", "COUNTRY")

# More variables to discard
vars_to_discard2 <- c("WEIGHT", "HEIGHT", "AGE", "REB", "PLUS_MINUS", "L", "W_PCT",
                      "PF", "PFD", "BLKA", "W")

# Remove the defined variables from the dataset
nba_data <- nba_data[, setdiff(names(nba_data), c(vars_to_discard2, vars_to_discard1))]

# Convert variables to factors and filter data
nba_data$SEASON <- as.factor(nba_data$SEASON)
nba_data$POSITION <- as.factor(nba_data$POSITION)
nba_data$ALL_STAR <- as.factor(nba_data$ALL_STAR)
nba_data <- subset(nba_data, nba_data$SEASON != "1998-99" & !is.na(nba_data$POSITION)
                   & nba_data$POSITION != "")

# Clean up temporary variables
rm(vars_to_discard1, vars_to_discard2)

# ----------------------------------------------------
# 2. RANDOM FOREST MODEL TRAINING
# ----------------------------------------------------
set.seed(123)

# Convert the target variable to a factor with specific labels
nba_data$ALL_STAR <- factor(nba_data$ALL_STAR, levels = c(0, 1), labels = c("no", "yes"))

# Split the data into training and test sets (80/20)
trainIndex <- createDataPartition(nba_data$ALL_STAR, p = 0.80, list = FALSE)
train_data <- nba_data[trainIndex, -1] # Exclude the PLAYER_NAME column
test_data <- nba_data[-trainIndex, -1]

# Control settings for cross-validation
control <- trainControl(
  method = "cv",
  number = 5,
  classProbs = TRUE,
  summaryFunction = prSummary,  # Use Precision-Recall summary
  savePredictions = TRUE
)

# Hyperparameter grid for tuning 'mtry'
tunegrid <- expand.grid(
  mtry = c(2, 4, 6, 8, 10)
)

# Train the model with caret, searching for the best configuration
tuned_rf_model <- train(
  ALL_STAR ~ .,
  data = train_data,
  method = "rf",
  metric = "AUC",               # Optimize for AUC
  trControl = control,
  tuneGrid = tunegrid,
  ntree = 250,
  classwt = c("no" = 1, "yes" = 1)
)

# Print the training results
print(tuned_rf_model)
ggplot(tuned_rf_model) +
  labs(
    title = "AUC Evolution Based on the Number of Selected Predictors",
    x = "Number of Randomly Selected Predictors (mtry)",
    y = "AUC (Cross-validation)"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold", hjust = 0.5),
    axis.title = element_text(face = "bold")
  )

# Predict using the best model
rf_predictions <- predict(tuned_rf_model, test_data)
conf_matrix <- confusionMatrix(rf_predictions, test_data$ALL_STAR, positive = "yes")

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
varImpPlot(tuned_rf_model$finalModel,
           type = 1,
           scale = FALSE,
           main = "Feature Importance")

# Clean up temporary variables
remove(control, test_data, train_data, trainIndex, tunegrid)

# ----------------------------------------------------
# 3. OPTIMAL PROBABILITY THRESHOLD SELECTION
# ----------------------------------------------------

# Get the probabilities for the 'yes' class
rf_probabilities <- predict(tuned_rf_model, test_data, type = "prob")[, "yes"]

# Test different thresholds to find the optimal one
thresholds <- seq(0.2, 0.8, by = 0.02)
f1_scores <- sapply(thresholds, function(thresh) {
  preds <- ifelse(rf_probabilities >= thresh, "yes", "no")
  F1_Score(y_pred = preds, y_true = test_data$ALL_STAR, positive = "yes")
})

# Get the optimal threshold (the one that maximizes F1)
optimal_threshold <- thresholds[which.max(f1_scores)]
cat("Optimal threshold:", optimal_threshold, "\nMax F1:", max(f1_scores), "\n")

# Make a new prediction with the optimal threshold
optimal_rf_predictions <- ifelse(rf_probabilities >= optimal_threshold, "yes", "no")
optimal_rf_predictions <- factor(optimal_rf_predictions, levels = c("no", "yes"))

# New confusion matrix
optimal_conf_matrix <- confusionMatrix(optimal_rf_predictions, test_data$ALL_STAR, positive = "yes")
print(optimal_conf_matrix)

# New calculation of recall, precision, and F1
optimal_recall <- optimal_conf_matrix$byClass["Sensitivity"]
optimal_precision <- optimal_conf_matrix$byClass["Precision"]
optimal_f1 <- 2 * (optimal_precision * optimal_recall) / (optimal_precision + optimal_recall)

optimal_recall
optimal_precision
optimal_f1

# Visualize F1 as a function of the threshold
threshold_df <- data.frame(
  Threshold = thresholds,
  F1_Score = f1_scores
)

ggplot(threshold_df, aes(x = Threshold, y = F1_Score)) +
  geom_line(size = 1.2, color = "steelblue") +
  geom_vline(xintercept = optimal_threshold, linetype = "dashed", color = "red") +
  labs(
    title = "F1 Score Evolution as a Function of the Classification Threshold",
    x = "Probability Threshold for All-Star Prediction",
    y = "F1 Score"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold", hjust = 0.5),
    axis.title = element_text(face = "bold")
  )
