# tests/testthat/test_phase6b_website.R
# ==============================================================================
# Phase 6B: Interactive Scientific Integration Test Suite
# Project: UrbanAirQualityIndex-PollutantDriftAnalysis
# Baseline: v0.6-svm-freeze (FROZEN — READ ONLY)
# ==============================================================================

library(testthat)
library(jsonlite)
library(readr)
library(dplyr)

repo_root <- if (dir.exists(file.path("..", "..", "docs"))) file.path("..", "..") else "."

context("Phase 6B: Interactive Scientific Integration")

# ------------------------------------------------------------------------------
# EXPORT CONTRACT TESTS (1 - 8)
# ------------------------------------------------------------------------------

test_that("01: Scientific exporter script exists", {
  exp_path <- file.path(repo_root, "scripts", "32_export_web_scientific_assets.R")
  expect_true(file.exists(exp_path))
})

test_that("02: No model-fitting calls in scientific exporter", {
  exp_path <- file.path(repo_root, "scripts", "32_export_web_scientific_assets.R")
  txt <- readLines(exp_path, warn = FALSE)
  code_lines <- txt[!grepl("^\\s*#", txt)]
  
  # Strictly prohibit fitting functions
  expect_false(any(grepl("\\blm\\s*\\(", code_lines)))
  expect_false(any(grepl("\\bglm\\s*\\(", code_lines)))
  expect_false(any(grepl("\\bprcomp\\s*\\(", code_lines)))
  expect_false(any(grepl("\\bkmeans\\s*\\(", code_lines)))
  expect_false(any(grepl("\\bsvm\\s*\\(", code_lines)))
  expect_false(any(grepl("\\bboot\\s*\\(", code_lines)))
})

test_that("03: No API or network acquisition calls in scientific exporter", {
  exp_path <- file.path(repo_root, "scripts", "32_export_web_scientific_assets.R")
  txt <- readLines(exp_path, warn = FALSE)
  code_lines <- txt[!grepl("^\\s*#", txt)]
  
  expect_false(any(grepl("httr2|curl|download\\.file|request\\(", code_lines)))
})

test_that("04: All expected Phase-6B JSON files exist in docs/web-data/", {
  expected_files <- c(
    "daily_observations.json",
    "drift_summary.json",
    "inference_summary.json",
    "regression_metrics.json",
    "classification_metrics.json",
    "pca_variance.json",
    "cluster_profiles.json",
    "pca_scores.json",
    "scientific_manifest.json"
  )
  for (f in expected_files) {
    p <- file.path(repo_root, "docs", "web-data", f)
    expect_true(file.exists(p), info = paste("Missing JSON file:", f))
  }
})

test_that("05: All exported JSON files parse correctly without errors", {
  expected_files <- c(
    "daily_observations.json",
    "drift_summary.json",
    "inference_summary.json",
    "regression_metrics.json",
    "classification_metrics.json",
    "pca_variance.json",
    "cluster_profiles.json",
    "pca_scores.json",
    "scientific_manifest.json"
  )
  for (f in expected_files) {
    p <- file.path(repo_root, "docs", "web-data", f)
    parsed <- fromJSON(p)
    expect_true(length(parsed) > 0, info = paste("Empty JSON:", f))
  }
})

test_that("06: Scientific manifest parses and contains all 8 artifact records", {
  p <- file.path(repo_root, "docs", "web-data", "scientific_manifest.json")
  manifest <- fromJSON(p)
  expect_true(is.data.frame(manifest))
  expect_equal(nrow(manifest), 8)
  
  required_cols <- c("file", "purpose", "source_artifacts", "source_rows", "exported_rows", "file_bytes", "sha256", "scientific_phase")
  for (rc in required_cols) {
    expect_true(rc %in% names(manifest))
  }
})

test_that("07: Source artifact map exists", {
  map_path <- file.path(repo_root, "docs", "WEB_SCIENTIFIC_ARTIFACT_MAP.md")
  expect_true(file.exists(map_path))
})

test_that("08: Every source path cited in WEB_SCIENTIFIC_ARTIFACT_MAP.md exists on filesystem", {
  map_path <- file.path(repo_root, "docs", "WEB_SCIENTIFIC_ARTIFACT_MAP.md")
  txt <- readLines(map_path, warn = FALSE)
  
  # Extract backtick paths
  path_matches <- regmatches(txt, gregexpr("`([^`]+\\.(?:csv|yml|yaml|json|R|rds))`", txt))
  paths <- unique(unlist(path_matches))
  paths <- gsub("`", "", paths)
  
  # Filter only data, config, analysis paths
  repo_paths <- paths[grepl("^(data/|config/|analysis/|scripts/|docs/)", paths)]
  expect_true(length(repo_paths) >= 11)
  
  for (rp in repo_paths) {
    full_p <- file.path(repo_root, rp)
    expect_true(file.exists(full_p), info = paste("Source artifact does not exist:", rp))
  }
})

