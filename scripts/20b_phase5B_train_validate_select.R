# scripts/20b_phase5B_train_validate_select.R
# Phase 5B: Grid Search, Model Fitting, Validation Scoring, and Hyperparameter Selection

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(yaml)
})

source("R/30_classification_metrics.R")
source("R/32_svm_helpers.R")

cat(">>> Running scripts/20b_phase5B_train_validate_select.R...\n")

design_path <- "data/analysis/phase5B/phase5B_design_master.csv"
if (!file.exists(design_path)) {
  stop("FATAL: Design master dataset missing: ", design_path)
}
design_df <- read_csv(design_path, show_col_types = FALSE)

# 1. Setup Hyperparameter Grid
costs <- c(0.25, 1.0, 4.0, 16.0)
gamma_multipliers <- c(0.25, 0.5, 1.0, 2.0, 4.0)

grid_records <- list()
selection_records <- list()
scaling_train_records <- list()
selected_models <- list()

scopes <- c("HYDERABAD", "INDIA")

for (sc in scopes) {
  cat(sprintf("\n=== Processing Scope: %s ===\n", sc))
  use_col <- if (sc == "HYDERABAD") "use_hyderabad" else "use_india"
  
  train_data <- design_df %>% filter(.data[[use_col]] == TRUE, eligible_svm, split == "TRAIN")
  val_data <- design_df %>% filter(.data[[use_col]] == TRUE, eligible_svm, split == "VALIDATION")
  
  # Preprocess: learn parameters strictly from TRAIN
  prep <- prepare_svm_features(train_data, val_data)
  
  # Store training scaling parameters
  scaling_df <- prep$scaling_df %>% mutate(scope = sc)
  scaling_train_records[[sc]] <- scaling_df
  
  base_g <- prep$base_gamma
  cat(sprintf("Scope %s: p = %d encoded features, base_gamma = 1/%d = %.6f\n",
              sc, prep$p, prep$p, base_g))
  
  scope_grid <- list()
  fitted_candidates <- list()
  
  cand_idx <- 0
  for (c_val in costs) {
    for (gm_val in gamma_multipliers) {
      cand_idx <- cand_idx + 1
      g_val <- gm_val * base_g
      
      # Fit candidate model on TRAIN ONLY
      fit_obj <- fit_and_orient_svm(
        X_train = prep$X_train,
        y_train = prep$y_train,
        cost = c_val,
        gamma = g_val,
        seed = 20260925
      )
      
      fitted_candidates[[cand_idx]] <- fit_obj
      
      # Predict on VALIDATION
      val_pred <- predict_oriented_svm(fit_obj, prep$X_eval)
      
      # Decision score ranking metrics
      val_roc_auc <- calc_roc_auc(prep$y_eval, val_pred$decision_score)
      val_pr_auc <- calc_pr_auc_tie_safe(prep$y_eval, val_pred$decision_score)
      val_avg_prec <- calc_average_precision_tie_safe(prep$y_eval, val_pred$decision_score)
      
      # Native separating boundary hard classification metrics
      y_val <- prep$y_eval
      p_class <- val_pred$predicted_class
      
      tp <- sum(y_val == 1 & p_class == 1)
      tn <- sum(y_val == 0 & p_class == 0)
      fp <- sum(y_val == 0 & p_class == 1)
      fn <- sum(y_val == 1 & p_class == 0)
      
      sens <- if (tp + fn == 0) NA_real_ else tp / (tp + fn)
      spec <- if (tn + fp == 0) NA_real_ else tn / (tn + fp)
      prec <- if (tp + fp == 0) NA_real_ else tp / (tp + fp)
      npv <- if (tn + fn == 0) NA_real_ else tn / (tn + fn)
      f1 <- if (is.na(prec) || is.na(sens) || (prec + sens) == 0) NA_real_ else 2 * prec * sens / (prec + sens)
      bal_acc <- if (is.na(sens) || is.na(spec)) NA_real_ else (sens + spec) / 2
      acc <- (tp + tn) / length(y_val)
      
      scope_grid[[cand_idx]] <- data.frame(
        scope = sc,
        cost = c_val,
        gamma = g_val,
        base_gamma = base_g,
        train_n = nrow(prep$X_train),
        validation_n = nrow(prep$X_eval),
        validation_ROC_AUC = val_roc_auc,
        validation_PR_AUC = val_pr_auc,
        validation_average_precision = val_avg_prec,
        validation_accuracy = acc,
        validation_balanced_accuracy = bal_acc,
        validation_sensitivity = sens,
        validation_specificity = spec,
        validation_precision = prec,
        validation_F1 = f1,
        score_orientation_multiplier = fit_obj$score_orientation_multiplier,
        cand_idx = cand_idx,
        stringsAsFactors = FALSE
      )
    }
  }
  
  scope_grid_df <- bind_rows(scope_grid)
  
  # Deterministic Selection Rule:
  # Maximum validation PR-AUC; tie tolerance 1e-10; prefer lower cost, then lower gamma
  max_pr <- max(scope_grid_df$validation_PR_AUC, na.rm = TRUE)
  tied_candidates <- scope_grid_df %>%
    filter(abs(validation_PR_AUC - max_pr) <= 1e-10) %>%
    arrange(cost, gamma)
  
  selected_cand_idx <- tied_candidates$cand_idx[1]
  scope_grid_df <- scope_grid_df %>%
    mutate(selected_candidate = (cand_idx == selected_cand_idx)) %>%
    select(-cand_idx)
  
  grid_records[[sc]] <- scope_grid_df
  
  best_row <- scope_grid_df %>% filter(selected_candidate == TRUE)
  cat(sprintf("[SELECTED] %s: Cost = %.4f, Gamma = %.6f | Val PR-AUC = %.6f, ROC-AUC = %.6f, F1 = %.4f\n",
              sc, best_row$cost, best_row$gamma, best_row$validation_PR_AUC,
              best_row$validation_ROC_AUC, best_row$validation_F1))
  
  # Save selected model fitted on TRAIN ONLY
  best_fit_obj <- fitted_candidates[[selected_cand_idx]]
  saveRDS(best_fit_obj, sprintf("models/phase5B/%s_svm_train.rds", tolower(sc)))
  
  selection_records[[sc]] <- data.frame(
    scope = sc,
    engine = "e1071",
    kernel = "radial",
    selected_cost = best_row$cost,
    selected_gamma = best_row$gamma,
    validation_PR_AUC = best_row$validation_PR_AUC,
    validation_ROC_AUC = best_row$validation_ROC_AUC,
    validation_average_precision = best_row$validation_average_precision,
    selection_basis = "VALIDATION_PR_AUC",
    tie_rule = "higher_PR_AUC_then_lower_cost_then_lower_gamma_tol_1e-10",
    stringsAsFactors = FALSE
  )
}

