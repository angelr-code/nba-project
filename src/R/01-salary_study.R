# 1. Variable Selection based on Exploratory Analysis

# Define variables to discard that are not useful for the analysis
variables_to_drop1 <- c("PLAYER_ID", "TEAM_ABBREVIATION", "SCHOOL", "COUNTRY")

# Note: Further analysis may be needed to account for macroeconomic changes

# The following statistics are discarded as they introduce redundant information
# and/or multicollinearity. Some, like physical attributes, add more noise
# than relevant information for salary prediction.
variables_to_drop2 <- c("WEIGHT", "HEIGHT", "REB", "FGM", "FG3M", "FTM", "PLUS_MINUS", 
                        "L", "W_PCT", "BLK_A", "PF", "PFD", "BLKA", "NBA_FANTASY_PTS", 
                        "POSITION", "DD2", "W", "GP", "AGE")

# Remove the defined variables from the dataset
nba_data <- nba_data[, setdiff(names(nba_data), c(variables_to_drop2, variables_to_drop1))]

# Plot the new correlation matrix to check for multicollinearity
cols_to_show <- c("PLAYER_NAME", "SEASON", "ALL_STAR")

library(corrplot)
library(RColorBrewer)

correlation_matrix <- cor(nba_data[, setdiff(names(nba_data), cols_to_show)], use = "complete.obs")

corrplot(correlation_matrix, 
         method = "color",
         type = "lower",
         col = colorRampPalette(brewer.pal(8, "RdBu"))(200),
         addCoef.col = "black",   # Add correlation values to the plot
         tl.col = "black",        # Color of label text
         tl.cex = 0.8,            # Size of label text
         number.cex = 0.55
)

# Clean up temporary variables
rm(correlation_matrix, variables_to_drop1, variables_to_drop2, cols_to_show)


# Filter out salary outliers and players with low playing time
nba_data <- subset(nba_data, MIN > 10)

q_low <- quantile(nba_data$SALARY, 0.01, na.rm = TRUE)
q_high <- quantile(nba_data$SALARY, 0.99, na.rm = TRUE)
nba_data <- subset(nba_data, SALARY >= q_low & SALARY <= q_high)


# 2. XGBoost Model

library(caret)
library(xgboost)
library(Matrix)

# Prepare the data for modeling
nba_data$SEASON <- as.numeric(substr(nba_data$SEASON, 1, 4)) + 1
nba_data$ALL_STAR <- as.factor(nba_data$ALL_STAR)

# Split data into training and test sets
set.seed(1234)
train_index <- sample(1:nrow(nba_data), 0.95 * nrow(nba_data))
train_data <- nba_data[train_index, ]
test_data <- nba_data[-train_index, ]

# Create matrices for XGBoost
X_train <- model.matrix(SALARY ~ . -1, data = train_data[, -c(1)]) # exclude PLAYER_NAME
y_train <- train_data$SALARY

X_test <- model.matrix(SALARY ~ . -1, data = test_data[, -c(1)])
y_test <- test_data$SALARY

# Convert to DMatrix format for XGBoost
dtrain <- xgb.DMatrix(data = X_train, label = y_train)
dtest <- xgb.DMatrix(data = X_test, label = y_test)


# Define base parameters for the model
params <- list(
  booster = "gbtree",
  objective = "reg:squarederror",
  eval_metric = "rmse",          # Root Mean Square Error
  eta = 0.1,                     # Learning rate
  max_depth = 6,                 # Maximum tree depth
  subsample = 0.8,               # Percentage of data used per tree
  colsample_bytree = 0.8         # Percentage of features used per tree
)

# Perform cross-validation with early stopping
set.seed(123)
cv_model <- xgb.cv(
  params = params,
  data = dtrain,
  nrounds = 1000,
  nfold = 5,
  early_stopping_rounds = 20,
  verbose = 0
)

# Get the best number of rounds
best_nrounds <- cv_model$best_iteration

