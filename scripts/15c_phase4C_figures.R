library(dplyr)
library(readr)
library(ggplot2)
library(yaml)
source("R/30_classification_metrics.R")

dir.create("analysis/phase4C/figures", showWarnings=FALSE, recursive=TRUE)

val_preds <- read_csv("analysis/phase4C/tables/phase4C_validation_predictions.csv", show_col_types=F)
test_preds <- read_csv("analysis/phase4C/tables/phase4C_test_predictions.csv", show_col_types=F)
hold_preds <- read_csv("analysis/phase4C/tables/phase4C_holdout_predictions.csv", show_col_types=F)
val_mets <- read_csv("analysis/phase4C/tables/phase4C_validation_metrics.csv", show_col_types=F)
prev <- read_csv("analysis/phase4C/tables/phase4C_prevalence_shift_summary.csv", show_col_types=F)
coefs <- read_csv("analysis/phase4C/tables/phase4C_training_coefficients.csv", show_col_types=F)
calib <- read_csv("analysis/phase4C/tables/phase4C_calibration_by_bin.csv", show_col_types=F)
sel_cfg <- read_yaml("config/phase4C_selected_models.yml")

# 1-4. ROC and PR Curves for Validation
for(scp in c("HYDERABAD", "INDIA")) {
  df_A <- val_preds %>% filter(scope==scp, model_name=="MODEL_A")
  df_B <- val_preds %>% filter(scope==scp, model_name=="MODEL_B")
  
  roc_A <- generate_roc_curve(df_A$actual_class, df_A$predicted_probability) %>% mutate(model="MODEL_A")
  roc_B <- generate_roc_curve(df_B$actual_class, df_B$predicted_probability) %>% mutate(model="MODEL_B")
  pr_A <- generate_pr_curve(df_A$actual_class, df_A$predicted_probability) %>% mutate(model="MODEL_A")
  pr_B <- generate_pr_curve(df_B$actual_class, df_B$predicted_probability) %>% mutate(model="MODEL_B")
  
  p_roc <- ggplot(bind_rows(roc_A, roc_B), aes(x=fpr, y=tpr, color=model)) + geom_line() + geom_abline(slope=1, intercept=0, linetype="dashed") + theme_minimal() + labs(title=paste(scp, "Validation ROC"), x="FPR", y="TPR")
  p_pr <- ggplot(bind_rows(pr_A, pr_B), aes(x=rec, y=prec, color=model)) + geom_line() + theme_minimal() + labs(title=paste(scp, "Validation PR Curve"), x="Recall", y="Precision")
  
  ggsave(paste0("analysis/phase4C/figures/", ifelse(scp=="HYDERABAD", "01", "03"), "_", tolower(scp), "_validation_roc.png"), p_roc, width=6, height=5)
  ggsave(paste0("analysis/phase4C/figures/", ifelse(scp=="HYDERABAD", "02", "04"), "_", tolower(scp), "_validation_pr.png"), p_pr, width=6, height=5)
}

# 5. Validation PR-AUC Model A vs B
p5 <- ggplot(val_mets %>% filter(model_name %in% c("MODEL_A", "MODEL_B")), aes(x=model_name, y=PR_AUC, fill=scope)) + geom_bar(stat="identity", position="dodge") + theme_minimal() + labs(title="Validation PR-AUC Comparison")
ggsave("analysis/phase4C/figures/05_validation_prauc_comparison.png", p5, width=8, height=5)

