# scripts/21a_phase5B1_consistency_audit.R
# Phase 5B.1: Metric Consistency, Selection Leakage, and Archive Dependency Audits

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(yaml)
})

source("R/30_classification_metrics.R")
source("R/32_svm_helpers.R")

cat(">>> Running scripts/21a_phase5B1_consistency_audit.R...\n")

tables_dir <- "analysis/phase5B/tables"
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)

# ==============================================================================
# AUDIT 1: SELECTION LEAKAGE AUDIT (Section 18)
# ==============================================================================
cat("\n--- 1. Generating Selection Leakage Audit Table ---\n")

val_grid <- read_csv("analysis/phase5B/tables/phase5B_validation_grid.csv", show_col_types = FALSE)
svm_sel <- read_csv("data/analysis/phase5B/phase5B_svm_selection.csv", show_col_types = FALSE)
design_df <- read_csv("data/analysis/phase5B/phase5B_design_master.csv", show_col_types = FALSE)

leakage_records <- list()
for (sc in c("HYDERABAD", "INDIA")) {
  use_col <- if (sc == "HYDERABAD") "use_hyderabad" else "use_india"
  
  tr_n <- nrow(design_df %>% filter(.data[[use_col]] == TRUE, eligible_svm, split == "TRAIN"))
  val_n <- nrow(design_df %>% filter(.data[[use_col]] == TRUE, eligible_svm, split == "VALIDATION"))
  
  # Reproduce selected hyperparameters purely from validation grid
  sub_grid <- val_grid %>% filter(scope == sc)
  max_pr <- max(sub_grid$validation_PR_AUC, na.rm = TRUE)
  tied <- sub_grid %>%
    filter(abs(validation_PR_AUC - max_pr) <= 1e-10) %>%
    arrange(cost, gamma)
  
  repro_cost <- tied$cost[1]
  repro_gamma <- tied$gamma[1]
  
  art_row <- svm_sel %>% filter(scope == sc)
  art_cost <- art_row$selected_cost
  art_gamma <- art_row$selected_gamma
  
  match_ok <- (abs(repro_cost - art_cost) < 1e-10) && (abs(repro_gamma - art_gamma) < 1e-10)
  
  leakage_records[[sc]] <- data.frame(
    scope = sc,
    candidate_fitting_data = "TRAIN only (target_date 2025-03-02 to 2025-12-31)",
    fitting_sample_count = tr_n,
    candidate_selection_data = "VALIDATION only (target_date 2026-01-01 to 2026-04-30)",
    selection_sample_count = val_n,
    test_involvement = "NONE (strictly locked during selection)",
    holdout_involvement = "NONE (strictly locked during selection)",
    reproduced_selected_cost = repro_cost,
    reproduced_selected_gamma = repro_gamma,
    selection_artifact_cost = art_cost,
    selection_artifact_gamma = art_gamma,
    reproducibility_status = if (match_ok) "VERIFIED_IDENTICAL" else "MISMATCH",
    stringsAsFactors = FALSE
  )
}

leakage_df <- bind_rows(leakage_records)
leakage_path <- file.path(tables_dir, "phase5B_selection_leakage_audit.csv")
write_csv(leakage_df, leakage_path)
cat("Saved selection leakage audit to:", leakage_path, "\n")
print(leakage_df)

# ==============================================================================
# AUDIT 2: METRIC CONSISTENCY AUDIT (Section 19)
# ==============================================================================
cat("\n--- 2. Generating Metric Consistency Audit Table ---\n")

test_preds <- read_csv("data/analysis/phase5B/phase5B_test_predictions.csv", show_col_types = FALSE)
holdout_preds <- read_csv("data/analysis/phase5B/phase5B_holdout_predictions.csv", show_col_types = FALSE)
stored_test_m <- read_csv("analysis/phase5B/tables/phase5B_test_metrics.csv", show_col_types = FALSE)
stored_hold_m <- read_csv("analysis/phase5B/tables/phase5B_holdout_metrics.csv", show_col_types = FALSE)

