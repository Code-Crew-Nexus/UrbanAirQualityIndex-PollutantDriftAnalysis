library(dplyr)
library(readr)
library(yaml)
source("R/30_classification_metrics.R")

sel_cfg <- read_yaml("config/phase4C_selected_models.yml")

val_preds <- read_csv("analysis/phase4C/tables/phase4C_validation_predictions.csv", show_col_types=F)
test_preds <- read_csv("analysis/phase4C/tables/phase4C_test_predictions.csv", show_col_types=F)
hold_preds <- read_csv("analysis/phase4C/tables/phase4C_holdout_predictions.csv", show_col_types=F)

# 1. Validation metrics & revalidation
make_met <- function(df, p_col, c_col, mname, scp, th) {
  actual <- df$actual_class
  p <- df[[p_col]]
  cls_pred <- df[[c_col]]
  
  mp <- list(
    positive_n = sum(actual==1),
    ROC_AUC = calc_roc_auc(actual, p),
    PR_AUC = calc_pr_auc_tie_safe(actual, p),
    avg_prec = calc_average_precision_tie_safe(actual, p),
    Brier = calc_brier(actual, p),
    log_loss = calc_log_loss(actual, p),
    mean_prob = mean(p, na.rm=T),
    max_prob = max(p, na.rm=T),
    count_pred_adverse = sum(cls_pred==1, na.rm=T)
  )
  
  if (mname == "PERSISTENCE") {
    mc <- calc_class_metrics(actual, cls_pred, 0.5)
  } else {
    mc <- calc_class_metrics(actual, p, th)
  }
  
  bind_cols(data.frame(scope=scp, model_name=mname), as.data.frame(mp), as.data.frame(mc))
}

process_val <- function(scp) {
  v <- val_preds %>% filter(scope == scp)
  th <- sel_cfg[[scp]]$selected_threshold
  
  mets <- bind_rows(lapply(unique(v$model_name), function(m) {
    v_m <- v %>% filter(model_name == m)
    make_met(v_m, "predicted_probability", "predicted_class", m, scp, th)
  }))
  mets
}

v_hyd <- process_val("HYDERABAD")
v_ind <- process_val("INDIA")
v_all <- bind_rows(v_hyd, v_ind)
write_csv(v_all, "analysis/phase4C/tables/phase4C_validation_metrics.csv")

# Verify model selection stays Model B
hyd_A_pr <- v_hyd %>% filter(model_name == "MODEL_A") %>% pull(PR_AUC)
hyd_B_pr <- v_hyd %>% filter(model_name == "MODEL_B") %>% pull(PR_AUC)
ind_A_pr <- v_ind %>% filter(model_name == "MODEL_A") %>% pull(PR_AUC)
ind_B_pr <- v_ind %>% filter(model_name == "MODEL_B") %>% pull(PR_AUC)

cat("Hyd A:", hyd_A_pr, "B:", hyd_B_pr, "\n")
cat("Ind A:", ind_A_pr, "B:", ind_B_pr, "\n")
if (hyd_B_pr <= hyd_A_pr || ind_B_pr <= ind_A_pr) {
  stop("Model B is no longer the best by PR-AUC. REPAIR ABORTED.")
}

# Threshold selection consistency check
th_hyd <- sel_cfg$HYDERABAD$selected_threshold
th_ind <- sel_cfg$INDIA$selected_threshold
cat("Thresholds check... Hyd:", th_hyd, "Ind:", th_ind, "\n")
bal_acc_hyd <- v_hyd %>% filter(model_name == "MODEL_B") %>% pull(balanced_accuracy)
bal_acc_ind <- v_ind %>% filter(model_name == "MODEL_B") %>% pull(balanced_accuracy)
cat("Validation Bal Acc... Hyd:", bal_acc_hyd, "Ind:", bal_acc_ind, "\n")


# 2. TEST metrics
process_split <- function(df_preds) {
  bind_rows(lapply(unique(df_preds$scope), function(scp) {
    v_s <- df_preds %>% filter(scope == scp)
    th <- sel_cfg[[scp]]$selected_threshold
    bind_rows(lapply(unique(v_s$model_name), function(m) {
      v_m <- v_s %>% filter(model_name == m)
      make_met(v_m, "predicted_probability", "predicted_class", m, scp, th)
    }))
  }))
}

