# scripts/20d_phase5B_figures.R
# Phase 5B: Generate Comprehensive Diagnostic, Evaluation, and Comparison Figures

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(ggplot2)
})

source("R/30_classification_metrics.R")
source("R/32_svm_helpers.R")

cat(">>> Running scripts/20d_phase5B_figures.R...\n")

fig_dir <- "analysis/phase5B/figures"
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
docs_fig_dir <- "docs/figures"
dir.create(docs_fig_dir, recursive = TRUE, showWarnings = FALSE)

# Load data tables
val_grid <- read_csv("analysis/phase5B/tables/phase5B_validation_grid.csv", show_col_types = FALSE)
test_preds <- read_csv("data/analysis/phase5B/phase5B_test_predictions.csv", show_col_types = FALSE)
holdout_preds <- read_csv("data/analysis/phase5B/phase5B_holdout_predictions.csv", show_col_types = FALSE)
comp_df <- read_csv("analysis/phase5B/tables/phase5B_comparison_to_phase4.csv", show_col_types = FALSE)
prev_df <- read_csv("analysis/phase5B/tables/phase5B_prevalence_by_split.csv", show_col_types = FALSE)
sv_df <- read_csv("analysis/phase5B/tables/phase5B_support_vector_summary.csv", show_col_types = FALSE)
test_metrics <- read_csv("analysis/phase5B/tables/phase5B_test_metrics.csv", show_col_types = FALSE)
design_df <- read_csv("data/analysis/phase5B/phase5B_design_master.csv", show_col_types = FALSE)

theme_set(theme_minimal(base_size = 11) +
            theme(plot.title = element_text(face = "bold", size = 12),
                  plot.subtitle = element_text(color = "gray30", size = 10),
                  panel.grid.minor = element_blank()))

# -------------------------------------------------------------
# Figure 01: Hyderabad Validation PR-AUC Heatmap
# -------------------------------------------------------------
hyd_grid <- val_grid %>% filter(scope == "HYDERABAD")
p1 <- ggplot(hyd_grid, aes(x = factor(gamma, labels = sprintf("%.4f", unique(sort(gamma)))),
                           y = factor(cost), fill = validation_PR_AUC)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = sprintf("%.4f\n%s", validation_PR_AUC, ifelse(selected_candidate, "★", ""))),
            size = 3.2, fontface = ifelse(hyd_grid$selected_candidate, "bold", "plain")) +
  scale_fill_viridis_c(option = "magma", name = "PR-AUC") +
  labs(title = "Figure 01: Hyderabad Validation PR-AUC Hyperparameter Grid",
       subtitle = "RBF SVM Cost vs. Gamma (★ = Selected: C=16, γ=0.0100)",
       x = "Gamma (multiplier × base_gamma)", y = "Cost (C)")
ggsave(file.path(fig_dir, "01_hyderabad_validation_prauc_heatmap.png"), p1, width = 7, height = 5, dpi = 300)

# -------------------------------------------------------------
# Figure 02: India Validation PR-AUC Heatmap
# -------------------------------------------------------------
ind_grid <- val_grid %>% filter(scope == "INDIA")
p2 <- ggplot(ind_grid, aes(x = factor(gamma, labels = sprintf("%.4f", unique(sort(gamma)))),
                           y = factor(cost), fill = validation_PR_AUC)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = sprintf("%.4f\n%s", validation_PR_AUC, ifelse(selected_candidate, "★", ""))),
            size = 3.2, fontface = ifelse(ind_grid$selected_candidate, "bold", "plain")) +
  scale_fill_viridis_c(option = "magma", name = "PR-AUC") +
  labs(title = "Figure 02: India Validation PR-AUC Hyperparameter Grid",
       subtitle = "RBF SVM Cost vs. Gamma (★ = Selected: C=4, γ=0.0076)",
       x = "Gamma (multiplier × base_gamma)", y = "Cost (C)")
