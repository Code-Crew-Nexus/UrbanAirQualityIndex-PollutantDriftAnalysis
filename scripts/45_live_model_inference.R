# ==============================================================================
# scripts/45_live_model_inference.R
# UrbanAirQualityIndex-PollutantDriftAnalysis
# Checkpoint G6: Deterministic Frozen-Model Inference on Live Extension
#
# POLICY:
# ZERO model retraining. ZERO parameter modification.
# Loads frozen Level-1 artifacts from v0.6-svm-freeze and scores incoming
# live observational records deterministically.
# ==============================================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(jsonlite)
})

cat("============================================================\n")
cat("Checkpoint G6: Deterministic Frozen-Model Live Inference\n")
cat("Scientific Baseline: v0.6-svm-freeze (FROZEN — READ ONLY)\n")
cat("============================================================\n\n")

live_obs_path <- "data/live/processed/live_daily_observations.csv"
if (!file.exists(live_obs_path)) {
  stop("Live processed observations missing: ", live_obs_path)
}

stations_path <- "config/selected_stations.csv"
stations <- read_csv(stations_path, show_col_types = FALSE)

live_df <- read_csv(live_obs_path, show_col_types = FALSE)
cat(sprintf("Loaded %d live daily observation records (%s to %s).\n",
            nrow(live_df), min(live_df$date), max(live_df$date)))

# Guarantee frozen boundary
stopifnot(all(live_df$date >= as.Date("2026-09-22")))

# ------------------------------------------------------------------------------
# 1. Feature Engineering (Strictly Matching Phase 4 Design Specification)
# ------------------------------------------------------------------------------
cat("Engineering predictor features matching Phase 4 design...\n")

inference_df <- live_df %>%
  arrange(project_station_id, date) %>%
  left_join(stations %>% select(project_station_id, station_name, city, state, use_hyderabad, use_india), by = "project_station_id") %>%
  mutate(
    target_date = date + 1,
    day_of_week = weekdays(date),
    sin_wind_direction = if ("wind_direction" %in% names(.)) sin(wind_direction * pi / 180) else NA_real_,
    cos_wind_direction = if ("wind_direction" %in% names(.)) cos(wind_direction * pi / 180) else NA_real_,
    month_number = as.numeric(format(date, "%m")),
    month_sin = sin(2 * pi * month_number / 12),
    month_cos = cos(2 * pi * month_number / 12)
  )

# Next-day actual AQI lookup within live dataset
next_day_lookup <- live_df %>%
  select(project_station_id, target_date = date, actual_aqi_next_day = aqi_verified, actual_category_next_day = aqi_category)

inference_df <- inference_df %>%
  left_join(next_day_lookup, by = c("project_station_id", "target_date")) %>%
  mutate(
    actual_adverse_next_day = ifelse(!is.na(actual_aqi_next_day), ifelse(actual_aqi_next_day > 100, 1, 0), NA_integer_)
  )

# ------------------------------------------------------------------------------
# 2. Load Frozen Models
# ------------------------------------------------------------------------------
cat("Loading frozen Level-1 model artifacts (v0.6-svm-freeze)...\n")

hyd_mlr_path <- "models/phase4B/hyderabad_final_history_model.rds"
ind_mlr_path <- "models/phase4B/india_final_history_model.rds"
hyd_log_path <- "models/phase4C/hyderabad_final_history_model.rds"
ind_log_path <- "models/phase4C/india_final_history_model.rds"

hyd_mlr <- readRDS(hyd_mlr_path)
ind_mlr <- readRDS(ind_mlr_path)
hyd_log <- readRDS(hyd_log_path)
ind_log <- readRDS(ind_log_path)

cat("[OK] Loaded MLR and Logistic final history models for Hyderabad and India.\n")

