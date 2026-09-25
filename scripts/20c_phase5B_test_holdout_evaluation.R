# scripts/20c_phase5B_test_holdout_evaluation.R
# Phase 5B: Test Refit, September Holdout Evaluation, Support Vector Summary, and Phase 4 Comparison

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})

source("R/30_classification_metrics.R")
source("R/32_svm_helpers.R")

cat(">>> Running scripts/20c_phase5B_test_holdout_evaluation.R...\n")

design_df <- read_csv("data/analysis/phase5B/phase5B_design_master.csv", show_col_types = FALSE)
selection_df <- read_csv("data/analysis/phase5B/phase5B_svm_selection.csv", show_col_types = FALSE)

scopes <- c("HYDERABAD", "INDIA")

test_pred_list <- list()
holdout_pred_list <- list()
test_metrics_list <- list()
holdout_metrics_list <- list()
sv_summary_list <- list()
scaling_test_list <- list()
scaling_hist_list <- list()

for (sc in scopes) {
  cat(sprintf("\n=== Evaluating Scope: %s ===\n", sc))
  use_col <- if (sc == "HYDERABAD") "use_hyderabad" else "use_india"
  
  sel_cost <- selection_df$selected_cost[selection_df$scope == sc]
  sel_gamma <- selection_df$selected_gamma[selection_df$scope == sc]
  
  # Load train-only model for SV summary
  train_model_path <- sprintf("models/phase5B/%s_svm_train.rds", tolower(sc))
  train_fit_obj <- readRDS(train_model_path)
  train_n_samples <- nrow(design_df %>% filter(.data[[use_col]] == TRUE, eligible_svm, split == "TRAIN"))
  
  sv_summary_list[[length(sv_summary_list) + 1]] <- data.frame(
    scope = sc,
    fit_stage = "TRAIN_ONLY",
    total_samples = train_n_samples,
    cost = sel_cost,
    gamma = sel_gamma,
    total_support_vectors = train_fit_obj$n_support_vectors,
    sv_class_0 = train_fit_obj$n_sv_class_0,
    sv_class_1 = train_fit_obj$n_sv_class_1,
    sv_proportion = train_fit_obj$sv_proportion,
    stringsAsFactors = FALSE
  )
  
  # -------------------------------------------------------------
  # STAGE 1: TEST REFIT (TRAIN + VALIDATION -> evaluate on TEST)
  # -------------------------------------------------------------
  cat("--- Stage 1: TEST Refit (Train + Validation -> Test) ---\n")
  train_val_df <- design_df %>%
    filter(.data[[use_col]] == TRUE, eligible_svm, split %in% c("TRAIN", "VALIDATION"))
  test_df <- design_df %>%
    filter(.data[[use_col]] == TRUE, eligible_svm, split == "TEST")
  
  prep_test <- prepare_svm_features(train_val_df, test_df)
  scaling_test_list[[sc]] <- prep_test$scaling_df %>% mutate(scope = sc)
  
  test_refit_obj <- fit_and_orient_svm(
    X_train = prep_test$X_train,
    y_train = prep_test$y_train,
    cost = sel_cost,
    gamma = sel_gamma,
    seed = 20260925
  )
  saveRDS(test_refit_obj, sprintf("models/phase5B/%s_svm_test_refit.rds", tolower(sc)))
  
  sv_summary_list[[length(sv_summary_list) + 1]] <- data.frame(
    scope = sc,
    fit_stage = "TEST_REFIT",
    total_samples = nrow(prep_test$X_train),
    cost = sel_cost,
    gamma = sel_gamma,
    total_support_vectors = test_refit_obj$n_support_vectors,
    sv_class_0 = test_refit_obj$n_sv_class_0,
    sv_class_1 = test_refit_obj$n_sv_class_1,
    sv_proportion = test_refit_obj$sv_proportion,
    stringsAsFactors = FALSE
  )
  
  # Predict on locked TEST
  test_preds <- predict_oriented_svm(test_refit_obj, prep_test$X_eval)
  
  test_pred_df <- test_df %>%
    select(project_station_id, station_name, date, target_date, actual_class = target_adverse_next_day) %>%
    mutate(
      scope = sc,
      decision_score = test_preds$decision_score,
      predicted_class = test_preds$predicted_class,
      cost = sel_cost,
      gamma = sel_gamma,
      split = "TEST"
    ) %>%
    select(scope, project_station_id, station_name, date, target_date, actual_class,
           decision_score, predicted_class, cost, gamma, split)
  test_pred_list[[sc]] <- test_pred_df
  
  # Evaluate TEST metrics
  y_test <- test_pred_df$actual_class
  p_test_class <- test_pred_df$predicted_class
  score_test <- test_pred_df$decision_score
  
  test_roc <- calc_roc_auc(y_test, score_test)
  test_pr <- calc_pr_auc_tie_safe(y_test, score_test)
  test_avg_prec <- calc_average_precision_tie_safe(y_test, score_test)
  
  tp <- sum(y_test == 1 & p_test_class == 1)
  tn <- sum(y_test == 0 & p_test_class == 0)
  fp <- sum(y_test == 0 & p_test_class == 1)
  fn <- sum(y_test == 1 & p_test_class == 0)
  
  sens <- if (tp + fn == 0) NA_real_ else tp / (tp + fn)
  spec <- if (tn + fp == 0) NA_real_ else tn / (tn + fp)
  prec <- if (tp + fp == 0) NA_real_ else tp / (tp + fp)
  npv <- if (tn + fn == 0) NA_real_ else tn / (tn + fn)
  f1 <- if (is.na(prec) || is.na(sens) || (prec + sens) == 0) NA_real_ else 2 * prec * sens / (prec + sens)
  bal_acc <- if (is.na(sens) || is.na(spec)) NA_real_ else (sens + spec) / 2
  acc <- (tp + tn) / length(y_test)
  
  test_metrics_list[[sc]] <- data.frame(
    scope = sc,
    split = "TEST",
    n = length(y_test),
    positive_n = sum(y_test == 1),
    negative_n = sum(y_test == 0),
    ROC_AUC = test_roc,
    PR_AUC = test_pr,
    average_precision = test_avg_prec,
    TP = tp,
    TN = tn,
    FP = fp,
    FN = fn,
    sensitivity = sens,
    specificity = spec,
    precision = prec,
    NPV = npv,
    F1 = f1,
    balanced_accuracy = bal_acc,
    accuracy = acc,
    stringsAsFactors = FALSE
  )
  
  cat(sprintf("[TEST RESULTS] %s: PR-AUC = %.6f, ROC-AUC = %.6f, F1 = %.4f (TP=%d, FP=%d, FN=%d, TN=%d)\n",
              sc, test_pr, test_roc, f1, tp, fp, fn, tn))
  
  # ---------------------------------------------------------------------------------
  # STAGE 2: FINAL HISTORY REFIT (TRAIN + VAL + TEST -> evaluate on RECENT HOLDOUT)
  # ---------------------------------------------------------------------------------
  cat("--- Stage 2: Final History Refit (History through 2026-08-31 -> Holdout) ---\n")
  history_df <- design_df %>%
    filter(.data[[use_col]] == TRUE, eligible_svm, split %in% c("TRAIN", "VALIDATION", "TEST"))
  holdout_df <- design_df %>%
    filter(.data[[use_col]] == TRUE, eligible_svm, split == "FINAL_RECENT_HOLDOUT")
  
  prep_hist <- prepare_svm_features(history_df, holdout_df)
  scaling_hist_list[[sc]] <- prep_hist$scaling_df %>% mutate(scope = sc)
  
  final_history_obj <- fit_and_orient_svm(
    X_train = prep_hist$X_train,
    y_train = prep_hist$y_train,
    cost = sel_cost,
    gamma = sel_gamma,
    seed = 20260925
  )
  saveRDS(final_history_obj, sprintf("models/phase5B/%s_svm_final_history.rds", tolower(sc)))
  
  sv_summary_list[[length(sv_summary_list) + 1]] <- data.frame(
    scope = sc,
    fit_stage = "FINAL_HISTORY",
    total_samples = nrow(prep_hist$X_train),
    cost = sel_cost,
    gamma = sel_gamma,
    total_support_vectors = final_history_obj$n_support_vectors,
    sv_class_0 = final_history_obj$n_sv_class_0,
    sv_class_1 = final_history_obj$n_sv_class_1,
    sv_proportion = final_history_obj$sv_proportion,
    stringsAsFactors = FALSE
  )
  
  # Predict on September Holdout
  holdout_preds <- predict_oriented_svm(final_history_obj, prep_hist$X_eval)
  
  holdout_pred_df <- holdout_df %>%
    select(project_station_id, station_name, date, target_date, actual_class = target_adverse_next_day) %>%
    mutate(
      scope = sc,
      decision_score = holdout_preds$decision_score,
      predicted_class = holdout_preds$predicted_class,
      cost = sel_cost,
      gamma = sel_gamma,
      split = "FINAL_RECENT_HOLDOUT"
    ) %>%
    select(scope, project_station_id, station_name, date, target_date, actual_class,
           decision_score, predicted_class, cost, gamma, split)
  holdout_pred_list[[sc]] <- holdout_pred_df
  
  # Evaluate Holdout metrics
  y_hold <- holdout_pred_df$actual_class
  p_hold_class <- holdout_pred_df$predicted_class
  score_hold <- holdout_pred_df$decision_score
  pos_hold <- sum(y_hold == 1)
  
  hold_roc <- calc_roc_auc(y_hold, score_hold)
  hold_pr <- calc_pr_auc_tie_safe(y_hold, score_hold)
  hold_avg_prec <- calc_average_precision_tie_safe(y_hold, score_hold)
  
  tp_h <- sum(y_hold == 1 & p_hold_class == 1)
  tn_h <- sum(y_hold == 0 & p_hold_class == 0)
  fp_h <- sum(y_hold == 0 & p_hold_class == 1)
  fn_h <- sum(y_hold == 1 & p_hold_class == 0)
  
  sens_h <- if (tp_h + fn_h == 0) NA_real_ else tp_h / (tp_h + fn_h)
  spec_h <- if (tn_h + fp_h == 0) NA_real_ else tn_h / (tn_h + fp_h)
  prec_h <- if (tp_h + fp_h == 0) NA_real_ else tp_h / (tp_h + fp_h)
  npv_h <- if (tn_h + fn_h == 0) NA_real_ else tn_h / (tn_h + fn_h)
  f1_h <- if (is.na(prec_h) || is.na(sens_h) || (prec_h + sens_h) == 0) NA_real_ else 2 * prec_h * sens_h / (prec_h + sens_h)
  bal_acc_h <- if (is.na(sens_h) || is.na(spec_h)) NA_real_ else (sens_h + spec_h) / 2
  acc_h <- (tp_h + tn_h) / length(y_hold)
  
  holdout_metrics_list[[sc]] <- data.frame(
    scope = sc,
    split = "FINAL_RECENT_HOLDOUT",
    n = length(y_hold),
    positive_n = pos_hold,
    negative_n = sum(y_hold == 0),
    ROC_AUC = hold_roc,
    PR_AUC = hold_pr,
    average_precision = hold_avg_prec,
    TP = tp_h,
    TN = tn_h,
    FP = fp_h,
    FN = fn_h,
    sensitivity = sens_h,
    specificity = spec_h,
    precision = prec_h,
    NPV = npv_h,
    F1 = f1_h,
    balanced_accuracy = bal_acc_h,
    accuracy = acc_h,
    stringsAsFactors = FALSE
  )
  
  cat(sprintf("[HOLDOUT RESULTS] %s: pos_n = %d, PR-AUC = %s, ROC-AUC = %s, Accuracy = %.4f (TP=%d, FP=%d, FN=%d, TN=%d)\n",
              sc, pos_hold, as.character(hold_pr), as.character(hold_roc), acc_h, tp_h, fp_h, fn_h, tn_h))
}