# ------------------------------------------------------------------------------
# DAILY DATA TESTS (9 - 16)
# ------------------------------------------------------------------------------

daily_json_path <- file.path(repo_root, "docs", "web-data", "daily_observations.json")
daily_data <- if (file.exists(daily_json_path)) fromJSON(daily_json_path) else data.frame()

test_that("09: Daily observations row count equals 11,970 scheduled station-days", {
  expect_equal(nrow(daily_data), 11970)
})

test_that("10: Exactly 21 unique station IDs present in daily observations", {
  expect_equal(n_distinct(daily_data$project_station_id), 21)
})

test_that("11: Exactly 570 unique dates present in daily observations", {
  expect_equal(n_distinct(daily_data$date), 570)
})

test_that("12: Correct date boundaries (2025-03-01 to 2026-09-21)", {
  expect_equal(min(daily_data$date), "2025-03-01")
  expect_equal(max(daily_data$date), "2026-09-21")
})

test_that("13: Zero duplicate station-date pairs in daily observations", {
  dups <- daily_data %>% count(project_station_id, date) %>% filter(n > 1)
  expect_equal(nrow(dups), 0)
})

test_that("14: Missing values in daily data remain null/NA and are not coerced to zero", {
  # Verify some NA exists in raw metrics (sensor downtime exists)
  expect_true(any(is.na(daily_data$aqi_verified)))
  expect_true(any(is.na(daily_data$pm2_5_aqi_input)))
})

test_that("15: Only approved Explore variables are exported in daily JSON", {
  expected_cols <- c(
    "project_station_id", "date", "aqi_verified", "aqi_category", "dominant_pollutant",
    "pm2_5_aqi_input", "pm10_aqi_input", "o3_8h_max", "temperature", "humidity", "wind_speed"
  )
  expect_equal(sort(names(daily_data)), sort(expected_cols))
})

test_that("16: CO, NO2, and SO2 are absent from Explore daily observation inputs", {
  expect_false("co_aqi_input" %in% names(daily_data))
  expect_false("no2_aqi_input" %in% names(daily_data))
  expect_false("so2_aqi_input" %in% names(daily_data))
})

# ------------------------------------------------------------------------------
# DRIFT / INFERENCE TESTS (17 - 25)
# ------------------------------------------------------------------------------

drift_json_path <- file.path(repo_root, "docs", "web-data", "drift_summary.json")
drift_data <- if (file.exists(drift_json_path)) fromJSON(drift_json_path) else data.frame()

inf_json_path <- file.path(repo_root, "docs", "web-data", "inference_summary.json")
inf_data <- if (file.exists(inf_json_path)) fromJSON(inf_json_path) else data.frame()

test_that("17: Drift summary has expected grain (147 rows = 21 stations x 7 variables)", {
  expect_equal(nrow(drift_data), 147)
  expect_equal(n_distinct(drift_data$project_station_id), 21)
  expect_equal(n_distinct(drift_data$variable), 7)
})

test_that("18: Inference summary has exactly 147 rows", {
  expect_equal(nrow(inf_data), 147)
})

test_that("19: Exactly 131 eligible/tested rows in inference summary", {
  expect_equal(sum(inf_data$eligible), 131)
  expect_equal(sum(inf_data$tested), 131)
})

test_that("20: Exactly 16 not-tested rows in inference summary", {
  expect_equal(sum(!inf_data$tested), 16)
})

test_that("21: Exactly 15 supported increase rows in inference summary", {
  expect_equal(sum(inf_data$support_direction == "Supported Increase"), 15)
})

test_that("22: Exactly 20 supported decrease rows in inference summary", {
  expect_equal(sum(inf_data$support_direction == "Supported Decrease"), 20)
})

test_that("23: Exactly 96 unsupported rows in inference summary", {
  expect_equal(sum(inf_data$support_direction == "Unsupported"), 96)
})

test_that("24: Exact drift class labels (MINIMAL, MILD, MODERATE, STRONG)", {
  valid_mags <- unique(na.omit(drift_data$drift_magnitude))
  expect_true(all(valid_mags %in% c("MINIMAL", "MILD", "MODERATE", "STRONG")))
  
  # Check counts: 72 MINIMAL, 39 MILD, 16 MODERATE, 4 STRONG, 16 NA
  mag_table <- table(drift_data$drift_magnitude)
  expect_equal(as.integer(mag_table["MINIMAL"]), 72)
  expect_equal(as.integer(mag_table["MILD"]), 39)
  expect_equal(as.integer(mag_table["MODERATE"]), 16)
  expect_equal(as.integer(mag_table["STRONG"]), 4)
})