# 2. Export Training Scaling Parameters
scaling_train_df <- bind_rows(scaling_train_records) %>%
  select(scope, feature, mean, sd)
write_csv(scaling_train_df, "analysis/phase5B/tables/phase5B_scaling_parameters_train.csv")
cat("\nSaved training scaling parameters to analysis/phase5B/tables/phase5B_scaling_parameters_train.csv\n")

# 3. Export Full Validation Grid
validation_grid_df <- bind_rows(grid_records)
write_csv(validation_grid_df, "analysis/phase5B/tables/phase5B_validation_grid.csv")
cat("Saved validation grid to analysis/phase5B/tables/phase5B_validation_grid.csv (", nrow(validation_grid_df), "candidates )\n")

# 4. Export Selection Artifact CSV
selection_df <- bind_rows(selection_records)
write_csv(selection_df, "data/analysis/phase5B/phase5B_svm_selection.csv")
cat("Saved selection summary to data/analysis/phase5B/phase5B_svm_selection.csv\n")
print(selection_df)

# 5. Export Selection YAML
selected_yml <- list(
  selection_metadata = list(
    phase = "5B",
    timestamp = as.character(Sys.time()),
    selection_criterion = "VALIDATION_PR_AUC",
    tie_rule = "higher_PR_AUC_then_lower_cost_then_lower_gamma_tol_1e-10",
    test_leakage = "NONE (TEST and HOLDOUT strictly locked)"
  ),
  hyderabad = list(
    engine = "e1071",
    kernel = "radial",
    cost = selection_df$selected_cost[selection_df$scope == "HYDERABAD"],
    gamma = selection_df$selected_gamma[selection_df$scope == "HYDERABAD"],
    validation_PR_AUC = selection_df$validation_PR_AUC[selection_df$scope == "HYDERABAD"],
    validation_ROC_AUC = selection_df$validation_ROC_AUC[selection_df$scope == "HYDERABAD"],
    validation_average_precision = selection_df$validation_average_precision[selection_df$scope == "HYDERABAD"]
  ),
  india = list(
    engine = "e1071",
    kernel = "radial",
    cost = selection_df$selected_cost[selection_df$scope == "INDIA"],
    gamma = selection_df$selected_gamma[selection_df$scope == "INDIA"],
    validation_PR_AUC = selection_df$validation_PR_AUC[selection_df$scope == "INDIA"],
    validation_ROC_AUC = selection_df$validation_ROC_AUC[selection_df$scope == "INDIA"],
    validation_average_precision = selection_df$validation_average_precision[selection_df$scope == "INDIA"]
  )
)
write_yaml(selected_yml, "config/phase5B_selected_svm.yml")
cat("Saved config/phase5B_selected_svm.yml\n")

cat(">>> scripts/20b_phase5B_train_validate_select.R completed successfully.\n")