ggsave(file.path(fig_dir, "02_india_validation_prauc_heatmap.png"), p2, width = 7, height = 5, dpi = 300)

# -------------------------------------------------------------
# Figure 03: Selected Hyperparameters Summary
# -------------------------------------------------------------
sel_summary <- val_grid %>% filter(selected_candidate == TRUE)
p3 <- ggplot(sel_summary, aes(x = scope, y = validation_PR_AUC, fill = scope)) +
  geom_col(width = 0.5, alpha = 0.85) +
  geom_text(aes(label = sprintf("Cost: %g\nGamma: %.4f\nVal PR-AUC: %.4f\nVal ROC-AUC: %.4f\nVal F1: %.4f",
                                cost, gamma, validation_PR_AUC, validation_ROC_AUC, validation_F1)),
            vjust = 1.2, color = "white", fontface = "bold", size = 3.5) +
  scale_fill_manual(values = c("HYDERABAD" = "#2c7bb6", "INDIA" = "#d7191c")) +
  ylim(0, 1.05) +
  labs(title = "Figure 03: Selected Hyperparameter Configuration",
       subtitle = "Primary selection metric: Validation PR-AUC (Higher is better)",
       x = "Scope", y = "Validation PR-AUC", fill = "Scope")
ggsave(file.path(fig_dir, "03_selected_hyperparameters_summary.png"), p3, width = 6.5, height = 5, dpi = 300)

# -------------------------------------------------------------
# Generate Validation Predictions for PR curves
# -------------------------------------------------------------
hyd_train_m <- readRDS("models/phase5B/hyderabad_svm_train.rds")
ind_train_m <- readRDS("models/phase5B/india_svm_train.rds")

hyd_tr_df <- design_df %>% filter(use_hyderabad == TRUE, eligible_svm, split == "TRAIN")
hyd_val_df <- design_df %>% filter(use_hyderabad == TRUE, eligible_svm, split == "VALIDATION")
prep_hyd_v <- prepare_svm_features(hyd_tr_df, hyd_val_df)
pred_hyd_v <- predict_oriented_svm(hyd_train_m, prep_hyd_v$X_eval)

ind_tr_df <- design_df %>% filter(use_india == TRUE, eligible_svm, split == "TRAIN")
ind_val_df <- design_df %>% filter(use_india == TRUE, eligible_svm, split == "VALIDATION")
prep_ind_v <- prepare_svm_features(ind_tr_df, ind_val_df)
pred_ind_v <- predict_oriented_svm(ind_train_m, prep_ind_v$X_eval)

# -------------------------------------------------------------
# Figure 04: Hyderabad Validation PR Curve
# -------------------------------------------------------------
pr_hyd_v <- calc_pr_curve_data(prep_hyd_v$y_eval, pred_hyd_v$decision_score)
p4 <- ggplot(pr_hyd_v, aes(x = recall, y = precision)) +
  geom_line(color = "#2c7bb6", linewidth = 1.2) +
  geom_hline(yintercept = mean(prep_hyd_v$y_eval), linetype = "dashed", color = "gray50") +
  annotate("text", x = 0.6, y = mean(prep_hyd_v$y_eval) + 0.05,
           label = sprintf("Baseline Prevalence = %.3f", mean(prep_hyd_v$y_eval)), color = "gray40") +
  xlim(0, 1) + ylim(0, 1.05) +
  labs(title = "Figure 04: Hyderabad Validation Precision-Recall Curve",
       subtitle = sprintf("PR-AUC = %.4f | AP = %.4f (Validation n = %d, Pos = %d)",
                          calc_pr_auc_tie_safe(prep_hyd_v$y_eval, pred_hyd_v$decision_score),
                          calc_average_precision_tie_safe(prep_hyd_v$y_eval, pred_hyd_v$decision_score),
                          length(prep_hyd_v$y_eval), sum(prep_hyd_v$y_eval)),
       x = "Recall", y = "Precision")
ggsave(file.path(fig_dir, "04_hyderabad_validation_pr_curve.png"), p4, width = 6.5, height = 4.5, dpi = 300)

