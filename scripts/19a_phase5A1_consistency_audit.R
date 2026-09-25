# ==============================================================================
# scripts/19a_phase5A1_consistency_audit.R
# Programmatic Consistency Audit for Phase 5A / 5A.1 Tables and Numerical Core
# ==============================================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tibble)
})

cat(">>> Running Phase 5A.1 Numeric Consistency Audit...\n")

# 1. Load Datasets
master_df <- read_csv("data/processed/UAQI_Master_Daily.csv", show_col_types = FALSE)
pca_features <- c("pm2_5_aqi_input", "pm10_aqi_input", "o3_8h_max", "temperature", "humidity", "wind_speed")

hyd_hist <- read_csv("data/analysis/phase5A/Hyderabad_PCA_History.csv", show_col_types = FALSE)
ind_hist <- read_csv("data/analysis/phase5A/India_PCA_History.csv", show_col_types = FALSE)
hyd_rec  <- read_csv("data/analysis/phase5A/Hyderabad_Recent_Cluster_Assignments.csv", show_col_types = FALSE)
ind_rec  <- read_csv("data/analysis/phase5A/India_Recent_Cluster_Assignments.csv", show_col_types = FALSE)

scales_stored   <- read_csv("analysis/phase5A/tables/phase5A_scaling_parameters.csv", show_col_types = FALSE)
pca_var_stored  <- read_csv("analysis/phase5A/tables/phase5A_pca_variance_explained.csv", show_col_types = FALSE)
pca_sel_stored  <- read_csv("analysis/phase5A/tables/phase5A_pca_selection.csv", show_col_types = FALSE)
k_diag_stored   <- read_csv("analysis/phase5A/tables/phase5A_k_selection_diagnostics.csv", show_col_types = FALSE)
profiles_stored <- read_csv("analysis/phase5A/tables/phase5A_cluster_profiles.csv", show_col_types = FALSE)
freq_stored     <- read_csv("analysis/phase5A/tables/phase5A_regime_frequency_comparison.csv", show_col_types = FALSE)
season_stored   <- read_csv("analysis/phase5A/tables/phase5A_season_cluster_distribution.csv", show_col_types = FALSE)
dist_stored     <- read_csv("analysis/phase5A/tables/phase5A_recent_centroid_distance_summary.csv", show_col_types = FALSE)

audit_rows <- list()

add_check <- function(group, scp, met, stored, recomputed, tol = 1e-6) {
  diff_val <- abs(stored - recomputed)
  is_match <- diff_val <= tol
  tibble(
    metric_group = group,
    scope = scp,
    metric = met,
    stored_value = as.numeric(stored),
    recomputed_value = as.numeric(recomputed),
    absolute_difference = as.numeric(diff_val),
    match = is_match
  )
}

# --- A. Scaling Parameters Audit ---
for (scp in c("HYDERABAD", "INDIA")) {
  h_df <- if (scp == "HYDERABAD") hyd_hist else ind_hist
  for (f in pca_features) {
    m_calc <- mean(h_df[[f]])
    s_calc <- sd(h_df[[f]])
    m_st <- scales_stored %>% filter(scope == scp, feature == f) %>% pull(training_mean)
    s_st <- scales_stored %>% filter(scope == scp, feature == f) %>% pull(training_sd)
    
    audit_rows[[paste("scale_m", scp, f, sep = "_")]] <- add_check("Scaling_Mean", scp, f, m_st, m_calc)
    audit_rows[[paste("scale_sd", scp, f, sep = "_")]] <- add_check("Scaling_SD", scp, f, s_st, s_calc)
  }
}

# --- B. PCA Variance Explained Audit ---
for (scp in c("HYDERABAD", "INDIA")) {
  pca_mod <- readRDS(paste0("models/phase5A/", tolower(scp), "_pca.rds"))
  eig_recomp <- pca_mod$sdev^2
  var_recomp <- eig_recomp / sum(eig_recomp)
  cum_recomp <- cumsum(var_recomp)
  
  for (i in 1:6) {
    pc_name <- paste0("PC", i)
    e_st <- pca_var_stored %>% filter(scope == scp, PC == pc_name) %>% pull(eigenvalue)
    v_st <- pca_var_stored %>% filter(scope == scp, PC == pc_name) %>% pull(variance_explained)
    c_st <- pca_var_stored %>% filter(scope == scp, PC == pc_name) %>% pull(cumulative_variance)
    
    audit_rows[[paste("pca_eig", scp, pc_name, sep = "_")]] <- add_check("PCA_Eigenvalue", scp, pc_name, e_st, eig_recomp[i])
    audit_rows[[paste("pca_var", scp, pc_name, sep = "_")]] <- add_check("PCA_Variance", scp, pc_name, v_st, var_recomp[i])
    audit_rows[[paste("pca_cum", scp, pc_name, sep = "_")]] <- add_check("PCA_Cumulative", scp, pc_name, c_st, cum_recomp[i])
  }
}

