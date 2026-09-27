# scripts/40_build_g5_addons_archive.R
# Checkpoint G5 Add-Ons: Assembles and audits review_archive_checkpoint_G5_addons.zip
# Project: UrbanAirQualityIndex-PollutantDriftAnalysis (SML PBL, Code-Crew-Nexus)

suppressPackageStartupMessages({
  library(digest)
})

cat("============================================================\n")
cat("Checkpoint G5 Add-Ons: Review Archive Builder & Auditor\n")
cat("============================================================\n\n")

archive_file <- "review_archive_checkpoint_G5_addons.zip"
if (file.exists(archive_file)) {
  cat("Removing existing archive:", archive_file, "\n")
  unlink(archive_file)
}

# 1. Gather all files to pack
files_to_pack <- character(0)

# Website core: All files in docs/
docs_all <- list.files("docs", recursive = TRUE, full.names = TRUE)
files_to_pack <- c(files_to_pack, docs_all, "docs/.nojekyll")

# Checkpoint reports & canonical docs
checkpoint_docs <- c(
  "README.md",
  "checkpoint_G5_addons_report.md",
  "checkpoint_G5_post_deployment_ui_integrity_report.md",
  "checkpoint_G4_website_release_integration_report.md",
  "docs/PROJECT_CHECKPOINTS.md"
)
files_to_pack <- c(files_to_pack, checkpoint_docs[file.exists(checkpoint_docs)])

# Scripts
script_files <- c(
  "scripts/37_checkpoint_g5_browser_qa.py",
  "scripts/38_checkpoint_g5_addons_browser_qa.py",
  "scripts/39_verify_live_deployment.py",
  "scripts/generate_favicon.py",
  "scripts/40_build_g5_addons_archive.R"
)
files_to_pack <- c(files_to_pack, script_files[file.exists(script_files)])

# Tests
test_files <- c(
  "tests/testthat/test_checkpoint_g5_addons.R",
  "tests/testthat/test_checkpoint_g5_ui_integrity.R",
  "tests/testthat/test_phase6c_release.R",
  "tests/testthat/test_phase6a_website.R"
)
files_to_pack <- c(files_to_pack, test_files[file.exists(test_files)])

# Normalize paths and deduplicate
files_to_pack <- sort(unique(gsub("\\\\", "/", files_to_pack)))
files_to_pack <- files_to_pack[!dir.exists(files_to_pack)]
files_to_pack <- files_to_pack[file.exists(files_to_pack)]

cat("Total files gathered for archive:", length(files_to_pack), "\n\n")

# 2. Build ZIP archive
cat("Creating ZIP archive:", archive_file, "...\n")
zip_res <- zip(zipfile = archive_file, files = files_to_pack, flags = "-r9Xq")

if (!file.exists(archive_file) || file.info(archive_file)$size == 0) {
  stop("FATAL: Failed to create review archive: ", archive_file)
}

archive_size_bytes <- file.info(archive_file)$size
archive_size_mb <- archive_size_bytes / (1024 * 1024)
archive_sha256 <- digest(archive_file, algo = "sha256", file = TRUE)

cat("Archive created successfully!\n")
cat("File:", archive_file, "\n")
cat("Size:", sprintf("%.2f MB (%d bytes)", archive_size_mb, archive_size_bytes), "\n")
cat("SHA-256:", archive_sha256, "\n\n")

# Verify critical inclusions
zip_contents <- unzip(archive_file, list = TRUE)$Name

req_files <- c(
  "docs/explore.html",
  "docs/assets/js/explore.js",
  "docs/assets/css/styles.css",
  "docs/favicon.svg",
  "docs/favicon.ico",
  "docs/favicon-32x32.png",
  "docs/apple-touch-icon.png",
  "checkpoint_G5_addons_report.md",
  "tests/testthat/test_checkpoint_g5_addons.R",
  "scripts/38_checkpoint_g5_addons_browser_qa.py"
)

missing <- setdiff(req_files, zip_contents)
if (length(missing) > 0) {
  stop("FATAL: Archive is missing critical files: ", paste(missing, collapse = ", "))
}

cat("All critical files verified present in archive!\n")
cat("Archive packaging complete.\n")