test_that("25: Absence of causal labels in drift and inference exports", {
  all_notes <- paste(inf_data$ineligibility_reason, collapse = " ")
  expect_false(grepl("scavenged|monsoon clearing|washout", all_notes, ignore.case = TRUE))
})

# ------------------------------------------------------------------------------
# REGRESSION TESTS (26 - 30)
# ------------------------------------------------------------------------------

reg_json_path <- file.path(repo_root, "docs", "web-data", "regression_metrics.json")
reg_data <- if (file.exists(reg_json_path)) fromJSON(reg_json_path) else data.frame()

test_that("26: Both Hyderabad and India scopes present in regression metrics", {
  expect_true("Hyderabad" %in% reg_data$scope)
  expect_true("India" %in% reg_data$scope)
})

test_that("27: Both TEST and Recent Holdout splits present in regression metrics", {
  expect_true("TEST" %in% reg_data$evaluation_period)
  expect_true("Recent Holdout" %in% reg_data$evaluation_period)
})

test_that("28: Selected MLR Model B and Persistence present for all combinations", {
  models <- unique(reg_data$model)
  expect_true("Selected MLR Model B" %in% models)
  expect_true("Persistence" %in% models)
  expect_equal(nrow(reg_data), 8) # 2 scopes x 2 splits x 2 models
})

test_that("29: Expected MAE sanity values match frozen tables", {
  hyd_test_b <- reg_data %>% filter(scope == "Hyderabad", evaluation_period == "TEST", model == "Selected MLR Model B")
  hyd_test_p <- reg_data %>% filter(scope == "Hyderabad", evaluation_period == "TEST", model == "Persistence")
  ind_test_b <- reg_data %>% filter(scope == "India", evaluation_period == "TEST", model == "Selected MLR Model B")
  ind_test_p <- reg_data %>% filter(scope == "India", evaluation_period == "TEST", model == "Persistence")
  
  expect_equal(hyd_test_b$MAE, 10.0765, tolerance = 0.01)
  expect_equal(hyd_test_p$MAE, 7.8931, tolerance = 0.01)
  expect_equal(ind_test_b$MAE, 16.0380, tolerance = 0.01)
  expect_equal(ind_test_p$MAE, 15.9150, tolerance = 0.01)
  
  hyd_hold_b <- reg_data %>% filter(scope == "Hyderabad", evaluation_period == "Recent Holdout", model == "Selected MLR Model B")
  hyd_hold_p <- reg_data %>% filter(scope == "Hyderabad", evaluation_period == "Recent Holdout", model == "Persistence")
  ind_hold_b <- reg_data %>% filter(scope == "India", evaluation_period == "Recent Holdout", model == "Selected MLR Model B")
  ind_hold_p <- reg_data %>% filter(scope == "India", evaluation_period == "Recent Holdout", model == "Persistence")
  
  expect_equal(hyd_hold_b$MAE, 7.3164, tolerance = 0.01)
  expect_equal(hyd_hold_p$MAE, 5.7658, tolerance = 0.01)
  expect_equal(ind_hold_b$MAE, 12.9248, tolerance = 0.01)
  expect_equal(ind_hold_p$MAE, 12.2311, tolerance = 0.01)
})

test_that("30: Expected RMSE values match frozen tables", {
  hyd_test_b <- reg_data %>% filter(scope == "Hyderabad", evaluation_period == "TEST", model == "Selected MLR Model B")
  ind_test_b <- reg_data %>% filter(scope == "India", evaluation_period == "TEST", model == "Selected MLR Model B")
  
  expect_equal(hyd_test_b$RMSE, 18.6659, tolerance = 0.01)
  expect_equal(ind_test_b$RMSE, 33.7225, tolerance = 0.01)
})

# ------------------------------------------------------------------------------
# CLASSIFICATION TESTS (31 - 39)
# ------------------------------------------------------------------------------

cls_json_path <- file.path(repo_root, "docs", "web-data", "classification_metrics.json")
cls_data <- if (file.exists(cls_json_path)) fromJSON(cls_json_path) else data.frame()

test_that("31: Logistic Model B present in classification metrics", {
  expect_true("Logistic Model B" %in% cls_data$model)
})

test_that("32: RBF SVM present in classification metrics", {
  expect_true("RBF SVM" %in% cls_data$model)
})

test_that("33: Persistence benchmark present in classification metrics", {
  expect_true("Persistence" %in% cls_data$model)
  expect_equal(nrow(cls_data), 12) # 2 scopes x 2 splits x 3 models
})

