# ==============================================================================
# scripts/19b_phase5A2_reproducibility_check.R
# Reproducibility and Tracked-Input Validation for Phase 5A Unsupervised Layer
# ==============================================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(testthat)
})

cat("================================================================================\n")
cat("PHASE 5A.2 REPRODUCIBILITY & TRACKED-INPUT INTEGRITY CHECK\n")
cat("================================================================================\n\n")

# 1. Tracked Primary Data & Metadata Inputs
required_inputs <- c(
  "data/processed/UAQI_Master_Daily.csv",
  "data/processed/UAQI_Hyderabad_Daily.csv",
  "data/processed/UAQI_India_Daily.csv",
  "data/metadata/station_catalog.csv",
  "data/metadata/pollutant_dictionary.csv"
)

cat("1. Checking tracked primary data & metadata inputs...\n")
for (f in required_inputs) {
  if (!file.exists(f)) {
    stop(paste("CRITICAL: Missing required input file:", f))
  }
  cat("  [OK] Found:", f, "\n")
}

# 2. Tracked Models & Phase 5 Artifacts
required_artifacts <- c(
  "models/phase5A/hyderabad_pca.rds",
  "models/phase5A/hyderabad_kmeans.rds",
  "models/phase5A/india_pca.rds",
  "models/phase5A/india_kmeans.rds",
  "data/analysis/phase5A/Hyderabad_PCA_History.csv",
  "data/analysis/phase5A/India_PCA_History.csv",
  "data/analysis/phase5A/Hyderabad_Recent_Cluster_Assignments.csv",
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
  "analysis/phase5A/tables/phase5A_numeric_consistency_audit.csv",
  "analysis/phase5A/tables/phase5A_report_generation_integrity.csv"
)

cat("\n2. Checking Phase 5 analysis artifacts & models...\n")
for (f in required_artifacts) {
  if (!file.exists(f)) {
    stop(paste("CRITICAL: Missing required artifact file:", f))
  }
  cat("  [OK] Found:", f, "\n")
}

# 3. Validating Complete-Case Observations
cat("\n3. Validating observation counts...\n")
hyd_hist <- read_csv("data/analysis/phase5A/Hyderabad_PCA_History.csv", show_col_types = FALSE)
ind_hist <- read_csv("data/analysis/phase5A/India_PCA_History.csv", show_col_types = FALSE)
hyd_rec  <- read_csv("data/analysis/phase5A/Hyderabad_Recent_Cluster_Assignments.csv", show_col_types = FALSE)
ind_rec  <- read_csv("data/analysis/phase5A/India_Recent_Cluster_Assignments.csv", show_col_types = FALSE)

stopifnot(nrow(hyd_hist) == 2749)
stopifnot(nrow(hyd_rec) == 121)
stopifnot(nrow(ind_hist) == 6796)
stopifnot(nrow(ind_rec) == 262)

cat("  [OK] Hyderabad History complete cases:", nrow(hyd_hist), "(expected 2749)\n")
cat("  [OK] Hyderabad Recent complete cases: ", nrow(hyd_rec), "(expected 121)\n")
cat("  [OK] India History complete cases:    ", nrow(ind_hist), "(expected 6796)\n")
cat("  [OK] India Recent complete cases:     ", nrow(ind_rec), "(expected 262)\n")

# 4. Check for Zero Dependency on Scratch / Ignored Paths in Test Suite
cat("\n4. Checking for zero scratch/ignored dependencies in tests...\n")
test_code <- read_file("tests/testthat/test_phase5a.R")
if (grepl("scratch/", test_code)) {
  stop("CRITICAL: test_phase5a.R still contains dependencies on 'scratch/'!")
}
cat("  [OK] Zero 'scratch/' references in test_phase5a.R\n")

# 5. Programmatic Execution of Test Suite
cat("\n5. Running tests/testthat/test_phase5a.R...\n")
test_res <- testthat::test_file("tests/testthat/test_phase5a.R")
df_res <- as.data.frame(test_res)

n_fail <- sum(df_res$failed)
n_warn <- sum(df_res$warning)
n_skip <- sum(df_res$skipped)
n_pass <- sum(df_res$passed)

cat("\n================================================================================\n")
cat("TEST SUITE EXECUTION SUMMARY:\n")
cat("  Blocks executed: ", nrow(df_res), "\n")
cat("  Assertions passed: ", n_pass, "\n")
cat("  Failures:          ", n_fail, "\n")
cat("  Warnings:          ", n_warn, "\n")
cat("  Skips:             ", n_skip, "\n")
cat("================================================================================\n")

if (n_fail > 0 || n_skip > 0) {
  stop("CRITICAL: Test suite did not complete with 100% pass and 0 skips!")
}

cat(">>> Phase 5A.2 Reproducibility Check PASSED completely.\n")
