# scripts/32_export_web_scientific_assets.R
# ==============================================================================
# Phase 6B: Interactive Scientific Asset Exporter
# Project: UrbanAirQualityIndex-PollutantDriftAnalysis
# Baseline: v0.6-svm-freeze (FROZEN — READ ONLY)
#
# STRICT POLICY:
# Zero model fitting. Zero API calls. Zero bootstrapping.
# Reads frozen Level-1 artifacts and serializes compact JSON for website views.
# ==============================================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(jsonlite)
  library(digest)
})

cat("============================================================\n")
cat("Phase 6B: Exporting Scientific Web Assets\n")
cat("Baseline: v0.6-svm-freeze (FROZEN — READ ONLY)\n")
cat("============================================================\n\n")

out_dir <- "docs/web-data"
if (!dir.exists(out_dir)) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
}

manifest_records <- list()

# Helper to record manifest entry
record_manifest <- function(file_name, purpose, sources, src_rows, exp_rows, phase) {
  full_path <- file.path(out_dir, file_name)
  f_bytes <- file.size(full_path)
  f_hash <- digest::digest(file = full_path, algo = "sha256")
  list(
    file = file_name,
    relative_path = file.path("docs/web-data", file_name),
    purpose = purpose,
    source_artifacts = as.list(sources),
    source_rows = src_rows,
    exported_rows = exp_rows,
    file_bytes = f_bytes,
    sha256 = f_hash,
    schema_version = "1.0.0",
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    scientific_phase = phase
  )
}

# ------------------------------------------------------------------------------
# 1. Daily Observations Export (Explore Data)
# ------------------------------------------------------------------------------
cat("--- 1. Exporting Daily Observations ---\n")
daily_src_path <- "data/processed/UAQI_Master_Daily.csv"

daily_raw <- read_csv(daily_src_path, show_col_types = FALSE)
cat("Loaded raw daily rows:", nrow(daily_raw), "cols:", ncol(daily_raw), "\n")

# Validate daily contracts:
# 21 unique stations, 570 dates, date range 2025-03-01 to 2026-09-21, 11970 rows, no dups
stopifnot(nrow(daily_raw) == 11970)
stopifnot(n_distinct(daily_raw$project_station_id) == 21)
stopifnot(n_distinct(daily_raw$date) == 570)
stopifnot(min(daily_raw$date) == as.Date("2025-03-01"))
stopifnot(max(daily_raw$date) == as.Date("2026-09-21"))
dup_check <- daily_raw %>% count(project_station_id, date) %>% filter(n > 1)
stopifnot(nrow(dup_check) == 0)

# Select ONLY approved fields for Explore Data
daily_export <- daily_raw %>%
  select(
    project_station_id,
    date,
    aqi_verified,
    aqi_category,
    dominant_pollutant,
    pm2_5_aqi_input,
    pm10_aqi_input,
    o3_8h_max,
    temperature,
    humidity,
    wind_speed
  ) %>%
  mutate(
    date = as.character(date),
    # Round numerical metrics for compact JSON
    aqi_verified = ifelse(is.na(aqi_verified), NA_real_, round(aqi_verified, 1)),
    pm2_5_aqi_input = ifelse(is.na(pm2_5_aqi_input), NA_real_, round(pm2_5_aqi_input, 2)),
    pm10_aqi_input = ifelse(is.na(pm10_aqi_input), NA_real_, round(pm10_aqi_input, 2)),
    o3_8h_max = ifelse(is.na(o3_8h_max), NA_real_, round(o3_8h_max, 2)),
    temperature = ifelse(is.na(temperature), NA_real_, round(temperature, 2)),
    humidity = ifelse(is.na(humidity), NA_real_, round(humidity, 2)),
    wind_speed = ifelse(is.na(wind_speed), NA_real_, round(wind_speed, 2))
  )

daily_json_file <- file.path(out_dir, "daily_observations.json")
write_json(daily_export, daily_json_file, na = "null", auto_unbox = TRUE, pretty = FALSE)
cat("Wrote:", daily_json_file, "(", sprintf("%.2f MB", file.size(daily_json_file) / (1024 * 1024)), ")\n")

