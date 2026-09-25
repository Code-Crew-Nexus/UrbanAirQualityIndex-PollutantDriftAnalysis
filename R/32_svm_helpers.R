# R/32_svm_helpers.R
# Phase 5B: Helper Functions for RBF Support Vector Machine Pipeline
# Standardization, One-Hot Encoding, Model Fitting, Decision Value Orientation

suppressPackageStartupMessages({
  library(dplyr)
  library(e1071)
})

# Source tie-safe classification metrics
if (!exists("calc_roc_auc", mode = "function")) {
  metrics_path <- if (file.exists("R/30_classification_metrics.R")) {
    "R/30_classification_metrics.R"
  } else if (file.exists("../R/30_classification_metrics.R")) {
    "../R/30_classification_metrics.R"
  } else {
    stop("Cannot locate R/30_classification_metrics.R")
  }
  source(metrics_path)
}

#' Canonical continuous predictors for Phase 5B
svm_continuous_predictors <- function() {
  c(
    "pm2_5_aqi_input",
    "pm10_aqi_input",
    "o3_8h_max",
    "temperature",
    "humidity",
    "wind_speed",
    "sin_wind_direction",
    "cos_wind_direction",
    "month_sin",
    "month_cos",
    "aqi_verified"
  )
}

#' Prepare standardized and one-hot encoded feature matrices for SVM
#' Preprocessing parameters are strictly learned from train_data
prepare_svm_features <- function(train_data, eval_data = NULL) {
  cont_vars <- svm_continuous_predictors()
  
  # Verify all continuous features exist
  missing_train <- setdiff(cont_vars, names(train_data))
  if (length(missing_train) > 0) {
    stop("Missing continuous features in training data: ", paste(missing_train, collapse = ", "))
  }
  
  # Learn continuous parameters from train_data ONLY
  means <- sapply(train_data[cont_vars], mean, na.rm = TRUE)
  sds <- sapply(train_data[cont_vars], sd, na.rm = TRUE)
  
  # Check zero-variance safety
  zero_sd <- names(sds[sds == 0 | is.na(sds)])
  if (length(zero_sd) > 0) {
    stop("Zero or NA variance detected in training continuous features: ", paste(zero_sd, collapse = ", "))
  }
  
  # Learn categorical factor levels from train_data ONLY
  station_levels <- sort(unique(train_data$project_station_id))
  dow_levels <- sort(unique(train_data$day_of_week))
  
  encode_df <- function(df) {
    # 1. Standardize continuous predictors
    cont_mat <- matrix(0, nrow = nrow(df), ncol = length(cont_vars))
    colnames(cont_mat) <- cont_vars
    for (i in seq_along(cont_vars)) {
      v <- cont_vars[i]
      cont_mat[, i] <- (df[[v]] - means[v]) / sds[v]
    }
    
    # 2. One-hot encode stations
    station_mat <- matrix(0, nrow = nrow(df), ncol = length(station_levels))
    colnames(station_mat) <- paste0("station_", station_levels)
    for (j in seq_along(station_levels)) {
      st <- station_levels[j]
      station_mat[, j] <- as.numeric(df$project_station_id == st)
    }
    
    # 3. One-hot encode day_of_week
    dow_mat <- matrix(0, nrow = nrow(df), ncol = length(dow_levels))
    colnames(dow_mat) <- paste0("dow_", dow_levels)
    for (k in seq_along(dow_levels)) {
      dw <- dow_levels[k]
      dow_mat[, k] <- as.numeric(df$day_of_week == dw)
    }
    
    # Combine into single feature matrix
    cbind(cont_mat, station_mat, dow_mat)
  }
  
  X_train <- encode_df(train_data)
  
  # Check zero-variance dummy columns in train
  col_sds <- apply(X_train, 2, sd)
  zero_cols <- names(col_sds[col_sds == 0 | is.na(col_sds)])
  if (length(zero_cols) > 0) {
    cat("[NOTE] Removing zero-variance training columns:", paste(zero_cols, collapse = ", "), "\n")
    keep_cols <- setdiff(colnames(X_train), zero_cols)
    X_train <- X_train[, keep_cols, drop = FALSE]
  } else {
    keep_cols <- colnames(X_train)
  }
  
  X_eval <- if (!is.null(eval_data)) {
    full_eval <- encode_df(eval_data)
    full_eval[, keep_cols, drop = FALSE]
  } else {
    NULL
  }
  
  y_train <- train_data$target_adverse_next_day
  y_eval <- if (!is.null(eval_data)) eval_data$target_adverse_next_day else NULL
  
  scaling_df <- data.frame(
    feature = cont_vars,
    mean = as.numeric(means),
    sd = as.numeric(sds),
    stringsAsFactors = FALSE
  )
  
  p <- ncol(X_train)
  base_gamma <- 1 / p
  
  list(
    X_train = X_train,
    y_train = y_train,
    X_eval = X_eval,
    y_eval = y_eval,
    scaling_df = scaling_df,
    station_levels = station_levels,
    dow_levels = dow_levels,
    feature_names = keep_cols,
    p = p,
    base_gamma = base_gamma
  )
}

#' Fit an RBF SVM and determine decision score orientation on fitting data
fit_and_orient_svm <- function(X_train, y_train, cost, gamma, seed = 20260925) {
  set.seed(seed)
  
  # Fit RBF classification SVM
  fit <- e1071::svm(
    x = X_train,
    y = factor(y_train, levels = c("0", "1")),
    type = "C-classification",
    kernel = "radial",
    cost = cost,
    gamma = gamma,
    scale = FALSE
  )
  
  # Decision values on training set
  tr_preds <- predict(fit, X_train, decision.values = TRUE)
  raw_dv_tr <- as.numeric(attr(tr_preds, "decision.values"))
  
  # Orient score so higher score = stronger evidence for adverse class (1)
  # Orientation multiplier is determined strictly from training data
  train_auc_raw <- calc_roc_auc(y_train, raw_dv_tr)
  multiplier <- if (!is.na(train_auc_raw) && train_auc_raw < 0.5) -1.0 else 1.0
  
  oriented_dv_tr <- raw_dv_tr * multiplier
  train_auc_oriented <- calc_roc_auc(y_train, oriented_dv_tr)
  
  # Support vector diagnostics
  n_sv_total <- sum(fit$nSV)
  n_sv_per_class <- as.numeric(fit$nSV) # Index 1 is class 0, Index 2 is class 1
  sv_prop <- n_sv_total / nrow(X_train)
  
  list(
    model = fit,
    cost = cost,
    gamma = gamma,
    score_orientation_multiplier = multiplier,
    train_roc_auc_oriented = train_auc_oriented,
    n_support_vectors = n_sv_total,
    n_sv_class_0 = n_sv_per_class[1],
    n_sv_class_1 = n_sv_per_class[2],
    sv_proportion = sv_prop
  )
}

#' Predict with oriented SVM object
predict_oriented_svm <- function(fitted_svm_obj, X_new) {
  preds <- predict(fitted_svm_obj$model, X_new, decision.values = TRUE)
  raw_dv <- as.numeric(attr(preds, "decision.values"))
  oriented_dv <- raw_dv * fitted_svm_obj$score_orientation_multiplier
  pred_class <- as.numeric(as.character(preds))
  
  list(
    decision_score = oriented_dv,
    predicted_class = pred_class
  )
}
