# scripts/31_phase6A_build_archive.R
# Phase 6A: Assembles and audits review_archive_phase6A_light.zip

cat("============================================================\n")
cat("Phase 6A: Review Archive Builder & Membership Auditor\n")
cat("============================================================\n\n")

archive_file <- "review_archive_phase6A_light.zip"
if (file.exists(archive_file)) {
  cat("Removing existing archive:", archive_file, "\n")
  unlink(archive_file)
}

# 1. Gather all files to include
files_to_pack <- character(0)

# Website core & HTML
html_files <- list.files("docs", pattern = "\\.html$", full.names = TRUE)
files_to_pack <- c(files_to_pack, html_files, "docs/.nojekyll")

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

# Canonical docs referenced in manifest
canonical_docs <- c(
  "README.md",
  "docs/WEBSITE_DOCUMENTATION_AUDIT.md",
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
files_to_pack <- c(files_to_pack, canonical_docs)

# Config specs
config_files <- list.files("config", recursive = TRUE, full.names = TRUE)
files_to_pack <- c(files_to_pack, config_files)

# Web data JSON
web_data_files <- list.files("docs/web-data", recursive = TRUE, full.names = TRUE)
files_to_pack <- c(files_to_pack, web_data_files)

# Exporter & builder scripts
script_files <- c("scripts/30_export_web_assets.R", "scripts/31_phase6A_build_archive.R")
files_to_pack <- c(files_to_pack, script_files)

# Tests & fixtures
test_files <- c("tests/testthat/test_phase6a_website.R", "tests/fixtures/math_smoke_fixtures.md")
files_to_pack <- c(files_to_pack, test_files)

# Phase 6A report
files_to_pack <- c(files_to_pack, "phase_6A_static_website_foundation_report.md")

# UI review screenshots
screenshot_files <- list.files("analysis/phase6A/ui_review", pattern = "\\.png$", full.names = TRUE)
files_to_pack <- c(files_to_pack, screenshot_files)

# Normalize paths (forward slashes) and deduplicate
files_to_pack <- sort(unique(gsub("\\\\", "/", files_to_pack)))

cat("Total unique files queued for packaging:", length(files_to_pack), "\n")

# Verify all files exist
missing_files <- files_to_pack[!file.exists(files_to_pack)]
if (length(missing_files) > 0) {
  stop("Missing files encountered before packaging:\n", paste(missing_files, collapse = "\n"))
}

# Verify exclusion list (no secrets, raw data, scratch, logs, or bulky models)
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
cat("SUCCESS: review_archive_phase6A_light.zip is 100% self-contained!\n")
cat(sprintf("Total audited members: %d | All PASS\n", nrow(audit_df)))
cat("============================================================\n")
