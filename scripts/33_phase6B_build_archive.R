# scripts/33_phase6B_build_archive.R
# Phase 6B.1: Assembles and audits review_archive_phase6B1_light.zip
# Project: UrbanAirQualityIndex-PollutantDriftAnalysis (SML PBL, Code-Crew-Nexus)

suppressPackageStartupMessages({
  library(digest)
})

cat("============================================================\n")
cat("Phase 6B.1: Review Archive Builder & Membership Auditor\n")
cat("============================================================\n\n")

archive_file <- "review_archive_phase6B1_light.zip"
old_archives <- c(
  "review_archive_phase6A_light.zip",
  "review_archive_phase6A1_light.zip",
  "review_archive_phase6A2_light.zip",
  "review_archive_phase6B_light.zip",
  archive_file
)
for (oa in old_archives) {
  if (file.exists(oa)) {
    cat("Removing existing archive:", oa, "\n")
    unlink(oa)
  }
}

# 1. Gather all files to include
files_to_pack <- character(0)

# Website core & HTML
html_files <- list.files("docs", pattern = "\\.html$", full.names = TRUE)
files_to_pack <- c(files_to_pack, html_files, "docs/.nojekyll", "docs/favicon.ico")

# CSS and JS
css_files <- list.files("docs/assets/css", recursive = TRUE, full.names = TRUE)
js_files <- list.files("docs/assets/js", recursive = TRUE, full.names = TRUE)
files_to_pack <- c(files_to_pack, css_files, js_files)

# Vendor assets
vendor_files <- list.files("docs/assets/vendor", recursive = TRUE, full.names = TRUE)
files_to_pack <- c(files_to_pack, vendor_files)

# Guide documentation
guide_files <- list.files("docs/guide", recursive = TRUE, full.names = TRUE)
files_to_pack <- c(files_to_pack, guide_files)

# Canonical docs referenced in manifest and audits
canonical_docs <- c(
  "README.md",
  "docs/TEAM.md",
  "docs/WEBSITE_SCIENTIFIC_TRUTH.md",
  "docs/WEBSITE_SCIENTIFIC_SOURCE_AUDIT.md",
  "docs/PACKAGE_REQUIREMENTS.md",
  "docs/WEBSITE_DOCUMENTATION_AUDIT.md",
  "docs/WEBSITE_LINK_AUDIT.md",
  "docs/WEB_SCIENTIFIC_ARTIFACT_MAP.md",
  "docs/ENVIRONMENT.md",
  "docs/cpcb_aqi_methodology_verified.md",
  "docs/data_sources.md",
  "docs/dataset_schema.md",
  "docs/methodology.md",
  "docs/MODELING_FREEZE_SUMMARY.md",
  "docs/PROJECT_CHECKPOINTS.md",
  "docs/phase1_station_selection_decision.md",
  "docs/reports/phase2_data_aqi_summary.md",
  "docs/reports/phase3_statistical_analysis_summary.md",
  "docs/reports/phase4_supervised_learning_summary.md",
  "docs/reports/phase5_pca_kmeans_summary.md",
  "docs/reports/phase5b_svm_summary.md"
)
files_to_pack <- c(files_to_pack, canonical_docs[file.exists(canonical_docs)])

# Documentation figure assets
figure_files <- list.files("docs/figures", pattern = "\\.png$", full.names = TRUE)
files_to_pack <- c(files_to_pack, figure_files)

# Internal phase history docs
hist_files <- list.files("docs/internal_phase_history", pattern = "\\.md$", full.names = TRUE)
files_to_pack <- c(files_to_pack, hist_files)

# Config specs
config_files <- list.files("config", recursive = TRUE, full.names = TRUE)
files_to_pack <- c(files_to_pack, config_files)

# Web data JSON
web_data_files <- list.files("docs/web-data", recursive = TRUE, full.names = TRUE)
files_to_pack <- c(files_to_pack, web_data_files)

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

# Exporter, builder & QA scripts
script_files <- c(
  "scripts/09_phase2E_generate_final_aqi.R",
  "scripts/11_phase3B_pollutant_drift.R",
  "scripts/12_phase3C_statistical_inference.R",
  "scripts/30_export_web_assets.R",
  "scripts/31_phase6A_build_archive.R",
  "scripts/32_export_web_scientific_assets.R",
  "scripts/33_phase6B_build_archive.R",
  "scripts/34_phase6B_browser_smoke.py"
)
files_to_pack <- c(files_to_pack, script_files[file.exists(script_files)])

# Tests & fixtures
test_files <- c(
  "tests/testthat/test_phase6a_website.R",
  "tests/testthat/test_phase6b_website.R",
  "tests/fixtures/math_smoke_fixtures.md"
)
files_to_pack <- c(files_to_pack, test_files[file.exists(test_files)])

# Phase reports at root
reports_to_pack <- c(
  "phase_6A_static_website_foundation_report.md",
  "phase_6A1_website_scientific_integrity_report.md",
  "phase_6A2_final_website_foundation_freeze_report.md",
  "phase_6B_interactive_scientific_integration_report.md",
  "phase_6B1_interactive_ui_integrity_report.md"
)
files_to_pack <- c(files_to_pack, reports_to_pack[file.exists(reports_to_pack)])