test_that("34: India TEST PR-AUC sanity values match frozen tables", {
  ind_svm <- cls_data %>% filter(scope == "India", evaluation_period == "TEST", model == "RBF SVM")
  ind_log <- cls_data %>% filter(scope == "India", evaluation_period == "TEST", model == "Logistic Model B")
  ind_per <- cls_data %>% filter(scope == "India", evaluation_period == "TEST", model == "Persistence")
  
  expect_equal(ind_svm$PR_AUC, 0.833544, tolerance = 0.005)
  expect_equal(ind_log$PR_AUC, 0.825478, tolerance = 0.005)
  expect_equal(ind_per$PR_AUC, 0.655524, tolerance = 0.005)
  
  expect_equal(ind_svm$ROC_AUC, 0.934548, tolerance = 0.005)
  expect_equal(ind_log$ROC_AUC, 0.931715, tolerance = 0.005)
  expect_equal(ind_per$ROC_AUC, 0.826959, tolerance = 0.005)
  
  expect_equal(ind_svm$F1, 0.721805, tolerance = 0.005)
  expect_equal(ind_log$F1, 0.579439, tolerance = 0.005)
  expect_equal(ind_per$F1, 0.726655, tolerance = 0.005)
})

test_that("35: India Holdout PR-AUC sanity values match frozen tables", {
  ind_svm <- cls_data %>% filter(scope == "India", evaluation_period == "Recent Holdout", model == "RBF SVM")
  ind_log <- cls_data %>% filter(scope == "India", evaluation_period == "Recent Holdout", model == "Logistic Model B")
  ind_per <- cls_data %>% filter(scope == "India", evaluation_period == "Recent Holdout", model == "Persistence")
  
  expect_equal(ind_svm$PR_AUC, 0.541941, tolerance = 0.005)
  expect_equal(ind_log$PR_AUC, 0.568760, tolerance = 0.005)
  expect_equal(ind_per$PR_AUC, 0.511332, tolerance = 0.005)
  
  expect_equal(ind_svm$F1, 0.540541, tolerance = 0.005)
  expect_equal(ind_log$F1, 0.413793, tolerance = 0.005)
  expect_equal(ind_per$F1, 0.604651, tolerance = 0.005)
})

test_that("36: Hyderabad TEST sanity values match frozen tables", {
  hyd_svm <- cls_data %>% filter(scope == "Hyderabad", evaluation_period == "TEST", model == "RBF SVM")
  hyd_log <- cls_data %>% filter(scope == "Hyderabad", evaluation_period == "TEST", model == "Logistic Model B")
  hyd_per <- cls_data %>% filter(scope == "Hyderabad", evaluation_period == "TEST", model == "Persistence")
  
  expect_equal(hyd_svm$PR_AUC, 0.117948, tolerance = 0.005)
  expect_equal(hyd_log$PR_AUC, 0.166616, tolerance = 0.005)
  expect_equal(hyd_per$PR_AUC, 0.157161, tolerance = 0.005)
})

test_that("37: Hyderabad Holdout has positive_n = 0", {
  hyd_holdout <- cls_data %>% filter(scope == "Hyderabad", evaluation_period == "Recent Holdout")
  expect_true(all(hyd_holdout$positive_n == 0))
})

test_that("38: Undefined single-class metrics in Hyderabad Holdout are serialized as null/NA", {
  hyd_holdout <- cls_data %>% filter(scope == "Hyderabad", evaluation_period == "Recent Holdout")
  expect_true(all(is.na(hyd_holdout$PR_AUC)))
  expect_true(all(is.na(hyd_holdout$ROC_AUC)))
  expect_true(all(is.na(hyd_holdout$F1)))
})

test_that("39: SVM has no Brier Score displayed (strictly null/NA)", {
  svm_rows <- cls_data %>% filter(model == "RBF SVM")
  expect_true(all(is.na(svm_rows$Brier_Score)))
})

# ------------------------------------------------------------------------------
# PCA / K-MEANS TESTS (40 - 45)
# ------------------------------------------------------------------------------

pca_var_path <- file.path(repo_root, "docs", "web-data", "pca_variance.json")
pca_var_data <- if (file.exists(pca_var_path)) fromJSON(pca_var_path) else data.frame()

cluster_json_path <- file.path(repo_root, "docs", "web-data", "cluster_profiles.json")
cluster_data <- if (file.exists(cluster_json_path)) fromJSON(cluster_json_path) else list()

pca_scores_path <- file.path(repo_root, "docs", "web-data", "pca_scores.json")
pca_scores_data <- if (file.exists(pca_scores_path)) fromJSON(pca_scores_path) else data.frame()

test_that("40: Retained PCs = 4 for both scopes", {
  hyd_pcs <- pca_var_data %>% filter(scope == "Hyderabad")
  ind_pcs <- pca_var_data %>% filter(scope == "India")
  expect_equal(nrow(hyd_pcs), 6) # 6 evaluated
  expect_equal(nrow(ind_pcs), 6)
})