manifest_records[[length(manifest_records) + 1]] <- record_manifest(
  "daily_observations.json",
  "Daily station observations for Explore Data time-series and summary cards",
  daily_src_path,
  nrow(daily_raw),
  nrow(daily_export),
  "Phase 2E"
)

# ------------------------------------------------------------------------------
# 2. Drift Summary Export (Statistical Analysis)
# ------------------------------------------------------------------------------
cat("\n--- 2. Exporting Drift Summary ---\n")
drift_src_path <- "data/analysis/phase3B/phase3B_current_drift_snapshot.csv"
stations_meta_path <- "config/selected_stations.csv"

drift_raw <- read_csv(drift_src_path, show_col_types = FALSE)
stations_meta <- read_csv(stations_meta_path, show_col_types = FALSE)

stopifnot(nrow(drift_raw) == 147)

# Scope mapping:
# PROJ_007 has use_hyderabad == TRUE and use_india == TRUE (Both Panels)
# Others are either Hyderabad or India Representative Panel
drift_export <- drift_raw %>%
  left_join(stations_meta %>% select(project_station_id, use_hyderabad, use_india), by = "project_station_id") %>%
  mutate(
    scope = case_when(
      use_hyderabad & use_india ~ "Both Panels",
      use_hyderabad ~ "Hyderabad",
      use_india ~ "India Representative Panel",
      TRUE ~ "National"
    ),
    as_of_date = as.character(date),
    drift_magnitude = as.character(drift_magnitude_class),
    eligible = as.logical(drift_eligible),
    ineligibility_reason = ifelse(is.na(drift_ineligibility_reason), "eligible", drift_ineligibility_reason),
    recent_mean = round(recent_mean, 3),
    baseline_mean = round(baseline_mean, 3),
    drift_z = ifelse(is.na(drift_z), NA_real_, round(drift_z, 3))
  ) %>%
  select(
    scope,
    use_hyderabad,
    use_india,
    project_station_id,
    station_name,
    variable,
    as_of_date,
    recent_mean,
    baseline_mean,
    recent_n = recent_valid_days,
    baseline_n = baseline_valid_days,
    drift_z,
    drift_magnitude,
    drift_direction,
    eligible,
    ineligibility_reason
  )

drift_json_file <- file.path(out_dir, "drift_summary.json")
write_json(drift_export, drift_json_file, na = "null", auto_unbox = TRUE, pretty = TRUE)
cat("Wrote:", drift_json_file, "(", nrow(drift_export), "rows )\n")

manifest_records[[length(manifest_records) + 1]] <- record_manifest(
  "drift_summary.json",
  "Latest frozen station-variable standardized pollutant drift metrics (Dz)",
  c(drift_src_path, stations_meta_path),
  nrow(drift_raw),
  nrow(drift_export),
  "Phase 3B"
)

# ------------------------------------------------------------------------------
# 3. Inference Summary Export (Statistical Analysis)
# ------------------------------------------------------------------------------
cat("\n--- 3. Exporting Statistical Inference Summary ---\n")
inf_src_path <- "data/analysis/phase3C/phase3C_current_drift_inference_results.csv"
inf_raw <- read_csv(inf_src_path, show_col_types = FALSE)

stopifnot(nrow(inf_raw) == 147)
stopifnot(sum(inf_raw$test_eligible) == 131)
stopifnot(sum(!inf_raw$test_eligible) == 16)
stopifnot(sum(inf_raw$statistical_support == "SUPPORTED_UPWARD_SHIFT") == 15)
stopifnot(sum(inf_raw$statistical_support == "SUPPORTED_DOWNWARD_SHIFT") == 20)
stopifnot(sum(inf_raw$statistical_support == "NOT_STATISTICALLY_SUPPORTED") == 96)
stopifnot(sum(inf_raw$statistical_support == "NOT_TESTED_INSUFFICIENT_DATA") == 16)