# -------------------------------------------------------------
# Figure 05: India Validation PR Curve
# -------------------------------------------------------------
pr_ind_v <- calc_pr_curve_data(prep_ind_v$y_eval, pred_ind_v$decision_score)
p5 <- ggplot(pr_ind_v, aes(x = recall, y = precision)) +
  geom_line(color = "#d7191c", linewidth = 1.2) +
  geom_hline(yintercept = mean(prep_ind_v$y_eval), linetype = "dashed", color = "gray50") +
  annotate("text", x = 0.6, y = mean(prep_ind_v$y_eval) - 0.05,
           label = sprintf("Baseline Prevalence = %.3f", mean(prep_ind_v$y_eval)), color = "gray40") +
  xlim(0, 1) + ylim(0, 1.05) +
  labs(title = "Figure 05: India Validation Precision-Recall Curve",
       subtitle = sprintf("PR-AUC = %.4f | AP = %.4f (Validation n = %d, Pos = %d)",
                          calc_pr_auc_tie_safe(prep_ind_v$y_eval, pred_ind_v$decision_score),
                          calc_average_precision_tie_safe(prep_ind_v$y_eval, pred_ind_v$decision_score),
                          length(prep_ind_v$y_eval), sum(prep_ind_v$y_eval)),
       x = "Recall", y = "Precision")
ggsave(file.path(fig_dir, "05_india_validation_pr_curve.png"), p5, width = 6.5, height = 4.5, dpi = 300)

# -------------------------------------------------------------
# Figure 06: Hyderabad TEST PR Curve
# -------------------------------------------------------------
hyd_test_sub <- test_preds %>% filter(scope == "HYDERABAD")
pr_hyd_t <- calc_pr_curve_data(hyd_test_sub$actual_class, hyd_test_sub$decision_score)
p6 <- ggplot(pr_hyd_t, aes(x = recall, y = precision)) +
  geom_line(color = "#2c7bb6", linewidth = 1.2) +
  geom_hline(yintercept = mean(hyd_test_sub$actual_class), linetype = "dashed", color = "gray50") +
  annotate("text", x = 0.5, y = mean(hyd_test_sub$actual_class) + 0.05,
           label = sprintf("Baseline Prevalence = %.3f (Low Prevalence Period)", mean(hyd_test_sub$actual_class)), color = "gray40") +
  xlim(0, 1) + ylim(0, 1.05) +
  labs(title = "Figure 06: Hyderabad Locked TEST Precision-Recall Curve",
       subtitle = sprintf("PR-AUC = %.4f | AP = %.4f (TEST n = %d, Pos = %d)",
                          calc_pr_auc_tie_safe(hyd_test_sub$actual_class, hyd_test_sub$decision_score),
                          calc_average_precision_tie_safe(hyd_test_sub$actual_class, hyd_test_sub$decision_score),
                          nrow(hyd_test_sub), sum(hyd_test_sub$actual_class)),
       x = "Recall", y = "Precision")
ggsave(file.path(fig_dir, "06_hyderabad_test_pr_curve.png"), p6, width = 6.5, height = 4.5, dpi = 300)

# -------------------------------------------------------------
# Figure 07: India TEST PR Curve
# -------------------------------------------------------------
ind_test_sub <- test_preds %>% filter(scope == "INDIA")
pr_ind_t <- calc_pr_curve_data(ind_test_sub$actual_class, ind_test_sub$decision_score)
p7 <- ggplot(pr_ind_t, aes(x = recall, y = precision)) +
  geom_line(color = "#d7191c", linewidth = 1.2) +
  geom_hline(yintercept = mean(ind_test_sub$actual_class), linetype = "dashed", color = "gray50") +
  annotate("text", x = 0.6, y = mean(ind_test_sub$actual_class) - 0.05,
           label = sprintf("Baseline Prevalence = %.3f", mean(ind_test_sub$actual_class)), color = "gray40") +
  xlim(0, 1) + ylim(0, 1.05) +
  labs(title = "Figure 07: India Locked TEST Precision-Recall Curve",
       subtitle = sprintf("PR-AUC = %.4f | AP = %.4f (TEST n = %d, Pos = %d)",
                          calc_pr_auc_tie_safe(ind_test_sub$actual_class, ind_test_sub$decision_score),
                          calc_average_precision_tie_safe(ind_test_sub$actual_class, ind_test_sub$decision_score),
                          nrow(ind_test_sub), sum(ind_test_sub$actual_class)),
       x = "Recall", y = "Precision")
