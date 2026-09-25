# ==============================================================================
# scripts/18a_phase5A_pca.R
# Phase 5A: PCA Dimensionality Analysis on Verified Environmental Features
# ==============================================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tibble)
})

cat(">>> Running Phase 5A PCA Pipeline...\n")

# 1. Directories
dir.create("analysis/phase5A/tables", recursive = TRUE, showWarnings = FALSE)
dir.create("analysis/phase5A/figures", recursive = TRUE, showWarnings = FALSE)
dir.create("data/analysis/phase5A", recursive = TRUE, showWarnings = FALSE)
dir.create("models/phase5A", recursive = TRUE, showWarnings = FALSE)

# 2. Load Master Daily Dataset
master_file <- "data/processed/UAQI_Master_Daily.csv"
if (!file.exists(master_file)) {
  stop("Master dataset not found: ", master_file)
}
master_df <- read_csv(master_file, show_col_types = FALSE)

# Exact 6 features
pca_features <- c(
  "pm2_5_aqi_input",
  "pm10_aqi_input",
  "o3_8h_max",
  "temperature",
  "humidity",
  "wind_speed"
)

# Date boundaries
history_start <- as.Date("2025-03-01")
history_end   <- as.Date("2026-08-31")
recent_start  <- as.Date("2026-09-01")
recent_end    <- as.Date("2026-09-21")

# Assign Period
master_df <- master_df %>%
  mutate(
    date = as.Date(date),
    period = case_when(
      date >= history_start & date <= history_end ~ "MODELING_HISTORY",
      date >= recent_start  & date <= recent_end  ~ "RECENT_EVALUATION",
      TRUE ~ "OUT_OF_STUDY_RANGE"
    )
  )

# 3. Eligibility Profile (Missing Data Audit)
scopes <- list(
  HYDERABAD = master_df %>% filter(use_hyderabad, period %in% c("MODELING_HISTORY", "RECENT_EVALUATION")),
  INDIA     = master_df %>% filter(use_india, period %in% c("MODELING_HISTORY", "RECENT_EVALUATION"))
)

eligibility_list <- list()
for (scope_name in names(scopes)) {
  sdf <- scopes[[scope_name]]
  prof <- sdf %>%
    group_by(project_station_id, station_name, period) %>%
    summarise(
      structural_rows = n(),
      complete_rows = sum(complete.cases(across(all_of(pca_features)))),
      incomplete_rows = structural_rows - complete_rows,
      complete_pct = round(100 * complete_rows / structural_rows, 2),
      .groups = "drop"
    ) %>%
    mutate(scope = scope_name) %>%
    select(scope, project_station_id, station_name, period, structural_rows, complete_rows, incomplete_rows, complete_pct)
  
  eligibility_list[[scope_name]] <- prof
}
eligibility_profile <- bind_rows(eligibility_list)
write_csv(eligibility_profile, "analysis/phase5A/tables/phase5A_eligibility_profile.csv")
cat("Saved: phase5A_eligibility_profile.csv\n")

# 4. Standardize, Fit PCA, and Extract Outputs
scaling_params_list <- list()
variance_explained_list <- list()
selection_list <- list()
loadings_list <- list()
loading_summary_list <- list()

