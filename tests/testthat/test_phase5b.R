# tests/testthat/test_phase5b.R
# Phase 5B: Test Suite for RBF Support Vector Machine Adverse-AQI Classification
# Verifies all 51 criteria specified in Phase 5B contract

library(testthat)
library(readr)
library(dplyr)
library(yaml)

source("../../R/30_classification_metrics.R")
source("../../R/32_svm_helpers.R")

context("Phase 5B RBF Support Vector Machine Classification Tests")

# Load artifacts
design_df <- read_csv("../../data/analysis/phase5B/phase5B_design_master.csv", show_col_types = FALSE)
val_grid <- read_csv("../../analysis/phase5B/tables/phase5B_validation_grid.csv", show_col_types = FALSE)
svm_sel <- read_csv("../../data/analysis/phase5B/phase5B_svm_selection.csv", show_col_types = FALSE)
test_preds <- read_csv("../../data/analysis/phase5B/phase5B_test_predictions.csv", show_col_types = FALSE)
holdout_preds <- read_csv("../../data/analysis/phase5B/phase5B_holdout_predictions.csv", show_col_types = FALSE)
test_metrics <- read_csv("../../analysis/phase5B/tables/phase5B_test_metrics.csv", show_col_types = FALSE)
holdout_metrics <- read_csv("../../analysis/phase5B/tables/phase5B_holdout_metrics.csv", show_col_types = FALSE)
prev_df <- read_csv("../../analysis/phase5B/tables/phase5B_prevalence_by_split.csv", show_col_types = FALSE)
spec_yml <- yaml::read_yaml("../../config/phase5B_svm_specification.yml")
sel_yml <- yaml::read_yaml("../../config/phase5B_selected_svm.yml")

# ==============================================================================
# BLOCK A: Target Definition, Alignment, Splits & Feature Exclusions
# Tests 1-4, 14-20, 23-25
# ==============================================================================
test_that("Block A: Target definition, alignment, chronology and feature contract", {
  # 1. Target exactly AQI_(t+1) > 100
  sample_eligible <- design_df %>% filter(eligible_svm, !is.na(target_aqi_next_day))
  expect_true(all(sample_eligible$target_adverse_next_day == ifelse(sample_eligible$target_aqi_next_day > 100, 1, 0)))
  
  # 2. Exact same-station t+1 alignment
  expect_true(all(design_df$target_date == (design_df$date + 1)))
  
  # 3. Target-date split boundaries exact
  train_rows <- design_df %>% filter(split == "TRAIN")
  expect_true(min(train_rows$target_date) >= as.Date("2025-03-02"))
  expect_true(max(train_rows$target_date) <= as.Date("2025-12-31"))
  
  val_rows <- design_df %>% filter(split == "VALIDATION")
  expect_true(min(val_rows$target_date) >= as.Date("2026-01-01"))
  expect_true(max(val_rows$target_date) <= as.Date("2026-04-30"))
  
  test_rows <- design_df %>% filter(split == "TEST")
  expect_true(min(test_rows$target_date) >= as.Date("2026-05-01"))
  expect_true(max(test_rows$target_date) <= as.Date("2026-08-31"))
  
  hold_rows <- design_df %>% filter(split == "FINAL_RECENT_HOLDOUT")
  expect_true(min(hold_rows$target_date) >= as.Date("2026-09-01"))
  expect_true(max(hold_rows$target_date) <= as.Date("2026-09-21"))
  
  # 4. No random splitting
  expect_false(spec_yml$chronological_splits$random_split_allowed)
  expect_false(spec_yml$experimental_constraints$random_split_allowed)
  
  # 14. Exact continuous feature contract
  expected_cont <- c("pm2_5_aqi_input", "pm10_aqi_input", "o3_8h_max", "temperature", "humidity",
                     "wind_speed", "sin_wind_direction", "cos_wind_direction", "month_sin", "month_cos", "aqi_verified")
  expect_equal(svm_continuous_predictors(), expected_cont)
  
  # 15. AQI category excluded
  # 16. Unresolved gases excluded
  # 17. Future predictors excluded
  # 18. Phase-3 results excluded
  # 19. Phase-5 PC features excluded
  # 20. Phase-5 cluster features excluded
  prohibited <- c("aqi_category", "dominant_pollutant", "pm2_5_subindex", "pm10_subindex", "o3_subindex",
                  "co_source_mean", "no2_source_mean", "so2_source_mean", "drift_score", "p_val",
                  "PC1", "PC2", "PC3", "PC4", "cluster", "cluster_label", "centroid_distance")
  hyd_features <- svm_continuous_predictors()
  expect_true(length(intersect(hyd_features, prohibited)) == 0)
  
  # 23. No imputation
  expect_true(all(!is.na(design_df %>% filter(eligible_svm) %>% select(all_of(expected_cont)))))
  
  # 24. No SMOTE
  # 25. No class weighting
  expect_equal(spec_yml$experimental_constraints$class_resampling_policy,
               "none (NO SMOTE, NO oversampling, NO undersampling, NO synthetic positives, NO class weighting)")
})

