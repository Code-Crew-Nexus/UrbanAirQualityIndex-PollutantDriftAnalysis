library(dplyr)
library(readr)
library(yaml)
library(broom)

spec <- read_yaml("config/modeling_specification.yml")
master <- read_csv("data/modeling/phase4A/NextDay_AQI_Modeling_Design_Master.csv", show_col_types = FALSE) %>%
  select(project_station_id, date, target_date, target_adverse_next_day)

hyd_data <- read_csv("data/modeling/phase4A/Hyderabad_Common_Comparison.csv", show_col_types = FALSE) %>%
  inner_join(master, by = c("project_station_id", "date", "target_date"))
ind_data <- read_csv("data/modeling/phase4A/India_Common_Comparison.csv", show_col_types = FALSE) %>%
  inner_join(master, by = c("project_station_id", "date", "target_date"))

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

form_A_str <- gsub("target_aqi_next_day", "target_adverse_next_day", spec$model_A$explicit_formula)
form_B_str <- gsub("target_aqi_next_day", "target_adverse_next_day", spec$model_B$explicit_formula)
form_A <- as.formula(form_A_str)
form_B <- as.formula(form_B_str)

hyd_train <- hyd_data %>% filter(split == "TRAIN")
hyd_val <- hyd_data %>% filter(split == "VALIDATION")
ind_train <- ind_data %>% filter(split == "TRAIN")
ind_val <- ind_data %>% filter(split == "VALIDATION")

cat("Hyderabad Train n:", nrow(hyd_train), " adverse:", sum(hyd_train$target_adverse_next_day), "\n")
cat("India Train n:", nrow(ind_train), " adverse:", sum(ind_train$target_adverse_next_day), "\n")

# Fit Models
hyd_mod_A <- glm(form_A, family = binomial(link = "logit"), data = hyd_train)
hyd_mod_B <- glm(form_B, family = binomial(link = "logit"), data = hyd_train)
ind_mod_A <- glm(form_A, family = binomial(link = "logit"), data = ind_train)
ind_mod_B <- glm(form_B, family = binomial(link = "logit"), data = ind_train)

# Audit
audit <- bind_rows(
  data.frame(scope="HYDERABAD", model="MODEL_A", converged=hyd_mod_A$converged, iter=hyd_mod_A$iter, 
             coef_max=max(abs(coef(hyd_mod_A)), na.rm=T), prob_low=sum(hyd_mod_A$fitted.values < 1e-6), prob_high=sum(hyd_mod_A$fitted.values > 1-1e-6)),
  data.frame(scope="HYDERABAD", model="MODEL_B", converged=hyd_mod_B$converged, iter=hyd_mod_B$iter, 
             coef_max=max(abs(coef(hyd_mod_B)), na.rm=T), prob_low=sum(hyd_mod_B$fitted.values < 1e-6), prob_high=sum(hyd_mod_B$fitted.values > 1-1e-6)),
  data.frame(scope="INDIA", model="MODEL_A", converged=ind_mod_A$converged, iter=ind_mod_A$iter, 
             coef_max=max(abs(coef(ind_mod_A)), na.rm=T), prob_low=sum(ind_mod_A$fitted.values < 1e-6), prob_high=sum(ind_mod_A$fitted.values > 1-1e-6)),
  data.frame(scope="INDIA", model="MODEL_B", converged=ind_mod_B$converged, iter=ind_mod_B$iter, 
             coef_max=max(abs(coef(ind_mod_B)), na.rm=T), prob_low=sum(ind_mod_B$fitted.values < 1e-6), prob_high=sum(ind_mod_B$fitted.values > 1-1e-6))
)
write_csv(audit, "analysis/phase4C/tables/phase4C_fit_stability_audit.csv")

saveRDS(hyd_mod_A, "models/phase4C/hyderabad_model_A_train.rds")
saveRDS(hyd_mod_B, "models/phase4C/hyderabad_model_B_train.rds")
saveRDS(ind_mod_A, "models/phase4C/india_model_A_train.rds")
saveRDS(ind_mod_B, "models/phase4C/india_model_B_train.rds")