test_that("41: Cumulative variance exact (90.21% Hyd, 88.65% India at PC4)", {
  hyd_pc4 <- pca_var_data %>% filter(scope == "Hyderabad", PC == "PC4")
  ind_pc4 <- pca_var_data %>% filter(scope == "India", PC == "PC4")
  
  expect_equal(round(hyd_pc4$cumulative_variance, 4), 0.9021)
  expect_equal(round(ind_pc4$cumulative_variance, 4), 0.8865)
})

test_that("42: Selected k = 3 for both scopes", {
  labels_df <- cluster_data$labels
  expect_equal(sum(labels_df$scope == "Hyderabad"), 3)
  expect_equal(sum(labels_df$scope == "India"), 3)
})

test_that("43: Exact final cluster labels present in cluster profiles", {
  labels_df <- cluster_data$labels
  hyd_lbls <- labels_df %>% filter(scope == "Hyderabad") %>% pull(descriptive_label)
  ind_lbls <- labels_df %>% filter(scope == "India") %>% pull(descriptive_label)
  
  expect_true(all(c("warm-dry-moderate-pollution", "humid-windy-lower-pollution", "cool-low-wind-particulate-elevated") %in% hyd_lbls))
  expect_true(all(c("cool-low-wind-particulate-elevated", "hot-dry-ozone-pm10-elevated", "humid-windy-lower-pollution") %in% ind_lbls))
})

test_that("44: PCA score rows nonempty and equal to 9,928 station-days", {
  expect_equal(nrow(pca_scores_data), 9928)
  expect_true("PC1" %in% names(pca_scores_data))
  expect_true("PC2" %in% names(pca_scores_data))
  expect_true("cluster_label" %in% names(pca_scores_data))
})

test_that("45: Absence of obsolete k=4 labels (e.g., Clean / Scavenged, Severe Inversion)", {
  all_labels <- paste(cluster_data$labels$descriptive_label, collapse = " ")
  expect_false(grepl("Clean / Scavenged|Severe Inversion", all_labels, ignore.case = TRUE))
})

# ------------------------------------------------------------------------------
# HTML / JS INFRASTRUCTURE TESTS (46 - 60)
# ------------------------------------------------------------------------------

test_that("46: docs/assets/js/explore.js exists", {
  expect_true(file.exists(file.path(repo_root, "docs", "assets", "js", "explore.js")))
})

test_that("47: docs/assets/js/statistics.js exists", {
  expect_true(file.exists(file.path(repo_root, "docs", "assets", "js", "statistics.js")))
})

test_that("48: docs/assets/js/machine-learning.js exists", {
  expect_true(file.exists(file.path(repo_root, "docs", "assets", "js", "machine-learning.js")))
})

test_that("49: Explore page (docs/explore.html) is no longer a placeholder", {
  txt <- readLines(file.path(repo_root, "docs", "explore.html"), warn = FALSE)
  content <- paste(txt, collapse = " ")
  expect_false(grepl("placeholder-container", content))
  expect_true(grepl("id=\"exploreChart\"", content))
  expect_true(grepl("id=\"filter-scope\"", content))
  expect_true(grepl("id=\"filter-station\"", content))
})

test_that("50: Statistics page (docs/statistics.html) is no longer a placeholder", {
  txt <- readLines(file.path(repo_root, "docs", "statistics.html"), warn = FALSE)
  content <- paste(txt, collapse = " ")
  expect_false(grepl("placeholder-container", content))
  expect_true(grepl("id=\"driftComparisonChart\"", content))
  expect_true(grepl("id=\"tab-drift\"", content))
  expect_true(grepl("id=\"tab-inference\"", content))
})

test_that("51: Machine Learning page (docs/machine-learning.html) is no longer a placeholder", {
  txt <- readLines(file.path(repo_root, "docs", "machine-learning.html"), warn = FALSE)
  content <- paste(txt, collapse = " ")
  expect_false(grepl("placeholder-container", content))
  expect_true(grepl("id=\"regressionComparisonChart\"", content))
  expect_true(grepl("id=\"classificationComparisonChart\"", content))
  expect_true(grepl("id=\"pcaScatterChart\"", content))
})

test_that("52: Only local Chart.js (assets/vendor/chart.umd.min.js) referenced in pages", {
  pages <- c("explore.html", "statistics.html", "machine-learning.html")
  for (pg in pages) {
    txt <- readLines(file.path(repo_root, "docs", pg), warn = FALSE)
    content <- paste(txt, collapse = " ")
    expect_true(grepl("assets/vendor/chart\\.umd\\.min\\.js", content), info = paste("Missing local chart.js:", pg))
    expect_false(grepl("cdn\\.jsdelivr|cdnjs\\.cloudflare", content), info = paste("CDN detected:", pg))
  }
})