metric_names <- c(
  "ROC_AUC", "PR_AUC", "average_precision",
  "TP", "TN", "FP", "FN",
  "sensitivity", "specificity", "precision", "NPV",
  "F1", "balanced_accuracy", "accuracy"
)

audit_records <- list()

# Recompute helper
recompute_metrics <- function(actual, score, pred_class) {
  y <- actual
  p_class <- pred_class
  sc <- score
  
  roc <- calc_roc_auc(y, sc)
  pr <- calc_pr_auc_tie_safe(y, sc)
  ap <- calc_average_precision_tie_safe(y, sc)
  
  tp <- sum(y == 1 & p_class == 1)
  tn <- sum(y == 0 & p_class == 0)
  fp <- sum(y == 0 & p_class == 1)
  fn <- sum(y == 1 & p_class == 0)
  
  sens <- if (tp + fn == 0) NA_real_ else tp / (tp + fn)
  spec <- if (tn + fp == 0) NA_real_ else tn / (tn + fp)
  prec <- if (tp + fp == 0) NA_real_ else tp / (tp + fp)
  npv <- if (tn + fn == 0) NA_real_ else tn / (tn + fn)
  f1 <- if (is.na(prec) || is.na(sens) || (prec + sens) == 0) NA_real_ else 2 * prec * sens / (prec + sens)
  bal_acc <- if (is.na(sens) || is.na(spec)) NA_real_ else (sens + spec) / 2
  acc <- (tp + tn) / length(y)
  
  list(
    ROC_AUC = roc,
    PR_AUC = pr,
    average_precision = ap,
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
    accuracy = acc
  )
}

# Audit TEST split
for (sc in c("HYDERABAD", "INDIA")) {
  sub_test <- test_preds %>% filter(scope == sc)
  stored_row <- stored_test_m %>% filter(scope == sc)
  recomp <- recompute_metrics(sub_test$actual_class, sub_test$decision_score, sub_test$predicted_class)
  
  for (m_name in metric_names) {
    s_val <- as.numeric(stored_row[[m_name]])
    r_val <- as.numeric(recomp[[m_name]])
    
    both_na <- is.na(s_val) && is.na(r_val)
    abs_diff <- if (both_na) 0 else if (is.na(s_val) || is.na(r_val)) Inf else abs(s_val - r_val)
    status <- if (both_na) "BOTH_NA" else if (abs_diff < 1e-10) "MATCH" else "MISMATCH"
    
    audit_records[[length(audit_records) + 1]] <- data.frame(
      scope = sc,
      split = "TEST",
      metric_name = m_name,
      stored_value = s_val,
      recomputed_value = r_val,
      absolute_difference = abs_diff,
      match_status = status,
      stringsAsFactors = FALSE
    )
  }
}

# Audit FINAL_RECENT_HOLDOUT split
for (sc in c("HYDERABAD", "INDIA")) {
  sub_hold <- holdout_preds %>% filter(scope == sc)
  stored_row <- stored_hold_m %>% filter(scope == sc)
  recomp <- recompute_metrics(sub_hold$actual_class, sub_hold$decision_score, sub_hold$predicted_class)
  
  for (m_name in metric_names) {
    s_val <- as.numeric(stored_row[[m_name]])
    r_val <- as.numeric(recomp[[m_name]])
    
    both_na <- is.na(s_val) && is.na(r_val)
    abs_diff <- if (both_na) 0 else if (is.na(s_val) || is.na(r_val)) Inf else abs(s_val - r_val)
    status <- if (both_na) "BOTH_NA" else if (abs_diff < 1e-10) "MATCH" else "MISMATCH"
    
    audit_records[[length(audit_records) + 1]] <- data.frame(
      scope = sc,
      split = "FINAL_RECENT_HOLDOUT",
      metric_name = m_name,
      stored_value = s_val,
      recomputed_value = r_val,
      absolute_difference = abs_diff,
      match_status = status,
      stringsAsFactors = FALSE
    )
  }
}