# ------------------------------------------------------------------------------
# 3. Factor Levels & Predictor Matrix Alignment
# ------------------------------------------------------------------------------
prepare_factors <- function(df, scope) {
  df <- df %>% mutate(day_of_week = factor(day_of_week, levels = c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")))
  if (scope == "HYDERABAD") {
    df$project_station_id <- relevel(factor(df$project_station_id), ref = "PROJ_007")
  } else {
    df$project_station_id <- relevel(factor(df$project_station_id), ref = "PROJ_002")
  }
  return(df)
}

# Eligibility check: all predictors in Model B must be present
is_eligible_model_b <- function(df) {
  !is.na(df$aqi_verified) &
    !is.na(df$pm2_5_aqi_input) &
    !is.na(df$pm10_aqi_input) &
    !is.na(df$o3_8h_max) &
    !is.na(df$temperature) &
    !is.na(df$humidity) &
    !is.na(df$wind_speed) &
    !is.na(df$sin_wind_direction) &
    !is.na(df$cos_wind_direction) &
    !is.na(df$day_of_week) &
    !is.na(df$month_sin) &
    !is.na(df$month_cos) &
    !is.na(df$project_station_id)
}

# ------------------------------------------------------------------------------
# 4. Deterministic Scoring
# ------------------------------------------------------------------------------
cat("Computing deterministic next-day forecasts...\n")

# Hyderabad Panel Scoring
hyd_records <- inference_df %>%
  filter(use_hyderabad == TRUE) %>%
  prepare_factors("HYDERABAD")

hyd_eligible_idx <- which(is_eligible_model_b(hyd_records))
cat(sprintf("Hyderabad: %d / %d records eligible for Model B scoring.\n",
            length(hyd_eligible_idx), nrow(hyd_records)))

hyd_preds_mlr <- rep(NA_real_, nrow(hyd_records))
hyd_preds_log <- rep(NA_real_, nrow(hyd_records))

if (length(hyd_eligible_idx) > 0) {
  hyd_sub <- hyd_records[hyd_eligible_idx, ]
  hyd_preds_mlr[hyd_eligible_idx] <- predict(hyd_mlr, newdata = hyd_sub)
  hyd_preds_log[hyd_eligible_idx] <- predict(hyd_log, newdata = hyd_sub, type = "response")
}

hyd_records$scope <- "Hyderabad"
hyd_records$predicted_aqi_next_day_mlr <- round(pmax(0, hyd_preds_mlr), 1)
hyd_records$predicted_adverse_prob_next_day <- round(hyd_preds_log, 4)
hyd_records$predicted_adverse_class_next_day <- ifelse(is.na(hyd_preds_log), NA_integer_, ifelse(hyd_preds_log >= 0.5, 1L, 0L))

# India Panel Scoring
ind_records <- inference_df %>%
  filter(use_india == TRUE) %>%
  prepare_factors("INDIA")

ind_eligible_idx <- which(is_eligible_model_b(ind_records))
cat(sprintf("India: %d / %d records eligible for Model B scoring.\n",
            length(ind_eligible_idx), nrow(ind_records)))

ind_preds_mlr <- rep(NA_real_, nrow(ind_records))
ind_preds_log <- rep(NA_real_, nrow(ind_records))

if (length(ind_eligible_idx) > 0) {
  ind_sub <- ind_records[ind_eligible_idx, ]
  ind_preds_mlr[ind_eligible_idx] <- predict(ind_mlr, newdata = ind_sub)
  ind_preds_log[ind_eligible_idx] <- predict(ind_log, newdata = ind_sub, type = "response")
}

ind_records$scope <- "India"
ind_records$predicted_aqi_next_day_mlr <- round(pmax(0, ind_preds_mlr), 1)
ind_records$predicted_adverse_prob_next_day <- round(ind_preds_log, 4)
ind_records$predicted_adverse_class_next_day <- ifelse(is.na(ind_preds_log), NA_integer_, ifelse(ind_preds_log >= 0.5, 1L, 0L))

# Combine and compute evaluation metrics where target has realized
all_predictions <- bind_rows(hyd_records, ind_records) %>%
  mutate(
    residual_mlr = ifelse(!is.na(predicted_aqi_next_day_mlr) & !is.na(actual_aqi_next_day),
                          round(predicted_aqi_next_day_mlr - actual_aqi_next_day, 1), NA_real_),
    persistence_baseline_aqi = aqi_verified,
    residual_persistence = ifelse(!is.na(persistence_baseline_aqi) & !is.na(actual_aqi_next_day),
                                  round(persistence_baseline_aqi - actual_aqi_next_day, 1), NA_real_)
  ) %>%
  select(
    scope,
    project_station_id,
    station_name,
    city,
    observation_date = date,
    target_date,
    observed_aqi_current = aqi_verified,
    predicted_aqi_next_day_mlr,
    predicted_adverse_prob_next_day,
    predicted_adverse_class_next_day,
    actual_aqi_next_day,
    residual_mlr,
    residual_persistence
  ) %>%
  mutate(
    observation_date = as.character(observation_date),
    target_date = as.character(target_date)
  )

# ------------------------------------------------------------------------------
# 5. Export Web JSON
# ------------------------------------------------------------------------------
out_json_path <- "docs/web-data/live_predictions.json"

export_payload <- list(
  metadata = list(
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    model_baseline = "v0.6-svm-freeze",
    inference_type = "DETERMINISTIC_FROZEN_INFERENCE",
    models_used = list(
      mlr = "Phase 4B Persistence-Aware MLR (Model B)",
      logistic = "Phase 4C Adverse Event Logistic Regression (Model B)"
    ),
    disclaimer = "Predictions generated deterministically using frozen v0.6 models. Models have NOT been retrained on live data.",
    total_scored_records = sum(!is.na(all_predictions$predicted_aqi_next_day_mlr)),
    observation_window = list(
      start = min(all_predictions$observation_date),
      end = max(all_predictions$observation_date)
    )
  ),
  predictions = all_predictions
)

write_json(export_payload, out_json_path, pretty = TRUE, auto_unbox = TRUE, na = "null")
cat(sprintf("[SUCCESS] Exported live predictions to %s (%.2f KB, %d records)\n",
            out_json_path, file.size(out_json_path) / 1024, nrow(all_predictions)))