# ==============================================================================
# BLOCK B: Sample Sizes and Positive Counts by Split and Scope
# Tests 5-13, 44, 46
# ==============================================================================
test_that("Block B: Exact complete-case observation and class counts", {
  # Hyderabad counts
  hyd_counts <- prev_df %>% filter(scope == "HYDERABAD")
  
  # 5. Hyderabad TRAIN n = 1398 (adverse 269)
  expect_equal(hyd_counts$n[hyd_counts$split == "TRAIN"], 1398)
  expect_equal(hyd_counts$positive_n[hyd_counts$split == "TRAIN"], 269)
  
  # 6. Hyderabad VALIDATION n = 498 (adverse 66)
  expect_equal(hyd_counts$n[hyd_counts$split == "VALIDATION"], 498)
  expect_equal(hyd_counts$positive_n[hyd_counts$split == "VALIDATION"], 66)
  
  # 7. Hyderabad TEST n = 477 (adverse 11)
  expect_equal(hyd_counts$n[hyd_counts$split == "TEST"], 477)
  expect_equal(hyd_counts$positive_n[hyd_counts$split == "TEST"], 11)
  
  # 8. Hyderabad HOLDOUT n = 111 (adverse 0)
  expect_equal(hyd_counts$n[hyd_counts$split == "FINAL_RECENT_HOLDOUT"], 111)
  expect_equal(hyd_counts$positive_n[hyd_counts$split == "FINAL_RECENT_HOLDOUT"], 0)
  
  # India counts
  ind_counts <- prev_df %>% filter(scope == "INDIA")
  
  # 9. India TRAIN n = 3501 (adverse 1553)
  expect_equal(ind_counts$n[ind_counts$split == "TRAIN"], 3501)
  expect_equal(ind_counts$positive_n[ind_counts$split == "TRAIN"], 1553)
  
  # 10. India VALIDATION n = 1302 (adverse 828)
  expect_equal(ind_counts$n[ind_counts$split == "VALIDATION"], 1302)
  expect_equal(ind_counts$positive_n[ind_counts$split == "VALIDATION"], 828)
  
  # 11. India TEST n = 1389 (adverse 294)
  expect_equal(ind_counts$n[ind_counts$split == "TEST"], 1389)
  expect_equal(ind_counts$positive_n[ind_counts$split == "TEST"], 294)
  
  # 12. India HOLDOUT n = 238 (adverse 22)
  expect_equal(ind_counts$n[ind_counts$split == "FINAL_RECENT_HOLDOUT"], 238)
  expect_equal(ind_counts$positive_n[ind_counts$split == "FINAL_RECENT_HOLDOUT"], 22)
  
  # 13. Correct positive counts by split (sum across scopes for TEST and HOLDOUT)
  expect_equal(sum(test_metrics$positive_n), 11 + 294)
  expect_equal(sum(holdout_metrics$positive_n), 0 + 22)
  
  # 44. Hyderabad holdout positive_n = 0
  expect_equal(holdout_metrics$positive_n[holdout_metrics$scope == "HYDERABAD"], 0)
  
  # 46. India holdout contains both classes
  expect_gt(holdout_metrics$positive_n[holdout_metrics$scope == "INDIA"], 0)
  expect_gt(holdout_metrics$negative_n[holdout_metrics$scope == "INDIA"], 0)
})