inf_export <- inf_raw %>%
  left_join(stations_meta %>% select(project_station_id, use_hyderabad, use_india), by = "project_station_id") %>%
  mutate(
    scope = case_when(
      use_hyderabad & use_india ~ "Both Panels",
      use_hyderabad ~ "Hyderabad",
      use_india ~ "India Representative Panel",
      TRUE ~ "National"
    ),
    tested = as.logical(test_performed),
    support_direction = case_when(
      statistical_support == "SUPPORTED_UPWARD_SHIFT" ~ "Supported Increase",
      statistical_support == "SUPPORTED_DOWNWARD_SHIFT" ~ "Supported Decrease",
      statistical_support == "NOT_STATISTICALLY_SUPPORTED" ~ "Unsupported",
      statistical_support == "NOT_TESTED_INSUFFICIENT_DATA" ~ "Not Tested",
      TRUE ~ statistical_support
    ),
    bh_q_value = ifelse(is.na(p_block7_bh_global), NA_real_, round(p_block7_bh_global, 5)),
    ci_lower = ifelse(is.na(block7_ci_low), NA_real_, round(block7_ci_low, 3)),
    ci_upper = ifelse(is.na(block7_ci_high), NA_real_, round(block7_ci_high, 3)),
    hedges_g = ifelse(is.na(hedges_g), NA_real_, round(hedges_g, 3)),
    cliffs_delta = ifelse(is.na(cliffs_delta), NA_real_, round(cliffs_delta, 3)),
    drift_z = ifelse(is.na(drift_z), NA_real_, round(drift_z, 3)),
    mean_difference = ifelse(is.na(mean_difference), NA_real_, round(mean_difference, 3)),
    robustness_agreement = ifelse(is.na(robustness_agreement), "Not Applicable", robustness_agreement),
    ineligibility_reason = ifelse(test_eligible, "eligible", "Insufficient valid baseline or recent window observations")
  ) %>%
  select(
    scope,
    use_hyderabad,
    use_india,
    project_station_id,
    station_name,
    variable,
    tested,
    eligible = test_eligible,
    support_direction,
    statistical_support,
    bh_q_value,
    ci_lower,
    ci_upper,
    hedges_g,
    cliffs_delta,
    drift_z,
    mean_difference,
    robustness_agreement,
    ineligibility_reason
  )

inf_json_file <- file.path(out_dir, "inference_summary.json")
write_json(inf_export, inf_json_file, na = "null", auto_unbox = TRUE, pretty = TRUE)
cat("Wrote:", inf_json_file, "(", nrow(inf_export), "rows )\n")

manifest_records[[length(manifest_records) + 1]] <- record_manifest(
  "inference_summary.json",
  "Statistical inference results: moving-block bootstrap (B=2000, l=7), BH-FDR, and effect sizes",
  c(inf_src_path, stations_meta_path),
  nrow(inf_raw),
  nrow(inf_export),
  "Phase 3C"
)

# ------------------------------------------------------------------------------
# 4. Regression Metrics Export (Machine Learning)
# ------------------------------------------------------------------------------
cat("\n--- 4. Exporting Regression Metrics ---\n")
p4b_test_src <- "analysis/phase4B/tables/phase4B_test_metrics.csv"
p4b_holdout_src <- "analysis/phase4B/tables/phase4B_holdout_metrics.csv"

p4b_test_raw <- read_csv(p4b_test_src, show_col_types = FALSE) %>% mutate(evaluation_period = "TEST")
p4b_holdout_raw <- read_csv(p4b_holdout_src, show_col_types = FALSE) %>% mutate(evaluation_period = "Recent Holdout")

# Normalize scope names: HYDERABAD -> Hyderabad, INDIA -> India
p4b_combined <- bind_rows(p4b_test_raw, p4b_holdout_raw) %>%
  mutate(
    scope = case_when(
      toupper(scope) == "HYDERABAD" ~ "Hyderabad",
      toupper(scope) == "INDIA" ~ "India",
      TRUE ~ scope
    ),
    model = case_when(
      toupper(model_name) %in% c("MODEL_B", "MODEL B") ~ "Selected MLR Model B",
      toupper(model_name) == "PERSISTENCE" ~ "Persistence",
      TRUE ~ model_name
    )
  ) %>%
  filter(model %in% c("Selected MLR Model B", "Persistence")) %>%
  select(
    scope,
    evaluation_period,
    model,
    MAE,
    RMSE,
    bias,
    median_absolute_error,
    R2
  ) %>%
  mutate(across(where(is.numeric), ~ round(.x, 4)))