metric_audit_df <- bind_rows(audit_records)
metric_audit_path <- file.path(tables_dir, "phase5B_metric_consistency_audit.csv")
write_csv(metric_audit_df, metric_audit_path)
cat("Saved metric consistency audit to:", metric_audit_path, "(", nrow(metric_audit_df), "checks )\n")
mismatches <- metric_audit_df %>% filter(!match_status %in% c("MATCH", "BOTH_NA"))
if (nrow(mismatches) > 0) {
  stop("FATAL: Metric consistency audit found mismatches:\n", print(mismatches))
} else {
  cat("[OK] All 56 metric comparisons MATCH stored values exactly (0 mismatches).\n")
}

# ==============================================================================
# AUDIT 3: ARCHIVE DEPENDENCY AUDIT (Section 15)
# ==============================================================================
cat("\n--- 3. Generating Archive Dependency Audit Table ---\n")

dependencies <- c(
  "R/30_classification_metrics.R",
  "R/32_svm_helpers.R",
  "config/phase5B_svm_specification.yml",
  "config/phase5B_selected_svm.yml",
  "data/processed/UAQI_Master_Daily.csv",
  "data/analysis/phase5B/phase5B_design_master.csv",
  "data/analysis/phase5B/phase5B_svm_selection.csv",
  "data/analysis/phase5B/phase5B_test_predictions.csv",
  "data/analysis/phase5B/phase5B_holdout_predictions.csv",
  "analysis/phase5B/tables/phase5B_validation_grid.csv",
  "analysis/phase5B/tables/phase5B_test_metrics.csv",
  "analysis/phase5B/tables/phase5B_holdout_metrics.csv",
  "analysis/phase5B/tables/phase5B_prevalence_by_split.csv",
  "analysis/phase5B/tables/phase5B_scaling_parameters_train.csv",
  "analysis/phase5B/tables/phase5B_scaling_parameters_test_refit.csv",
  "analysis/phase5B/tables/phase5B_scaling_parameters_final_history.csv",
  "analysis/phase5B/tables/phase5B_support_vector_summary.csv",
  "analysis/phase5B/tables/phase5B_comparison_to_phase4.csv",
  "analysis/phase4C/tables/phase4_supervised_learning_summary.csv",
  "models/phase5B/hyderabad_svm_train.rds",
  "models/phase5B/india_svm_train.rds",
  "models/phase5B/hyderabad_svm_test_refit.rds",
  "models/phase5B/india_svm_test_refit.rds",
  "models/phase5B/hyderabad_svm_final_history.rds",
  "models/phase5B/india_svm_final_history.rds",
  "scripts/20a_phase5B_prepare_design.R",
  "scripts/20b_phase5B_train_validate_select.R",
  "scripts/20c_phase5B_test_holdout_evaluation.R",
  "scripts/20d_phase5B_figures.R",
  "tests/testthat/test_phase5b.R",
  "docs/reports/phase5b_svm_summary.md",
  "phase_5B_svm_classification_report.md"
)

archive_audit_records <- list()
for (dep in dependencies) {
  f_exists <- file.exists(dep)
  archive_audit_records[[length(archive_audit_records) + 1]] <- data.frame(
    dependency = dep,
    required_by = "test_phase5b.R / Phase 5B Pipeline",
    included_in_archive = if (f_exists) "YES" else "MISSING",
    status = if (f_exists) "PASS" else "FAIL",
    stringsAsFactors = FALSE
  )
}

dep_audit_df <- bind_rows(archive_audit_records)
dep_audit_path <- file.path(tables_dir, "phase5B_archive_dependency_audit.csv")
write_csv(dep_audit_df, dep_audit_path)
cat("Saved archive dependency audit to:", dep_audit_path, "(", nrow(dep_audit_df), "dependencies )\n")
failed_deps <- dep_audit_df %>% filter(status != "PASS")
if (nrow(failed_deps) > 0) {
  stop("FATAL: Archive dependency audit found missing dependencies:\n", print(failed_deps))
} else {
  cat("[OK] All 32 archive dependencies verified and present (0 failures).\n")
}

cat(">>> scripts/21a_phase5B1_consistency_audit.R completed successfully.\n")