test_mets <- process_split(test_preds)
write_csv(test_mets, "analysis/phase4C/tables/phase4C_test_metrics.csv")

hold_mets <- process_split(hold_preds)
write_csv(hold_mets, "analysis/phase4C/tables/phase4C_holdout_metrics.csv")

# 3. Station metrics
st_mets <- function(preds_df) {
  preds_df %>% group_by(scope, project_station_id, split, model_name) %>%
    summarize(
      n = n(), positive_n = sum(actual_class==1), negative_n = sum(actual_class==0),
      Brier = mean((predicted_probability - actual_class)^2),
      TP=sum(actual_class==1 & predicted_class==1), TN=sum(actual_class==0 & predicted_class==0), 
      FP=sum(actual_class==0 & predicted_class==1), FN=sum(actual_class==1 & predicted_class==0),
      sensitivity = if(TP+FN==0) NA_real_ else TP/(TP+FN), specificity = if(TN+FP==0) NA_real_ else TN/(TN+FP), precision = if(TP+FP==0) NA_real_ else TP/(TP+FP),
      F1 = if(is.na(precision)||is.na(sensitivity)||precision+sensitivity==0) NA_real_ else 2*precision*sensitivity/(precision+sensitivity),
      balanced_accuracy = if(is.na(sensitivity)||is.na(specificity)) NA_real_ else (sensitivity+specificity)/2,
      accuracy = (TP+TN)/n,
      ROC_AUC = calc_roc_auc(actual_class, predicted_probability), 
      PR_AUC = calc_pr_auc_tie_safe(actual_class, predicted_probability),
      average_precision = calc_average_precision_tie_safe(actual_class, predicted_probability),
      .groups="drop"
    ) %>%
    mutate(
      station_metric_status = if_else(n < 10, "STATION_METRIC_LOW_SAMPLE", "ADEQUATE_FOR_DESCRIPTIVE_STATION_METRIC"),
      station_metric_status = if_else(positive_n == 0 | negative_n == 0, paste0(station_metric_status, "|SINGLE_CLASS_METRIC_LIMITATION"), station_metric_status)
    )
}
write_csv(st_mets(test_preds), "analysis/phase4C/tables/phase4C_test_station_metrics.csv")
write_csv(st_mets(hold_preds), "analysis/phase4C/tables/phase4C_holdout_station_metrics.csv")

# 4. Calibration ECE
calib <- read_csv("analysis/phase4C/tables/phase4C_calibration_by_bin.csv", show_col_types=F)
# ECE = sum(n_bin / N * abs(observed_rate - mean_pred_prob))
ece_df <- calib %>%
  group_by(scope, split, model_name) %>%
  mutate(N = sum(n)) %>%
  summarize(
    ECE = sum((n / N[1]) * abs(observed_adverse_rate - mean_predicted_probability)),
    .groups="drop"
  )

# Combine ECE with Brier and positive prevalence
brier_df <- bind_rows(v_all %>% mutate(split="VALIDATION"), test_mets %>% mutate(split="TEST"), hold_mets %>% mutate(split="FINAL_RECENT_HOLDOUT")) %>%
  select(scope, split, model_name, Brier, positive_prevalence = positive_n)

# Wait, prevalence = positive_n / n
counts <- bind_rows(val_preds, test_preds, hold_preds) %>%
  group_by(scope, split, model_name) %>%
  summarize(n_total = n(), pos_rate = mean(actual_class), .groups="drop")

calib_summary <- ece_df %>%
  left_join(brier_df, by=c("scope", "split", "model_name")) %>%
  left_join(counts, by=c("scope", "split", "model_name")) %>%
  mutate(positive_prevalence = pos_rate) %>%
  select(scope, split, model_name, Brier, ECE, positive_prevalence)

write_csv(calib_summary, "analysis/phase4C/tables/phase4C_calibration_summary.csv")

cat("Recomputation Done.\n")