# Sanity check values
hyd_test_b <- p4b_combined %>% filter(scope == "Hyderabad", evaluation_period == "TEST", model == "Selected MLR Model B")
hyd_test_p <- p4b_combined %>% filter(scope == "Hyderabad", evaluation_period == "TEST", model == "Persistence")
ind_test_b <- p4b_combined %>% filter(scope == "India", evaluation_period == "TEST", model == "Selected MLR Model B")
ind_test_p <- p4b_combined %>% filter(scope == "India", evaluation_period == "TEST", model == "Persistence")

stopifnot(abs(hyd_test_b$MAE - 10.0765) < 0.01)
stopifnot(abs(hyd_test_p$MAE - 7.8931) < 0.01)
stopifnot(abs(ind_test_b$MAE - 16.0380) < 0.01)
stopifnot(abs(ind_test_p$MAE - 15.9150) < 0.01)

reg_json_file <- file.path(out_dir, "regression_metrics.json")
write_json(p4b_combined, reg_json_file, na = "null", auto_unbox = TRUE, pretty = TRUE)
cat("Wrote:", reg_json_file, "(", nrow(p4b_combined), "rows )\n")

manifest_records[[length(manifest_records) + 1]] <- record_manifest(
  "regression_metrics.json",
  "Supervised regression evaluation metrics comparing Selected MLR Model B and Persistence benchmark",
  c(p4b_test_src, p4b_holdout_src),
  nrow(p4b_test_raw) + nrow(p4b_holdout_raw),
  nrow(p4b_combined),
  "Phase 4B"
)

# ------------------------------------------------------------------------------
# 5. Classification Metrics Export (Machine Learning)
# ------------------------------------------------------------------------------
cat("\n--- 5. Exporting Classification Metrics ---\n")
p4c_test_src <- "analysis/phase4C/tables/phase4C_test_metrics.csv"
p4c_holdout_src <- "analysis/phase4C/tables/phase4C_holdout_metrics.csv"
p5b_test_src <- "analysis/phase5B/tables/phase5B_test_metrics.csv"
p5b_holdout_src <- "analysis/phase5B/tables/phase5B_holdout_metrics.csv"

p4c_test_raw <- read_csv(p4c_test_src, show_col_types = FALSE) %>% mutate(evaluation_period = "TEST")
p4c_holdout_raw <- read_csv(p4c_holdout_src, show_col_types = FALSE) %>% mutate(evaluation_period = "Recent Holdout")
p5b_test_raw <- read_csv(p5b_test_src, show_col_types = FALSE) %>% mutate(evaluation_period = "TEST")
p5b_holdout_raw <- read_csv(p5b_holdout_src, show_col_types = FALSE) %>% mutate(evaluation_period = "Recent Holdout")

# Process Logistic & Persistence from Phase 4C
cls_p4c <- bind_rows(p4c_test_raw, p4c_holdout_raw) %>%
  mutate(
    scope = case_when(
      toupper(scope) == "HYDERABAD" ~ "Hyderabad",
      toupper(scope) == "INDIA" ~ "India",
      TRUE ~ scope
    ),
    model = case_when(
      model_name == "MODEL_B" ~ "Logistic Model B",
      model_name == "PERSISTENCE" ~ "Persistence",
      TRUE ~ model_name
    ),
    model_type = ifelse(model == "Logistic Model B", "probability_model", "benchmark")
  ) %>%
  filter(model %in% c("Logistic Model B", "Persistence")) %>%
  select(
    scope,
    evaluation_period,
    model,
    model_type,
    positive_n,
    PR_AUC,
    ROC_AUC,
    avg_prec,
    F1,
    sensitivity,
    specificity,
    precision,
    NPV,
    balanced_accuracy,
    accuracy,
    TP,
    TN,
    FP,
    FN,
    Brier_Score = Brier
  )

# Process SVM from Phase 5B
cls_p5b <- bind_rows(p5b_test_raw, p5b_holdout_raw) %>%
  mutate(
    scope = case_when(
      toupper(scope) == "HYDERABAD" ~ "Hyderabad",
      toupper(scope) == "INDIA" ~ "India",
      TRUE ~ scope
    ),
    model = "RBF SVM",
    model_type = "decision_margin_classifier",
    # CRITICAL: Brier score is strictly undefined/forbidden for uncalibrated decision scores
    Brier_Score = NA_real_
  ) %>%
  select(
    scope,
    evaluation_period,
    model,
    model_type,
    positive_n,
    PR_AUC,
    ROC_AUC,
    avg_prec = average_precision,
    F1,
    sensitivity,
    specificity,
    precision,
    NPV,
    balanced_accuracy,
    accuracy,
    TP,
    TN,
    FP,
    FN,
    Brier_Score
  )

