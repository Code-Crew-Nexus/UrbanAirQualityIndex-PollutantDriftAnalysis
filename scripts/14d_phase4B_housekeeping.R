library(dplyr)
library(readr)
library(broom)

# Load data and models
hyd_data <- read_csv("data/modeling/phase4A/Hyderabad_Common_Comparison.csv", show_col_types = FALSE)
ind_data <- read_csv("data/modeling/phase4A/India_Common_Comparison.csv", show_col_types = FALSE)

hyd_mod_tv <- readRDS("models/phase4B/hyderabad_selected_train_validation.rds")
ind_mod_tv <- readRDS("models/phase4B/india_selected_train_validation.rds")

# 1. Out-of-range audit
val_preds <- read_csv("analysis/phase4B/tables/phase4B_validation_predictions.csv", show_col_types = FALSE)
test_preds <- read_csv("analysis/phase4B/tables/phase4B_test_predictions.csv", show_col_types = FALSE)
hold_preds <- read_csv("analysis/phase4B/tables/phase4B_holdout_predictions.csv", show_col_types = FALSE)

audit_preds <- bind_rows(val_preds, test_preds, hold_preds) %>%
  filter(!model_name %in% c("PERSISTENCE", "TRAINING_STATION_MEAN"))

audit_summary <- audit_preds %>%
  group_by(scope, split, model_name) %>%
  summarize(
    n = n(),
    pred_below_0 = sum(prediction < 0, na.rm = TRUE),
    pred_above_500 = sum(prediction > 500, na.rm = TRUE),
    prediction_min = min(prediction, na.rm = TRUE),
    prediction_max = max(prediction, na.rm = TRUE),
    .groups = "drop"
  )
write_csv(audit_summary, "analysis/phase4B/tables/phase4B_prediction_range_audit.csv")

# 2. Heteroscedasticity Summary
calc_hetero <- function(mod, scope) {
  df <- data.frame(fit = fitted(mod), res = residuals(mod))
  df$quartile <- ntile(df$fit, 4)
  df %>% group_by(quartile) %>%
    summarize(
      scope = scope,
      n = n(),
      fitted_min = min(fit),
      fitted_max = max(fit),
      residual_variance = var(res),
      residual_sd = sd(res),
      MAE = mean(abs(res)),
      .groups = "drop"
    )
}
het_hyd <- calc_hetero(hyd_mod_tv, "HYDERABAD")
het_ind <- calc_hetero(ind_mod_tv, "INDIA")
write_csv(bind_rows(het_hyd, het_ind), "analysis/phase4B/tables/phase4B_residual_variance_by_fitted_quartile.csv")

# 3. Condition Number
calc_cond <- function(mod, scope) {
  X <- model.matrix(mod)
  kappa_val <- kappa(X, exact = TRUE)
  data.frame(scope = scope, condition_number = kappa_val)
}
cond_hyd <- calc_cond(hyd_mod_tv, "HYDERABAD")
cond_ind <- calc_cond(ind_mod_tv, "INDIA")
write_csv(bind_rows(cond_hyd, cond_ind), "analysis/phase4B/tables/phase4B_condition_number.csv")

# 4. Training Model Summary
hyd_train_A <- readRDS("models/phase4B/hyderabad_model_A_train.rds")
hyd_train_B <- readRDS("models/phase4B/hyderabad_model_B_train.rds")
ind_train_A <- readRDS("models/phase4B/india_model_A_train.rds")
ind_train_B <- readRDS("models/phase4B/india_model_B_train.rds")

extract_summary <- function(mod, scope, model_name) {
  gl <- glance(mod)
  data.frame(
    scope = scope,
    model = model_name,
    n = nobs(mod),
    number_parameters = length(coef(mod)),
    R2 = gl$r.squared,
    adjusted_R2 = gl$adj.r.squared,
    residual_standard_error = gl$sigma,
    AIC = gl$AIC,
    BIC = gl$BIC
  )
}

summs <- bind_rows(
  extract_summary(hyd_train_A, "HYDERABAD", "MODEL_A"),
  extract_summary(hyd_train_B, "HYDERABAD", "MODEL_B"),
  extract_summary(ind_train_A, "INDIA", "MODEL_A"),
  extract_summary(ind_train_B, "INDIA", "MODEL_B")
)
write_csv(summs, "analysis/phase4B/tables/phase4B_training_model_summary.csv")
cat("Phase 4B Housekeeping completed.\n")