ggsave(file.path(fig_dir, "07_india_test_pr_curve.png"), p7, width = 6.5, height = 4.5, dpi = 300)

# -------------------------------------------------------------
# Figure 08: Hyderabad TEST Confusion Matrix
# -------------------------------------------------------------
hyd_m_row <- test_metrics %>% filter(scope == "HYDERABAD")
cm_hyd <- data.frame(
  Actual = factor(c("Adverse (1)", "Adverse (1)", "Non-Adverse (0)", "Non-Adverse (0)"),
                  levels = c("Non-Adverse (0)", "Adverse (1)")),
  Predicted = factor(c("Adverse (1)", "Non-Adverse (0)", "Adverse (1)", "Non-Adverse (0)"),
                     levels = c("Non-Adverse (0)", "Adverse (1)")),
  Count = c(hyd_m_row$TP, hyd_m_row$FN, hyd_m_row$FP, hyd_m_row$TN)
)
p8 <- ggplot(cm_hyd, aes(x = Predicted, y = Actual, fill = Count)) +
  geom_tile(color = "white", linewidth = 1) +
  geom_text(aes(label = sprintf("%d", Count)), size = 6, fontface = "bold") +
  scale_fill_gradient(low = "#e0f3f8", high = "#2c7bb6") +
  labs(title = "Figure 08: Hyderabad TEST Confusion Matrix",
       subtitle = sprintf("Native Separating Boundary (Accuracy = %.3f, Specificity = %.3f)",
                          hyd_m_row$accuracy, hyd_m_row$specificity),
       x = "Predicted Class", y = "Actual Class")
ggsave(file.path(fig_dir, "08_hyderabad_test_confusion_matrix.png"), p8, width = 5.5, height = 4.5, dpi = 300)

# -------------------------------------------------------------
# Figure 09: India TEST Confusion Matrix
# -------------------------------------------------------------
ind_m_row <- test_metrics %>% filter(scope == "INDIA")
cm_ind <- data.frame(
  Actual = factor(c("Adverse (1)", "Adverse (1)", "Non-Adverse (0)", "Non-Adverse (0)"),
                  levels = c("Non-Adverse (0)", "Adverse (1)")),
  Predicted = factor(c("Adverse (1)", "Non-Adverse (0)", "Adverse (1)", "Non-Adverse (0)"),
                     levels = c("Non-Adverse (0)", "Adverse (1)")),
  Count = c(ind_m_row$TP, ind_m_row$FN, ind_m_row$FP, ind_m_row$TN)
)
p9 <- ggplot(cm_ind, aes(x = Predicted, y = Actual, fill = Count)) +
  geom_tile(color = "white", linewidth = 1) +
  geom_text(aes(label = sprintf("%d", Count)), size = 6, fontface = "bold") +
  scale_fill_gradient(low = "#fee090", high = "#d7191c") +
  labs(title = "Figure 09: India TEST Confusion Matrix",
       subtitle = sprintf("Native Separating Boundary (Accuracy = %.3f, F1 = %.3f, Sens = %.3f, Spec = %.3f)",
                          ind_m_row$accuracy, ind_m_row$F1, ind_m_row$sensitivity, ind_m_row$specificity),
       x = "Predicted Class", y = "Actual Class")
ggsave(file.path(fig_dir, "09_india_test_confusion_matrix.png"), p9, width = 5.5, height = 4.5, dpi = 300)