# -------------------------------------------------------------
# Save Artifacts
# -------------------------------------------------------------
# 1. Predictions
test_pred_all <- bind_rows(test_pred_list)
write_csv(test_pred_all, "data/analysis/phase5B/phase5B_test_predictions.csv")
cat("\nSaved test predictions to data/analysis/phase5B/phase5B_test_predictions.csv (", nrow(test_pred_all), "rows )\n")

holdout_pred_all <- bind_rows(holdout_pred_list)
write_csv(holdout_pred_all, "data/analysis/phase5B/phase5B_holdout_predictions.csv")
cat("Saved holdout predictions to data/analysis/phase5B/phase5B_holdout_predictions.csv (", nrow(holdout_pred_all), "rows )\n")

# 2. Metrics tables
test_metrics_df <- bind_rows(test_metrics_list)
write_csv(test_metrics_df, "analysis/phase5B/tables/phase5B_test_metrics.csv")
cat("Saved test metrics to analysis/phase5B/tables/phase5B_test_metrics.csv\n")
print(test_metrics_df)

holdout_metrics_df <- bind_rows(holdout_metrics_list)
write_csv(holdout_metrics_df, "analysis/phase5B/tables/phase5B_holdout_metrics.csv")
cat("Saved holdout metrics to analysis/phase5B/tables/phase5B_holdout_metrics.csv\n")
print(holdout_metrics_df)