for (scope_name in names(scopes)) {
  cat("\n=== Processing Scope:", scope_name, "===\n")
  sdf <- scopes[[scope_name]]
  
  # Separate history and recent complete cases
  history_complete <- sdf %>%
    filter(period == "MODELING_HISTORY") %>%
    filter(complete.cases(across(all_of(pca_features))))
  
  recent_complete <- sdf %>%
    filter(period == "RECENT_EVALUATION") %>%
    filter(complete.cases(across(all_of(pca_features))))
  
  cat("History complete observations:", nrow(history_complete), "\n")
  cat("Recent complete observations:", nrow(recent_complete), "\n")
  
  # Compute scaling parameters from HISTORY ONLY
  scale_stats <- history_complete %>%
    summarise(across(all_of(pca_features), list(mean = ~mean(.x), sd = ~sd(.x))))
  
  means_vec <- numeric(length(pca_features))
  sds_vec   <- numeric(length(pca_features))
  names(means_vec) <- pca_features
  names(sds_vec)   <- pca_features
  
  for (f in pca_features) {
    m_val <- scale_stats[[paste0(f, "_mean")]]
    s_val <- scale_stats[[paste0(f, "_sd")]]
    if (is.na(s_val) || s_val <= 0) {
      stop("Zero or invalid variance detected in feature: ", f, " for scope: ", scope_name)
    }
    means_vec[f] <- m_val
    sds_vec[f]   <- s_val
    
    scaling_params_list[[paste(scope_name, f, sep = "_")]] <- tibble(
      scope = scope_name,
      feature = f,
      training_mean = m_val,
      training_sd = s_val,
      training_n = nrow(history_complete)
    )
  }
  
  # Standardize history data
  X_hist_mat <- as.matrix(history_complete[, pca_features])
  X_hist_std <- scale(X_hist_mat, center = means_vec, scale = sds_vec)
  attr(X_hist_std, "scaled:center") <- NULL
  attr(X_hist_std, "scaled:scale") <- NULL
  
  # Sanity check standardization
  stopifnot(all(abs(colMeans(X_hist_std)) < 1e-10))
  stopifnot(all(abs(apply(X_hist_std, 2, sd) - 1.0) < 1e-10))
  
  # Fit PCA (center = FALSE, scale. = FALSE because already standardized)
  pca_fit <- prcomp(X_hist_std, center = FALSE, scale. = FALSE)
  
  # Save PCA model
  pca_model_file <- paste0("models/phase5A/", tolower(scope_name), "_pca.rds")
  saveRDS(pca_fit, pca_model_file)
  cat("Saved PCA model:", pca_model_file, "\n")
  
  # Variance Explained
  eig_vals <- pca_fit$sdev^2
  var_exp  <- eig_vals / sum(eig_vals)
  cum_var  <- cumsum(var_exp)
  
  var_df <- tibble(
    scope = scope_name,
    PC = paste0("PC", 1:length(eig_vals)),
    eigenvalue = eig_vals,
    variance_explained = var_exp,
    cumulative_variance = cum_var
  )
  variance_explained_list[[scope_name]] <- var_df
  
  # Selection Rule: Smallest number of PCs where cumulative variance >= 80%
  retained_count <- which(cum_var >= 0.80)[1]
  cum_var_sel <- cum_var[retained_count]
  
  cat("Retained PCs (cumulative variance >= 80%):", retained_count, "with", round(100 * cum_var_sel, 2), "%\n")
  
  selection_list[[scope_name]] <- tibble(
    scope = scope_name,
    retained_pc_count = retained_count,
    cumulative_variance_at_selection = cum_var_sel
  )
  
  # Loadings
  rot_mat <- pca_fit$rotation
  for (pc_idx in 1:ncol(rot_mat)) {
    pc_name <- colnames(rot_mat)[pc_idx]
    for (f in pca_features) {
      loadings_list[[paste(scope_name, pc_name, f, sep = "_")]] <- tibble(
        scope = scope_name,
        feature = f,
        PC = pc_name,
        loading = rot_mat[f, pc_idx]
      )
    }
  }
  
  # Loading Interpretation Summary for retained PCs
  for (pc_idx in 1:retained_count) {
    pc_name <- paste0("PC", pc_idx)
    loads <- rot_mat[, pc_idx]
    
    # Largest absolute contributors
    abs_order <- order(abs(loads), decreasing = TRUE)
    top1_feat <- names(loads)[abs_order[1]]
    top1_load <- unname(loads[top1_feat])
    top2_feat <- names(loads)[abs_order[2]]
    top2_load <- unname(loads[top2_feat])
    
    pos_loads <- loads[loads > 0]
    neg_loads <- loads[loads < 0]
    
    pos_top <- if (length(pos_loads) > 0) names(pos_loads)[which.max(pos_loads)] else "None"
    pos_val <- if (length(pos_loads) > 0) unname(pos_loads[pos_top]) else NA_real_
    
    neg_top <- if (length(neg_loads) > 0) names(neg_loads)[which.min(neg_loads)] else "None"
    neg_val <- if (length(neg_loads) > 0) unname(neg_loads[neg_top]) else NA_real_
    
    interp_note <- paste0(
      "Dominant: ", top1_feat, " (", round(top1_load, 3), "), ",
      top2_feat, " (", round(top2_load, 3), ")"
    )
    
    loading_summary_list[[paste(scope_name, pc_name, sep = "_")]] <- tibble(
      scope = scope_name,
      PC = pc_name,
      top_abs_feature = as.character(top1_feat),
      top_abs_loading = as.numeric(top1_load),
      second_abs_feature = as.character(top2_feat),
      second_abs_loading = as.numeric(top2_load),
      top_positive_feature = as.character(pos_top),
      top_positive_loading = as.numeric(pos_val),
      top_negative_feature = as.character(neg_top),
      top_negative_loading = as.numeric(neg_val),
      interpretation_summary = as.character(interp_note)
    )
  }
  
  # History PCA Scores
  scores_hist <- as.data.frame(pca_fit$x)
  history_pca_df <- bind_cols(
    history_complete %>% select(
      project_station_id, station_name, city, date, season,
      all_of(pca_features),
      aqi_verified, aqi_category, dominant_pollutant
    ),
    scores_hist
  ) %>%
    mutate(pca_fit_period = "MODELING_HISTORY")
  
  hist_score_file <- paste0("data/analysis/phase5A/", ifelse(scope_name == "HYDERABAD", "Hyderabad", "India"), "_PCA_History.csv")
  write_csv(history_pca_df, hist_score_file)
  cat("Saved History PCA scores:", hist_score_file, "\n")
  
  # September PCA Projection using frozen scaler + rotation
  X_rec_mat <- as.matrix(recent_complete[, pca_features])
  X_rec_std <- scale(X_rec_mat, center = means_vec, scale = sds_vec)
  attr(X_rec_std, "scaled:center") <- NULL
  attr(X_rec_std, "scaled:scale") <- NULL
  scores_recent_manual <- X_rec_std %*% rot_mat
  scores_recent_predict <- predict(pca_fit, newdata = as.data.frame(X_rec_std))
  
  # Verify predict equals manual matrix multiplication
  stopifnot(max(abs(scores_recent_manual - scores_recent_predict)) < 1e-10)
  
  recent_pca_df <- bind_cols(
    recent_complete %>% select(
      project_station_id, station_name, city, date, season,
      all_of(pca_features),
      aqi_verified, aqi_category, dominant_pollutant
    ),
    as.data.frame(scores_recent_manual)
  ) %>%
    mutate(pca_fit_period = "MODELING_HISTORY")
  
  rec_score_file <- paste0("data/analysis/phase5A/", ifelse(scope_name == "HYDERABAD", "Hyderabad", "India"), "_PCA_Recent.csv")
  write_csv(recent_pca_df, rec_score_file)
  cat("Saved Recent PCA projection scores:", rec_score_file, "\n")
}

# 5. Write Combined Tables
scaling_params_df <- bind_rows(scaling_params_list)
write_csv(scaling_params_df, "analysis/phase5A/tables/phase5A_scaling_parameters.csv")
cat("Saved: phase5A_scaling_parameters.csv\n")

variance_explained_df <- bind_rows(variance_explained_list)
write_csv(variance_explained_df, "analysis/phase5A/tables/phase5A_pca_variance_explained.csv")
cat("Saved: phase5A_pca_variance_explained.csv\n")

selection_df <- bind_rows(selection_list)
write_csv(selection_df, "analysis/phase5A/tables/phase5A_pca_selection.csv")
cat("Saved: phase5A_pca_selection.csv\n")

loadings_df <- bind_rows(loadings_list)
write_csv(loadings_df, "analysis/phase5A/tables/phase5A_pca_loadings.csv")
cat("Saved: phase5A_pca_loadings.csv\n")

loading_summary_df <- bind_rows(loading_summary_list)
write_csv(loading_summary_df, "analysis/phase5A/tables/phase5A_pca_loading_summary.csv")
cat("Saved: phase5A_pca_loading_summary.csv\n")

cat("\n>>> Phase 5A PCA Completed Successfully.\n")