# 6. Selected threshold balanced-accuracy curve
build_th_curve <- function(scp) {
  df <- val_preds %>% filter(scope==scp, model_name=="MODEL_B")
  ths <- seq(0, 1, by=0.01)
  res <- do.call(rbind, lapply(ths, function(th) {
    cm <- calc_class_metrics(df$actual_class, df$predicted_probability, th)
    data.frame(scope=scp, threshold=th, balanced_accuracy=cm$balanced_accuracy, sensitivity=cm$sensitivity, specificity=cm$specificity)
  }))
  res
}
th_data <- bind_rows(build_th_curve("HYDERABAD"), build_th_curve("INDIA"))
p6 <- ggplot(th_data, aes(x=threshold, y=balanced_accuracy, color=scope)) + geom_line() + 
  geom_vline(data=data.frame(scope=c("HYDERABAD","INDIA"), th=c(sel_cfg$HYDERABAD$selected_threshold, sel_cfg$INDIA$selected_threshold)), aes(xintercept=th, color=scope), linetype="dashed") + 
  theme_minimal() + labs(title="Validation Threshold Selection (Max Balanced Accuracy)", y="Balanced Accuracy")
ggsave("analysis/phase4C/figures/06_selected_threshold_curve.png", p6, width=7, height=5)


# 7-8. TEST confusion matrix
make_cm_plot <- function(df, scp) {
  cm <- df %>% count(actual_class, predicted_class) %>% mutate(actual_class = factor(actual_class), predicted_class = factor(predicted_class))
  ggplot(cm, aes(x=predicted_class, y=actual_class, fill=n, label=n)) + geom_tile() + geom_text(color="white", size=6) + theme_minimal() + labs(title=paste(scp, "TEST Confusion Matrix"))
}
p7 <- make_cm_plot(test_preds %>% filter(scope=="HYDERABAD", !model_name %in% c("PERSISTENCE", "TRAINING_STATION_PREVALENCE")), "Hyderabad")
ggsave("analysis/phase4C/figures/07_hyderabad_test_confusion_matrix.png", p7, width=5, height=4)
p8 <- make_cm_plot(test_preds %>% filter(scope=="INDIA", !model_name %in% c("PERSISTENCE", "TRAINING_STATION_PREVALENCE")), "India")
ggsave("analysis/phase4C/figures/08_india_test_confusion_matrix.png", p8, width=5, height=4)

# 9. India TEST ROC summary
df_ind_test <- test_preds %>% filter(scope=="INDIA", !model_name %in% c("PERSISTENCE", "TRAINING_STATION_PREVALENCE"))
roc_ind_test <- generate_roc_curve(df_ind_test$actual_class, df_ind_test$predicted_probability)
p9 <- ggplot(roc_ind_test, aes(x=fpr, y=tpr)) + geom_line(color="blue") + theme_minimal() + labs(title="India TEST ROC")
ggsave("analysis/phase4C/figures/09_india_test_roc.png", p9, width=5, height=4)

# 10-12. Calibration
p10 <- ggplot(calib %>% filter(scope=="HYDERABAD", split=="VALIDATION"), aes(x=mean_predicted_probability, y=observed_adverse_rate)) + geom_point() + geom_abline(slope=1, intercept=0, linetype="dashed") + theme_minimal() + labs(title="Hyderabad Validation Calibration")
ggsave("analysis/phase4C/figures/10_hyderabad_validation_calibration.png", p10, width=5, height=4)
p11 <- ggplot(calib %>% filter(scope=="INDIA", split=="VALIDATION"), aes(x=mean_predicted_probability, y=observed_adverse_rate)) + geom_point() + geom_abline(slope=1, intercept=0, linetype="dashed") + theme_minimal() + labs(title="India Validation Calibration")
ggsave("analysis/phase4C/figures/11_india_validation_calibration.png", p11, width=5, height=4)
p12 <- ggplot(calib %>% filter(scope=="INDIA", split=="FINAL_RECENT_HOLDOUT"), aes(x=mean_predicted_probability, y=observed_adverse_rate)) + geom_point() + geom_abline(slope=1, intercept=0, linetype="dashed") + theme_minimal() + labs(title="India Holdout Calibration")
ggsave("analysis/phase4C/figures/12_india_holdout_calibration.png", p12, width=5, height=4)