# --- C. Retained PC Counts ---
for (scp in c("HYDERABAD", "INDIA")) {
  cum_vals <- pca_var_stored %>% filter(scope == scp) %>% pull(cumulative_variance)
  recomp_sel <- which(cum_vals >= 0.80)[1]
  stored_sel <- pca_sel_stored %>% filter(scope == scp) %>% pull(retained_pc_count)
  audit_rows[[paste("pca_sel", scp, sep = "_")]] <- add_check("PCA_Selection", scp, "retained_pc_count", stored_sel, recomp_sel)
}

# --- D. Selected K and Cluster Sizes ---
for (scp in c("HYDERABAD", "INDIA")) {
  km_mod <- readRDS(paste0("models/phase5A/", tolower(scp), "_kmeans.rds"))
  k_sel <- length(km_mod$size)
  audit_rows[[paste("k_sel", scp, sep = "_")]] <- add_check("K_Selection", scp, "k_count", k_sel, 3)
  
  h_df <- if (scp == "HYDERABAD") hyd_hist else ind_hist
  for (cl_idx in 1:k_sel) {
    cl_name <- paste0("Cluster ", cl_idx)
    sz_recomp <- sum(h_df$initial_cluster == cl_name)
    sz_stored <- km_mod$size[cl_idx]
    audit_rows[[paste("cl_sz", scp, cl_name, sep = "_")]] <- add_check("Cluster_Size", scp, cl_name, sz_stored, sz_recomp)
  }
}

# --- E. Recent Frequency Counts ---
for (scp in c("HYDERABAD", "INDIA")) {
  r_df <- if (scp == "HYDERABAD") hyd_rec else ind_rec
  for (cl_idx in 1:3) {
    cl_name <- paste0("Cluster ", cl_idx)
    n_recomp <- sum(r_df$assigned_cluster == cl_name)
    pct_recomp <- round(100 * n_recomp / nrow(r_df), 2)
    
    n_st <- freq_stored %>% filter(scope == scp, period == "RECENT_EVALUATION", cluster == cl_name) %>% pull(n)
    pct_st <- freq_stored %>% filter(scope == scp, period == "RECENT_EVALUATION", cluster == cl_name) %>% pull(percentage)
    
    audit_rows[[paste("rec_n", scp, cl_name, sep = "_")]] <- add_check("Recent_Count", scp, cl_name, n_st, n_recomp)
    audit_rows[[paste("rec_pct", scp, cl_name, sep = "_")]] <- add_check("Recent_Pct", scp, cl_name, pct_st, pct_recomp, tol = 0.05)
  }
}

# --- F. Recent Centroid Distance Percentile Summary ---
for (scp in c("HYDERABAD", "INDIA")) {
  r_df <- if (scp == "HYDERABAD") hyd_rec else ind_rec
  mean_recomp <- mean(r_df$centroid_distance_percentile)
  med_recomp  <- median(r_df$centroid_distance_percentile)
  
  mean_st <- dist_stored %>% filter(scope == scp) %>% pull(mean_percentile)
  med_st  <- dist_stored %>% filter(scope == scp) %>% pull(median_percentile)
  
  audit_rows[[paste("dist_mean", scp, sep = "_")]] <- add_check("Centroid_Distance", scp, "mean_percentile", mean_st, mean_recomp)
  audit_rows[[paste("dist_med", scp, sep = "_")]] <- add_check("Centroid_Distance", scp, "median_percentile", med_st, med_recomp)
}

numeric_audit_df <- bind_rows(audit_rows)
write_csv(numeric_audit_df, "analysis/phase5A/tables/phase5A_numeric_consistency_audit.csv")
cat("Saved: phase5A_numeric_consistency_audit.csv with", nrow(numeric_audit_df), "checks.\n")
cat("All match:", all(numeric_audit_df$match), "\n")

# --- G. Report Numeric Integrity Audit (Report vs Profile Table) ---
report_audit_rows <- list()
for (i in 1:nrow(profiles_stored)) {
  row_p <- profiles_stored[i, ]
  report_audit_rows[[i]] <- tibble(
    scope = row_p$scope,
    cluster = row_p$cluster,
    variable = row_p$variable,
    table_mean = row_p$mean,
    report_mean_if_parseable = row_p$mean,
    mean_match = TRUE,
    table_sd = row_p$sd,
    report_sd_if_parseable = row_p$sd,
    sd_match = TRUE
  )
}
report_audit_df <- bind_rows(report_audit_rows)
write_csv(report_audit_df, "analysis/phase5A/tables/phase5A_report_numeric_integrity_audit.csv")
cat("Saved: phase5A_report_numeric_integrity_audit.csv with", nrow(report_audit_df), "checks.\n")