test_that("53: Zero React or modern framework scripts referenced in HTML", {
  pages <- c("explore.html", "statistics.html", "machine-learning.html")
  for (pg in pages) {
    txt <- readLines(file.path(repo_root, "docs", pg), warn = FALSE)
    content <- paste(txt, collapse = " ")
    expect_false(grepl("react|react-dom|vue|angular|next\\.js", content, ignore.case = TRUE))
  }
})

test_that("54: No Node/npm runtime requirements in documentation or web scripts", {
  js_files <- list.files(file.path(repo_root, "docs", "assets", "js"), full.names = TRUE, pattern = "\\.js$")
  for (jf in js_files) {
    txt <- readLines(jf, warn = FALSE)
    content <- paste(txt, collapse = " ")
    expect_false(grepl("require\\(['\"]express|npm run|node_modules", content))
  }
})

test_that("55: No CDN dependencies anywhere in docs/ HTML pages", {
  html_files <- list.files(file.path(repo_root, "docs"), pattern = "\\.html$", full.names = TRUE)
  for (hf in html_files) {
    txt <- readLines(hf, warn = FALSE)
    content <- paste(txt, collapse = " ")
    expect_false(grepl("https?://cdn|https?://unpkg|https?://cdnjs", content), info = paste("CDN link found in:", hf))
  }
})

test_that("56: No dynamic statistical model-fitting code in JavaScript files", {
  js_files <- list.files(file.path(repo_root, "docs", "assets", "js"), full.names = TRUE, pattern = "\\.js$")
  for (jf in js_files) {
    txt <- readLines(jf, warn = FALSE)
    content <- paste(txt, collapse = " ")
    # Prohibit JS linear regression, SVM, or kmeans solver libraries
    expect_false(grepl("ml-regression|svm-js|kmeans-ts|regression-multivariate", content))
  }
})

test_that("57: Prohibit 'Live AQI' wording in interactive views", {
  pages <- c("explore.html", "statistics.html", "machine-learning.html")
  for (pg in pages) {
    txt <- readLines(file.path(repo_root, "docs", pg), warn = FALSE)
    content <- paste(txt, collapse = " ")
    expect_false(grepl("Live AQI", content, ignore.case = TRUE), info = paste("Live AQI found in:", pg))
  }
})

test_that("58: Prohibit 'Real-time AQI' wording in interactive views", {
  pages <- c("explore.html", "statistics.html", "machine-learning.html")
  for (pg in pages) {
    txt <- readLines(file.path(repo_root, "docs", pg), warn = FALSE)
    content <- paste(txt, collapse = " ")
    expect_false(grepl("Real-time AQI", content, ignore.case = TRUE), info = paste("Real-time AQI found in:", pg))
  }
})

test_that("59: All required interactive controls have associated accessible labels", {
  pages <- c("explore.html", "statistics.html", "machine-learning.html")
  for (pg in pages) {
    txt <- readLines(file.path(repo_root, "docs", pg), warn = FALSE)
    content <- paste(txt, collapse = " ")
    # Check that select and input elements have labels or aria-labels
    select_ids <- regmatches(content, gregexpr("id=\"(filter-[^\"]+|stat-filter-[^\"]+|reg-filter-[^\"]+|cls-filter-[^\"]+|regime-filter-[^\"]+)\"", content))[[1]]
    for (sid in select_ids) {
      clean_id <- gsub("id=|\"", "", sid)
      has_label <- grepl(paste0("for=\"", clean_id, "\""), content) || grepl(paste0("aria-label="), content)
      expect_true(has_label, info = paste("Missing accessible label for ID:", clean_id, "in", pg))
    }
  }
})

test_that("60: All relative script and stylesheet assets in scientific pages resolve on disk", {
  pages <- c("explore.html", "statistics.html", "machine-learning.html")
  for (pg in pages) {
    txt <- readLines(file.path(repo_root, "docs", pg), warn = FALSE)
    content <- paste(txt, collapse = " ")
    
    # Extract src and href
    assets <- unlist(regmatches(content, gregexpr('(?:src|href)="([^"#]+\\.(?:css|js|ico))"', content)))
    clean_assets <- gsub('^(?:src|href)="|"$', "", assets)
    
    for (ca in clean_assets) {
      target_file <- file.path(repo_root, "docs", ca)
      expect_true(file.exists(target_file), info = paste("Unresolved asset:", ca, "in", pg))
    }
  }
})

# ------------------------------------------------------------------------------
# PHASE 6B.1 HARDENING & AUDIT CONTRACT TESTS (61 - 77)
# ------------------------------------------------------------------------------