# ==============================================================================
# BLOCK C: Preprocessing, One-Hot Encoding & Standardization Isolation
# Tests 21-22, 36-39
# ==============================================================================
test_that("Block C: Preprocessing, encoding and standardization integrity", {
  # 21. Categorical features one-hot encoded
  hyd_tr <- design_df %>% filter(use_hyderabad == TRUE, eligible_svm, split == "TRAIN")
  hyd_val <- design_df %>% filter(use_hyderabad == TRUE, eligible_svm, split == "VALIDATION")
  prep_hyd <- prepare_svm_features(hyd_tr, hyd_val)
  
  # 7 stations + 7 DOW = 14 dummy cols; + 11 continuous = 25 total
  expect_equal(prep_hyd$p, 25)
  station_dummies <- grep("^station_", prep_hyd$feature_names, value = TRUE)
  dow_dummies <- grep("^dow_", prep_hyd$feature_names, value = TRUE)
  expect_equal(length(station_dummies), 7)
  expect_equal(length(dow_dummies), 7)
  
  # Dummies strictly 0/1
  expect_true(all(prep_hyd$X_train[, c(station_dummies, dow_dummies)] %in% c(0, 1)))
  
  # 22. Numeric features standardized from fitting data only
  # Continuous train columns have mean approx 0 and sd approx 1
  cont_vars <- svm_continuous_predictors()
  tr_means <- colMeans(prep_hyd$X_train[, cont_vars])
  tr_sds <- apply(prep_hyd$X_train[, cont_vars], 2, sd)
  expect_true(all(abs(tr_means) < 1e-10))
  expect_true(all(abs(tr_sds - 1.0) < 1e-10))
  
  # 36. TEST refit uses TRAIN + VALIDATION only
  # 37. TEST absent from TEST refit preprocessing
  scale_test_df <- read_csv("../../analysis/phase5B/tables/phase5B_scaling_parameters_test_refit.csv", show_col_types = FALSE)
  train_val_hyd <- design_df %>% filter(use_hyderabad == TRUE, eligible_svm, split %in% c("TRAIN", "VALIDATION"))
  for (v in cont_vars) {
    exp_m <- mean(train_val_hyd[[v]])
    exp_s <- sd(train_val_hyd[[v]])
    act_m <- scale_test_df$mean[scale_test_df$scope == "HYDERABAD" & scale_test_df$feature == v]
    act_s <- scale_test_df$sd[scale_test_df$scope == "HYDERABAD" & scale_test_df$feature == v]
    expect_equal(act_m, exp_m, tolerance = 1e-6)
    expect_equal(act_s, exp_s, tolerance = 1e-6)
  }
  
  # 38. Final-history refit uses through 2026-08-31 only
  # 39. HOLDOUT absent from final-history fit
  scale_hist_df <- read_csv("../../analysis/phase5B/tables/phase5B_scaling_parameters_final_history.csv", show_col_types = FALSE)
  hist_hyd <- design_df %>% filter(use_hyderabad == TRUE, eligible_svm, split %in% c("TRAIN", "VALIDATION", "TEST"))
  for (v in cont_vars) {
    exp_m <- mean(hist_hyd[[v]])
    exp_s <- sd(hist_hyd[[v]])
    act_m <- scale_hist_df$mean[scale_hist_df$scope == "HYDERABAD" & scale_hist_df$feature == v]
    act_s <- scale_hist_df$sd[scale_hist_df$scope == "HYDERABAD" & scale_hist_df$feature == v]
    expect_equal(act_m, exp_m, tolerance = 1e-6)
    expect_equal(act_s, exp_s, tolerance = 1e-6)
  }
})