cls_combined <- bind_rows(cls_p4c, cls_p5b) %>%
  arrange(scope, evaluation_period, model) %>%
  mutate(
    across(c(PR_AUC, ROC_AUC, avg_prec, F1, sensitivity, specificity, precision, NPV, balanced_accuracy, accuracy, Brier_Score),
           ~ ifelse(is.na(.x), NA_real_, round(.x, 4)))
  )

# Verify Sanity Values from Section 29
ind_test_svm <- cls_combined %>% filter(scope == "India", evaluation_period == "TEST", model == "RBF SVM")
ind_test_log <- cls_combined %>% filter(scope == "India", evaluation_period == "TEST", model == "Logistic Model B")
ind_test_per <- cls_combined %>% filter(scope == "India", evaluation_period == "TEST", model == "Persistence")

stopifnot(abs(ind_test_svm$PR_AUC - 0.833544) < 0.01)
stopifnot(abs(ind_test_svm$ROC_AUC - 0.934548) < 0.01)
stopifnot(abs(ind_test_svm$F1 - 0.721805) < 0.01)
stopifnot(is.na(ind_test_svm$Brier_Score)) # Strict prohibition check

stopifnot(abs(ind_test_log$PR_AUC - 0.825478) < 0.01)
stopifnot(abs(ind_test_log$ROC_AUC - 0.931715) < 0.01)
stopifnot(abs(ind_test_log$F1 - 0.579439) < 0.01)

stopifnot(abs(ind_test_per$PR_AUC - 0.655524) < 0.01)
stopifnot(abs(ind_test_per$ROC_AUC - 0.826959) < 0.01)
stopifnot(abs(ind_test_per$F1 - 0.726655) < 0.01)

# Hyderabad Holdout single-class check (positive_n == 0)
hyd_holdout <- cls_combined %>% filter(scope == "Hyderabad", evaluation_period == "Recent Holdout")
stopifnot(all(hyd_holdout$positive_n == 0))
stopifnot(all(is.na(hyd_holdout$ROC_AUC)))
stopifnot(all(is.na(hyd_holdout$PR_AUC)))
stopifnot(all(is.na(hyd_holdout$F1)))

cls_json_file <- file.path(out_dir, "classification_metrics.json")
write_json(cls_combined, cls_json_file, na = "null", auto_unbox = TRUE, pretty = TRUE)
cat("Wrote:", cls_json_file, "(", nrow(cls_combined), "rows )\n")

manifest_records[[length(manifest_records) + 1]] <- record_manifest(
  "classification_metrics.json",
  "Adverse event classification metrics comparing Logistic Model B, RBF SVM, and Persistence benchmark",
  c(p4c_test_src, p4c_holdout_src, p5b_test_src, p5b_holdout_src),
  nrow(p4c_test_raw) + nrow(p4c_holdout_raw) + nrow(p5b_test_raw) + nrow(p5b_holdout_raw),
  nrow(cls_combined),
  "Phase 4C / 5B"
)

# ------------------------------------------------------------------------------
# 6. PCA Variance Export (Machine Learning)
# ------------------------------------------------------------------------------
cat("\n--- 6. Exporting PCA Variance ---\n")
pca_var_src <- "analysis/phase5A/tables/phase5A_pca_variance_explained.csv"
pca_sel_src <- "analysis/phase5A/tables/phase5A_pca_selection.csv"

pca_var_raw <- read_csv(pca_var_src, show_col_types = FALSE)

pca_var_export <- pca_var_raw %>%
  mutate(
    scope = case_when(
      toupper(scope) == "HYDERABAD" ~ "Hyderabad",
      toupper(scope) == "INDIA" ~ "India",
      TRUE ~ scope
    ),
    eigenvalue = round(eigenvalue, 4),
    variance_explained = round(variance_explained, 4),
    cumulative_variance = round(cumulative_variance, 4)
  )