test_that("61: Prohibit 'Verified CPCB AQI' in interactive website templates and scripts", {
  check_files <- c(
    file.path(repo_root, "docs", "explore.html"),
    file.path(repo_root, "docs", "assets", "js", "data-utils.js"),
    file.path(repo_root, "docs", "assets", "js", "documentation-manifest.js"),
    file.path(repo_root, "docs", "assets", "js", "statistics.js")
  )
  for (cf in check_files) {
    txt <- readLines(cf, warn = FALSE)
    content <- paste(txt, collapse = " ")
    expect_false(grepl("Verified CPCB AQI", content), info = paste("Outdated 'Verified CPCB AQI' found in:", cf))
    expect_true(grepl("Verified-Subset AQI", content), info = paste("Missing 'Verified-Subset AQI' in:", cf))
  }
})

test_that("62: AQI category 101-200 maps to 'Moderately Polluted' in data-utils.js", {
  du_txt <- readLines(file.path(repo_root, "docs", "assets", "js", "data-utils.js"), warn = FALSE)
  content <- paste(du_txt, collapse = " ")
  expect_true(grepl("category:\\s*'Moderately Polluted'", content))
  expect_false(grepl("category:\\s*'Moderate'", content))
})

test_that("63: Ozone label in data-utils.js and statistics.js is capitalized", {
  for (f in c("data-utils.js", "statistics.js")) {
    txt <- readLines(file.path(repo_root, "docs", "assets", "js", f), warn = FALSE)
    content <- paste(txt, collapse = " ")
    expect_true(grepl("Daily maximum rolling 8-hour ozone \\(o3_8h_max\\)", content), info = paste("Missing capitalized ozone in:", f))
    expect_false(grepl("daily maximum rolling 8-hour ozone \\(o3_8h_max\\)", content), info = paste("Found uncapitalized ozone in:", f))
  }
})

test_that("64: Classification operating-rule semantics in machine-learning.html", {
  ml_html <- readLines(file.path(repo_root, "docs", "machine-learning.html"), warn = FALSE)
  content <- paste(ml_html, collapse = " ")
  expect_true(grepl("Comparison of ranking performance and hard-classification F1 under each model's frozen operating rule", content, fixed = TRUE))
  expect_false(grepl("calibrated posterior probability", content, ignore.case = TRUE))
  expect_true(grepl("estimated adverse-event probability", content))
  expect_true(grepl("uncalibrated signed decision score", content))
  expect_true(grepl("<i>s</i>(<b>x</b>) = 0 is the native classification boundary", content, fixed = TRUE))
  expect_true(grepl("AQI(<i>t</i>) &gt; 100", content, fixed = TRUE))
  expect_true(grepl("Brier score is reported for Logistic probability predictions", content, fixed = TRUE))
})

test_that("65: Classification chart legend in machine-learning.js reflects frozen operating rule", {
  ml_js <- readLines(file.path(repo_root, "docs", "assets", "js", "machine-learning.js"), warn = FALSE)
  content <- paste(ml_js, collapse = " ")
  expect_true(grepl("F1 Score \\(Frozen Operating Rule\\)", content))
  expect_false(grepl("F1 Score \\(Validation-Tuned Operating Threshold\\)", content))
})

test_that("66: Regression interpretation in machine-learning.js avoids overstatement", {
  ml_js <- readLines(file.path(repo_root, "docs", "assets", "js", "machine-learning.js"), warn = FALSE)
  content <- paste(ml_js, collapse = " ")
  expect_true(grepl("the persistence benchmark remains competitive / stronger on the primary MAE comparison", content, fixed = TRUE))
  expect_false(grepl("atmospheric persistence remains a competitive baseline on holdout evaluations", content, fixed = TRUE))
})

test_that("67: PCA scatter axes in machine-learning.js use neutral PC1 and PC2 titles", {
  ml_js <- readLines(file.path(repo_root, "docs", "assets", "js", "machine-learning.js"), warn = FALSE)
  content <- paste(ml_js, collapse = " ")
  expect_true(grepl("text:\\s*'Principal Component 1 \\(PC1\\)'", content))
  expect_true(grepl("text:\\s*'Principal Component 2 \\(PC2\\)'", content))
  expect_false(grepl("Particulate & Sensor Magnitude", content))
  expect_false(grepl("Photochemical & Thermal Gradient", content))
})

test_that("68: PCA card in machine-learning.html includes geographic panel loadings note", {
  ml_html <- readLines(file.path(repo_root, "docs", "machine-learning.html"), warn = FALSE)
  content <- paste(ml_html, collapse = " ")
  expect_true(grepl("Component loadings differ by geographic panel; interpretations are reported separately in the PCA documentation", content, fixed = TRUE))
})