extract_coef <- function(mod, scope, mname) {
  tidy(mod) %>% mutate(
    scope = scope, model = mname, log_odds_coefficient = estimate,
    odds_ratio = exp(estimate),
    `95% CI lower` = exp(estimate - 1.96 * std.error),
    `95% CI upper` = exp(estimate + 1.96 * std.error)
  ) %>% select(scope, model, term, log_odds_coefficient, standard_error = std.error, z_value = statistic, classical_p_value = p.value, odds_ratio, `95% CI lower`, `95% CI upper`)
}
write_csv(bind_rows(extract_coef(hyd_mod_A, "HYDERABAD", "MODEL_A"), extract_coef(hyd_mod_B, "HYDERABAD", "MODEL_B"), extract_coef(ind_mod_A, "INDIA", "MODEL_A"), extract_coef(ind_mod_B, "INDIA", "MODEL_B")), "analysis/phase4C/tables/phase4C_training_coefficients.csv")

# Station Prevalence
train_prev <- bind_rows(
  hyd_train %>% group_by(project_station_id) %>% summarize(scope="HYDERABAD", prev = mean(target_adverse_next_day), .groups="drop"),
  ind_train %>% group_by(project_station_id) %>% summarize(scope="INDIA", prev = mean(target_adverse_next_day), .groups="drop")
)
write_csv(train_prev, "analysis/phase4C/tables/phase4C_training_station_prevalence.csv")

# Metrics definitions
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
  sum(diff(rec) * (prec[-1] + prec[-length(prec)]) / 2) # Trapezoidal integration documented
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