# Verify Section 33 cumulative variance
hyd_pc4 <- pca_var_export %>% filter(scope == "Hyderabad", PC == "PC4")
ind_pc4 <- pca_var_export %>% filter(scope == "India", PC == "PC4")
stopifnot(abs(hyd_pc4$cumulative_variance - 0.9021) < 0.005)
stopifnot(abs(ind_pc4$cumulative_variance - 0.8865) < 0.005)

pca_var_json_file <- file.path(out_dir, "pca_variance.json")
write_json(pca_var_export, pca_var_json_file, na = "null", auto_unbox = TRUE, pretty = TRUE)
cat("Wrote:", pca_var_json_file, "(", nrow(pca_var_export), "rows )\n")

manifest_records[[length(manifest_records) + 1]] <- record_manifest(
  "pca_variance.json",
  "PCA eigenvalues, variance explained, and cumulative variance for 6 standardized sensor components",
  pca_var_src,
  nrow(pca_var_raw),
  nrow(pca_var_export),
  "Phase 5A"
)

# ------------------------------------------------------------------------------
# 7. Cluster Profiles Export (Machine Learning)
# ------------------------------------------------------------------------------
cat("\n--- 7. Exporting Cluster Profiles ---\n")
k_lbl_src <- "analysis/phase5A/tables/phase5A_cluster_labels.csv"
k_prf_src <- "analysis/phase5A/tables/phase5A_cluster_profiles.csv"
k_cnt_src <- "analysis/phase5A/tables/phase5A_cluster_centroids_pca.csv"

k_lbl_raw <- read_csv(k_lbl_src, show_col_types = FALSE)
k_prf_raw <- read_csv(k_prf_src, show_col_types = FALSE)
k_cnt_raw <- read_csv(k_cnt_src, show_col_types = FALSE)

# Verify Section 34 labels
hyd_labels <- k_lbl_raw %>% filter(toupper(scope) == "HYDERABAD") %>% pull(descriptive_label)
ind_labels <- k_lbl_raw %>% filter(toupper(scope) == "INDIA") %>% pull(descriptive_label)

stopifnot(all(c("warm-dry-moderate-pollution", "humid-windy-lower-pollution", "cool-low-wind-particulate-elevated") %in% hyd_labels))
stopifnot(all(c("cool-low-wind-particulate-elevated", "hot-dry-ozone-pm10-elevated", "humid-windy-lower-pollution") %in% ind_labels))

cluster_export <- list(
  labels = k_lbl_raw %>%
    mutate(
      scope = case_when(
        toupper(scope) == "HYDERABAD" ~ "Hyderabad",
        toupper(scope) == "INDIA" ~ "India",
        TRUE ~ scope
      )
    ),
  centroids = k_cnt_raw %>%
    mutate(
      scope = case_when(
        toupper(scope) == "HYDERABAD" ~ "Hyderabad",
        toupper(scope) == "INDIA" ~ "India",
        TRUE ~ scope
      ),
      across(starts_with("PC"), ~ round(.x, 3))
    ),
  feature_profiles = k_prf_raw %>%
    mutate(
      scope = case_when(
        toupper(scope) == "HYDERABAD" ~ "Hyderabad",
        toupper(scope) == "INDIA" ~ "India",
        TRUE ~ scope
      ),
      across(where(is.numeric), ~ round(.x, 3))
    )
)

cluster_json_file <- file.path(out_dir, "cluster_profiles.json")
write_json(cluster_export, cluster_json_file, na = "null", auto_unbox = TRUE, pretty = TRUE)
cat("Wrote:", cluster_json_file, "\n")

manifest_records[[length(manifest_records) + 1]] <- record_manifest(
  "cluster_profiles.json",
  "K-Means (k=3) descriptive cluster regime labels, centroids, and sensor feature profiles",
  c(k_lbl_src, k_prf_src, k_cnt_src),
  nrow(k_lbl_raw) + nrow(k_prf_raw) + nrow(k_cnt_raw),
  nrow(k_lbl_raw),
  "Phase 5A"
)

# ------------------------------------------------------------------------------
# 8. PCA Scores Export (Machine Learning / Regimes Scatter)
# ------------------------------------------------------------------------------
cat("\n--- 8. Exporting PCA Scores ---\n")
hyd_hist_src <- "data/analysis/phase5A/Hyderabad_PCA_History.csv"
hyd_rec_src <- "data/analysis/phase5A/Hyderabad_Recent_Cluster_Assignments.csv"
ind_hist_src <- "data/analysis/phase5A/India_PCA_History.csv"
ind_rec_src <- "data/analysis/phase5A/India_Recent_Cluster_Assignments.csv"