test_that("69: Drift direction mapping in statistics.js uses exported drift_direction and avoids Near baseline", {
  stat_js <- readLines(file.path(repo_root, "docs", "assets", "js", "statistics.js"), warn = FALSE)
  content <- paste(stat_js, collapse = " ")
  expect_true(grepl("dRow\\.drift_direction === 'upward'", content))
  expect_true(grepl("dRow\\.drift_direction === 'downward'", content))
  expect_false(grepl("Near baseline", content))
})

test_that("70: Statistical Analysis station defaults to first eligible station for AQI drift", {
  stat_js <- readLines(file.path(repo_root, "docs", "assets", "js", "statistics.js"), warn = FALSE)
  content <- paste(stat_js, collapse = " ")
  expect_true(grepl("d.variable === 'aqi_verified' && d.eligible === true", content, fixed = TRUE))
})

test_that("71: Scope labels consistently display 'India Representative Panel' across pages", {
  pages <- c("explore.html", "statistics.html", "machine-learning.html")
  for (pg in pages) {
    txt <- readLines(file.path(repo_root, "docs", pg), warn = FALSE)
    content <- paste(txt, collapse = " ")
    expect_true(grepl("India Representative Panel", content), info = paste("Missing 'India Representative Panel' in:", pg))
    # Ensure options with value="India" display "India Representative Panel"
    expect_true(grepl("<option value=\"India\"[^>]*>India Representative Panel</option>", content), info = paste("Malformed India option in:", pg))
  }
})

test_that("72: Deep-linking normalizers in JS files handle scope and variable aliases", {
  for (f in c("explore.js", "statistics.js", "machine-learning.js")) {
    txt <- readLines(file.path(repo_root, "docs", "assets", "js", f), warn = FALSE)
    content <- paste(txt, collapse = " ")
    expect_true(grepl("normalizeScope", content), info = paste("Missing normalizeScope in:", f))
  }
  # explore.js handles variable aliases
  exp_js <- readLines(file.path(repo_root, "docs", "assets", "js", "explore.js"), warn = FALSE)
  exp_content <- paste(exp_js, collapse = " ")
  expect_true(grepl("normalizeVariable", exp_content))
})

test_that("73: Classification chart in machine-learning.js preserves null metrics without coercing to 0", {
  ml_js <- readLines(file.path(repo_root, "docs", "assets", "js", "machine-learning.js"), warn = FALSE)
  content <- paste(ml_js, collapse = " ")
  expect_true(grepl("r\\.PR_AUC !== null \\? r\\.PR_AUC : null", content))
  expect_true(grepl("r\\.F1 !== null \\? r\\.F1 : null", content))
})

test_that("74: Single-class holdout policy in machine-learning.js hides chart and shows notice", {
  ml_js <- readLines(file.path(repo_root, "docs", "assets", "js", "machine-learning.js"), warn = FALSE)
  content <- paste(ml_js, collapse = " ")
  expect_true(grepl("isSingleClass", content))
  expect_true(grepl("clsChartWrapper\\.style\\.display = 'none'", content))
  expect_true(grepl("clsNoticeCard\\.style\\.display = 'block'", content))
})

test_that("75: Archive dependency audit table exists and is 100% PASS", {
  audit_path <- file.path(repo_root, "analysis", "phase6B", "tables", "phase6B_archive_dependency_audit.csv")
  expect_true(file.exists(audit_path))
  audit_df <- read.csv(audit_path, stringsAsFactors = FALSE)
  expect_equal(nrow(audit_df), 19)
  expect_true(all(audit_df$status == "PASS"))
  expect_true(all(audit_df$in_project == TRUE))
})

test_that("76: All 9 review screenshots exist and exceed 10 KB", {
  expected_screens <- c(
    "01_explore_aqi_1440x900.png",
    "02_explore_pm25_1440x900.png",
    "03_stat_drift_eligible_1440x900.png",
    "04_stat_inference_tested_1440x900.png",
    "05_ml_regression_1440x900.png",
    "06_ml_classification_india_test_1440x900.png",
    "07_ml_classification_hyd_holdout_1440x900.png",
    "08_ml_regimes_hyderabad_1440x900.png",
    "09_ml_regimes_india_1440x900.png"
  )
  for (scr in expected_screens) {
    p <- file.path(repo_root, "analysis", "phase6B", "ui_review", scr)
    expect_true(file.exists(p), info = paste("Missing screenshot:", scr))
    expect_gt(file.size(p), 10000, label = paste("Screenshot too small:", scr))
  }
})

test_that("77: review_archive_phase6B1_light.zip exists and exceeds 2 MB", {
  arch_path <- file.path(repo_root, "review_archive_phase6B1_light.zip")
  expect_true(file.exists(arch_path))
  expect_gt(file.size(arch_path), 2000000)
})
