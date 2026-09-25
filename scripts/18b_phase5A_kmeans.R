# ==============================================================================
# scripts/18b_phase5A_kmeans.R
# Phase 5A: K-Means Pollution-Regime Discovery on Retained PCA Dimensions
# ==============================================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tibble)
  library(cluster)
})

source("R/31_unsupervised_metrics.R")

cat(">>> Running Phase 5A K-Means Pipeline...\n")

# 1. Load PCA Selection to know retained PCs
pca_sel <- read_csv("analysis/phase5A/tables/phase5A_pca_selection.csv", show_col_types = FALSE)

scopes <- c("HYDERABAD", "INDIA")
k_candidates <- 2:8
primary_seed <- 20260925

diagnostics_list <- list()
final_centroids_list <- list()
stability_list <- list()
selection_rule_doc_list <- list()

for (scope_name in scopes) {
  cat("\n=== K-Means Evaluation for Scope:", scope_name, "===\n")
  
  # Load history PCA scores
  hist_file <- paste0("data/analysis/phase5A/", ifelse(scope_name == "HYDERABAD", "Hyderabad", "India"), "_PCA_History.csv")
  rec_file  <- paste0("data/analysis/phase5A/", ifelse(scope_name == "HYDERABAD", "Hyderabad", "India"), "_PCA_Recent.csv")
  
  hist_df <- read_csv(hist_file, show_col_types = FALSE)
  rec_df  <- read_csv(rec_file, show_col_types = FALSE)
  
  # Determine retained PCs
  retained_count <- pca_sel %>% filter(scope == scope_name) %>% pull(retained_pc_count)
  retained_pc_cols <- paste0("PC", 1:retained_count)
  cat("Using retained PCs:", paste(retained_pc_cols, collapse = ", "), "\n")
  
  X_hist_pca <- as.matrix(hist_df[, retained_pc_cols])
  X_rec_pca  <- as.matrix(rec_df[, retained_pc_cols])
  n_hist <- nrow(X_hist_pca)
  
  # Evaluate k = 2:8
  k_diag_list <- list()
  fitted_models <- list()
  
  for (k in k_candidates) {
    set.seed(primary_seed)
    km <- kmeans(X_hist_pca, centers = k, nstart = 50, iter.max = 100)
    fitted_models[[as.character(k)]] <- km
    
    cl_sizes <- km$size
    min_size <- min(cl_sizes)
    max_size <- max(cl_sizes)
    min_pct  <- 100 * min_size / n_hist
    
    # Silhouette width in Euclidean retained PCA space
    sil_avg <- calc_avg_silhouette(X_hist_pca, km$cluster)
    
    # Feasibility check: no cluster < 2% of history AND no cluster < 30 observations
    feasible <- (min_pct >= 2.0) && (min_size >= 30)
    
    k_diag_list[[as.character(k)]] <- tibble(
      scope = scope_name,
      k = k,
      total_withinss = km$tot.withinss,
      between_SS = km$betweenss,
      total_SS = km$totss,
      between_to_total_ratio = km$betweenss / km$totss,
      average_silhouette_width = sil_avg,
      minimum_cluster_size = min_size,
      maximum_cluster_size = max_size,
      smallest_cluster_pct = min_pct,
      is_feasible = feasible
    )
  }
  
  diag_df <- bind_rows(k_diag_list)
  diagnostics_list[[scope_name]] <- diag_df
  
  # Apply Deterministic Selection Rule:
  # A. Exclude candidate k where min_pct < 2% OR min_size < 30
  # B. Among feasible candidates choose k with highest average silhouette width
  # C. If silhouette values tie within 0.01, choose SMALLER k
  feasible_cands <- diag_df %>% filter(is_feasible)
  if (nrow(feasible_cands) == 0) {
    cat("Warning: No candidate met strict size constraints. Falling back to all candidates.\n")
    feasible_cands <- diag_df
  }
  
  max_sil <- max(feasible_cands$average_silhouette_width)
  # Candidates within 0.01 of maximum silhouette
  top_cands <- feasible_cands %>% filter(average_silhouette_width >= (max_sil - 0.01))
  # Choose smaller k among ties within 0.01
  selected_k <- min(top_cands$k)
  selected_diag <- diag_df %>% filter(k == selected_k)
  
  cat("Selected K for", scope_name, ":", selected_k, 
      "| Avg Silhouette:", round(selected_diag$average_silhouette_width, 4),
      "| BSS/TSS:", round(selected_diag$between_to_total_ratio, 4), "\n")
  
  # Save chosen K-Means model
  km_final <- fitted_models[[as.character(selected_k)]]
  saveRDS(km_final, paste0("models/phase5A/", tolower(scope_name), "_kmeans.rds"))
  
  # Add cluster to history df
  # Sort cluster IDs by PC1 centroid or keep 1:K as initial cluster IDs
  hist_clusters <- paste0("Cluster ", km_final$cluster)
  hist_df$initial_cluster <- hist_clusters
  
  # Calculate distance to assigned centroid for history
  hist_centroids <- km_final$centers
  rownames(hist_centroids) <- paste0("Cluster ", 1:selected_k)
  
  hist_dists_all <- calc_distance_to_centroids(X_hist_pca, hist_centroids)
  hist_dist_assigned <- numeric(n_hist)
  for (i in 1:n_hist) {
    hist_dist_assigned[i] <- hist_dists_all[i, km_final$cluster[i]]
  }
  hist_df$distance_to_centroid <- hist_dist_assigned
  
  # Save updated history PCA + Cluster dataset
  write_csv(hist_df, hist_file)
  
  # Save PCA-space centroids
  cents_df <- as_tibble(hist_centroids) %>%
    mutate(
      scope = scope_name,
      cluster = rownames(hist_centroids)
    ) %>%
    select(scope, cluster, everything())
  final_centroids_list[[scope_name]] <- cents_df
  
  # Assign September rows to nearest frozen history centroid
  rec_assign <- assign_to_nearest_centroid(X_rec_pca, hist_centroids)
  
  # Centroid distance percentile relative to assigned history cluster
  n_rec <- nrow(rec_df)
  pctile_vec <- numeric(n_rec)
  for (r in 1:n_rec) {
    cl_r <- rec_assign$assigned_cluster[r]
    dist_r <- rec_assign$distance_to_assigned_centroid[r]
    hist_cl_dists <- hist_dist_assigned[hist_clusters == cl_r]
    pctile_vec[r] <- mean(hist_cl_dists <= dist_r)
  }
  
  rec_df$assigned_cluster <- rec_assign$assigned_cluster
  rec_df$distance_to_assigned_centroid <- rec_assign$distance_to_assigned_centroid
  rec_df$centroid_distance_percentile <- pctile_vec
  
  # Save Recent Cluster Assignments
  rec_assign_file <- paste0("data/analysis/phase5A/", ifelse(scope_name == "HYDERABAD", "Hyderabad", "India"), "_Recent_Cluster_Assignments.csv")
  write_csv(rec_df, rec_assign_file)
  cat("Saved Recent Cluster Assignments:", rec_assign_file, "\n")
  
  # Stability Sensitivity across 10 deterministic seeds
  stability_seeds <- primary_seed + (1:10)
  ari_vec <- numeric(length(stability_seeds))
  
  for (s_idx in seq_along(stability_seeds)) {
    s_val <- stability_seeds[s_idx]
    set.seed(s_val)
    km_seed <- kmeans(X_hist_pca, centers = selected_k, nstart = 50, iter.max = 100)
    ari_vec[s_idx] <- calc_ari(km_final$cluster, km_seed$cluster)
  }
  
  stab_df <- tibble(
    scope = scope_name,
    selected_k = selected_k,
    seed = stability_seeds,
    ARI_against_primary = ari_vec
  )
  stability_list[[scope_name]] <- stab_df
}

# 2. Write Combined K-Means Diagnostics & Stability
diagnostics_df <- bind_rows(diagnostics_list)
write_csv(diagnostics_df, "analysis/phase5A/tables/phase5A_k_selection_diagnostics.csv")
cat("Saved: phase5A_k_selection_diagnostics.csv\n")

centroids_df <- bind_rows(final_centroids_list)
write_csv(centroids_df, "analysis/phase5A/tables/phase5A_cluster_centroids_pca.csv")
cat("Saved: phase5A_cluster_centroids_pca.csv\n")

stability_df <- bind_rows(stability_list)
stability_summary <- stability_df %>%
  group_by(scope, selected_k) %>%
  summarise(
    runs = n(),
    median_ARI = median(ARI_against_primary),
    minimum_ARI = min(ARI_against_primary),
    .groups = "drop"
  )
write_csv(stability_df, "analysis/phase5A/tables/phase5A_cluster_stability.csv")
write_csv(stability_summary, "analysis/phase5A/tables/phase5A_cluster_stability_summary.csv")
cat("Saved: phase5A_cluster_stability.csv\n")

cat("\n>>> Phase 5A K-Means Completed Successfully.\n")
