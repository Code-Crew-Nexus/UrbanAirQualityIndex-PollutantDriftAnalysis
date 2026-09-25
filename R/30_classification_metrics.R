library(dplyr)

calc_roc_auc <- function(actual, pred) {
  if (length(unique(actual)) < 2) return(NA_real_)
  n1 <- sum(actual == 1)
  n0 <- sum(actual == 0)
  # rank(ties.method="average") ensures tie-safe ROC AUC via Mann-Whitney U
  r <- rank(pred, ties.method = "average")
  s1 <- sum(r[actual == 1])
  auc <- (s1 - n1 * (n1 + 1) / 2) / (n1 * n0)
  return(auc)
}

calc_pr_curve_data <- function(actual, pred) {
  # Group ties at exact score thresholds
  df <- data.frame(actual = actual, pred = pred)
  
  agg <- df %>% 
    group_by(pred) %>%
    summarize(
      total = n(),
      positives = sum(actual == 1),
      .groups = "drop"
    ) %>%
    arrange(desc(pred))
  
  agg <- agg %>%
    mutate(
      tp = cumsum(positives),
      fp = cumsum(total - positives),
      precision = tp / (tp + fp),
      recall = tp / sum(positives)
    )
  
  # Precision can be NaN if tp+fp=0, which shouldn't happen here since total >= 1 per step
  # but handle NA just in case
  agg$precision[is.na(agg$precision)] <- 0
  
  return(agg)
}

calc_pr_auc_tie_safe <- function(actual, pred) {
  if (length(unique(actual)) < 2) return(NA_real_)
  
  curve <- calc_pr_curve_data(actual, pred)
  rec <- curve$recall
  prec <- curve$precision
  
  # Ensure point at recall=0 for trapezoidal integration
  # By convention, prec[0] is set to prec[1]
  rec <- c(0, rec)
  prec <- c(prec[1], prec)
  
  # Trapezoidal area
  auc <- sum(diff(rec) * (prec[-1] + prec[-length(prec)]) / 2)
  return(auc)
}

calc_average_precision_tie_safe <- function(actual, pred) {
  if (length(unique(actual)) < 2) return(NA_real_)
  
  curve <- calc_pr_curve_data(actual, pred)
  rec <- curve$recall
  prec <- curve$precision
  
  rec <- c(0, rec)
  prec <- c(prec[1], prec)
  
  # Step-wise increment weighting
  rec_diff <- diff(rec)
  # precision_k is prec[-1]
  avg_prec <- sum(rec_diff * prec[-1])
  return(avg_prec)
}

calc_brier <- function(actual, pred) {
  mean((pred - actual)^2, na.rm = TRUE)
}

calc_log_loss <- function(actual, pred) {
  eps <- 1e-15
  p <- pmax(pmin(pred, 1 - eps), eps)
  -mean(actual * log(p) + (1 - actual) * log(1 - p), na.rm = TRUE)
}

calc_class_metrics <- function(actual, pred_prob, thresh) {
  p_class <- ifelse(pred_prob >= thresh, 1, 0)
  tp <- sum(actual == 1 & p_class == 1)
  tn <- sum(actual == 0 & p_class == 0)
  fp <- sum(actual == 0 & p_class == 1)
  fn <- sum(actual == 1 & p_class == 0)
  
  sens <- if(tp + fn == 0) NA_real_ else tp / (tp + fn)
  spec <- if(tn + fp == 0) NA_real_ else tn / (tn + fp)
  prec <- if(tp + fp == 0) NA_real_ else tp / (tp + fp)
  npv <- if(tn + fn == 0) NA_real_ else tn / (tn + fn)
  
  f1 <- if(is.na(prec) || is.na(sens) || prec+sens == 0) NA_real_ else 2 * prec * sens / (prec + sens)
  bal_acc <- if(is.na(sens) || is.na(spec)) NA_real_ else (sens + spec) / 2
  acc <- (tp + tn) / length(actual)
  
  list(TP=tp, TN=tn, FP=fp, FN=fn, 
       sensitivity=sens, specificity=spec, precision=prec, 
       NPV=npv, F1=f1, balanced_accuracy=bal_acc, accuracy=acc)
}

generate_pr_curve <- function(actual, pred) {
  curve <- calc_pr_curve_data(actual, pred)
  rec <- c(0, curve$recall)
  prec <- c(curve$precision[1], curve$precision)
  data.frame(rec = rec, prec = prec)
}

generate_roc_curve <- function(actual, pred) {
  # For exact tie-handling in ROC, group by score similarly
  df <- data.frame(actual = actual, pred = pred)
  agg <- df %>% 
    group_by(pred) %>%
    summarize(
      positives = sum(actual == 1),
      negatives = sum(actual == 0),
      .groups = "drop"
    ) %>%
    arrange(desc(pred)) %>%
    mutate(
      tpr = cumsum(positives) / sum(positives),
      fpr = cumsum(negatives) / sum(negatives)
    )
  tpr <- c(0, agg$tpr)
  fpr <- c(0, agg$fpr)
  data.frame(fpr = fpr, tpr = tpr, prob = c(Inf, agg$pred))
}