# Train the final XGBoost model
final_xgb_model <- xgboost(
  params = params,
  data = dtrain,
  nrounds = best_nrounds,
  verbose = 0
)

# Make predictions and evaluate the model
pred_xgb <- predict(final_xgb_model, dtest)

rmse_xgb <- sqrt(mean((pred_xgb - y_test)^2))
r2_xgb <- 1 - sum((pred_xgb - y_test)^2) / sum((y_test - mean(y_test))^2)
mean_absolute_error <- mean(abs(pred_xgb - y_test))

cat("Adjusted RMSE:", rmse_xgb, "\n")
cat("Adjusted R²:", r2_xgb, "\n")
cat("Adjusted Mean Absolute Error:", mean_absolute_error, "\n")


# Get feature importance
importance <- xgb.importance(model = final_xgb_model)

# Plot feature importance using ggplot2
ggplot(importance, aes(x = reorder(Feature, Gain), y = Gain)) +
  geom_col(fill = "#1D428A") + # NBA Blue
  coord_flip() +
  ggtitle("Feature Importance (XGBoost)") +
  xlab("Feature") +
  ylab("Gain") +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(size = 20, face = "bold", hjust = 0.5),
    axis.text = element_text(size = 18),
    axis.title = element_text(size = 18)
  )

# Visualize actual vs. predicted salaries
library(ggplot2)

# Convert salaries to millions for the plot
test_results <- data.frame(
  Actual = y_test / 1e6,
  Predicted = pred_xgb / 1e6
)

ggplot(test_results, aes(x = Actual, y = Predicted)) +
  geom_point(color = "#1D428A", alpha = 0.6) +
  geom_abline(slope = 1, intercept = 0, color = "red", linetype = "dashed") +
  labs(
    title = "Actual vs. Predicted Salaries (Test Set)",
    x = "Actual Salary (M$)",
    y = "Predicted Salary (M$)"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(size = 25, face = "bold", hjust = 0.5),
    axis.text = element_text(size = 18),
    axis.title = element_text(size = 18)
  )


# 3. Regularized Regression Models (excluded in the reports)

# Load necessary packages
library(glmnet)
library(Matrix)
library(caret)

# Convert categorical variables to factors
nba_data$SEASON <- as.numeric(substr(nba_data$SEASON, 1, 4)) + 1
nba_data$ALL_STAR <- as.factor(nba_data$ALL_STAR)

# Split data into training and test sets
set.seed(123)
train_index <- sample(1:nrow(nba_data), 0.8 * nrow(nba_data))
train_data <- nba_data[train_index, ]
test_data <- nba_data[-train_index, ]

# Encode variables (create dummy variables for factors)
X_train <- model.matrix(SALARY ~ . - 1, data = train_data[, -1])
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

# Make predictions
pred_ridge <- predict(ridge_model, s = ridge_best_lambda, newx = X_test)
pred_lasso <- predict(lasso_model, s = lasso_best_lambda, newx = X_test)

# Calculate evaluation metrics
rmse_ridge <- sqrt(mean((pred_ridge - y_test)^2))
r2_ridge <- 1 - sum((pred_ridge - y_test)^2) / sum((y_test - mean(y_test))^2)
mae_ridge <- mean(abs(pred_ridge - y_test))

rmse_lasso <- sqrt(mean((pred_lasso - y_test)^2))
r2_lasso <- 1 - sum((pred_lasso - y_test)^2) / sum((y_test - mean(y_test))^2)
mae_lasso <- mean(abs(pred_lasso - y_test))

# Display results
cat("----- RIDGE -----\n")
cat("RMSE:", rmse_ridge, "\nR²:", r2_ridge, "\nMAE:", mae_ridge, "\n\n")

cat("----- LASSO -----\n")
cat("RMSE:", rmse_lasso, "\nR²:", r2_lasso, "\nMAE:", mae_lasso, "\n")
