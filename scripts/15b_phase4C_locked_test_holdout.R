library(dplyr)
library(readr)
library(yaml)
library(broom)

spec <- read_yaml("config/modeling_specification.yml")
sel <- read_yaml("config/phase4C_selected_models.yml")
master <- read_csv("data/modeling/phase4A/NextDay_AQI_Modeling_Design_Master.csv", show_col_types = FALSE) %>%
  select(project_station_id, date, target_date, target_adverse_next_day)
hyd_data <- read_csv("data/modeling/phase4A/Hyderabad_Common_Comparison.csv", show_col_types = FALSE) %>% inner_join(master, by = c("project_station_id", "date", "target_date"))
ind_data <- read_csv("data/modeling/phase4A/India_Common_Comparison.csv", show_col_types = FALSE) %>% inner_join(master, by = c("project_station_id", "date", "target_date"))

prepare_factors <- function(df, scope) {
  df <- df %>% mutate(day_of_week = factor(day_of_week, levels = c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")))
  if(scope=="HYDERABAD") df$project_station_id <- relevel(factor(df$project_station_id), ref="PROJ_007")
  else df$project_station_id <- relevel(factor(df$project_station_id), ref="PROJ_002")
  df
}
hyd_data <- prepare_factors(hyd_data, "HYDERABAD")
ind_data <- prepare_factors(ind_data, "INDIA")

form_A <- as.formula(gsub("target_aqi_next_day", "target_adverse_next_day", spec$model_A$explicit_formula))
form_B <- as.formula(gsub("target_aqi_next_day", "target_adverse_next_day", spec$model_B$explicit_formula))
hyd_sel_form <- if(sel$HYDERABAD$selected_family == "MODEL_A") form_A else form_B
ind_sel_form <- if(sel$INDIA$selected_family == "MODEL_A") form_A else form_B

hyd_train_val <- hyd_data %>% filter(split %in% c("TRAIN", "VALIDATION"))
hyd_test <- hyd_data %>% filter(split == "TEST")
ind_train_val <- ind_data %>% filter(split %in% c("TRAIN", "VALIDATION"))
ind_test <- ind_data %>% filter(split == "TEST")
train_prev <- read_csv("analysis/phase4C/tables/phase4C_training_station_prevalence.csv", show_col_types=F)

# Refit on TRAIN+VAL
hyd_mod_tv <- glm(hyd_sel_form, family=binomial(link="logit"), data=hyd_train_val)
ind_mod_tv <- glm(ind_sel_form, family=binomial(link="logit"), data=ind_train_val)
saveRDS(hyd_mod_tv, "models/phase4C/hyderabad_selected_train_validation.rds")
saveRDS(ind_mod_tv, "models/phase4C/india_selected_train_validation.rds")

# Functions
calc_roc_auc <- function(actual, pred) {
  if (length(unique(actual)) < 2) return(NA)
  n1 <- sum(actual == 1); n0 <- sum(actual == 0)
  r <- rank(pred)
  s1 <- sum(r[actual == 1])
  (s1 - n1 * (n1 + 1) / 2) / (n1 * n0)
}
calc_pr_auc <- function(actual, pred) {
  if (length(unique(actual)) < 2) return(NA)
  ord <- order(pred, decreasing = TRUE)
  a <- actual[ord]
  tp <- cumsum(a == 1); fp <- cumsum(a == 0)
  rec <- tp / sum(a == 1); prec <- tp / (tp + fp)
  prec[is.na(prec)] <- 0
  rec <- c(0, rec); prec <- c(prec[1], prec)
  sum(diff(rec) * (prec[-1] + prec[-length(prec)]) / 2) 
}
calc_avg_prec <- function(actual, pred) {
  if (length(unique(actual)) < 2) return(NA)
  ord <- order(pred, decreasing = TRUE)
  a <- actual[ord]
  tp <- cumsum(a == 1); fp <- cumsum(a == 0)
  rec <- tp / sum(a == 1); prec <- tp / (tp + fp)
  prec[is.na(prec)] <- 0
  sum(c(rec[1], diff(rec)) * prec)
}
calc_brier <- function(actual, pred) mean((pred - actual)^2, na.rm=T)
calc_log_loss <- function(actual, pred) {
  eps <- 1e-15
  p <- pmax(pmin(pred, 1 - eps), eps)
  -mean(actual * log(p) + (1 - actual) * log(1 - p), na.rm=T)
}
calc_class_metrics <- function(actual, pred_prob, thresh) {
  p_class <- ifelse(pred_prob >= thresh, 1, 0)
  tp <- sum(actual == 1 & p_class == 1); tn <- sum(actual == 0 & p_class == 0)
  fp <- sum(actual == 0 & p_class == 1); fn <- sum(actual == 1 & p_class == 0)
  sens <- if(tp + fn == 0) NA else tp / (tp + fn)
  spec <- if(tn + fp == 0) NA else tn / (tn + fp)
  prec <- if(tp + fp == 0) NA else tp / (tp + fp)
  npv <- if(tn + fn == 0) NA else tn / (tn + fn)
  f1 <- if(is.na(prec) || is.na(sens) || prec+sens == 0) NA else 2 * prec * sens / (prec + sens)
  bal_acc <- if(is.na(sens) || is.na(spec)) NA else (sens + spec) / 2
  acc <- (tp + tn) / length(actual)
  list(TP=tp, TN=tn, FP=fp, FN=fn, sensitivity=sens, specificity=spec, precision=prec, NPV=npv, F1=f1, balanced_accuracy=bal_acc, accuracy=acc)
}

eval_split <- function(df, mod, scope, sel_name, th) {
  actual <- df$target_adverse_next_day
  pS <- predict(mod, df, type="response")
  pP <- ifelse(df$aqi_verified > 100, 1, 0)
  pM <- df %>% left_join(train_prev %>% filter(scope==!!scope), by="project_station_id") %>% pull(prev)
  
  make_pred <- function(probs, mname, cls=NULL) {
    p_cls <- if(is.null(cls)) ifelse(probs >= th, 1, 0) else cls
    df %>% select(project_station_id, station_name, date, target_date, split, actual_class = target_adverse_next_day) %>%
      mutate(scope = scope, model_name = mname, predicted_probability = probs, selected_threshold = th, predicted_class = p_cls)
  }
  preds <- bind_rows(
    make_pred(pS, sel_name), make_pred(pP, "PERSISTENCE", pP), make_pred(pM, "TRAINING_STATION_PREVALENCE")
  )
  
  make_met <- function(p, cls_pred, mname) {
    mp <- list(positive_n = sum(actual==1), ROC_AUC = calc_roc_auc(actual, p), PR_AUC = calc_pr_auc(actual, p), avg_prec = calc_avg_prec(actual, p), Brier = calc_brier(actual, p), log_loss = calc_log_loss(actual, p), mean_prob = mean(p,na.rm=T), max_prob=max(p,na.rm=T), count_pred_adverse = sum(cls_pred==1, na.rm=T))
    mc <- calc_class_metrics(actual, p, th)
    if(mname == "PERSISTENCE") mc <- calc_class_metrics(actual, cls_pred, 0.5)
    bind_cols(data.frame(scope=scope, model_name=mname), as.data.frame(mp), as.data.frame(mc))
  }
  mets <- bind_rows(
    make_met(pS, ifelse(pS>=th,1,0), sel_name), make_met(pP, pP, "PERSISTENCE"), make_met(pM, ifelse(pM>=th,1,0), "TRAINING_STATION_PREVALENCE")
  )
  list(preds=preds, mets=mets)
}

res_hyd_test <- eval_split(hyd_test, hyd_mod_tv, "HYDERABAD", sel$HYDERABAD$selected_family, sel$HYDERABAD$selected_threshold)
res_ind_test <- eval_split(ind_test, ind_mod_tv, "INDIA", sel$INDIA$selected_family, sel$INDIA$selected_threshold)
write_csv(bind_rows(res_hyd_test$preds, res_ind_test$preds), "analysis/phase4C/tables/phase4C_test_predictions.csv")
write_csv(bind_rows(res_hyd_test$mets, res_ind_test$mets), "analysis/phase4C/tables/phase4C_test_metrics.csv")

# Final History Refit
hyd_train_val_test <- hyd_data %>% filter(split %in% c("TRAIN", "VALIDATION", "TEST"))
ind_train_val_test <- ind_data %>% filter(split %in% c("TRAIN", "VALIDATION", "TEST"))
hyd_mod_fin <- glm(hyd_sel_form, family=binomial(link="logit"), data=hyd_train_val_test)
ind_mod_fin <- glm(ind_sel_form, family=binomial(link="logit"), data=ind_train_val_test)
saveRDS(hyd_mod_fin, "models/phase4C/hyderabad_final_history_model.rds")
saveRDS(ind_mod_fin, "models/phase4C/india_final_history_model.rds")

# Holdout
hyd_hold <- hyd_data %>% filter(split == "FINAL_RECENT_HOLDOUT")
ind_hold <- ind_data %>% filter(split == "FINAL_RECENT_HOLDOUT")
res_hyd_hold <- eval_split(hyd_hold, hyd_mod_fin, "HYDERABAD", sel$HYDERABAD$selected_family, sel$HYDERABAD$selected_threshold)
res_ind_hold <- eval_split(ind_hold, ind_mod_fin, "INDIA", sel$INDIA$selected_family, sel$INDIA$selected_threshold)
write_csv(bind_rows(res_hyd_hold$preds, res_ind_hold$preds), "analysis/phase4C/tables/phase4C_holdout_predictions.csv")
write_csv(bind_rows(res_hyd_hold$mets, res_ind_hold$mets), "analysis/phase4C/tables/phase4C_holdout_metrics.csv")

# Station Metrics
st_mets <- function(preds_df) {
  preds_df %>% group_by(scope, project_station_id, split, model_name) %>%
    summarize(
      n = n(), positive_n = sum(actual_class==1), negative_n = sum(actual_class==0),
      Brier = mean((predicted_probability - actual_class)^2),
      TP=sum(actual_class==1 & predicted_class==1), TN=sum(actual_class==0 & predicted_class==0), FP=sum(actual_class==0 & predicted_class==1), FN=sum(actual_class==1 & predicted_class==0),
      sensitivity = if(TP+FN==0) NA else TP/(TP+FN), specificity = if(TN+FP==0) NA else TN/(TN+FP), precision = if(TP+FP==0) NA else TP/(TP+FP),
      F1 = if(is.na(precision)||is.na(sensitivity)||precision+sensitivity==0) NA else 2*precision*sensitivity/(precision+sensitivity),
      balanced_accuracy = if(is.na(sensitivity)||is.na(specificity)) NA else (sensitivity+specificity)/2,
      accuracy = (TP+TN)/n,
      ROC_AUC = calc_roc_auc(actual_class, predicted_probability), PR_AUC = calc_pr_auc(actual_class, predicted_probability),
      .groups="drop"
    ) %>%
    mutate(
      station_metric_status = if_else(n < 10, "STATION_METRIC_LOW_SAMPLE", "ADEQUATE_FOR_DESCRIPTIVE_STATION_METRIC"),
      station_metric_status = if_else(positive_n == 0 | negative_n == 0, paste0(station_metric_status, "|SINGLE_CLASS_METRIC_LIMITATION"), station_metric_status)
    )
}
write_csv(st_mets(bind_rows(res_hyd_test$preds, res_ind_test$preds)), "analysis/phase4C/tables/phase4C_test_station_metrics.csv")
write_csv(st_mets(bind_rows(res_hyd_hold$preds, res_ind_hold$preds)), "analysis/phase4C/tables/phase4C_holdout_station_metrics.csv")

# Prevalence Shift

  
  
shift <- bind_rows(hyd_data %>% mutate(scope="HYDERABAD"), ind_data %>% mutate(scope="INDIA")) %>%
  group_by(scope, split) %>%
  summarize(n = n(), positive_n = sum(target_adverse_next_day), negative_n = n() - positive_n, positive_rate = mean(target_adverse_next_day), .groups="drop")
write_csv(shift, "analysis/phase4C/tables/phase4C_prevalence_shift_summary.csv")

# Calibration
calib <- function(preds_df) {
  preds_df %>% filter(!model_name %in% c("PERSISTENCE", "TRAINING_STATION_PREVALENCE")) %>%
    mutate(bin = cut(predicted_probability, breaks = seq(0, 1, by=0.1), include.lowest=T, right=F, labels=paste0(seq(0, 0.9, 0.1), "-", seq(0.1, 1.0, 0.1)))) %>%
    group_by(scope, split, model_name, bin) %>%
    summarize(n = n(), mean_predicted_probability = mean(predicted_probability), observed_adverse_rate = mean(actual_class), .groups="drop")
}
write_csv(calib(bind_rows(read_csv("analysis/phase4C/tables/phase4C_validation_predictions.csv", show_col_types=F), res_hyd_test$preds, res_ind_test$preds, res_hyd_hold$preds, res_ind_hold$preds)), "analysis/phase4C/tables/phase4C_calibration_by_bin.csv")

cat("Phase 4C Locked Test and Holdout Complete.\n")
