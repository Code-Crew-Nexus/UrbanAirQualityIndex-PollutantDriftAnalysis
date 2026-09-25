# ==============================================================================
# tests/testthat/test_phase5a.R
# Hardened Test Suite for Phase 5A / 5A.1 Unsupervised Dimensionality & Regimes
# ==============================================================================

library(testthat)
library(dplyr)
library(readr)
source("../../R/31_unsupervised_metrics.R")

test_that("Phase 5A Unsupervised Methodology and Integrity Constraints", {
  
  # 1. One-time execution environment check (skip gracefully if detached or post-merge)
  git_branch <- tryCatch(
    system("git branch --show-current", intern = TRUE),
    error = function(e) character(0)
  )
  if (length(git_branch) == 0 || nchar(git_branch[1]) == 0) {
    skip("Git branch information not available in this environment")
  } else if (git_branch[1] != "feature/pca-kmeans") {
    skip(paste0("Currently on branch '", git_branch[1], "'; feature check applies to feature/pca-kmeans"))
  } else {
    expect_equal(git_branch[1], "feature/pca-kmeans")
  }
  
  # 2. Frozen Phase-4 outputs unchanged
  expect_true(file.exists("../../analysis/phase4C/tables/phase4_supervised_learning_summary.csv"))
  expect_true(file.exists("../../models/phase4C/hyderabad_model_B_train.rds"))
  expect_true(file.exists("../../models/phase4B/india_model_B_train.rds"))
  
  # 3. Exact six-feature contract
  pca_features <- c("pm2_5_aqi_input", "pm10_aqi_input", "o3_8h_max", "temperature", "humidity", "wind_speed")
  scales <- read_csv("../../analysis/phase5A/tables/phase5A_scaling_parameters.csv", show_col_types = FALSE)
  expect_equal(sort(unique(scales$feature)), sort(pca_features))
  
  # 4. AQI excluded from PCA input
  expect_false("aqi_verified" %in% scales$feature)
  expect_false("aqi_category" %in% scales$feature)
  
  # 5. Gases excluded from PCA input
  expect_false(any(c("co_source_mean", "no2_source_mean", "so2_source_mean") %in% scales$feature))
  
  # 6. Target fields excluded
  expect_false(any(grepl("target", scales$feature)))
  
  # 7. Phase-3 inference fields excluded
  expect_false(any(c("drift_z", "p_value_raw", "p_value_fdr") %in% scales$feature))
  
  # 8. Modeling-history date boundary exact
  hyd_hist <- read_csv("../../data/analysis/phase5A/Hyderabad_PCA_History.csv", show_col_types = FALSE)
  expect_equal(min(hyd_hist$date), as.Date("2025-03-01"))
  expect_equal(max(hyd_hist$date), as.Date("2026-08-31"))
  
  # 9. September excluded from fitting
  expect_false(any(hyd_hist$date >= as.Date("2026-09-01")))
  
  # 10. No imputation: eligibility profile accounts for incomplete rows
  elig <- read_csv("../../analysis/phase5A/tables/phase5A_eligibility_profile.csv", show_col_types = FALSE)
  expect_true(all(elig$structural_rows == elig$complete_rows + elig$incomplete_rows))
  
  # 11. Scaler means learned from history only
  ind_hist <- read_csv("../../data/analysis/phase5A/India_PCA_History.csv", show_col_types = FALSE)
  ind_scale <- scales %>% filter(scope == "INDIA")
  for (f in pca_features) {
    m_calc <- mean(ind_hist[[f]])
    m_stored <- ind_scale %>% filter(feature == f) %>% pull(training_mean)
    expect_equal(m_calc, m_stored, tolerance = 1e-6)
  }
  
  # 12. Scaler SD learned from history only
  for (f in pca_features) {
    sd_calc <- sd(ind_hist[[f]])
    sd_stored <- ind_scale %>% filter(feature == f) %>% pull(training_sd)
    expect_equal(sd_calc, sd_stored, tolerance = 1e-6)
  }
  
  # 13. All training SD > 0
  expect_true(all(scales$training_sd > 0))
  
  # 14. Standardized history mean approximately zero
  hyd_scale <- scales %>% filter(scope == "HYDERABAD")
  for (f in pca_features) {
    m_val <- hyd_scale %>% filter(feature == f) %>% pull(training_mean)
    s_val <- hyd_scale %>% filter(feature == f) %>% pull(training_sd)
    z <- (hyd_hist[[f]] - m_val) / s_val
    expect_true(abs(mean(z)) < 1e-10)
  }
  
  # 15. Standardized history SD approximately one
  for (f in pca_features) {
    m_val <- hyd_scale %>% filter(feature == f) %>% pull(training_mean)
    s_val <- hyd_scale %>% filter(feature == f) %>% pull(training_sd)
    z <- (hyd_hist[[f]] - m_val) / s_val
    expect_true(abs(sd(z) - 1.0) < 1e-10)
  }
  
  # 16. prcomp fit history only
  hyd_pca <- readRDS("../../models/phase5A/hyderabad_pca.rds")
  expect_equal(nrow(hyd_pca$x), nrow(hyd_hist))
  
  # 17. Retained PC rule >= 80%
  pca_sel <- read_csv("../../analysis/phase5A/tables/phase5A_pca_selection.csv", show_col_types = FALSE)
  expect_true(all(pca_sel$cumulative_variance_at_selection >= 0.80))
  
  # 18. One fewer PC is < 80%
  pca_var <- read_csv("../../analysis/phase5A/tables/phase5A_pca_variance_explained.csv", show_col_types = FALSE)
  for (scp in c("HYDERABAD", "INDIA")) {
    k_sel <- pca_sel %>% filter(scope == scp) %>% pull(retained_pc_count)
    if (k_sel > 1) {
      cum_prev <- pca_var %>% filter(scope == scp, PC == paste0("PC", k_sel - 1)) %>% pull(cumulative_variance)
      expect_true(cum_prev < 0.80)
    }
  }
  
  # 19. PCA predict equals manual projection
  hyd_rec <- read_csv("../../data/analysis/phase5A/Hyderabad_Recent_Cluster_Assignments.csv", show_col_types = FALSE)
  means_h <- setNames(hyd_scale$training_mean, hyd_scale$feature)
  sds_h   <- setNames(hyd_scale$training_sd, hyd_scale$feature)
  X_rec_mat <- as.matrix(hyd_rec[, pca_features])
  X_rec_std <- scale(X_rec_mat, center = means_h, scale = sds_h)
  attr(X_rec_std, "scaled:center") <- NULL
  attr(X_rec_std, "scaled:scale") <- NULL
  
  scores_manual <- X_rec_std %*% hyd_pca$rotation
  scores_pred   <- predict(hyd_pca, newdata = as.data.frame(X_rec_std))
  expect_true(max(abs(scores_manual - scores_pred)) < 1e-10)
  
  # 20. Recent projection uses frozen PCA
  expect_equal(as.matrix(hyd_rec[, paste0("PC", 1:4)]), scores_manual[, 1:4], tolerance = 1e-8)
  
  # 21. K candidates exactly 2:8
  k_diag <- read_csv("../../analysis/phase5A/tables/phase5A_k_selection_diagnostics.csv", show_col_types = FALSE)
  expect_equal(sort(unique(k_diag$k)), 2:8)
  
  # 22. Deterministic seed specified
  script_content <- read_file("../../scripts/18b_phase5A_kmeans.R")
  expect_true(grepl("20260925", script_content))
  
  # 23. nstart >= 50
  expect_true(grepl("nstart = 50", script_content) || grepl("nstart >= 50", script_content))
  
  # 24. K exclusion rule enforced: small clusters flagged
  expect_true(all(k_diag %>% filter(!is_feasible) %>% pull(smallest_cluster_pct) < 2.0 |
                  k_diag %>% filter(!is_feasible) %>% pull(minimum_cluster_size) < 30))
  
  # 25. REAL K-selection test: selected k maximizes feasible silhouette under tie rule
  for (scp in c("HYDERABAD", "INDIA")) {
    diag_scp <- k_diag %>% filter(scope == scp, is_feasible)
    max_sil <- max(diag_scp$average_silhouette_width)
    top_cands <- diag_scp %>% filter(average_silhouette_width >= (max_sil - 0.01))
    expected_k <- min(top_cands$k)
    
    km_obj <- readRDS(paste0("../../models/phase5A/", tolower(scp), "_kmeans.rds"))
    actual_k <- length(km_obj$size)
    expect_equal(actual_k, expected_k)
    expect_equal(actual_k, 3)
  }
  
  # 26. K-Means history only
  hyd_km <- readRDS("../../models/phase5A/hyderabad_kmeans.rds")
  expect_equal(sum(hyd_km$size), nrow(hyd_hist))
  
  # 27. Recent data does not alter centroids
  cents <- read_csv("../../analysis/phase5A/tables/phase5A_cluster_centroids_pca.csv", show_col_types = FALSE)
  hyd_cents <- cents %>% filter(scope == "HYDERABAD") %>% select(PC1, PC2, PC3, PC4)
  expect_equal(unname(as.matrix(hyd_cents)), unname(hyd_km$centers), tolerance = 1e-8)
  
  # 28. Recent assignments use nearest frozen centroid
  dists_to_c <- calc_distance_to_centroids(as.matrix(hyd_rec[, paste0("PC", 1:4)]), hyd_km$centers)
  nearest_idx <- apply(dists_to_c, 1, which.min)
  expect_equal(hyd_rec$assigned_cluster, paste0("Cluster ", nearest_idx))
  
  # 29. Cluster labels assigned after fit
  labels_df <- read_csv("../../analysis/phase5A/tables/phase5A_cluster_labels.csv", show_col_types = FALSE)
  expect_equal(nrow(labels_df), 6) # 3 for Hyderabad + 3 for India
  expect_true(all(c("Cluster 1", "Cluster 2", "Cluster 3") %in% labels_df$cluster))
  
  # 30. AQI used only as passive metadata
  expect_true(all(c("aqi_verified", "aqi_category") %in% names(hyd_hist)))
  expect_false("aqi_verified" %in% colnames(hyd_pca$rotation))
  
  # 31. Hyderabad exactly 7 stations
  expect_equal(length(unique(hyd_hist$project_station_id)), 7)
  
  # 32. India exactly 15 stations
  expect_equal(length(unique(ind_hist$project_station_id)), 15)
  
  # 33. Zoo Park overlap intentional
  expect_true("PROJ_007" %in% hyd_hist$project_station_id)
  expect_true("PROJ_007" %in% ind_hist$project_station_id)
  
  # 34. Cluster sizes sum to history complete cases
  expect_equal(sum(hyd_km$size), 2749)
  ind_km <- readRDS("../../models/phase5A/india_kmeans.rds")
  expect_equal(sum(ind_km$size), 6796)
  
  # 35. Recent assignments sum to recent complete cases
  expect_equal(nrow(hyd_rec), 121)
  ind_rec <- read_csv("../../data/analysis/phase5A/India_Recent_Cluster_Assignments.csv", show_col_types = FALSE)
  expect_equal(nrow(ind_rec), 262)
  
  # 36. Centroid-distance percentile bounded [0, 1]
  expect_true(all(hyd_rec$centroid_distance_percentile >= 0 & hyd_rec$centroid_distance_percentile <= 1))
  expect_true(all(ind_rec$centroid_distance_percentile >= 0 & ind_rec$centroid_distance_percentile <= 1))
  
  # 37. Station cluster shares sum approximately 1
  st_dist <- read_csv("../../analysis/phase5A/tables/phase5A_station_cluster_distribution.csv", show_col_types = FALSE)
  st_sums <- st_dist %>%
    group_by(scope, station_name) %>%
    summarise(tot_hist = sum(history_pct), .groups = "drop")
  expect_true(all(abs(st_sums$tot_hist - 100) < 0.2))
  
  # 38. Season cluster shares sum approximately 1 where defined
  sea_dist <- read_csv("../../analysis/phase5A/tables/phase5A_season_cluster_distribution.csv", show_col_types = FALSE)
  sea_sums <- sea_dist %>%
    group_by(scope, season) %>%
    summarise(tot_pct = sum(pct), .groups = "drop")
  expect_true(all(abs(sea_sums$tot_pct - 100) < 0.2))
  
  # 39. ARI bounded in [-1, 1] and regression check for seed stability
  stab <- read_csv("../../analysis/phase5A/tables/phase5A_cluster_stability.csv", show_col_types = FALSE)
  expect_true(all(stab$ARI_against_primary >= -1.0 & stab$ARI_against_primary <= 1.0))
  expect_equal(min(stab$ARI_against_primary), 1.0, tolerance = 1e-4)
  
  # 40. No supervised target used in clustering
  expect_false(any(grepl("target", names(cents))))
  
  # 41. No random train/test split
  expect_equal(sort(unique(hyd_hist$pca_fit_period)), "MODELING_HISTORY")
  
  # 42. No network calls / new data acquisition in scripts
  all_scripts <- c("../../scripts/18a_phase5A_pca.R", "../../scripts/18b_phase5A_kmeans.R", "../../scripts/18c_phase5A_profiles_figures.R")
  for (sc in all_scripts) {
    code_text <- read_file(sc)
    expect_false(grepl("curl|httr|download.file|openaq.org|open-meteo.com", code_text))
  }
  
  # --- ADDITIONAL HARMONIZATION ASSERTIONS (Phase 5A.1) ---
  # 43. PCA variance table sums to 1.0 by scope
  var_sums <- pca_var %>%
    group_by(scope) %>%
    summarise(tot_var = sum(variance_explained), .groups = "drop")
  expect_equal(var_sums$tot_var, c(1.0, 1.0), tolerance = 1e-6)
  
  # 44. Recent frequency percentages sum to 100% by scope
  freq_df <- read_csv("../../analysis/phase5A/tables/phase5A_regime_frequency_comparison.csv", show_col_types = FALSE)
  rec_sums <- freq_df %>%
    filter(period == "RECENT_EVALUATION") %>%
    group_by(scope) %>%
    summarise(tot_pct = sum(percentage), .groups = "drop")
  expect_true(all(abs(rec_sums$tot_pct - 100) < 0.2))
  
  # 45. O3 primary units = ug/m3 (not ppb)
  dict_path <- "../../data/metadata/pollutant_dictionary.csv"
  if (file.exists(dict_path)) {
    dict_df <- read_csv(dict_path, show_col_types = FALSE)
    o3_unit <- dict_df %>% filter(canonical_name == "o3") %>% pull(canonical_unit)
    if (length(o3_unit) > 0) {
      expect_true(grepl("µg/m³|ug/m3", o3_unit[1]))
    }
  }
  
  # 46. No forbidden causal / mechanistic terms in descriptive_label
  forbidden_terms <- c("dust", "inversion", "scavenging", "photochemical", "cause", "toxic", "safe", "healthy")
  for (lbl in labels_df$descriptive_label) {
    expect_false(any(sapply(forbidden_terms, function(term) grepl(term, tolower(lbl)))))
  }
  
  # 47. Station IDs map exactly to verified master metadata
  master_meta <- read_csv("../../scratch/verified_station_metadata.csv", show_col_types = FALSE)
  expect_true(all(hyd_hist$project_station_id %in% master_meta$project_station_id))
  expect_true(all(ind_hist$project_station_id %in% master_meta$project_station_id))
  
  # 48. Centroid-distance percentile summary table matches recomputation
  dist_sum <- read_csv("../../analysis/phase5A/tables/phase5A_recent_centroid_distance_summary.csv", show_col_types = FALSE)
  expect_equal(dist_sum %>% filter(scope == "HYDERABAD") %>% pull(mean_percentile), mean(hyd_rec$centroid_distance_percentile), tolerance = 1e-4)
  expect_equal(dist_sum %>% filter(scope == "INDIA") %>% pull(mean_percentile), mean(ind_rec$centroid_distance_percentile), tolerance = 1e-4)
  
  # 49. Full numeric consistency audit passes 100%
  num_audit <- read_csv("../../analysis/phase5A/tables/phase5A_numeric_consistency_audit.csv", show_col_types = FALSE)
  expect_true(all(num_audit$match))
})