# Phase 6B UI review screenshots
screenshot_files <- list.files("analysis/phase6B/ui_review", pattern = "\\.png$", full.names = TRUE)
files_to_pack <- c(files_to_pack, screenshot_files)

# Generate Dependency Audit Table before packing
tables_dir <- "analysis/phase6B/tables"
if (!dir.exists(tables_dir)) {
  dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)
}
audit_table_path <- file.path(tables_dir, "phase6B_archive_dependency_audit.csv")

dep_metadata <- list(
  list(path = "data/processed/UAQI_Master_Daily.csv", phase = "Phase 2E", purpose = "Daily observations time series (11,970 scheduled rows)"),
  list(path = "data/analysis/phase3B/phase3B_current_drift_snapshot.csv", phase = "Phase 3B", purpose = "Drift snapshot (Dz, recent/baseline means, 147 rows)"),
  list(path = "config/selected_stations.csv", phase = "Phase 1", purpose = "21 selected CAAQMS station metadata and panels"),
  list(path = "data/analysis/phase3C/phase3C_current_drift_inference_results.csv", phase = "Phase 3C", purpose = "Statistical inference results (MBB, BH-FDR, 147 rows)"),
  list(path = "analysis/phase4B/tables/phase4B_test_metrics.csv", phase = "Phase 4B", purpose = "Supervised regression TEST metrics (MLR Model B vs Persistence)"),
  list(path = "analysis/phase4B/tables/phase4B_holdout_metrics.csv", phase = "Phase 4B", purpose = "Supervised regression Holdout metrics (MLR Model B vs Persistence)"),
  list(path = "analysis/phase4C/tables/phase4C_test_metrics.csv", phase = "Phase 4C", purpose = "Adverse event classification TEST metrics (Logistic Model B vs Persistence)"),
  list(path = "analysis/phase4C/tables/phase4C_holdout_metrics.csv", phase = "Phase 4C", purpose = "Adverse event classification Holdout metrics (Logistic Model B vs Persistence)"),
  list(path = "analysis/phase5B/tables/phase5B_test_metrics.csv", phase = "Phase 5B", purpose = "Adverse event classification TEST metrics (RBF SVM)"),
  list(path = "analysis/phase5B/tables/phase5B_holdout_metrics.csv", phase = "Phase 5B", purpose = "Adverse event classification Holdout metrics (RBF SVM)"),
  list(path = "analysis/phase5A/tables/phase5A_pca_variance_explained.csv", phase = "Phase 5A", purpose = "PCA variance explained table across 6 sensor features"),
  list(path = "analysis/phase5A/tables/phase5A_pca_selection.csv", phase = "Phase 5A", purpose = "PCA component retention selection criteria"),
  list(path = "analysis/phase5A/tables/phase5A_cluster_labels.csv", phase = "Phase 5A", purpose = "K-Means cluster descriptive labels (K=3)"),
  list(path = "analysis/phase5A/tables/phase5A_cluster_profiles.csv", phase = "Phase 5A", purpose = "K-Means cluster sensor centroid profiles"),
  list(path = "analysis/phase5A/tables/phase5A_cluster_centroids_pca.csv", phase = "Phase 5A", purpose = "K-Means cluster PC1/PC2 centroid coordinates"),
  list(path = "data/analysis/phase5A/Hyderabad_PCA_History.csv", phase = "Phase 5A", purpose = "Hyderabad panel historical PCA scores"),
  list(path = "data/analysis/phase5A/Hyderabad_Recent_Cluster_Assignments.csv", phase = "Phase 5A", purpose = "Hyderabad panel recent holdout cluster assignments"),
  list(path = "data/analysis/phase5A/India_PCA_History.csv", phase = "Phase 5A", purpose = "India representative panel historical PCA scores"),
  list(path = "data/analysis/phase5A/India_Recent_Cluster_Assignments.csv", phase = "Phase 5A", purpose = "India representative panel recent holdout cluster assignments")
)

audit_rows <- lapply(dep_metadata, function(item) {
  f_exists <- file.exists(item$path)
  f_bytes <- if (f_exists) file.size(item$path) else 0
  f_hash <- if (f_exists) digest::digest(file = item$path, algo = "sha256") else "MISSING"
  data.frame(
    dependency_file = item$path,
    scientific_phase = item$phase,
    purpose = item$purpose,
    file_bytes = f_bytes,
    sha256 = f_hash,
    in_project = f_exists,
    status = if (f_exists && f_bytes > 0) "PASS" else "FAIL",
    stringsAsFactors = FALSE
  )
})
dep_audit_df <- do.call(rbind, audit_rows)
write.csv(dep_audit_df, audit_table_path, row.names = FALSE)
cat("Wrote dependency audit table to:", audit_table_path, "\n")

# Add audit table to package
files_to_pack <- c(files_to_pack, audit_table_path)

# Normalize paths (forward slashes) and deduplicate
files_to_pack <- sort(unique(gsub("\\\\", "/", files_to_pack)))

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