# -------------------------------------------------------------
# Figure 10: TEST PR-AUC SVM vs Logistic vs Persistence
# -------------------------------------------------------------
comp_test <- comp_df %>% filter(split == "TEST")
prauc_long <- bind_rows(
  data.frame(scope = comp_test$scope, Model = "RBF SVM", PR_AUC = comp_test$svm_PR_AUC),
  data.frame(scope = comp_test$scope, Model = "Logistic Model B", PR_AUC = comp_test$logistic_PR_AUC),
  data.frame(scope = comp_test$scope, Model = "Persistence", PR_AUC = comp_test$persistence_PR_AUC)
)
p10 <- ggplot(prauc_long, aes(x = scope, y = PR_AUC, fill = Model)) +
  geom_col(position = position_dodge(0.8), width = 0.7, alpha = 0.9) +
  geom_text(aes(label = sprintf("%.4f", PR_AUC)),
            position = position_dodge(0.8), vjust = -0.4, size = 3.2, fontface = "bold") +
  scale_fill_manual(values = c("RBF SVM" = "#2b83ba", "Logistic Model B" = "#fdae61", "Persistence" = "#abd9e9")) +
  ylim(0, 1.0) +
  labs(title = "Figure 10: Locked TEST PR-AUC Comparison",
       subtitle = "RBF SVM vs. Logistic Regression Model B vs. AQI Persistence",
       x = "Scope", y = "PR-AUC", fill = "Model")
ggsave(file.path(fig_dir, "10_test_prauc_comparison.png"), p10, width = 7.5, height = 5, dpi = 300)

# -------------------------------------------------------------
# Figure 11: TEST F1 Comparison
# -------------------------------------------------------------
f1_long <- bind_rows(
  data.frame(scope = comp_test$scope, Model = "RBF SVM", F1 = ifelse(is.na(comp_test$svm_F1), 0, comp_test$svm_F1)),
  data.frame(scope = comp_test$scope, Model = "Logistic Model B", F1 = comp_test$logistic_F1),
  data.frame(scope = comp_test$scope, Model = "Persistence", F1 = comp_test$persistence_F1)
)
p11 <- ggplot(f1_long, aes(x = scope, y = F1, fill = Model)) +
  geom_col(position = position_dodge(0.8), width = 0.7, alpha = 0.9) +
  geom_text(aes(label = ifelse(F1 == 0 & scope == "HYDERABAD" & Model == "RBF SVM", "NA", sprintf("%.4f", F1))),
            position = position_dodge(0.8), vjust = -0.4, size = 3.2, fontface = "bold") +
  scale_fill_manual(values = c("RBF SVM" = "#2b83ba", "Logistic Model B" = "#fdae61", "Persistence" = "#abd9e9")) +
  ylim(0, 0.9) +
  labs(title = "Figure 11: Locked TEST F1-Score Comparison",
       subtitle = "Classification Boundary: SVM Native Margin vs. Tuned Logistic vs. Persistence Threshold",
       x = "Scope", y = "F1 Score", fill = "Model")
ggsave(file.path(fig_dir, "11_test_f1_comparison.png"), p11, width = 7.5, height = 5, dpi = 300)

# -------------------------------------------------------------
# Figure 12: India HOLDOUT PR Curve
# -------------------------------------------------------------
ind_hold_sub <- holdout_preds %>% filter(scope == "INDIA")
pr_ind_h <- calc_pr_curve_data(ind_hold_sub$actual_class, ind_hold_sub$decision_score)
p12 <- ggplot(pr_ind_h, aes(x = recall, y = precision)) +
  geom_line(color = "#d7191c", linewidth = 1.2) +
  geom_hline(yintercept = mean(ind_hold_sub$actual_class), linetype = "dashed", color = "gray50") +
  annotate("text", x = 0.6, y = mean(ind_hold_sub$actual_class) + 0.05,
           label = sprintf("Prevalence = %.3f (September Monsoon)", mean(ind_hold_sub$actual_class)), color = "gray40") +
  xlim(0, 1) + ylim(0, 1.05) +
  labs(title = "Figure 12: India September Final Holdout PR Curve",
       subtitle = sprintf("PR-AUC = %.4f | AP = %.4f (Holdout n = %d, Pos = %d)",
                          calc_pr_auc_tie_safe(ind_hold_sub$actual_class, ind_hold_sub$decision_score),
                          calc_average_precision_tie_safe(ind_hold_sub$actual_class, ind_hold_sub$decision_score),
                          nrow(ind_hold_sub), sum(ind_hold_sub$actual_class)),
       x = "Recall", y = "Precision")
