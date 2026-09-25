library(dplyr)
library(readr)
library(ggplot2)
library(tidyr)

dir.create("analysis/phase4B/figures", showWarnings=FALSE, recursive=TRUE)

val_preds <- read_csv("analysis/phase4B/tables/phase4B_validation_predictions.csv", show_col_types=F)
test_preds <- read_csv("analysis/phase4B/tables/phase4B_test_predictions.csv", show_col_types=F)
hold_preds <- read_csv("analysis/phase4B/tables/phase4B_holdout_predictions.csv", show_col_types=F)

val_mets <- read_csv("analysis/phase4B/tables/phase4B_validation_metrics.csv", show_col_types=F)
test_mets <- read_csv("analysis/phase4B/tables/phase4B_test_metrics.csv", show_col_types=F)
hold_mets <- read_csv("analysis/phase4B/tables/phase4B_holdout_metrics.csv", show_col_types=F)
cat_mets <- read_csv("analysis/phase4B/tables/phase4B_error_by_category.csv", show_col_types=F)

# 1. Hyderabad validation actual vs predicted
p1 <- ggplot(val_preds %>% filter(scope == "HYDERABAD", model_name != "TRAINING_STATION_MEAN"), aes(x = actual_aqi, y = prediction, color=model_name)) +
  geom_point(alpha=0.3) + geom_abline(slope=1, intercept=0, linetype="dashed") +
  facet_wrap(~model_name) + theme_minimal() + labs(title="Hyderabad Validation Actual vs Predicted", x="Actual AQI", y="Predicted AQI") + theme(legend.position="none")
ggsave("analysis/phase4B/figures/01_hyderabad_validation_actual_vs_predicted.png", p1, width=8, height=4)

# 2. India validation actual vs predicted
p2 <- ggplot(val_preds %>% filter(scope == "INDIA", model_name != "TRAINING_STATION_MEAN"), aes(x = actual_aqi, y = prediction, color=model_name)) +
  geom_point(alpha=0.3) + geom_abline(slope=1, intercept=0, linetype="dashed") +
  facet_wrap(~model_name) + theme_minimal() + labs(title="India Validation Actual vs Predicted", x="Actual AQI", y="Predicted AQI") + theme(legend.position="none")
ggsave("analysis/phase4B/figures/02_india_validation_actual_vs_predicted.png", p2, width=8, height=4)

# 3. Validation MAE benchmark comparison
p3 <- ggplot(val_mets, aes(x = model_name, y = MAE, fill = scope)) +
  geom_bar(stat="identity", position="dodge") + theme_minimal() + coord_flip() +
  labs(title="Validation MAE Benchmark Comparison", x="Model", y="MAE")
ggsave("analysis/phase4B/figures/03_validation_mae_comparison.png", p3, width=8, height=5)

# 4. Validation RMSE comparison
p4 <- ggplot(val_mets, aes(x = model_name, y = RMSE, fill = scope)) +
  geom_bar(stat="identity", position="dodge") + theme_minimal() + coord_flip() +
  labs(title="Validation RMSE Comparison", x="Model", y="RMSE")
ggsave("analysis/phase4B/figures/04_validation_rmse_comparison.png", p4, width=8, height=5)

# 5. Hyderabad locked TEST actual vs selected
p5 <- ggplot(test_preds %>% filter(scope == "HYDERABAD", !model_name %in% c("PERSISTENCE", "TRAINING_STATION_MEAN")), aes(x = actual_aqi, y = prediction)) +
  geom_point(alpha=0.4, color="blue") + geom_abline(slope=1, intercept=0, linetype="dashed") +
  theme_minimal() + labs(title="Hyderabad TEST Actual vs Selected Prediction", x="Actual AQI", y="Predicted AQI")
ggsave("analysis/phase4B/figures/05_hyderabad_test_actual_vs_selected.png", p5, width=6, height=5)

# 6. India locked TEST actual vs selected
p6 <- ggplot(test_preds %>% filter(scope == "INDIA", !model_name %in% c("PERSISTENCE", "TRAINING_STATION_MEAN")), aes(x = actual_aqi, y = prediction)) +
  geom_point(alpha=0.4, color="darkgreen") + geom_abline(slope=1, intercept=0, linetype="dashed") +
  theme_minimal() + labs(title="India TEST Actual vs Selected Prediction", x="Actual AQI", y="Predicted AQI")
ggsave("analysis/phase4B/figures/06_india_test_actual_vs_selected.png", p6, width=6, height=5)

# 7. TEST benchmark MAE comparison
p7 <- ggplot(test_mets, aes(x = model_name, y = MAE, fill = scope)) +
  geom_bar(stat="identity", position="dodge") + theme_minimal() + coord_flip() +
  labs(title="TEST MAE Benchmark Comparison", x="Model", y="MAE")
ggsave("analysis/phase4B/figures/07_test_mae_comparison.png", p7, width=8, height=5)

# 8. TEST benchmark RMSE comparison
p8 <- ggplot(test_mets, aes(x = model_name, y = RMSE, fill = scope)) +
  geom_bar(stat="identity", position="dodge") + theme_minimal() + coord_flip() +
  labs(title="TEST RMSE Benchmark Comparison", x="Model", y="RMSE")
