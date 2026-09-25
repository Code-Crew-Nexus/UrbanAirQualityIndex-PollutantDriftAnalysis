# ==============================================================================
# tests/testthat/test_phase5a.R
# Comprehensive Test Suite for Phase 5A / 5A.2 Unsupervised Learning & PCA
# ==============================================================================

library(testthat)
library(dplyr)
library(readr)
source("../../R/31_unsupervised_metrics.R")

pca_features <- c("pm2_5_aqi_input", "pm10_aqi_input", "o3_8h_max", "temperature", "humidity", "wind_speed")

# ==============================================================================
# BLOCK A: Feature Contract & PCA Constraints
# ==============================================================================
test_that("Phase 5A: Feature and PCA Contract", {
  # 1. Exact six-feature contract in scaling parameters
  scales <- read_csv("../../analysis/phase5A/tables/phase5A_scaling_parameters.csv", show_col_types = FALSE)
  expect_equal(sort(unique(scales$feature)), sort(pca_features))
  
  # 2. Excluded fields: AQI, gases, target, drift inference
  expect_false("aqi_verified" %in% scales$feature)
  expect_false("aqi_category" %in% scales$feature)
  expect_false(any(c("co_source_mean", "no2_source_mean", "so2_source_mean") %in% scales$feature))
  expect_false(any(grepl("target", scales$feature)))
  expect_false(any(c("drift_z", "p_value_raw", "p_value_fdr") %in% scales$feature))
  
  # 3. Modeling-history date boundary exact (2025-03-01 to 2026-08-31)
  hyd_hist <- read_csv("../../data/analysis/phase5A/Hyderabad_PCA_History.csv", show_col_types = FALSE)
  expect_equal(min(hyd_hist$date), as.Date("2025-03-01"))
  expect_equal(max(hyd_hist$date), as.Date("2026-08-31"))
  expect_false(any(hyd_hist$date >= as.Date("2026-09-01")))
  
  # 4. No imputation: eligibility profile accounts for incomplete rows
  elig <- read_csv("../../analysis/phase5A/tables/phase5A_eligibility_profile.csv", show_col_types = FALSE)
  expect_true(all(elig$structural_rows == elig$complete_rows + elig$incomplete_rows))
  
  # 5. Scaler parameters strictly learned from history with training_sd > 0
  expect_true(all(scales$training_sd > 0))
  ind_hist <- read_csv("../../data/analysis/phase5A/India_PCA_History.csv", show_col_types = FALSE)
  ind_scale <- scales %>% filter(scope == "INDIA")
  for (f in pca_features) {
    m_calc <- mean(ind_hist[[f]])
    sd_calc <- sd(ind_hist[[f]])
    m_st <- ind_scale %>% filter(feature == f) %>% pull(training_mean)
    sd_st <- ind_scale %>% filter(feature == f) %>% pull(training_sd)
    expect_equal(m_calc, m_st, tolerance = 1e-6)
    expect_equal(sd_calc, sd_st, tolerance = 1e-6)
  }
  
  # 6. Standardized history has zero mean and unit variance
  hyd_scale <- scales %>% filter(scope == "HYDERABAD")
  for (f in pca_features) {
    m_val <- hyd_scale %>% filter(feature == f) %>% pull(training_mean)
    s_val <- hyd_scale %>% filter(feature == f) %>% pull(training_sd)
    z <- (hyd_hist[[f]] - m_val) / s_val
    expect_true(abs(mean(z)) < 1e-10)
    expect_true(abs(sd(z) - 1.0) < 1e-10)
  }
  
  # 7. prcomp fits history observations only
  hyd_pca <- readRDS("../../models/phase5A/hyderabad_pca.rds")
  ind_pca <- readRDS("../../models/phase5A/india_pca.rds")
  expect_equal(nrow(hyd_pca$x), nrow(hyd_hist))
  expect_equal(nrow(ind_pca$x), nrow(ind_hist))
  
  # 8. Retained PC rule: >= 80% cumulative variance with exactly 4 PCs retained
  pca_sel <- read_csv("../../analysis/phase5A/tables/phase5A_pca_selection.csv", show_col_types = FALSE)
  pca_var <- read_csv("../../analysis/phase5A/tables/phase5A_pca_variance_explained.csv", show_col_types = FALSE)
  expect_equal(pca_sel %>% filter(scope == "HYDERABAD") %>% pull(retained_pc_count), 4)
  expect_equal(pca_sel %>% filter(scope == "INDIA") %>% pull(retained_pc_count), 4)
  expect_true(all(pca_sel$cumulative_variance_at_selection >= 0.80))
  
  # 9. Verify PC3 cumulative variance is strictly < 0.80 for both scopes
  for (scp in c("HYDERABAD", "INDIA")) {
    cum_pc3 <- pca_var %>% filter(scope == scp, PC == "PC3") %>% pull(cumulative_variance)
    expect_true(cum_pc3 < 0.80)
  }
})