# Label lookup map
lbl_map <- k_lbl_raw %>%
  mutate(
    scope_clean = case_when(
      toupper(scope) == "HYDERABAD" ~ "Hyderabad",
      toupper(scope) == "INDIA" ~ "India",
      TRUE ~ scope
    )
  )

hyd_hist_df <- read_csv(hyd_hist_src, show_col_types = FALSE) %>%
  mutate(scope = "Hyderabad", period = "history", cluster = as.character(initial_cluster)) %>%
  select(scope, date, project_station_id, PC1, PC2, cluster, period)

hyd_rec_df <- read_csv(hyd_rec_src, show_col_types = FALSE) %>%
  mutate(scope = "Hyderabad", period = "recent", cluster = as.character(assigned_cluster)) %>%
  select(scope, date, project_station_id, PC1, PC2, cluster, period)

ind_hist_df <- read_csv(ind_hist_src, show_col_types = FALSE) %>%
  mutate(scope = "India", period = "history", cluster = as.character(initial_cluster)) %>%
  select(scope, date, project_station_id, PC1, PC2, cluster, period)

ind_rec_df <- read_csv(ind_rec_src, show_col_types = FALSE) %>%
  mutate(scope = "India", period = "recent", cluster = as.character(assigned_cluster)) %>%
  select(scope, date, project_station_id, PC1, PC2, cluster, period)

pca_scores_combined <- bind_rows(hyd_hist_df, hyd_rec_df, ind_hist_df, ind_rec_df) %>%
  mutate(
    date = as.character(date),
    PC1 = round(PC1, 3),
    PC2 = round(PC2, 3),
    # Map cluster id to descriptive label
    cluster_num = as.integer(gsub("\\D", "", cluster)),
    cluster_label = case_when(
      scope == "Hyderabad" & cluster_num == 1 ~ "warm-dry-moderate-pollution",
      scope == "Hyderabad" & cluster_num == 2 ~ "humid-windy-lower-pollution",
      scope == "Hyderabad" & cluster_num == 3 ~ "cool-low-wind-particulate-elevated",
      scope == "India" & cluster_num == 1 ~ "cool-low-wind-particulate-elevated",
      scope == "India" & cluster_num == 2 ~ "hot-dry-ozone-pm10-elevated",
      scope == "India" & cluster_num == 3 ~ "humid-windy-lower-pollution",
      TRUE ~ paste("Cluster", cluster)
    )
  )

pca_scores_json_file <- file.path(out_dir, "pca_scores.json")
write_json(pca_scores_combined, pca_scores_json_file, na = "null", auto_unbox = TRUE, pretty = FALSE)
cat("Wrote:", pca_scores_json_file, "(", nrow(pca_scores_combined), "rows,", sprintf("%.2f MB", file.size(pca_scores_json_file) / (1024 * 1024)), ")\n")

manifest_records[[length(manifest_records) + 1]] <- record_manifest(
  "pca_scores.json",
  "PC1 and PC2 coordinates with K=3 cluster assignments for history and recent evaluation periods",
  c(hyd_hist_src, hyd_rec_src, ind_hist_src, ind_rec_src),
  nrow(hyd_hist_df) + nrow(hyd_rec_df) + nrow(ind_hist_df) + nrow(ind_rec_df),
  nrow(pca_scores_combined),
  "Phase 5A"
)

# ------------------------------------------------------------------------------
# 9. Scientific Web Manifest
# ------------------------------------------------------------------------------
cat("\n--- 9. Writing Scientific Manifest ---\n")
manifest_json_file <- file.path(out_dir, "scientific_manifest.json")
write_json(manifest_records, manifest_json_file, na = "null", auto_unbox = TRUE, pretty = TRUE)
cat("Wrote:", manifest_json_file, "(", length(manifest_records), "records )\n")

cat("\n============================================================\n")
cat("SUCCESS: All Phase 6B Scientific Web Assets Exported Cleanly!\n")
cat("============================================================\n")