ggsave(file.path(fig_dir, "12_india_holdout_pr_curve.png"), p12, width = 6.5, height = 4.5, dpi = 300)

# -------------------------------------------------------------
# Figure 13: India HOLDOUT Comparison
# -------------------------------------------------------------
comp_hold <- comp_df %>% filter(split == "FINAL_RECENT_HOLDOUT", scope == "INDIA")
hold_comp_data <- data.frame(
  Metric = c("PR-AUC", "PR-AUC", "PR-AUC", "F1 Score", "F1 Score", "F1 Score"),
  Model = c("RBF SVM", "Logistic Model B", "Persistence", "RBF SVM", "Logistic Model B", "Persistence"),
  Value = c(comp_hold$svm_PR_AUC, comp_hold$logistic_PR_AUC, comp_hold$persistence_PR_AUC,
            comp_hold$svm_F1, comp_hold$logistic_F1, comp_hold$persistence_F1)
)
p13 <- ggplot(hold_comp_data, aes(x = Metric, y = Value, fill = Model)) +
  geom_col(position = position_dodge(0.8), width = 0.7, alpha = 0.9) +
  geom_text(aes(label = sprintf("%.4f", Value)),
            position = position_dodge(0.8), vjust = -0.4, size = 3.2, fontface = "bold") +
  scale_fill_manual(values = c("RBF SVM" = "#2b83ba", "Logistic Model B" = "#fdae61", "Persistence" = "#abd9e9")) +
  ylim(0, 0.8) +
  labs(title = "Figure 13: India September Final Holdout Performance",
       subtitle = "Evaluation on out-of-distribution monsoon holdout (22 positives / 238 obs)",
       x = "Metric", y = "Value", fill = "Model")
ggsave(file.path(fig_dir, "13_india_holdout_comparison.png"), p13, width = 7, height = 5, dpi = 300)

# -------------------------------------------------------------
# Figure 14: Hyderabad Holdout Decision-Score Distribution
# -------------------------------------------------------------
hyd_hold_sub <- holdout_preds %>% filter(scope == "HYDERABAD")
p14 <- ggplot(hyd_hold_sub, aes(x = decision_score)) +
  geom_histogram(bins = 20, fill = "#2c7bb6", color = "white", alpha = 0.8) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "red", linewidth = 1) +
  annotate("text", x = 0.2, y = 15, label = "Separating Boundary (Score = 0)", color = "red", hjust = 0, size = 3.5) +
  labs(title = "Figure 14: Hyderabad Holdout Decision-Score Distribution",
       subtitle = "All 111 observations are Non-Adverse (Positives = 0; All scores < 0 -> TN = 111, FP = 0)",
       x = "Oriented SVM Decision Score", y = "Count")
ggsave(file.path(fig_dir, "14_hyderabad_holdout_score_distribution.png"), p14, width = 6.5, height = 4.5, dpi = 300)

# -------------------------------------------------------------
# Figure 15: India Holdout Decision-Score Distribution
# -------------------------------------------------------------
ind_hold_sub <- ind_hold_sub %>%
  mutate(Class_Label = ifelse(actual_class == 1, "Adverse (1)", "Non-Adverse (0)"))