# ==============================================================================
# BLOCK B: K-Means Selection and Centroids
# ==============================================================================
test_that("Phase 5A: K-Means Selection and Centroids", {
  k_diag <- read_csv("../../analysis/phase5A/tables/phase5A_k_selection_diagnostics.csv", show_col_types = FALSE)
  
  # 1. K candidates tested span 2 through 8
  expect_equal(sort(unique(k_diag$k)), 2:8)
  
  # 2. Feasibility constraint: smallest cluster >= 2% and >= 30 observations
  expect_true(all(k_diag %>% filter(!is_feasible) %>% pull(smallest_cluster_pct) < 2.0 |
                  k_diag %>% filter(!is_feasible) %>% pull(minimum_cluster_size) < 30))
  
  # 3. Algorithmic K-selection rule: maximize silhouette under 0.01 tie rule -> k=3
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
  
  # 4. K-Means fits history complete cases only
  hyd_hist <- read_csv("../../data/analysis/phase5A/Hyderabad_PCA_History.csv", show_col_types = FALSE)
  ind_hist <- read_csv("../../data/analysis/phase5A/India_PCA_History.csv", show_col_types = FALSE)
  hyd_km <- readRDS("../../models/phase5A/hyderabad_kmeans.rds")
  ind_km <- readRDS("../../models/phase5A/india_kmeans.rds")
  expect_equal(sum(hyd_km$size), nrow(hyd_hist))
  expect_equal(sum(ind_km$size), nrow(ind_hist))
  expect_equal(sum(hyd_km$size), 2749)
  expect_equal(sum(ind_km$size), 6796)
  
  # 5. Centroids in PCA space match serialized model centers
  cents <- read_csv("../../analysis/phase5A/tables/phase5A_cluster_centroids_pca.csv", show_col_types = FALSE)
  hyd_cents <- cents %>% filter(scope == "HYDERABAD") %>% select(PC1, PC2, PC3, PC4)
  expect_equal(unname(as.matrix(hyd_cents)), unname(hyd_km$centers), tolerance = 1e-8)
  
  ind_cents <- cents %>% filter(scope == "INDIA") %>% select(PC1, PC2, PC3, PC4)
  expect_equal(unname(as.matrix(ind_cents)), unname(ind_km$centers), tolerance = 1e-8)
  
  # 6. Multi-start seed stability: ARI bounded in [-1, 1] and equals 1.0 across tested seeds
  stab <- read_csv("../../analysis/phase5A/tables/phase5A_cluster_stability.csv", show_col_types = FALSE)
  expect_true(all(stab$ARI_against_primary >= -1.0 & stab$ARI_against_primary <= 1.0))
  expect_equal(min(stab$ARI_against_primary), 1.0, tolerance = 1e-4)
})

# ==============================================================================
# BLOCK C: Recent Projection and Distance Percentiles
# ==============================================================================
test_that("Phase 5A: Recent Projection and Distance Percentiles", {
  hyd_rec  <- read_csv("../../data/analysis/phase5A/Hyderabad_Recent_Cluster_Assignments.csv", show_col_types = FALSE)
  ind_rec  <- read_csv("../../data/analysis/phase5A/India_Recent_Cluster_Assignments.csv", show_col_types = FALSE)
  hyd_pca  <- readRDS("../../models/phase5A/hyderabad_pca.rds")
  hyd_km   <- readRDS("../../models/phase5A/hyderabad_kmeans.rds")
  scales   <- read_csv("../../analysis/phase5A/tables/phase5A_scaling_parameters.csv", show_col_types = FALSE)
  hyd_scale <- scales %>% filter(scope == "HYDERABAD")
  
  # 1. Recent sample sizes match complete cases
  expect_equal(nrow(hyd_rec), 121)
  expect_equal(nrow(ind_rec), 262)
  
  # 2. Recent projection uses frozen PCA transformation
  means_h <- setNames(hyd_scale$training_mean, hyd_scale$feature)
  sds_h   <- setNames(hyd_scale$training_sd, hyd_scale$feature)
  X_rec_mat <- as.matrix(hyd_rec[, pca_features])
  X_rec_std <- scale(X_rec_mat, center = means_h, scale = sds_h)
  attr(X_rec_std, "scaled:center") <- NULL
  attr(X_rec_std, "scaled:scale") <- NULL
  scores_manual <- X_rec_std %*% hyd_pca$rotation
  expect_equal(as.matrix(hyd_rec[, paste0("PC", 1:4)]), scores_manual[, 1:4], tolerance = 1e-8)
  
  # 3. Recent assignments match nearest frozen centroid
  dists_to_c <- calc_distance_to_centroids(as.matrix(hyd_rec[, paste0("PC", 1:4)]), hyd_km$centers)
  nearest_idx <- apply(dists_to_c, 1, which.min)
  expect_equal(hyd_rec$assigned_cluster, paste0("Cluster ", nearest_idx))
  
  # 4. Centroid distance percentiles strictly bounded in [0, 1]
  expect_true(all(hyd_rec$centroid_distance_percentile >= 0 & hyd_rec$centroid_distance_percentile <= 1))
  expect_true(all(ind_rec$centroid_distance_percentile >= 0 & ind_rec$centroid_distance_percentile <= 1))
  
  # 5. Centroid distance summary matches empirical distributions
  dist_sum <- read_csv("../../analysis/phase5A/tables/phase5A_recent_centroid_distance_summary.csv", show_col_types = FALSE)
  expect_equal(dist_sum %>% filter(scope == "HYDERABAD") %>% pull(mean_percentile), mean(hyd_rec$centroid_distance_percentile), tolerance = 1e-4)
  expect_equal(dist_sum %>% filter(scope == "INDIA") %>% pull(mean_percentile), mean(ind_rec$centroid_distance_percentile), tolerance = 1e-4)
  expect_equal(dist_sum %>% filter(scope == "HYDERABAD") %>% pull(count_ge_95), sum(hyd_rec$centroid_distance_percentile >= 0.95))
  expect_equal(dist_sum %>% filter(scope == "INDIA") %>% pull(count_ge_95), sum(ind_rec$centroid_distance_percentile >= 0.95))
  expect_equal(dist_sum %>% filter(scope == "HYDERABAD") %>% pull(count_ge_95), 3)
  expect_equal(dist_sum %>% filter(scope == "INDIA") %>% pull(count_ge_95), 2)
})