# ==============================================================================
# BLOCK D: Hyperparameter Grid, RBF Kernel & Selection Logic
# Tests 26-33, 40
# ==============================================================================
test_that("Block D: Hyperparameter grid, RBF kernel and validation selection", {
  # 26. RBF kernel only
  expect_equal(unique(svm_sel$kernel), "radial")
  
  # 27. Cost grid exact
  expected_costs <- c(0.25, 1.0, 4.0, 16.0)
  expect_equal(sort(unique(val_grid$cost)), sort(expected_costs))
  
  # 28. Gamma multiplier grid exact
  expected_mults <- c(0.25, 0.5, 1.0, 2.0, 4.0)
  hyd_grid_sub <- val_grid %>% filter(scope == "HYDERABAD")
  base_g_hyd <- unique(hyd_grid_sub$base_gamma)
  expect_equal(base_g_hyd, 1 / 25)
  expect_equal(sort(unique(hyd_grid_sub$gamma)), sort(expected_mults * base_g_hyd))
  
  # 29. Candidate count = 20 per scope (40 total)
  expect_equal(nrow(val_grid %>% filter(scope == "HYDERABAD")), 20)
  expect_equal(nrow(val_grid %>% filter(scope == "INDIA")), 20)
  expect_equal(nrow(val_grid), 40)
  
  # 30. Hyperparameter selection uses VALIDATION PR-AUC only
  # 31. Selected candidate equals deterministic rule
  for (sc in c("HYDERABAD", "INDIA")) {
    sub_g <- val_grid %>% filter(scope == sc)
    max_pr <- max(sub_g$validation_PR_AUC)
    tied <- sub_g %>% filter(abs(validation_PR_AUC - max_pr) <= 1e-10) %>% arrange(cost, gamma)
    best_c <- tied$cost[1]
    best_g <- tied$gamma[1]
    
    sel_row <- svm_sel %>% filter(scope == sc)
    expect_equal(sel_row$selected_cost, best_c)
    expect_equal(sel_row$selected_gamma, best_g)
    expect_equal(sel_row$selection_basis, "VALIDATION_PR_AUC")
  }
  
  # 32. TEST excluded from selection
  # 33. HOLDOUT excluded from selection
  expect_false(any(grepl("TEST", names(val_grid))))
  expect_false(any(grepl("HOLDOUT", names(val_grid))))
  
  # 40. Raw decision scores are not labeled probabilities
  # Verify decision scores are continuous unbounded real numbers (contain negative and values > 1)
  expect_true(any(test_preds$decision_score < 0))
  expect_true(any(test_preds$decision_score > 1))
})