p15 <- ggplot(ind_hold_sub, aes(x = decision_score, fill = Class_Label)) +
  geom_density(alpha = 0.5) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "black", linewidth = 1) +
  scale_fill_manual(values = c("Adverse (1)" = "#d7191c", "Non-Adverse (0)" = "#2c7bb6")) +
  labs(title = "Figure 15: India Holdout Decision-Score Distributions by Class",
       subtitle = "Decision boundary at 0 (22 Adverse, 216 Non-Adverse)",
       x = "Oriented SVM Decision Score", y = "Density", fill = "Actual Class")
ggsave(file.path(fig_dir, "15_india_holdout_score_distribution.png"), p15, width = 6.5, height = 4.5, dpi = 300)

# -------------------------------------------------------------
# Figure 16: Adverse Prevalence by Split
# -------------------------------------------------------------
p16 <- ggplot(prev_df, aes(x = factor(split, levels = c("TRAIN", "VALIDATION", "TEST", "FINAL_RECENT_HOLDOUT")),
                           y = positive_rate, fill = scope)) +
  geom_col(position = position_dodge(0.8), width = 0.7, alpha = 0.85) +
  geom_text(aes(label = sprintf("%.1f%%\n(%d/%d)", positive_rate * 100, positive_n, n)),
            position = position_dodge(0.8), vjust = -0.3, size = 3.0, fontface = "bold") +
  scale_fill_manual(values = c("HYDERABAD" = "#2c7bb6", "INDIA" = "#d7191c")) +
  ylim(0, 0.75) +
  labs(title = "Figure 16: Adverse-AQI Event Prevalence Across Chronological Splits",
       subtitle = "Dramatic temporal shifts: winter peak in validation vs. summer/monsoon drop in test and holdout",
       x = "Chronological Split", y = "Adverse Rate (AQI > 100)", fill = "Scope")
ggsave(file.path(fig_dir, "16_adverse_prevalence_by_split.png"), p16, width = 8, height = 5, dpi = 300)

# -------------------------------------------------------------
# Figure 17: Support Vector Proportions
# -------------------------------------------------------------
p17 <- ggplot(sv_df, aes(x = fit_stage, y = sv_proportion, fill = scope)) +
  geom_col(position = position_dodge(0.8), width = 0.7, alpha = 0.85) +
  geom_text(aes(label = sprintf("%.1f%%\n(%d SVs)", sv_proportion * 100, total_support_vectors)),
            position = position_dodge(0.8), vjust = -0.3, size = 3.0, fontface = "bold") +
  scale_fill_manual(values = c("HYDERABAD" = "#2c7bb6", "INDIA" = "#d7191c")) +
  ylim(0, 0.45) +
  labs(title = "Figure 17: Support Vector Proportions Across Refit Stages",
       subtitle = "Proportion of training sample points lying on or within the margin boundary",
       x = "Refit Stage", y = "Support Vector Proportion", fill = "Scope")
ggsave(file.path(fig_dir, "17_support_vector_proportions.png"), p17, width = 7.5, height = 5, dpi = 300)

# -------------------------------------------------------------
# Figure 18: Validation Decision-Score Distributions
# -------------------------------------------------------------
val_preds_combined <- bind_rows(
  data.frame(scope = "HYDERABAD", decision_score = pred_hyd_v$decision_score,
             actual_class = factor(ifelse(prep_hyd_v$y_eval == 1, "Adverse (1)", "Non-Adverse (0)"))),
  data.frame(scope = "INDIA", decision_score = pred_ind_v$decision_score,
             actual_class = factor(ifelse(prep_ind_v$y_eval == 1, "Adverse (1)", "Non-Adverse (0)")))
)
p18 <- ggplot(val_preds_combined, aes(x = decision_score, fill = actual_class)) +
  geom_density(alpha = 0.5) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "black", linewidth = 0.8) +
  facet_wrap(~scope, scales = "free") +
  scale_fill_manual(values = c("Adverse (1)" = "#d7191c", "Non-Adverse (0)" = "#2c7bb6")) +
  labs(title = "Figure 18: Validation Decision-Score Distributions by Class",
       subtitle = "Clear bimodal separation with separation margin centered around 0",
       x = "Oriented SVM Decision Score", y = "Density", fill = "Actual Class")