# ==============================================================================
# BLOCK D: Metadata, Units, and De-Causalization
# ==============================================================================
test_that("Phase 5A: Metadata, Units, and De-Causalization", {
  # 1. Authoritative station metadata from tracked station_catalog.csv
  station_catalog_path <- "../../data/metadata/station_catalog.csv"
  expect_true(file.exists(station_catalog_path))
  st_catalog <- read_csv(station_catalog_path, show_col_types = FALSE)
  expect_true("project_station_id" %in% names(st_catalog))
  expect_true("station_name" %in% names(st_catalog))
  
  # 2. Hyderabad exactly 7 stations, India exactly 15 stations
  hyd_hist <- read_csv("../../data/analysis/phase5A/Hyderabad_PCA_History.csv", show_col_types = FALSE)
  ind_hist <- read_csv("../../data/analysis/phase5A/India_PCA_History.csv", show_col_types = FALSE)
  expect_equal(length(unique(hyd_hist$project_station_id)), 7)
  expect_equal(length(unique(ind_hist$project_station_id)), 15)
  expect_true(all(hyd_hist$project_station_id %in% st_catalog$project_station_id))
  expect_true(all(ind_hist$project_station_id %in% st_catalog$project_station_id))
  
  # 3. Zoo Park (PROJ_007) intentional overlap verified
  expect_true("PROJ_007" %in% hyd_hist$project_station_id)
  expect_true("PROJ_007" %in% ind_hist$project_station_id)
  zoo_row <- st_catalog %>% filter(project_station_id == "PROJ_007")
  expect_true(grepl("Zoo Park", zoo_row$station_name))
  
  # 4. Hardened O3 unit test: pollutant_dictionary.csv must exist and declare µg/m³
  dict_path <- "../../data/metadata/pollutant_dictionary.csv"
  expect_true(file.exists(dict_path))
  dict_df <- read_csv(dict_path, show_col_types = FALSE)
  o3_rows <- dict_df %>% filter(canonical_name == "o3")
  expect_equal(nrow(o3_rows), 1)
  expect_true(grepl("µg/m³|ug/m3", o3_rows$canonical_unit[1]))
  
  # 5. Descriptive cluster labels must be free of unmeasured causal/mechanistic assertions
  labels_df <- read_csv("../../analysis/phase5A/tables/phase5A_cluster_labels.csv", show_col_types = FALSE)
  expect_equal(nrow(labels_df), 6) # 3 for Hyderabad + 3 for India
  forbidden_terms <- c("dust", "inversion", "scavenging", "photochemical", "cause", "toxic", "safe", "healthy")
  for (lbl in labels_df$descriptive_label) {
    expect_false(any(sapply(forbidden_terms, function(term) grepl(term, tolower(lbl)))))
  }
  
  # 6. Caution field confirms descriptive unsupervised regime
  expect_true(all(grepl("Descriptive unsupervised regime", labels_df$caution)))
})

