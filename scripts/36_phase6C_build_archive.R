# scripts/36_phase6C_build_archive.R
# Phase 6C: Assembles and audits review_archive_phase6C_light.zip
# Project: UrbanAirQualityIndex-PollutantDriftAnalysis (SML PBL, Code-Crew-Nexus)

suppressPackageStartupMessages({
  library(digest)
})

cat("============================================================\n")
cat("Phase 6C: Final Release Review Archive Builder & Auditor\n")
cat("============================================================\n\n")

archive_file <- "review_archive_phase6C_light.zip"
if (file.exists(archive_file)) {
  cat("Removing existing archive:", archive_file, "\n")
  unlink(archive_file)
}

# 1. Gather all files to include
files_to_pack <- character(0)

# Website core: All files in docs/ (excluding temporary/ignored)
docs_all <- list.files("docs", recursive = TRUE, full.names = TRUE)
files_to_pack <- c(files_to_pack, docs_all, "docs/.nojekyll")

# Canonical root documents
root_docs <- c(
  "README.md",
  "phase_6A_static_website_foundation_report.md",
  "phase_6A1_website_scientific_integrity_report.md",
  "phase_6A2_final_website_foundation_freeze_report.md",
  "phase_6B_interactive_scientific_integration_report.md",
  "phase_6B1_interactive_ui_integrity_report.md",
  "phase_6C_responsive_accessibility_deployment_release_report.md"
)
files_to_pack <- c(files_to_pack, root_docs[file.exists(root_docs)])

# Config specs
config_files <- list.files("config", recursive = TRUE, full.names = TRUE)
files_to_pack <- c(files_to_pack, config_files)

# Direct scientific source dependencies read by scripts/32_export_web_scientific_assets.R
scientific_deps <- c(
  "data/processed/UAQI_Master_Daily.csv",
  "data/analysis/phase3B/phase3B_current_drift_snapshot.csv",
  "config/selected_stations.csv",
  "data/analysis/phase3C/phase3C_current_drift_inference_results.csv",
  "analysis/phase4B/tables/phase4B_test_metrics.csv",
  "analysis/phase4B/tables/phase4B_holdout_metrics.csv",
  "analysis/phase4C/tables/phase4C_test_metrics.csv",
  "analysis/phase4C/tables/phase4C_holdout_metrics.csv",
  "analysis/phase5B/tables/phase5B_test_metrics.csv",
  "analysis/phase5B/tables/phase5B_holdout_metrics.csv",
  "analysis/phase5A/tables/phase5A_pca_variance_explained.csv",
  "analysis/phase5A/tables/phase5A_pca_loadings.csv",
  "analysis/phase5A/tables/phase5A_pca_selection.csv",
  "analysis/phase5A/tables/phase5A_cluster_labels.csv",
  "analysis/phase5A/tables/phase5A_cluster_profiles.csv",
  "analysis/phase5A/tables/phase5A_cluster_centroids_pca.csv",
  "data/analysis/phase5A/Hyderabad_PCA_History.csv",
  "data/analysis/phase5A/Hyderabad_Recent_Cluster_Assignments.csv",
  "data/analysis/phase5A/India_PCA_History.csv",
  "data/analysis/phase5A/India_Recent_Cluster_Assignments.csv"
)
files_to_pack <- c(files_to_pack, scientific_deps[file.exists(scientific_deps)])

# Pipeline, exporter, builder & QA scripts
script_files <- c(
  "scripts/09_phase2E_generate_final_aqi.R",
  "scripts/11_phase3B_pollutant_drift.R",
  "scripts/12_phase3C_statistical_inference.R",
  "scripts/30_export_web_assets.R",
  "scripts/31_phase6A_build_archive.R",
  "scripts/32_export_web_scientific_assets.R",
  "scripts/33_phase6B_build_archive.R",
  "scripts/34_phase6B_browser_smoke.py",
  "scripts/35_phase6C_browser_smoke.py",
  "scripts/36_phase6C_build_archive.R"
)
files_to_pack <- c(files_to_pack, script_files[file.exists(script_files)])

# Tests & fixtures
test_files <- c(
  "tests/testthat/test_phase6a_website.R",
  "tests/testthat/test_phase6b_website.R",
  "tests/testthat/test_phase6c_release.R",
  "tests/fixtures/math_smoke_fixtures.md"
)
files_to_pack <- c(files_to_pack, test_files[file.exists(test_files)])

# Phase 6B and Phase 6C UI review screenshots & tables
screenshot_files_6b <- list.files("analysis/phase6B/ui_review", pattern = "\\.png$", full.names = TRUE)
screenshot_files_6c <- list.files("analysis/phase6C/ui_review", pattern = "\\.png$", full.names = TRUE)
audit_table_6b <- "analysis/phase6B/tables/phase6B_archive_dependency_audit.csv"
files_to_pack <- c(files_to_pack, screenshot_files_6b, screenshot_files_6c, audit_table_6b[file.exists(audit_table_6b)])

# Normalize paths (forward slashes) and deduplicate
files_to_pack <- sort(unique(gsub("\\\\", "/", files_to_pack)))

# Remove directories if accidentally captured
files_to_pack <- files_to_pack[!dir.exists(files_to_pack)]

cat("Total unique files queued for packaging:", length(files_to_pack), "\n")

# Verify all files exist
missing_files <- files_to_pack[!file.exists(files_to_pack)]
if (length(missing_files) > 0) {
  stop("Missing files encountered before packaging:\n", paste(missing_files, collapse = "\n"))
}

# Verify exclusion list (no secrets, raw data, interim data, scratch, logs, or bulky model binaries)
excluded_patterns <- c("\\.Renviron", "data/raw", "data/interim", "data/modeling", "scratch/", "logs/", "models/", "\\.zip$")
for (pat in excluded_patterns) {
  leaks <- grep(pat, files_to_pack, value = TRUE)
  if (length(leaks) > 0) {
    stop("Forbidden file pattern matched for archive inclusion: ", pat, "\nMatched: ", paste(leaks, collapse = ", "))
  }
}

# Build archive using utils::zip
cat("Building zip archive:", archive_file, "...\n")
res <- utils::zip(archive_file, files_to_pack)

if (!file.exists(archive_file)) {
  stop("Failed to create zip archive: ", archive_file)
}

archive_bytes <- file.size(archive_file)
cat(sprintf("Archive successfully created: %s (%.2f MB)\n\n", archive_file, archive_bytes / (1024 * 1024)))

# Perform Archive Membership Audit
cat("--- Auditing Archive Membership ---\n")
zip_contents <- utils::unzip(archive_file, list = TRUE)
archive_members <- gsub("\\\\", "/", zip_contents$Name)

audit_df <- data.frame(
  file_path = files_to_pack,
  in_project = file.exists(files_to_pack),
  in_archive = files_to_pack %in% archive_members,
  stringsAsFactors = FALSE
)

audit_df$status <- ifelse(audit_df$in_project & audit_df$in_archive, "PASS", "FAIL")

audit_summary <- table(audit_df$status)
cat("Membership Audit Result:\n")
print(audit_summary)

if (any(audit_df$status != "PASS")) {
  failed <- audit_df[audit_df$status != "PASS", ]
  stop("Archive membership audit FAILED for:\n", paste(failed$file_path, collapse = "\n"))
}

cat("\n============================================================\n")
cat(sprintf("SUCCESS: %s is 100%% self-contained!\n", archive_file))
cat(sprintf("Total audited members: %d | All PASS\n", nrow(audit_df)))
cat("============================================================\n")
