library(dplyr)
library(readr)
library(yaml)
library(broom)

# 1. Load configuration and data
spec <- read_yaml("config/modeling_specification.yml")
hyd_data <- read_csv("data/modeling/phase4A/Hyderabad_Common_Comparison.csv", show_col_types = FALSE)
ind_data <- read_csv("data/modeling/phase4A/India_Common_Comparison.csv", show_col_types = FALSE)

# Define formulas
form_A <- as.formula(spec$model_A$explicit_formula)
form_B <- as.formula(spec$model_B$explicit_formula)

# Factor levels processing function
prepare_factors <- function(df, scope) {
  df <- df %>% mutate(day_of_week = factor(day_of_week, levels = c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")))
  
  # Station reference
  if (scope == "HYDERABAD") {
    df$project_station_id <- relevel(factor(df$project_station_id), ref = "PROJ_007")
  } else {
    df$project_station_id <- relevel(factor(df$project_station_id), ref = "PROJ_002")
  }
  return(df)
}

hyd_data <- prepare_factors(hyd_data, "HYDERABAD")
ind_data <- prepare_factors(ind_data, "INDIA")

# Splits
hyd_train <- hyd_data %>% filter(split == "TRAIN")
hyd_val <- hyd_data %>% filter(split == "VALIDATION")
ind_train <- ind_data %>% filter(split == "TRAIN")
ind_val <- ind_data %>% filter(split == "VALIDATION")

cat("Hyderabad Train:", nrow(hyd_train), "Val:", nrow(hyd_val), "\n")
cat("India Train:", nrow(ind_train), "Val:", nrow(ind_val), "\n")

# Check sanity limits
stopifnot(nrow(hyd_train) == 1398, nrow(ind_train) == 3501)

# 2. Fit models on TRAIN
hyd_mod_A <- lm(form_A, data = hyd_train)
hyd_mod_B <- lm(form_B, data = hyd_train)
ind_mod_A <- lm(form_A, data = ind_train)
ind_mod_B <- lm(form_B, data = ind_train)

saveRDS(hyd_mod_A, "models/phase4B/hyderabad_model_A_train.rds")
saveRDS(hyd_mod_B, "models/phase4B/hyderabad_model_B_train.rds")
saveRDS(ind_mod_A, "models/phase4B/india_model_A_train.rds")
saveRDS(ind_mod_B, "models/phase4B/india_model_B_train.rds")

# 3. Export Coefficients
extract_coef <- function(mod, scope, model_name) {
  tidy(mod) %>%
    mutate(
      scope = scope, 
      model_name = model_name,
      confidence_interval_low = estimate - 1.96 * std.error,
      confidence_interval_high = estimate + 1.96 * std.error
    ) %>%
    rename(standard_error = std.error, t_value = statistic, classical_p_value = p.value)
}
coefs <- bind_rows(
  extract_coef(hyd_mod_A, "HYDERABAD", "MODEL_A"),
  extract_coef(hyd_mod_B, "HYDERABAD", "MODEL_B"),
  extract_coef(ind_mod_A, "INDIA", "MODEL_A"),
  extract_coef(ind_mod_B, "INDIA", "MODEL_B")
)
write_csv(coefs, "analysis/phase4B/tables/phase4B_training_coefficients.csv")

# 4. Training-station-mean benchmark
train_means <- bind_rows(
  hyd_train %>% group_by(project_station_id) %>% summarize(mean_target = mean(target_aqi_next_day), scope = "HYDERABAD", .groups = "drop"),
  ind_train %>% group_by(project_station_id) %>% summarize(mean_target = mean(target_aqi_next_day), scope = "INDIA", .groups = "drop")
)
# For overlapping stations, we can average or keep by scope. The instruction says calculate for each station using COMMON TRAIN rows ONLY.
write_csv(train_means, "analysis/phase4B/tables/phase4B_training_station_means.csv")

# 5. Validation predictions and Metrics
calc_metrics <- function(actual, pred) {
  mae <- mean(abs(pred - actual))
  rmse <- sqrt(mean((pred - actual)^2))
  bias <- mean(pred - actual)
  medae <- median(abs(pred - actual))
  r2 <- 1 - sum((actual - pred)^2) / sum((actual - mean(actual))^2)
  list(MAE = mae, RMSE = rmse, bias = bias, median_absolute_error = medae, R2 = r2)
}

process_validation <- function(train_df, val_df, mod_A, mod_B, scope, means_df) {
  pred_A <- predict(mod_A, val_df)
  pred_B <- predict(mod_B, val_df)
  pred_P <- val_df$aqi_verified
  
  station_means <- means_df %>% filter(scope == !!scope) %>% select(project_station_id, mean_target)
  val_df <- val_df %>% left_join(station_means, by="project_station_id")
  pred_M <- val_df$mean_target
  
  actual <- val_df$target_aqi_next_day
  
  metrics_A <- calc_metrics(actual, pred_A)
  metrics_B <- calc_metrics(actual, pred_B)
  metrics_P <- calc_metrics(actual, pred_P)
  metrics_M <- calc_metrics(actual, pred_M)
  
  # Selection
  selected_family <- if(metrics_B$MAE < (metrics_A$MAE - 1e-10)) "MODEL_B" else "MODEL_A"
  sel_mae <- if(selected_family == "MODEL_A") metrics_A$MAE else metrics_B$MAE
  
  # Selection artifact row
  sel_row <- data.frame(
    scope = scope,
    model_A_validation_MAE = metrics_A$MAE,
    model_A_validation_RMSE = metrics_A$RMSE,
    model_B_validation_MAE = metrics_B$MAE,
    model_B_validation_RMSE = metrics_B$RMSE,
    persistence_validation_MAE = metrics_P$MAE,
    station_mean_validation_MAE = metrics_M$MAE,
    selected_mlr_family = selected_family,
    selection_metric = "VALIDATION_MAE",
    selection_reason = if(selected_family == "MODEL_A") "Model A MAE <= Model B" else "Model B MAE < Model A",
    selected_beats_persistence_validation = sel_mae < metrics_P$MAE
  )
  
  # Long predictions
  preds <- bind_rows(
    val_df %>% select(project_station_id, station_name, date, target_date, split, actual_aqi = target_aqi_next_day) %>% mutate(scope = scope, model_name = "MODEL_A", prediction = pred_A, residual = prediction - actual_aqi),
    val_df %>% select(project_station_id, station_name, date, target_date, split, actual_aqi = target_aqi_next_day) %>% mutate(scope = scope, model_name = "MODEL_B", prediction = pred_B, residual = prediction - actual_aqi),
    val_df %>% select(project_station_id, station_name, date, target_date, split, actual_aqi = target_aqi_next_day) %>% mutate(scope = scope, model_name = "PERSISTENCE", prediction = pred_P, residual = prediction - actual_aqi),
    val_df %>% select(project_station_id, station_name, date, target_date, split, actual_aqi = target_aqi_next_day) %>% mutate(scope = scope, model_name = "TRAINING_STATION_MEAN", prediction = pred_M, residual = prediction - actual_aqi)
  )
  
  # Metrics table
  mets <- bind_rows(
    as.data.frame(metrics_A) %>% mutate(scope = scope, model_name = "MODEL_A"),
    as.data.frame(metrics_B) %>% mutate(scope = scope, model_name = "MODEL_B"),
    as.data.frame(metrics_P) %>% mutate(scope = scope, model_name = "PERSISTENCE"),
    as.data.frame(metrics_M) %>% mutate(scope = scope, model_name = "TRAINING_STATION_MEAN")
  )
  
  list(selection = sel_row, preds = preds, metrics = mets)
}

res_hyd <- process_validation(hyd_train, hyd_val, hyd_mod_A, hyd_mod_B, "HYDERABAD", train_means)
res_ind <- process_validation(ind_train, ind_val, ind_mod_A, ind_mod_B, "INDIA", train_means)

write_csv(bind_rows(res_hyd$selection, res_ind$selection), "data/modeling/phase4B/phase4B_model_selection.csv")
write_csv(bind_rows(res_hyd$preds, res_ind$preds), "analysis/phase4B/tables/phase4B_validation_predictions.csv")
write_csv(bind_rows(res_hyd$metrics, res_ind$metrics), "analysis/phase4B/tables/phase4B_validation_metrics.csv")

# 6. Output YAML
sel_yaml <- list(
  HYDERABAD = list(
    selected_family = res_hyd$selection$selected_mlr_family,
    selection_basis = "VALIDATION_MAE"
  ),
  INDIA = list(
    selected_family = res_ind$selection$selected_mlr_family,
    selection_basis = "VALIDATION_MAE"
  )
)
write_yaml(sel_yaml, "config/phase4B_selected_models.yml")

cat("Phase 4B validation and selection complete.\n")