# ==============================================================================
# BLOCK E: Numerical Consistency & Cross-Tabulations
# ==============================================================================
test_that("Phase 5A: Numerical Consistency and Scaler Recovery", {
  # 1. Full numeric consistency audit passes 100%
  num_audit_path <- "../../analysis/phase5A/tables/phase5A_numeric_consistency_audit.csv"
  expect_true(file.exists(num_audit_path))
  num_audit <- read_csv(num_audit_path, show_col_types = FALSE)
  expect_true(nrow(num_audit) >= 120)
  expect_true(all(num_audit$match))
  
  # 2. PCA variance sums to exactly 1.000000 by scope
  pca_var <- read_csv("../../analysis/phase5A/tables/phase5A_pca_variance_explained.csv", show_col_types = FALSE)
  var_sums <- pca_var %>%
    group_by(scope) %>%
    summarise(tot_var = sum(variance_explained), tot_eig = sum(eigenvalue), .groups = "drop")
  expect_equal(var_sums$tot_var, c(1.0, 1.0), tolerance = 1e-6)
  expect_equal(var_sums$tot_eig, c(6.0, 6.0), tolerance = 1e-6)
  
  # 3. Recent frequency percentages sum to 100%
  freq_df <- read_csv("../../analysis/phase5A/tables/phase5A_regime_frequency_comparison.csv", show_col_types = FALSE)
  rec_sums <- freq_df %>%
    filter(period == "RECENT_EVALUATION") %>%
    group_by(scope) %>%
    summarise(tot_pct = sum(percentage), tot_n = sum(n), .groups = "drop")
  expect_true(all(abs(rec_sums$tot_pct - 100) < 0.2))
  expect_equal(rec_sums %>% filter(scope == "HYDERABAD") %>% pull(tot_n), 121)
  expect_equal(rec_sums %>% filter(scope == "INDIA") %>% pull(tot_n), 262)
  
  # 4. History cluster profiles match exact sample sizes
  profiles_df <- read_csv("../../analysis/phase5A/tables/phase5A_cluster_profiles.csv", show_col_types = FALSE)
  hyd_prof_sizes <- profiles_df %>%
    filter(scope == "HYDERABAD", variable == "pm2_5_aqi_input") %>%
    arrange(cluster) %>%
    pull(n)
  expect_equal(hyd_prof_sizes, c(866, 962, 921))
  
  ind_prof_sizes <- profiles_df %>%
    filter(scope == "INDIA", variable == "pm2_5_aqi_input") %>%
    arrange(cluster) %>%
    pull(n)
  expect_equal(ind_prof_sizes, c(1261, 1764, 3771))
  
  # 5. Station cluster shares sum to 100%
  st_dist <- read_csv("../../analysis/phase5A/tables/phase5A_station_cluster_distribution.csv", show_col_types = FALSE)
  st_sums <- st_dist %>%
    group_by(scope, station_name) %>%
    summarise(tot_hist = sum(history_pct), .groups = "drop")
  expect_true(all(abs(st_sums$tot_hist - 100) < 0.2))
  
  # 6. Season cluster shares sum to 100%
  sea_dist <- read_csv("../../analysis/phase5A/tables/phase5A_season_cluster_distribution.csv", show_col_types = FALSE)
  sea_sums <- sea_dist %>%
    group_by(scope, season) %>%
    summarise(tot_pct = sum(pct), .groups = "drop")
  expect_true(all(abs(sea_sums$tot_pct - 100) < 0.2))
})

# ==============================================================================
# BLOCK F: Reproducibility & Pipeline Safety
# ==============================================================================
test_that("Phase 5A: Reproducibility and Code Safety", {
  # 1. Zero network calls or external fetch commands in scripts
  all_scripts <- c(
    "../../scripts/18a_phase5A_pca.R",
    "../../scripts/18b_phase5A_kmeans.R",
    "../../scripts/18c_phase5A_profiles_figures.R",
    "../../scripts/19a_phase5A1_consistency_audit.R",
    "../../scripts/19b_phase5A2_reproducibility_check.R"
  )
  for (sc in all_scripts) {
    expect_true(file.exists(sc))
    code_text <- read_file(sc)
    expect_false(grepl("curl|httr|download.file|openaq.org|open-meteo.com", code_text))
  }
  
  # 2. Frozen Phase-4 supervised learning outputs remain untouched
  expect_true(file.exists("../../analysis/phase4C/tables/phase4_supervised_learning_summary.csv"))
  expect_true(file.exists("../../models/phase4C/hyderabad_model_B_train.rds"))
  expect_true(file.exists("../../models/phase4B/india_model_B_train.rds"))
  
  # 3. Report generation integrity documentation exists
  expect_true(file.exists("../../analysis/phase5A/tables/phase5A_report_generation_integrity.csv"))
})