# 3. Support vector summary
sv_summary_df <- bind_rows(sv_summary_list)
write_csv(sv_summary_df, "analysis/phase5B/tables/phase5B_support_vector_summary.csv")
cat("Saved support vector summary to analysis/phase5B/tables/phase5B_support_vector_summary.csv\n")
print(sv_summary_df)

# 4. Scaling parameters
scaling_test_df <- bind_rows(scaling_test_list) %>% select(scope, feature, mean, sd)
write_csv(scaling_test_df, "analysis/phase5B/tables/phase5B_scaling_parameters_test_refit.csv")
cat("Saved scaling parameters (test refit) to analysis/phase5B/tables/phase5B_scaling_parameters_test_refit.csv\n")

scaling_hist_df <- bind_rows(scaling_hist_list) %>% select(scope, feature, mean, sd)
write_csv(scaling_hist_df, "analysis/phase5B/tables/phase5B_scaling_parameters_final_history.csv")
cat("Saved scaling parameters (final history) to analysis/phase5B/tables/phase5B_scaling_parameters_final_history.csv\n")

# -------------------------------------------------------------
# 5. Build Cross-Model Comparison Table (Phase 4 vs Phase 5B)
# -------------------------------------------------------------
phase4_summary_path <- "analysis/phase4C/tables/phase4_supervised_learning_summary.csv"
if (!file.exists(phase4_summary_path)) {
  stop("FATAL: Phase 4 summary table missing: ", phase4_summary_path)
}
p4_summary <- read_csv(phase4_summary_path, show_col_types = FALSE)