# 13-14. India holdout ROC / PR
df_ind_hold <- hold_preds %>% filter(scope=="INDIA", !model_name %in% c("PERSISTENCE", "TRAINING_STATION_PREVALENCE"))
roc_ind_hold <- generate_roc_curve(df_ind_hold$actual_class, df_ind_hold$predicted_probability)
pr_ind_hold <- generate_pr_curve(df_ind_hold$actual_class, df_ind_hold$predicted_probability)
p13 <- ggplot(roc_ind_hold, aes(x=fpr, y=tpr)) + geom_line(color="blue") + theme_minimal() + labs(title="India Holdout ROC")
ggsave("analysis/phase4C/figures/13_india_holdout_roc.png", p13, width=5, height=4)
p14 <- ggplot(pr_ind_hold, aes(x=rec, y=prec)) + geom_line(color="blue") + theme_minimal() + labs(title="India Holdout PR")
ggsave("analysis/phase4C/figures/14_india_holdout_pr.png", p14, width=5, height=4)

# 15. Adverse prevalence by split
prev$split <- factor(prev$split, levels=c("TRAIN", "VALIDATION", "TEST", "FINAL_RECENT_HOLDOUT"))
p15 <- ggplot(prev, aes(x=split, y=positive_rate, fill=scope)) + geom_bar(stat="identity", position="dodge") + theme_minimal() + labs(title="Adverse Prevalence by Split")
ggsave("analysis/phase4C/figures/15_adverse_prevalence_by_split.png", p15, width=8, height=5)

# 16-17. Odds ratio plot
plot_or <- function(df, scp) {
  ggplot(df %>% filter(!grepl("Intercept|station", term)), aes(x=term, y=odds_ratio)) + geom_point() + geom_errorbar(aes(ymin=`95% CI lower`, ymax=`95% CI upper`), width=0.2) + geom_hline(yintercept=1, linetype="dashed", color="red") + coord_flip() + theme_minimal() + labs(title=paste(scp, "Odds Ratios"))
}
p16 <- plot_or(coefs %>% filter(scope=="HYDERABAD", model==sel_cfg$HYDERABAD$selected_family), "Hyderabad")
ggsave("analysis/phase4C/figures/16_selected_model_or_hyderabad.png", p16, width=6, height=5)
p17 <- plot_or(coefs %>% filter(scope=="INDIA", model==sel_cfg$INDIA$selected_family), "India")
ggsave("analysis/phase4C/figures/17_selected_model_or_india.png", p17, width=6, height=5)

# 18-19. Predicted adverse prob through time
p18 <- ggplot(hold_preds %>% filter(scope=="HYDERABAD", !model_name %in% c("PERSISTENCE", "TRAINING_STATION_PREVALENCE")), aes(x=target_date, y=predicted_probability)) + geom_line() + facet_wrap(~project_station_id) + theme_minimal() + labs(title="Predicted Prob - Hyderabad Holdout (0 Positives)")
ggsave("analysis/phase4C/figures/18_hyderabad_holdout_prob_time.png", p18, width=10, height=6)
p19 <- ggplot(hold_preds %>% filter(scope=="INDIA", !model_name %in% c("PERSISTENCE", "TRAINING_STATION_PREVALENCE")), aes(x=target_date, y=predicted_probability, color=factor(actual_class))) + geom_point() + geom_line(aes(group=1), color="grey") + facet_wrap(~project_station_id) + theme_minimal() + labs(title="Predicted Prob - India Holdout")
ggsave("analysis/phase4C/figures/19_india_holdout_prob_time.png", p19, width=10, height=6)

# 20. Logistic benchmark comparison (Brier on TEST)
test_mets <- read_csv("analysis/phase4C/tables/phase4C_test_metrics.csv", show_col_types=F)
p20 <- ggplot(test_mets, aes(x=model_name, y=Brier, fill=scope)) + geom_bar(stat="identity", position="dodge") + coord_flip() + theme_minimal() + labs(title="Logistic Benchmark Comparison (Brier Score on TEST)")
ggsave("analysis/phase4C/figures/20_logistic_benchmark_comparison.png", p20, width=8, height=5)

cat("Phase 4C.1 Figures Generated.\n")