ggsave("analysis/phase4B/figures/08_test_rmse_comparison.png", p8, width=8, height=5)

# 9. Hyderabad FINAL HOLDOUT time series
p9 <- ggplot(hold_preds %>% filter(scope == "HYDERABAD", !model_name %in% c("TRAINING_STATION_MEAN")), aes(x = target_date)) +
  geom_line(aes(y = actual_aqi), color="black", size=1) +
  geom_line(aes(y = prediction, color=model_name), alpha=0.7) +
  facet_wrap(~project_station_id, scales="free_y") + theme_minimal() +
  labs(title="Hyderabad FINAL HOLDOUT Time Series", x="Date", y="AQI")
ggsave("analysis/phase4B/figures/09_hyderabad_holdout_timeseries.png", p9, width=10, height=6)

# 10. India FINAL HOLDOUT time series
p10 <- ggplot(hold_preds %>% filter(scope == "INDIA", !model_name %in% c("TRAINING_STATION_MEAN")), aes(x = target_date)) +
  geom_line(aes(y = actual_aqi), color="black", size=1) +
  geom_line(aes(y = prediction, color=model_name), alpha=0.7) +
  facet_wrap(~project_station_id, scales="free_y") + theme_minimal() +
  labs(title="India FINAL HOLDOUT Time Series", x="Date", y="AQI")
ggsave("analysis/phase4B/figures/10_india_holdout_timeseries.png", p10, width=12, height=8)

# 11. Final holdout benchmark MAE
p11 <- ggplot(hold_mets, aes(x = model_name, y = MAE, fill = scope)) +
  geom_bar(stat="identity", position="dodge") + theme_minimal() + coord_flip() +
  labs(title="HOLDOUT MAE Benchmark Comparison", x="Model", y="MAE")
ggsave("analysis/phase4B/figures/11_holdout_mae_comparison.png", p11, width=8, height=5)

# 12-15 are already generated in script 14b

# 16. Residual lag-1 autocorrelation by station
ac <- read_csv("analysis/phase4B/tables/phase4B_residual_autocorrelation_by_station.csv", show_col_types=F)
p16 <- ggplot(ac, aes(x = project_station_id, y = lag1, fill = scope)) +
  geom_bar(stat="identity") + coord_flip() + facet_wrap(~scope, scales="free_y") +
  theme_minimal() + labs(title="Residual Lag-1 Autocorrelation by Station", x="Station", y="Lag-1 Correlation") + theme(legend.position="none")
ggsave("analysis/phase4B/figures/16_residual_lag1_autocorr.png", p16, width=10, height=6)

# 17. Coefficient estimate plot - Hyderabad
coefs <- read_csv("analysis/phase4B/tables/phase4B_training_coefficients.csv", show_col_types=F)
p17 <- ggplot(coefs %>% filter(scope == "HYDERABAD", !grepl("project_station_id|Intercept", term)), aes(x = term, y = estimate, color=model_name)) +
  geom_point(position=position_dodge(width=0.5)) + geom_errorbar(aes(ymin=confidence_interval_low, ymax=confidence_interval_high), position=position_dodge(width=0.5), width=0.2) +
  coord_flip() + theme_minimal() + labs(title="Coefficient Estimates - Hyderabad", x="Term", y="Estimate")
ggsave("analysis/phase4B/figures/17_coefficient_estimates_hyderabad.png", p17, width=8, height=6)

# 18. Coefficient estimate plot - India
p18 <- ggplot(coefs %>% filter(scope == "INDIA", !grepl("project_station_id|Intercept", term)), aes(x = term, y = estimate, color=model_name)) +
  geom_point(position=position_dodge(width=0.5)) + geom_errorbar(aes(ymin=confidence_interval_low, ymax=confidence_interval_high), position=position_dodge(width=0.5), width=0.2) +
  coord_flip() + theme_minimal() + labs(title="Coefficient Estimates - India", x="Term", y="Estimate")
ggsave("analysis/phase4B/figures/18_coefficient_estimates_india.png", p18, width=8, height=6)

# 19. Test error by actual AQI category
p19 <- ggplot(cat_mets %>% filter(split == "TEST", !model_name %in% c("TRAINING_STATION_MEAN")), aes(x = target_category_next_day, y = MAE, fill = model_name)) +
  geom_bar(stat="identity", position="dodge") + facet_wrap(~scope, scales="free_x") +
  theme_minimal() + theme(axis.text.x = element_text(angle=45, hjust=1)) +
  labs(title="Test MAE by Actual AQI Category", x="AQI Category", y="MAE")
ggsave("analysis/phase4B/figures/19_test_error_by_category.png", p19, width=10, height=5)

# 20. Prediction residual distribution
p20 <- ggplot(test_preds %>% filter(!model_name %in% c("TRAINING_STATION_MEAN")), aes(x = residual, fill = model_name)) +
  geom_density(alpha=0.4) + facet_wrap(~scope) + theme_minimal() +
  labs(title="Test Residual Distribution", x="Residual (Predicted - Actual)", y="Density")
ggsave("analysis/phase4B/figures/20_prediction_residual_distribution.png", p20, width=10, height=5)

cat("Figures generated.\n")
