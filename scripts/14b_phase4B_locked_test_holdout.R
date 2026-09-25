library(dplyr)
library(readr)
library(yaml)
library(ggplot2)
library(broom)
library(car)

# 1. Configs & Data
spec <- read_yaml("config/modeling_specification.yml")
sel <- read_yaml("config/phase4B_selected_models.yml")
form_A <- as.formula(spec$model_A$explicit_formula)
form_B <- as.formula(spec$model_B$explicit_formula)

hyd_data <- read_csv("data/modeling/phase4A/Hyderabad_Common_Comparison.csv", show_col_types = FALSE)
ind_data <- read_csv("data/modeling/phase4A/India_Common_Comparison.csv", show_col_types = FALSE)
master_full <- read_csv("data/modeling/phase4A/NextDay_AQI_Modeling_Design_Master.csv", show_col_types = FALSE) %>% select(project_station_id, target_date, target_category_next_day)

prepare_factors <- function(df, scope) {
  df <- df %>% mutate(day_of_week = factor(day_of_week, levels = c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")))
  if (scope == "HYDERABAD") {
    df$project_station_id <- relevel(factor(df$project_station_id), ref = "PROJ_007")
  } else {
    df$project_station_id <- relevel(factor(df$project_station_id), ref = "PROJ_002")
  }
  return(df)
}

hyd_data <- prepare_factors(hyd_data, "HYDERABAD")
ind_data <- prepare_factors(ind_data, "INDIA")

hyd_sel_form <- if(sel$HYDERABAD$selected_family == "MODEL_A") form_A else form_B
ind_sel_form <- if(sel$INDIA$selected_family == "MODEL_A") form_A else form_B

hyd_train_val <- hyd_data %>% filter(split %in% c("TRAIN", "VALIDATION"))
hyd_test <- hyd_data %>% filter(split == "TEST")
ind_train_val <- ind_data %>% filter(split %in% c("TRAIN", "VALIDATION"))
ind_test <- ind_data %>% filter(split == "TEST")

train_means <- read_csv("analysis/phase4B/tables/phase4B_training_station_means.csv", show_col_types = FALSE)

# 2. Refit on TRAIN+VALIDATION
hyd_mod_tv <- lm(hyd_sel_form, data = hyd_train_val)
ind_mod_tv <- lm(ind_sel_form, data = ind_train_val)
saveRDS(hyd_mod_tv, "models/phase4B/hyderabad_selected_train_validation.rds")
saveRDS(ind_mod_tv, "models/phase4B/india_selected_train_validation.rds")

# 3. Test Evaluation
calc_metrics <- function(actual, pred) {
  mae <- mean(abs(pred - actual))
  rmse <- sqrt(mean((pred - actual)^2))
  bias <- mean(pred - actual)
  medae <- median(abs(pred - actual))
  r2 <- 1 - sum((actual - pred)^2) / sum((actual - mean(actual))^2)
  list(MAE = mae, RMSE = rmse, bias = bias, median_absolute_error = medae, R2 = r2)
}

eval_split <- function(test_df, mod_tv, scope, means_df, sel_name) {
  pred_M_sel <- predict(mod_tv, test_df)
  pred_P <- test_df$aqi_verified
  
  st_means <- means_df %>% filter(scope == !!scope) %>% select(project_station_id, mean_target)
  test_df <- test_df %>% left_join(st_means, by="project_station_id")
  pred_M <- test_df$mean_target
  actual <- test_df$target_aqi_next_day
  
  mets_sel <- calc_metrics(actual, pred_M_sel)
  mets_P <- calc_metrics(actual, pred_P)
  mets_M <- calc_metrics(actual, pred_M)
  
  mets_sel$MAE_improvement_vs_persistence_pct <- 100 * (mets_P$MAE - mets_sel$MAE) / mets_P$MAE
  mets_sel$RMSE_improvement_vs_persistence_pct <- 100 * (mets_P$RMSE - mets_sel$RMSE) / mets_P$RMSE
  mets_P$MAE_improvement_vs_persistence_pct <- 0
  mets_P$RMSE_improvement_vs_persistence_pct <- 0
  mets_M$MAE_improvement_vs_persistence_pct <- 100 * (mets_P$MAE - mets_M$MAE) / mets_P$MAE
  mets_M$RMSE_improvement_vs_persistence_pct <- 100 * (mets_P$RMSE - mets_M$RMSE) / mets_P$RMSE
  
  preds <- bind_rows(
    test_df %>% select(project_station_id, station_name, date, target_date, split, actual_aqi = target_aqi_next_day) %>% mutate(scope = scope, model_name = sel_name, prediction = pred_M_sel, residual = prediction - actual_aqi),
    test_df %>% select(project_station_id, station_name, date, target_date, split, actual_aqi = target_aqi_next_day) %>% mutate(scope = scope, model_name = "PERSISTENCE", prediction = pred_P, residual = prediction - actual_aqi),
    test_df %>% select(project_station_id, station_name, date, target_date, split, actual_aqi = target_aqi_next_day) %>% mutate(scope = scope, model_name = "TRAINING_STATION_MEAN", prediction = pred_M, residual = prediction - actual_aqi)
  )
  
  mets <- bind_rows(
    as.data.frame(mets_sel) %>% mutate(scope = scope, model_name = sel_name),
    as.data.frame(mets_P) %>% mutate(scope = scope, model_name = "PERSISTENCE"),
    as.data.frame(mets_M) %>% mutate(scope = scope, model_name = "TRAINING_STATION_MEAN")
  )
  
  list(preds = preds, metrics = mets)
}

res_hyd_test <- eval_split(hyd_test, hyd_mod_tv, "HYDERABAD", train_means, sel$HYDERABAD$selected_family)
res_ind_test <- eval_split(ind_test, ind_mod_tv, "INDIA", train_means, sel$INDIA$selected_family)

write_csv(bind_rows(res_hyd_test$preds, res_ind_test$preds), "analysis/phase4B/tables/phase4B_test_predictions.csv")
write_csv(bind_rows(res_hyd_test$metrics, res_ind_test$metrics), "analysis/phase4B/tables/phase4B_test_metrics.csv")

# 4. Diagnostics & Multicollinearity
calc_vif <- function(mod, scope) {
  tryCatch({
    v <- vif(mod)
    v <- as.data.frame(v)
    v$term <- rownames(v)
    v$scope <- scope
    v
  }, error = function(e) { NULL })
}
vif_hyd <- calc_vif(hyd_mod_tv, "HYDERABAD")
vif_ind <- calc_vif(ind_mod_tv, "INDIA")
if(!is.null(vif_hyd) && !is.null(vif_ind)) write_csv(bind_rows(vif_hyd, vif_ind), "analysis/phase4B/tables/phase4B_vif.csv")

calc_autocorr <- function(df, mod) {
  df$res <- residuals(mod)
  df %>% group_by(project_station_id) %>% arrange(target_date) %>%
    summarize(
      lag1 = cor(res, lag(res, 1), use = "complete.obs"),
      lag7 = cor(res, lag(res, 7), use = "complete.obs"),
      .groups="drop"
    )
}
ac_hyd <- calc_autocorr(hyd_train_val, hyd_mod_tv) %>% mutate(scope="HYDERABAD")
ac_ind <- calc_autocorr(ind_train_val, ind_mod_tv) %>% mutate(scope="INDIA")
write_csv(bind_rows(ac_hyd, ac_ind), "analysis/phase4B/tables/phase4B_residual_autocorrelation_by_station.csv")

calc_influence <- function(mod, scope, df) {
  cd <- cooks.distance(mod)
  df$cooks <- cd
  df %>% arrange(desc(cooks)) %>% head(10) %>% 
    select(project_station_id, target_date, target_aqi_next_day, cooks) %>%
    mutate(scope = scope, max_cooks = max(cd, na.rm=T), count_above_thresh = sum(cd > 4/nrow(df), na.rm=T))
}
inf_hyd <- calc_influence(hyd_mod_tv, "HYDERABAD", hyd_train_val)
inf_ind <- calc_influence(ind_mod_tv, "INDIA", ind_train_val)
write_csv(bind_rows(inf_hyd, inf_ind), "analysis/phase4B/tables/phase4B_influence_summary.csv")

# 5. Final History Refit
hyd_train_val_test <- hyd_data %>% filter(split %in% c("TRAIN", "VALIDATION", "TEST"))
ind_train_val_test <- ind_data %>% filter(split %in% c("TRAIN", "VALIDATION", "TEST"))

hyd_mod_final <- lm(hyd_sel_form, data = hyd_train_val_test)
ind_mod_final <- lm(ind_sel_form, data = ind_train_val_test)
saveRDS(hyd_mod_final, "models/phase4B/hyderabad_final_history_model.rds")
saveRDS(ind_mod_final, "models/phase4B/india_final_history_model.rds")

# 6. Final Holdout Evaluation
hyd_holdout <- hyd_data %>% filter(split == "FINAL_RECENT_HOLDOUT")
ind_holdout <- ind_data %>% filter(split == "FINAL_RECENT_HOLDOUT")

res_hyd_hold <- eval_split(hyd_holdout, hyd_mod_final, "HYDERABAD", train_means, sel$HYDERABAD$selected_family)
res_ind_hold <- eval_split(ind_holdout, ind_mod_final, "INDIA", train_means, sel$INDIA$selected_family)

write_csv(bind_rows(res_hyd_hold$preds, res_ind_hold$preds), "analysis/phase4B/tables/phase4B_holdout_predictions.csv")
write_csv(bind_rows(res_hyd_hold$metrics, res_ind_hold$metrics), "analysis/phase4B/tables/phase4B_holdout_metrics.csv")

# 7. Station-level Metrics
station_mets <- function(preds_df) {
  preds_df %>% group_by(scope, project_station_id, split, model_name) %>%
    summarize(
      n = n(),
      MAE = mean(abs(residual)),
      RMSE = sqrt(mean(residual^2)),
      bias = mean(residual),
      median_absolute_error = median(abs(residual)),
      R2 = if(n < 2) NA else (1 - sum(residual^2)/sum((actual_aqi - mean(actual_aqi))^2)),
      .groups = "drop"
    ) %>%
    mutate(station_metric_status = if_else(n >= 10, "ADEQUATE_FOR_DESCRIPTIVE_STATION_METRIC", "STATION_METRIC_LOW_SAMPLE"))
}
st_test <- station_mets(bind_rows(res_hyd_test$preds, res_ind_test$preds))
st_hold <- station_mets(bind_rows(res_hyd_hold$preds, res_ind_hold$preds))
write_csv(st_test, "analysis/phase4B/tables/phase4B_test_station_metrics.csv")
write_csv(st_hold, "analysis/phase4B/tables/phase4B_holdout_station_metrics.csv")

# 8. Error by Actual AQI Category
cat_preds <- bind_rows(res_hyd_test$preds, res_ind_test$preds, res_hyd_hold$preds, res_ind_hold$preds) %>%
  left_join(master_full, by = c("project_station_id", "target_date"))
cat_mets <- cat_preds %>% group_by(scope, split, model_name, target_category_next_day) %>%
  summarize(n = n(), MAE = mean(abs(residual)), RMSE = sqrt(mean(residual^2)), bias = mean(residual), .groups = "drop")
write_csv(cat_mets, "analysis/phase4B/tables/phase4B_error_by_category.csv")

# 9. Final Model Metadata
val_mets <- read_csv("analysis/phase4B/tables/phase4B_validation_metrics.csv", show_col_types = F)
meta_hyd <- tibble(
  scope = "HYDERABAD", selected_model_family = sel$HYDERABAD$selected_family, formula = Reduce(paste, deparse(hyd_sel_form)),
  selection_validation_MAE = val_mets %>% filter(scope=="HYDERABAD", model_name == sel$HYDERABAD$selected_family) %>% pull(MAE),
  selection_validation_RMSE = val_mets %>% filter(scope=="HYDERABAD", model_name == sel$HYDERABAD$selected_family) %>% pull(RMSE),
  test_n = nrow(hyd_test),
  test_MAE = res_hyd_test$metrics %>% filter(model_name == sel$HYDERABAD$selected_family) %>% pull(MAE),
  test_RMSE = res_hyd_test$metrics %>% filter(model_name == sel$HYDERABAD$selected_family) %>% pull(RMSE),
  test_R2 = res_hyd_test$metrics %>% filter(model_name == sel$HYDERABAD$selected_family) %>% pull(R2),
  test_MAE_vs_persistence_pct = res_hyd_test$metrics %>% filter(model_name == sel$HYDERABAD$selected_family) %>% pull(MAE_improvement_vs_persistence_pct),
  holdout_n = nrow(hyd_holdout),
  holdout_MAE = res_hyd_hold$metrics %>% filter(model_name == sel$HYDERABAD$selected_family) %>% pull(MAE),
  holdout_RMSE = res_hyd_hold$metrics %>% filter(model_name == sel$HYDERABAD$selected_family) %>% pull(RMSE),
  holdout_R2 = res_hyd_hold$metrics %>% filter(model_name == sel$HYDERABAD$selected_family) %>% pull(R2),
  holdout_MAE_vs_persistence_pct = res_hyd_hold$metrics %>% filter(model_name == sel$HYDERABAD$selected_family) %>% pull(MAE_improvement_vs_persistence_pct),
  training_history_end = "2026-08-31", aqi_policy = spec$aqi_policy
)

meta_ind <- tibble(
  scope = "INDIA", selected_model_family = sel$INDIA$selected_family, formula = Reduce(paste, deparse(ind_sel_form)),
  selection_validation_MAE = val_mets %>% filter(scope=="INDIA", model_name == sel$INDIA$selected_family) %>% pull(MAE),
  selection_validation_RMSE = val_mets %>% filter(scope=="INDIA", model_name == sel$INDIA$selected_family) %>% pull(RMSE),
  test_n = nrow(ind_test),
  test_MAE = res_ind_test$metrics %>% filter(model_name == sel$INDIA$selected_family) %>% pull(MAE),
  test_RMSE = res_ind_test$metrics %>% filter(model_name == sel$INDIA$selected_family) %>% pull(RMSE),
  test_R2 = res_ind_test$metrics %>% filter(model_name == sel$INDIA$selected_family) %>% pull(R2),
  test_MAE_vs_persistence_pct = res_ind_test$metrics %>% filter(model_name == sel$INDIA$selected_family) %>% pull(MAE_improvement_vs_persistence_pct),
  holdout_n = nrow(ind_holdout),
  holdout_MAE = res_ind_hold$metrics %>% filter(model_name == sel$INDIA$selected_family) %>% pull(MAE),
  holdout_RMSE = res_ind_hold$metrics %>% filter(model_name == sel$INDIA$selected_family) %>% pull(RMSE),
  holdout_R2 = res_ind_hold$metrics %>% filter(model_name == sel$INDIA$selected_family) %>% pull(R2),
  holdout_MAE_vs_persistence_pct = res_ind_hold$metrics %>% filter(model_name == sel$INDIA$selected_family) %>% pull(MAE_improvement_vs_persistence_pct),
  training_history_end = "2026-08-31", aqi_policy = spec$aqi_policy
)
write_csv(bind_rows(meta_hyd, meta_ind), "data/modeling/phase4B/phase4B_final_model_metadata.csv")

# 10. Generate Figures
dir.create("analysis/phase4B/figures", showWarnings=FALSE, recursive=TRUE)

# 12. Residual vs fitted - Hyderabad selected
p12 <- ggplot(data.frame(fit = fitted(hyd_mod_tv), res = residuals(hyd_mod_tv)), aes(x = fit, y = res)) + geom_point(alpha=0.3) + geom_smooth(se=F, color="red") + theme_minimal() + labs(title="Residual vs Fitted - Hyderabad")
ggsave("analysis/phase4B/figures/12_residual_vs_fitted_hyderabad.png", p12, width=6, height=4)

p13 <- ggplot(data.frame(res = scale(residuals(hyd_mod_tv))), aes(sample = res)) + stat_qq() + stat_qq_line(color="red") + theme_minimal() + labs(title="Q-Q - Hyderabad")
ggsave("analysis/phase4B/figures/13_qq_hyderabad.png", p13, width=6, height=4)

p14 <- ggplot(data.frame(fit = fitted(ind_mod_tv), res = residuals(ind_mod_tv)), aes(x = fit, y = res)) + geom_point(alpha=0.3) + geom_smooth(se=F, color="red") + theme_minimal() + labs(title="Residual vs Fitted - India")
ggsave("analysis/phase4B/figures/14_residual_vs_fitted_india.png", p14, width=6, height=4)

p15 <- ggplot(data.frame(res = scale(residuals(ind_mod_tv))), aes(sample = res)) + stat_qq() + stat_qq_line(color="red") + theme_minimal() + labs(title="Q-Q - India")
ggsave("analysis/phase4B/figures/15_qq_india.png", p15, width=6, height=4)

cat("Phase 4B locked evaluation complete.\n")