ggsave(file.path(fig_dir, "18_validation_decision_score_distributions.png"), p18, width = 8, height = 4.5, dpi = 300)

# -------------------------------------------------------------
# Figure 19: TEST Decision-Score Distributions
# -------------------------------------------------------------
test_preds_labeled <- test_preds %>%
  mutate(actual_class_label = factor(ifelse(actual_class == 1, "Adverse (1)", "Non-Adverse (0)")))
p19 <- ggplot(test_preds_labeled, aes(x = decision_score, fill = actual_class_label)) +
  geom_density(alpha = 0.5) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "black", linewidth = 0.8) +
  facet_wrap(~scope, scales = "free") +
  scale_fill_manual(values = c("Adverse (1)" = "#d7191c", "Non-Adverse (0)" = "#2c7bb6")) +
  labs(title = "Figure 19: Locked TEST Decision-Score Distributions by Class",
       subtitle = "Substantial margin overlap in low-prevalence Hyderabad TEST vs. robust separation in India TEST",
       x = "Oriented SVM Decision Score", y = "Density", fill = "Actual Class")
ggsave(file.path(fig_dir, "19_test_decision_score_distributions.png"), p19, width = 8, height = 4.5, dpi = 300)

# -------------------------------------------------------------
# Figure 20: Overall SVM Comparison Summary
# -------------------------------------------------------------
diff_plot_data <- comp_df %>%
  filter(!is.na(svm_minus_logistic_PR_AUC)) %>%
  mutate(label = paste(scope, split, sep = "\n"))
p20 <- ggplot(diff_plot_data, aes(x = label, y = svm_minus_logistic_PR_AUC, fill = svm_minus_logistic_PR_AUC > 0)) +
  geom_col(width = 0.55, alpha = 0.85) +
  geom_hline(yintercept = 0, linetype = "solid", color = "black") +
  geom_text(aes(label = sprintf("%+.4f", svm_minus_logistic_PR_AUC)),
            vjust = ifelse(diff_plot_data$svm_minus_logistic_PR_AUC > 0, -0.4, 1.3),
            size = 3.5, fontface = "bold") +
  scale_fill_manual(values = c("TRUE" = "#2b83ba", "FALSE" = "#d7191c"), guide = "none") +
  ylim(-0.08, 0.04) +
  labs(title = "Figure 20: Overall SVM Discrimination Advantage (Δ PR-AUC: SVM − Logistic)",
       subtitle = "Nonlinear RBF SVM improves ranking on India TEST (+0.0081), but lags during severe low-prevalence shifts",
       x = "Evaluation Cohort", y = "PR-AUC Difference (SVM − Logistic Model B)")
ggsave(file.path(fig_dir, "20_overall_svm_comparison_summary.png"), p20, width = 7.5, height = 5, dpi = 300)

# -------------------------------------------------------------
# Copy Curated Key Figures to docs/figures/
# -------------------------------------------------------------
curated_figs <- c(
  "01_hyderabad_validation_prauc_heatmap.png",
  "02_india_validation_prauc_heatmap.png",
  "07_india_test_pr_curve.png",
  "10_test_prauc_comparison.png",
  "11_test_f1_comparison.png",
  "16_adverse_prevalence_by_split.png",
  "20_overall_svm_comparison_summary.png"
)

for (f in curated_figs) {
  src <- file.path(fig_dir, f)
  dst <- file.path(docs_fig_dir, paste0("phase5b_", f))
  file.copy(src, dst, overwrite = TRUE)
}
cat(sprintf("Copied %d curated figures to docs/figures/ (prefixed with phase5b_)\n", length(curated_figs)))

cat(">>> scripts/20d_phase5B_figures.R completed successfully. All 20 figures generated.\n")