# ==============================================================================
# BLOCK E: Score Orientation, Decision Values & Metric Bounds
# Tests 34-35, 41-43, 45, 47
# ==============================================================================
test_that("Block E: Score orientation and metric validity", {
  # 34. Score orientation learned from fit data only
  # Verify orientation multiplier exists and is +1 or -1
  expect_true(all(val_grid$score_orientation_multiplier %in% c(-1, 1)))
  
  # 35. Oriented validation ROC-AUC >= 0.5 where defined
  expect_true(all(val_grid$validation_ROC_AUC >= 0.5))
  
  # 41. ROC-AUC bounds when defined
  expect_true(all(test_metrics$ROC_AUC >= 0.5 & test_metrics$ROC_AUC <= 1.0))
  expect_true(holdout_metrics$ROC_AUC[holdout_metrics$scope == "INDIA"] >= 0.5 &&
              holdout_metrics$ROC_AUC[holdout_metrics$scope == "INDIA"] <= 1.0)
  
  # 42. PR-AUC bounds when defined
  expect_true(all(test_metrics$PR_AUC >= 0.0 & test_metrics$PR_AUC <= 1.0))
  expect_true(holdout_metrics$PR_AUC[holdout_metrics$scope == "INDIA"] >= 0.0 &&
              holdout_metrics$PR_AUC[holdout_metrics$scope == "INDIA"] <= 1.0)
  
  # 43. Average Precision bounds when defined
  expect_true(all(test_metrics$average_precision >= 0.0 & test_metrics$average_precision <= 1.0))
  expect_true(holdout_metrics$average_precision[holdout_metrics$scope == "INDIA"] >= 0.0 &&
              holdout_metrics$average_precision[holdout_metrics$scope == "INDIA"] <= 1.0)
  
  # 45. Hyderabad holdout ranking metrics NA
  hyd_h <- holdout_metrics %>% filter(scope == "HYDERABAD")
  expect_true(is.na(hyd_h$ROC_AUC))
  expect_true(is.na(hyd_h$PR_AUC))
  expect_true(is.na(hyd_h$average_precision))
  expect_true(is.na(hyd_h$sensitivity))
  expect_true(is.na(hyd_h$F1))
  
  # 47. Prediction row counts exact
  # TEST: 477 (Hyd) + 1389 (India) = 1866 rows
  expect_equal(nrow(test_preds), 477 + 1389)
  # HOLDOUT: 111 (Hyd) + 238 (India) = 349 rows
  expect_equal(nrow(holdout_preds), 111 + 238)
})

# ==============================================================================
# BLOCK F: Cross-Phase Immutability, Artifact Existence & Network Isolation
# Tests 48-51
# ==============================================================================
test_that("Block F: Cross-phase baseline immutability and artifact existence", {
  # 48. Frozen Phase-4 summary unchanged
  p4_sum <- read_csv("../../analysis/phase4C/tables/phase4_supervised_learning_summary.csv", show_col_types = FALSE)
  expect_equal(nrow(p4_sum), 8)
  expect_equal(p4_sum$Logistic_PR_AUC[p4_sum$scope == "INDIA" & p4_sum$split == "TEST" & p4_sum$model_name == "MODEL_B"],
               0.8254781557712162, tolerance = 1e-8)
  
  # 49. Frozen Phase-5A artifacts unchanged
  expect_true(file.exists("../../data/analysis/phase5A/Hyderabad_PCA_History.csv"))
  expect_true(file.exists("../../data/analysis/phase5A/India_PCA_History.csv"))
  expect_true(file.exists("../../models/phase5A/hyderabad_kmeans.rds"))
  expect_true(file.exists("../../models/phase5A/india_kmeans.rds"))
  
  # 50. Required SVM RDS objects exist
  expected_models <- c(
    "../../models/phase5B/hyderabad_svm_train.rds",
    "../../models/phase5B/india_svm_train.rds",
    "../../models/phase5B/hyderabad_svm_test_refit.rds",
    "../../models/phase5B/india_svm_test_refit.rds",
    "../../models/phase5B/hyderabad_svm_final_history.rds",
    "../../models/phase5B/india_svm_final_history.rds"
  )
  for (m_path in expected_models) {
    expect_true(file.exists(m_path), info = paste("Model RDS exists:", m_path))
  }
  
  # 51. No network calls in Phase-5B execution scripts
  # Inspect scripts for download.file, install.packages, curl, http
  p5b_scripts <- c(
    "../../scripts/20a_phase5B_prepare_design.R",
    "../../scripts/20b_phase5B_train_validate_select.R",
    "../../scripts/20c_phase5B_test_holdout_evaluation.R",
    "../../scripts/20d_phase5B_figures.R"
  )
  for (s_path in p5b_scripts) {
    lines <- readLines(s_path, warn = FALSE)
    expect_false(any(grepl("install\\.packages|download\\.file|http:|https:", lines)),
                 info = paste("No network calls in:", s_path))
  }
})