process_scope <- function(val_df, mod_A, mod_B, scope, prev_df) {
  actual <- val_df$target_adverse_next_day
  pA <- predict(mod_A, val_df, type="response")
  pB <- predict(mod_B, val_df, type="response")
  pP <- ifelse(val_df$aqi_verified > 100, 1, 0)
  pM <- val_df %>% left_join(prev_df %>% filter(scope==!!scope), by="project_station_id") %>% pull(prev)
  
  metA <- list(ROC_AUC = calc_roc_auc(actual, pA), PR_AUC = calc_pr_auc(actual, pA), avg_prec = calc_avg_prec(actual, pA), Brier = calc_brier(actual, pA), log_loss = calc_log_loss(actual, pA))
  metB <- list(ROC_AUC = calc_roc_auc(actual, pB), PR_AUC = calc_pr_auc(actual, pB), avg_prec = calc_avg_prec(actual, pB), Brier = calc_brier(actual, pB), log_loss = calc_log_loss(actual, pB))
  
  # Select family
  sel_fam <- if (metB$PR_AUC < metA$PR_AUC - 1e-10) "MODEL_A" else "MODEL_B"
  if (abs(metA$PR_AUC - metB$PR_AUC) <= 1e-10) sel_fam <- "MODEL_A"
  
  sel_probs <- if(sel_fam == "MODEL_A") pA else pB
  
  # Select threshold on validation
  cands <- sort(unique(c(sel_probs, 0.1, 0.3, 0.5, 0.7, 0.9)))
  best_thresh <- 0.5; best_bal <- -1
  for(th in cands) {
    cm <- calc_class_metrics(actual, sel_probs, th)
    ba <- cm$balanced_accuracy
    if(!is.na(ba)) {
      if(ba > best_bal + 1e-10) {
        best_bal <- ba; best_thresh <- th
      } else if(abs(ba - best_bal) <= 1e-10) {
        if(abs(th - 0.5) < abs(best_thresh - 0.5) - 1e-10) best_thresh <- th
        else if(abs(abs(th - 0.5) - abs(best_thresh - 0.5)) <= 1e-10 && th < best_thresh) best_thresh <- th
      }
    }
  }
  
  cm_best <- calc_class_metrics(actual, sel_probs, best_thresh)
  
  sel_df <- data.frame(
    scope = scope,
    model_A_validation_ROC_AUC = metA$ROC_AUC, model_A_validation_PR_AUC = metA$PR_AUC, model_A_validation_Brier = metA$Brier, model_A_validation_log_loss = metA$log_loss,
    model_B_validation_ROC_AUC = metB$ROC_AUC, model_B_validation_PR_AUC = metB$PR_AUC, model_B_validation_Brier = metB$Brier, model_B_validation_log_loss = metB$log_loss,
    selected_family = sel_fam, selection_basis = "VALIDATION_PR_AUC"
  )
  
  thresh_df <- data.frame(
    scope = scope, selected_family = sel_fam, validation_PR_AUC = if(sel_fam=="MODEL_A") metA$PR_AUC else metB$PR_AUC,
    selected_threshold = best_thresh, validation_balanced_accuracy = cm_best$balanced_accuracy,
    validation_sensitivity = cm_best$sensitivity, validation_specificity = cm_best$specificity, threshold_selection_rule = "Max Balanced Accuracy"
  )
  
  # Build predictions
  make_pred <- function(probs, mname, th, cls=NULL) {
    p_cls <- if(is.null(cls)) ifelse(probs >= th, 1, 0) else cls
    val_df %>% select(project_station_id, station_name, date, target_date, split, actual_class = target_adverse_next_day) %>%
      mutate(scope = scope, model_name = mname, predicted_probability = probs, selected_threshold = th, predicted_class = p_cls)
  }
  preds <- bind_rows(
    make_pred(pA, "MODEL_A", best_thresh), make_pred(pB, "MODEL_B", best_thresh),
    make_pred(pP, "PERSISTENCE", NA, pP), make_pred(pM, "TRAINING_STATION_PREVALENCE", best_thresh)
  )
  
  make_met <- function(p, cls_pred, mname) {
    mets_prob <- list(ROC_AUC = calc_roc_auc(actual, p), PR_AUC = calc_pr_auc(actual, p), avg_prec = calc_avg_prec(actual, p), Brier = calc_brier(actual, p), log_loss = calc_log_loss(actual, p))
    mets_cls <- calc_class_metrics(actual, p, best_thresh)
    if(mname == "PERSISTENCE") mets_cls <- calc_class_metrics(actual, cls_pred, 0.5) # hard class
    bind_cols(data.frame(scope=scope, model_name=mname), as.data.frame(mets_prob), as.data.frame(mets_cls))
  }
  mets <- bind_rows(
    make_met(pA, NULL, "MODEL_A"), make_met(pB, NULL, "MODEL_B"),
    make_met(pP, pP, "PERSISTENCE"), make_met(pM, NULL, "TRAINING_STATION_PREVALENCE")
  )
  
  list(sel = sel_df, thresh = thresh_df, preds = preds, mets = mets)
}

res_hyd <- process_scope(hyd_val, hyd_mod_A, hyd_mod_B, "HYDERABAD", train_prev)
res_ind <- process_scope(ind_val, ind_mod_A, ind_mod_B, "INDIA", train_prev)

write_csv(bind_rows(res_hyd$sel, res_ind$sel), "data/modeling/phase4C/phase4C_model_selection.csv")
write_csv(bind_rows(res_hyd$thresh, res_ind$thresh), "data/modeling/phase4C/phase4C_threshold_selection.csv")
write_csv(bind_rows(res_hyd$preds, res_ind$preds), "analysis/phase4C/tables/phase4C_validation_predictions.csv")
write_csv(bind_rows(res_hyd$mets, res_ind$mets), "analysis/phase4C/tables/phase4C_validation_metrics.csv")

cfg <- list(
  HYDERABAD = list(selected_family = res_hyd$sel$selected_family, selected_threshold = res_hyd$thresh$selected_threshold, selection_basis = "VALIDATION_PR_AUC"),
  INDIA = list(selected_family = res_ind$sel$selected_family, selected_threshold = res_ind$thresh$selected_threshold, selection_basis = "VALIDATION_PR_AUC")
)
write_yaml(cfg, "config/phase4C_selected_models.yml")

cat("Phase 4C Stage 1 Complete.\n")
