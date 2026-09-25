# ==============================================================================
# scripts/19a_phase5A1_consistency_audit.R
# Programmatic Consistency Audit for Phase 5A / 5A.2 Tables and Numerical Core
# ==============================================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tibble)
})

cat(">>> Running Phase 5A.2 Expanded Numeric Consistency Audit...\n")

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

add_check <- function(group, scp, met, stored, recomputed, tol = 1e-5) {
  diff_val <- abs(as.numeric(stored) - as.numeric(recomputed))
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

# --- A. Scaling Parameters Audit (24 checks) ---
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

# --- B. PCA Variance Explained Audit (36 checks: Eigenvalues, Variance %, Cumulative %) ---
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

# --- C. Retained PC Counts (2 checks) ---
for (scp in c("HYDERABAD", "INDIA")) {
  cum_vals <- pca_var_stored %>% filter(scope == scp) %>% pull(cumulative_variance)
  recomp_sel <- which(cum_vals >= 0.80)[1]
  stored_sel <- pca_sel_stored %>% filter(scope == scp) %>% pull(retained_pc_count)
  audit_rows[[paste("pca_sel", scp, sep = "_")]] <- add_check("PCA_Selection", scp, "retained_pc_count", stored_sel, recomp_sel)
}

# --- D. Selected K (2 checks) ---
for (scp in c("HYDERABAD", "INDIA")) {
  km_mod <- readRDS(paste0("models/phase5A/", tolower(scp), "_kmeans.rds"))
  k_sel <- length(km_mod$size)
  audit_rows[[paste("k_sel", scp, sep = "_")]] <- add_check("K_Selection", scp, "k_count", k_sel, 3)
}

# --- E. History Cluster Sizes and Frequencies (12 checks) ---
for (scp in c("HYDERABAD", "INDIA")) {
  h_df <- if (scp == "HYDERABAD") hyd_hist else ind_hist
  km_mod <- readRDS(paste0("models/phase5A/", tolower(scp), "_kmeans.rds"))
  tot_h <- nrow(h_df)
  
  for (cl_idx in 1:3) {
    cl_name <- paste0("Cluster ", cl_idx)
    sz_recomp <- sum(h_df$initial_cluster == cl_name)
    sz_stored <- km_mod$size[cl_idx]
    pct_recomp <- round(100 * sz_recomp / tot_h, 2)
    pct_stored <- freq_stored %>% filter(scope == scp, period == "MODELING_HISTORY", cluster == cl_name) %>% pull(percentage)
    
    audit_rows[[paste("cl_sz", scp, cl_name, sep = "_")]] <- add_check("Cluster_Size", scp, cl_name, sz_stored, sz_recomp)
    audit_rows[[paste("hist_pct", scp, cl_name, sep = "_")]] <- add_check("History_Frequency_Pct", scp, cl_name, pct_stored, pct_recomp, tol = 0.05)
  }
}

# --- F. Recent Frequency Counts and Percentages (12 checks) ---
for (scp in c("HYDERABAD", "INDIA")) {
  r_df <- if (scp == "HYDERABAD") hyd_rec else ind_rec
  tot_r <- nrow(r_df)
  
  for (cl_idx in 1:3) {
    cl_name <- paste0("Cluster ", cl_idx)
    n_recomp <- sum(r_df$assigned_cluster == cl_name)
    pct_recomp <- round(100 * n_recomp / tot_r, 2)
    
    n_st <- freq_stored %>% filter(scope == scp, period == "RECENT_EVALUATION", cluster == cl_name) %>% pull(n)
    pct_st <- freq_stored %>% filter(scope == scp, period == "RECENT_EVALUATION", cluster == cl_name) %>% pull(percentage)
    
    audit_rows[[paste("rec_n", scp, cl_name, sep = "_")]] <- add_check("Recent_Count", scp, cl_name, n_st, n_recomp)
    audit_rows[[paste("rec_pct", scp, cl_name, sep = "_")]] <- add_check("Recent_Pct", scp, cl_name, pct_st, pct_recomp, tol = 0.05)
  }
}

# --- G. Season Frequencies (24 checks) ---
for (i in 1:nrow(season_stored)) {
  s_row <- season_stored[i, ]
  scp <- s_row$scope
  sea <- s_row$season
  cl  <- s_row$cluster
  h_df <- if (scp == "HYDERABAD") hyd_hist else ind_hist
  
  n_recomp <- sum(h_df$season == sea & h_df$initial_cluster == cl)
  audit_rows[[paste("season", scp, sea, cl, sep = "_")]] <- add_check("Season_Frequency_Count", scp, paste(sea, cl), s_row$n, n_recomp)
}

# --- H. Centroid Distance Summary: mean, median, p90, p95, count_ge_95, pct_ge_95 (12 checks) ---
for (scp in c("HYDERABAD", "INDIA")) {
  r_df <- if (scp == "HYDERABAD") hyd_rec else ind_rec
  dists <- r_df$centroid_distance_percentile
  n_tot <- nrow(r_df)
  
  mean_recomp <- mean(dists)
  med_recomp  <- median(dists)
  p90_recomp  <- quantile(dists, 0.90, type = 7)
  p95_recomp  <- quantile(dists, 0.95, type = 7)
  cnt_ge_95   <- sum(dists >= 0.95)
  pct_ge_95   <- (cnt_ge_95 / n_tot) * 100
  
  st_row <- dist_stored %>% filter(scope == scp)
  
  audit_rows[[paste("dist_mean", scp, sep = "_")]]    <- add_check("Centroid_Distance", scp, "mean_percentile", st_row$mean_percentile, mean_recomp, tol = 1e-4)
  audit_rows[[paste("dist_med", scp, sep = "_")]]     <- add_check("Centroid_Distance", scp, "median_percentile", st_row$median_percentile, med_recomp, tol = 1e-4)
  audit_rows[[paste("dist_p90", scp, sep = "_")]]     <- add_check("Centroid_Distance", scp, "p90_percentile", st_row$p90_percentile, p90_recomp, tol = 1e-4)
  audit_rows[[paste("dist_p95", scp, sep = "_")]]     <- add_check("Centroid_Distance", scp, "p95_percentile", st_row$p95_percentile, p95_recomp, tol = 1e-4)
  audit_rows[[paste("dist_cnt95", scp, sep = "_")]]   <- add_check("Centroid_Distance", scp, "count_ge_95", st_row$count_ge_95, cnt_ge_95)
  audit_rows[[paste("dist_pct95", scp, sep = "_")]]   <- add_check("Centroid_Distance", scp, "pct_ge_95", st_row$pct_ge_95, pct_ge_95, tol = 1e-4)
}

numeric_audit_df <- bind_rows(audit_rows)
write_csv(numeric_audit_df, "analysis/phase5A/tables/phase5A_numeric_consistency_audit.csv")
cat("Saved: phase5A_numeric_consistency_audit.csv with", nrow(numeric_audit_df), "checks.\n")
cat("All match:", all(numeric_audit_df$match), "\n")
if (!all(numeric_audit_df$match)) {
  cat("Mismatches:\n")
  print(numeric_audit_df %>% filter(!match))
}

# --- I. Option A: Report Generation Integrity Table ---
report_gen_df <- tibble(
  report_section = c(
    "Section C: PCA Eigenvalues & Variance",
    "Section C: Retained Component Selection",
    "Section D: Scaling Parameters",
    "Section E: K-Selection Diagnostics",
    "Section F: History Cluster Sizes & Profiles",
    "Section G: Regime Frequency Comparison",
    "Section H: Seasonal Distribution",
    "Section I: Station Cluster Distribution",
    "Section J: Recent Evaluation & Centroid Distance",
    "Section K: Cluster Descriptive Labels"
  ),
  source_table = c(
    "analysis/phase5A/tables/phase5A_pca_variance_explained.csv",
    "analysis/phase5A/tables/phase5A_pca_selection.csv",
    "analysis/phase5A/tables/phase5A_scaling_parameters.csv",
    "analysis/phase5A/tables/phase5A_k_selection_diagnostics.csv",
    "analysis/phase5A/tables/phase5A_cluster_profiles.csv",
    "analysis/phase5A/tables/phase5A_regime_frequency_comparison.csv",
    "analysis/phase5A/tables/phase5A_season_cluster_distribution.csv",
    "analysis/phase5A/tables/phase5A_station_cluster_distribution.csv",
    "analysis/phase5A/tables/phase5A_recent_centroid_distance_summary.csv",
    "analysis/phase5A/tables/phase5A_cluster_labels.csv"
  ),
  programmatic_linkage = rep("Declared authoritative source table for final report section", 10),
  verification_status = rep("SOURCE_PROVENANCE_DECLARED", 10)
)

write_csv(report_gen_df, "analysis/phase5A/tables/phase5A_report_generation_integrity.csv")
cat("Saved: phase5A_report_generation_integrity.csv with", nrow(report_gen_df), "sections.\n")

# Remove obsolete/misleading audit file if present
if (file.exists("analysis/phase5A/tables/phase5A_report_numeric_integrity_audit.csv")) {
  file.remove("analysis/phase5A/tables/phase5A_report_numeric_integrity_audit.csv")
  cat("Removed obsolete phase5A_report_numeric_integrity_audit.csv.\n")
}

cat(">>> Audit Script Finished Successfully.\n")
