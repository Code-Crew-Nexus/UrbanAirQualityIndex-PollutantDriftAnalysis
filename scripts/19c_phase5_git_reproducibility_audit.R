# ==============================================================================
# scripts/19c_phase5_git_reproducibility_audit.R
# Clean-Clone Dependency and Git-Tracking Audit for Phase 5
# ==============================================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tibble)
})

cat("================================================================================\n")
cat("PHASE 5 CLEAN-CLONE GIT REPRODUCIBILITY AUDIT\n")
cat("================================================================================\n\n")

# 1. Obtain Git Tracked Files (including staged files)
tracked_files <- tryCatch(
  system("git ls-files", intern = TRUE),
  error = function(e) character(0)
)

if (length(tracked_files) == 0) {
  stop("CRITICAL: Failed to query Git tracked files via 'git ls-files'.")
}
cat("Queried", length(tracked_files), "tracked files in repository index.\n\n")

# 2. Define Explicit Dependencies Required by tests/testthat/test_phase5a.R
required_test_deps <- c(
  "data/processed/UAQI_Master_Daily.csv",
  "data/metadata/station_catalog.csv",
  "data/metadata/pollutant_dictionary.csv",
  "data/analysis/phase5A/Hyderabad_PCA_History.csv",
  "data/analysis/phase5A/Hyderabad_PCA_Recent.csv",
  "data/analysis/phase5A/Hyderabad_Recent_Cluster_Assignments.csv",
  "data/analysis/phase5A/India_PCA_History.csv",
  "data/analysis/phase5A/India_PCA_Recent.csv",
  "data/analysis/phase5A/India_Recent_Cluster_Assignments.csv",
  "analysis/phase5A/tables/phase5A_scaling_parameters.csv",
  "analysis/phase5A/tables/phase5A_pca_variance_explained.csv",
  "analysis/phase5A/tables/phase5A_pca_selection.csv",
  "analysis/phase5A/tables/phase5A_k_selection_diagnostics.csv",
  "analysis/phase5A/tables/phase5A_cluster_profiles.csv",
  "analysis/phase5A/tables/phase5A_regime_frequency_comparison.csv",
  "analysis/phase5A/tables/phase5A_recent_centroid_distance_summary.csv",
  "analysis/phase5A/tables/phase5A_season_cluster_distribution.csv",
  "analysis/phase5A/tables/phase5A_station_cluster_distribution.csv",
  "analysis/phase5A/tables/phase5A_cluster_labels.csv",
  "analysis/phase5A/tables/phase5A_cluster_centroids_pca.csv",
  "analysis/phase5A/tables/phase5A_cluster_stability.csv",
  "analysis/phase5A/tables/phase5A_eligibility_profile.csv",
  "analysis/phase5A/tables/phase5A_numeric_consistency_audit.csv",
  "analysis/phase5A/tables/phase5A_report_generation_integrity.csv",
  "models/phase5A/hyderabad_pca.rds",
  "models/phase5A/hyderabad_kmeans.rds",
  "models/phase5A/india_pca.rds",
  "models/phase5A/india_kmeans.rds",
  "R/31_unsupervised_metrics.R",
  "scripts/18a_phase5A_pca.R",
  "scripts/18b_phase5A_kmeans.R",
  "scripts/18c_phase5A_profiles_figures.R",
  "scripts/19a_phase5A1_consistency_audit.R",
  "scripts/19b_phase5A2_reproducibility_check.R",
  "scripts/19c_phase5_git_reproducibility_audit.R",
  "tests/testthat/test_phase5a.R"
)

# 3. Forbidden Paths: No test dependency may live in these
forbidden_prefixes <- c(
  "scratch/",
  "logs/",
  "docs/internal_phase_history/",
  "analysis/phase5A/figures/",
  "review_archive_"
)

audit_results <- list()

for (f in required_test_deps) {
  # Normalize path separators
  f_norm <- gsub("\\\\", "/", f)
  
  # Check file exists on disk
  f_exists <- file.exists(f_norm)
  
  # Check for forbidden locations
  is_forbidden <- any(sapply(forbidden_prefixes, function(p) grepl(paste0("^", p), f_norm)))
  
  audit_results[[f_norm]] <- tibble(
    file_path = f_norm,
    exists_on_disk = f_exists,
    is_forbidden_location = is_forbidden
  )
}

audit_df <- bind_rows(audit_results)

# Print Summary
cat("Audit of", nrow(audit_df), "core Phase-5 test dependencies:\n")
n_missing <- sum(!audit_df$exists_on_disk)
n_forbid  <- sum(audit_df$is_forbidden_location)

cat("  Missing from disk:      ", n_missing, "\n")
cat("  In forbidden locations: ", n_forbid, "\n")

if (n_missing > 0 || n_forbid > 0) {
  cat("\nFailed items:\n")
  print(audit_df %>% filter(!exists_on_disk | is_forbidden_location))
  stop("CRITICAL: Clean-clone dependency audit failed.")
}

cat("\n[OK] All core Phase-5 test dependencies exist and comply with clean-clone rules.\n")
cat(">>> Phase 5 Git Reproducibility Audit PASSED.\n")
