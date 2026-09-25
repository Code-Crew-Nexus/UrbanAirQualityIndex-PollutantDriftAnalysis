library(dplyr)
library(readr)
library(yaml)
source("R/30_classification_metrics.R")

dir.create("analysis/phase4C/tables", showWarnings=FALSE, recursive=TRUE)

# Load frozen tables
val_preds <- read_csv("analysis/phase4C/tables/phase4C_validation_predictions.csv", show_col_types=F)
test_preds <- read_csv("analysis/phase4C/tables/phase4C_test_predictions.csv", show_col_types=F)
hold_preds <- read_csv("analysis/phase4C/tables/phase4C_holdout_predictions.csv", show_col_types=F)

val_mets <- read_csv("analysis/phase4C/tables/phase4C_validation_metrics.csv", show_col_types=F)
test_mets <- read_csv("analysis/phase4C/tables/phase4C_test_metrics.csv", show_col_types=F)
hold_mets <- read_csv("analysis/phase4C/tables/phase4C_holdout_metrics.csv", show_col_types=F)

all_preds <- bind_rows(val_preds, test_preds, hold_preds)
all_mets <- bind_rows(
  val_mets %>% mutate(split = "VALIDATION"),
  test_mets %>% mutate(split = "TEST"),
  hold_mets %>% mutate(split = "FINAL_RECENT_HOLDOUT")
)

# 1. Metric Consistency Audit
audit_list <- lapply(unique(all_preds$split), function(spl) {
  df_spl <- all_preds %>% filter(split == spl)
  lapply(unique(df_spl$scope), function(scp) {
    df_scp <- df_spl %>% filter(scope == scp)
    lapply(unique(df_scp$model_name), function(mdl) {
      p_df <- df_scp %>% filter(model_name == mdl)
      actual <- p_df$actual_class
      pred_prob <- p_df$predicted_probability
      
      stored <- all_mets %>% filter(split == spl, scope == scp, model_name == mdl)
      if (nrow(stored) == 0) return(NULL)
      
      recomp_roc <- calc_roc_auc(actual, pred_prob)
      recomp_pr <- calc_pr_auc_tie_safe(actual, pred_prob)
      recomp_ap <- calc_average_precision_tie_safe(actual, pred_prob)
      recomp_br <- calc_brier(actual, pred_prob)
      recomp_ll <- calc_log_loss(actual, pred_prob)
      
      # Handle NA comparisons
      check_match <- function(s, r) {
        if (is.na(s) && is.na(r)) return(TRUE)
        if (is.na(s) || is.na(r)) return(FALSE)
        abs(s - r) < 1e-12
      }
      
      data.frame(
        scope = scp,
        split = spl,
        model_name = mdl,
        stored_ROC_AUC = stored$ROC_AUC[1],
        recomputed_ROC_AUC = recomp_roc,
        ROC_match = check_match(stored$ROC_AUC[1], recomp_roc),
        stored_PR_AUC = stored$PR_AUC[1],
        recomputed_PR_AUC = recomp_pr,
        PR_match = check_match(stored$PR_AUC[1], recomp_pr),
        stored_average_precision = stored$avg_prec[1],
        recomputed_average_precision = recomp_ap,
        AP_match = check_match(stored$avg_prec[1], recomp_ap),
        stored_Brier = stored$Brier[1],
        recomputed_Brier = recomp_br,
        Brier_match = check_match(stored$Brier[1], recomp_br),
        stored_log_loss = stored$log_loss[1],
        recomputed_log_loss = recomp_ll,
        logloss_match = check_match(stored$log_loss[1], recomp_ll)
      )
    }) %>% bind_rows()
  }) %>% bind_rows()
}) %>% bind_rows()

write_csv(audit_list, "analysis/phase4C/tables/phase4C_metric_consistency_audit.csv")

# 2. Threshold Source Audit
build_exact_th_curve <- function(scp) {
  df <- val_preds %>% filter(scope == scp, model_name == "MODEL_B")
  cands <- sort(unique(c(df$predicted_probability, 0.1, 0.3, 0.5, 0.7, 0.9)))
  
  do.call(rbind, lapply(cands, function(th) {
    cm <- calc_class_metrics(df$actual_class, df$predicted_probability, th)
    data.frame(scope = scp, threshold = th, balanced_accuracy = cm$balanced_accuracy, sensitivity = cm$sensitivity, specificity = cm$specificity)
  }))
}
th_data <- bind_rows(build_exact_th_curve("HYDERABAD"), build_exact_th_curve("INDIA"))
write_csv(th_data, "analysis/phase4C/tables/phase4C_threshold_curve_data.csv")

# Verify thresholds logic
sel_cfg <- read_yaml("config/phase4C_selected_models.yml")
for (scp in c("HYDERABAD", "INDIA")) {
  th_scp <- th_data %>% filter(scope == scp)
  max_ba <- max(th_scp$balanced_accuracy, na.rm=T)
  best_cands <- th_scp %>% filter(abs(balanced_accuracy - max_ba) < 1e-10)
  
  best_th <- best_cands$threshold[1]
  if (nrow(best_cands) > 1) {
    # Tie breaking: closest to 0.5, then lower
    dist_05 <- abs(best_cands$threshold - 0.5)
    best_cands <- best_cands[dist_05 == min(dist_05), ]
    best_th <- min(best_cands$threshold)
  }
  
  frozen_th <- sel_cfg[[scp]]$selected_threshold
  if (abs(best_th - frozen_th) > 1e-6) {
    stop(paste("Threshold logic failed for", scp, "Expected:", best_th, "Got:", frozen_th))
  }
}
cat("Threshold logic successfully verified.\n")

# 3. Supervised Learning Summary
mlr_test <- read_csv("analysis/phase4B/tables/phase4B_test_predictions.csv", show_col_types=F)
mlr_hold <- read_csv("analysis/phase4B/tables/phase4B_holdout_predictions.csv", show_col_types=F)

mlr_metrics <- bind_rows(
  mlr_test %>% mutate(split = "TEST"),
  mlr_hold %>% mutate(split = "FINAL_RECENT_HOLDOUT")
) %>%
  filter(model_name %in% c("MODEL_B", "PERSISTENCE")) %>%
  group_by(scope, split, model_name) %>%
  summarize(
    Regression_MAE = mean(abs(prediction - actual_aqi), na.rm=T),
    Regression_RMSE = sqrt(mean((prediction - actual_aqi)^2, na.rm=T)),
    .groups = "drop"
  )

log_metrics <- bind_rows(
  test_mets %>% mutate(split = "TEST"),
  hold_mets %>% mutate(split = "FINAL_RECENT_HOLDOUT")
) %>%
  filter(model_name %in% c("MODEL_B", "PERSISTENCE")) %>%
  select(scope, split, model_name, Logistic_PR_AUC = PR_AUC, Logistic_Brier = Brier, Logistic_F1 = F1)

sl_summary <- full_join(mlr_metrics, log_metrics, by = c("scope", "split", "model_name")) %>%
  arrange(scope, split, desc(model_name))

write_csv(sl_summary, "analysis/phase4C/tables/phase4_supervised_learning_summary.csv")

cat("Consistency Audit and Summaries Complete.\n")