comparison_rows <- list()

for (sc in scopes) {
  for (sp in c("TEST", "FINAL_RECENT_HOLDOUT")) {
    svm_metric_row <- if (sp == "TEST") {
      test_metrics_df %>% filter(scope == sc)
    } else {
      holdout_metrics_df %>% filter(scope == sc)
    }
    
    pos_count <- svm_metric_row$positive_n
    svm_pr <- svm_metric_row$PR_AUC
    svm_f1 <- svm_metric_row$F1
    svm_roc <- svm_metric_row$ROC_AUC
    svm_ap <- svm_metric_row$average_precision
    
    # Extract Phase 4 values
    p4_log_row <- p4_summary %>% filter(scope == sc, split == sp, model_name == "MODEL_B")
    p4_pers_row <- p4_summary %>% filter(scope == sc, split == sp, model_name == "PERSISTENCE")
    
    log_pr <- as.numeric(p4_log_row$Logistic_PR_AUC)
    log_f1 <- as.numeric(p4_log_row$Logistic_F1)
    
    pers_pr <- as.numeric(p4_pers_row$Logistic_PR_AUC)
    pers_f1 <- as.numeric(p4_pers_row$Logistic_F1)
    
    diff_pr <- if (!is.na(svm_pr) && !is.na(log_pr)) svm_pr - log_pr else NA_real_
    diff_f1 <- if (!is.na(svm_f1) && !is.na(log_f1)) svm_f1 - log_f1 else NA_real_
    
    comparison_rows[[length(comparison_rows) + 1]] <- data.frame(
      scope = sc,
      split = sp,
      positive_n = pos_count,
      svm_ROC_AUC = svm_roc,
      svm_average_precision = svm_ap,
      svm_PR_AUC = svm_pr,
      logistic_PR_AUC = log_pr,
      persistence_PR_AUC = pers_pr,
      svm_F1 = svm_f1,
      logistic_F1 = log_f1,
      persistence_F1 = pers_f1,
      svm_minus_logistic_PR_AUC = diff_pr,
      svm_minus_logistic_F1 = diff_f1,
      stringsAsFactors = FALSE
    )
  }
}

comparison_df <- bind_rows(comparison_rows)
comp_path <- "analysis/phase5B/tables/phase5B_comparison_to_phase4.csv"
write_csv(comparison_df, comp_path)
cat("\nSaved comparison to Phase 4 table: ", comp_path, "\n")
print(comparison_df)

cat(">>> scripts/20c_phase5B_test_holdout_evaluation.R completed successfully.\n")
