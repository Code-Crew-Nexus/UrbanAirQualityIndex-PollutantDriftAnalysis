# tests/testthat/test_phase6c_release.R
# ==============================================================================
# Phase 6C: Release-Layer Invariants & Static Deployment Test Suite
# Project: UrbanAirQualityIndex-PollutantDriftAnalysis
# Baseline: v0.6-svm-freeze (FROZEN — READ ONLY)
# ==============================================================================

library(testthat)

repo_root <- if (dir.exists(file.path("..", "..", "docs"))) file.path("..", "..") else "."
docs_dir <- file.path(repo_root, "docs")

context("Phase 6C: Release-Layer Invariants & Deployment QA")

# Helper to read file text safely
read_file_text <- function(filepath) {
  paste(readLines(filepath, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

# ------------------------------------------------------------------------------
# 1. SIX PUBLIC PAGES & SEMANTIC STRUCTURE
# ------------------------------------------------------------------------------

expected_pages <- c(
  "index.html",
  "explore.html",
  "statistics.html",
  "machine-learning.html",
  "documentation.html",
  "about.html"
)

test_that("01: All six public HTML pages exist in docs/", {
  for (pg in expected_pages) {
    p <- file.path(docs_dir, pg)
    expect_true(file.exists(p), info = paste("Missing public page:", pg))
  }
})

test_that("02: All six pages contain html lang='en' and valid semantic structure", {
  for (pg in expected_pages) {
    txt <- read_file_text(file.path(docs_dir, pg))
    expect_true(grepl('<!DOCTYPE html>', txt, ignore.case = TRUE), info = paste("Missing DOCTYPE in:", pg))
    expect_true(grepl('<html[^>]*lang=["\']en["\']', txt, ignore.case = TRUE), info = paste("Missing lang='en' in:", pg))
    expect_true(grepl('<header', txt), info = paste("Missing <header> in:", pg))
    expect_true(grepl('<nav', txt), info = paste("Missing <nav> in:", pg))
    expect_true(grepl('<main', txt), info = paste("Missing <main> in:", pg))
    expect_true(grepl('<footer', txt), info = paste("Missing <footer> in:", pg))
  }
})

test_that("03: All six pages have meaningful page titles", {
  for (pg in expected_pages) {
    txt <- read_file_text(file.path(docs_dir, pg))
    m <- regmatches(txt, regexec('<title>([^<]+)</title>', txt))[[1]]
    expect_true(length(m) >= 2, info = paste("Missing <title> in:", pg))
    title_text <- trimws(m[2])
    expect_gt(nchar(title_text), 10, label = paste("Title too short in:", pg))
    expect_true(grepl("Urban Air Quality", title_text), info = paste("Title lacks project branding in:", pg))
  }
})

test_that("04: All six pages contain an accessible skip-link to #main-content", {
  for (pg in expected_pages) {
    txt <- read_file_text(file.path(docs_dir, pg))
    expect_true(grepl('class="skip-link"', txt, fixed = TRUE), info = paste("Missing skip-link in:", pg))
    expect_true(grepl('href="#main-content"', txt, fixed = TRUE), info = paste("Skip-link does not target #main-content in:", pg))
    expect_true(grepl('id="main-content"', txt, fixed = TRUE), info = paste("Missing id='main-content' in:", pg))
  }
})

# ------------------------------------------------------------------------------
# 2. STATIC ASSET RESOLUTION & RELATIVE URL SAFETY
# ------------------------------------------------------------------------------

test_that("05: Core static CSS and JS assets exist", {
  required_assets <- c(
    "assets/css/styles.css",
    "assets/js/common.js",
    "assets/js/data-utils.js",
    "assets/js/explore.js",
    "assets/js/statistics.js",
    "assets/js/machine-learning.js",
    "assets/js/home.js",
    "assets/js/about.js",
    "assets/js/documentation.js",
    "assets/js/markdown-renderer.js",
    "assets/js/documentation-manifest.js"
  )
  for (a in required_assets) {
    p <- file.path(docs_dir, a)
    expect_true(file.exists(p), info = paste("Missing static asset:", a))
  }
})

test_that("06: No machine-specific or file:/// absolute paths in HTML or JS", {
  html_files <- list.files(docs_dir, pattern = "\\.html$", full.names = TRUE)
  js_files <- list.files(file.path(docs_dir, "assets", "js"), pattern = "\\.js$", full.names = TRUE)
  for (f in c(html_files, js_files)) {
    txt <- read_file_text(f)
    expect_false(grepl("[C-Z]:\\\\[A-Za-z0-9_]", txt), info = paste("Windows absolute path in:", f))
    expect_false(grepl('href=["\']file:///', txt, fixed = TRUE), info = paste("file:/// href in:", f))
    expect_false(grepl('src=["\']file:///', txt, fixed = TRUE), info = paste("file:/// src in:", f))
    expect_false(grepl('href=["\']/[a-zA-Z]', txt), info = paste("Root-relative href in:", f))
    expect_false(grepl('src=["\']/[a-zA-Z]', txt), info = paste("Root-relative src in:", f))
  }
})

test_that("07: GitHub Pages .nojekyll marker exists", {
  nojekyll_path <- file.path(docs_dir, ".nojekyll")
  expect_true(file.exists(nojekyll_path))
})

# ------------------------------------------------------------------------------
# 3. RESPONSIVE CSS & ACCESSIBILITY RULES
# ------------------------------------------------------------------------------

test_that("08: styles.css contains required responsive breakpoints and touch scrolling", {
  css_txt <- read_file_text(file.path(docs_dir, "assets", "css", "styles.css"))
  expect_true(grepl("@media\\s*\\(max-width:\\s*992px\\)", css_txt))
  expect_true(grepl("@media\\s*\\(max-width:\\s*768px\\)", css_txt))
  expect_true(grepl("@media\\s*\\(max-width:\\s*600px\\)", css_txt) || grepl("@media\\s*\\(max-width:\\s*580px\\)", css_txt))
  expect_true(grepl("-webkit-overflow-scrolling:\\s*touch", css_txt))
})

test_that("09: styles.css contains accessibility utility classes and focus states", {
  css_txt <- read_file_text(file.path(docs_dir, "assets", "css", "styles.css"))
  expect_true(grepl("\\.skip-link", css_txt))
  expect_true(grepl("\\.visually-hidden", css_txt))
  expect_true(grepl(":focus-visible", css_txt))
  expect_true(grepl("@media\\s*\\(prefers-reduced-motion:\\s*reduce\\)", css_txt))
})

test_that("10: Form controls have associated labels in interactive views", {
  interactive_pages <- c("explore.html", "statistics.html", "machine-learning.html")
  for (pg in interactive_pages) {
    txt <- read_file_text(file.path(docs_dir, pg))
    # Extract all select IDs
    select_ids <- regmatches(txt, gregexpr('<select[^>]+id=["\']([^"\']+)["\']', txt))[[1]]
    select_ids <- gsub('<select[^>]+id=["\']|["\']', '', select_ids)
    for (sid in select_ids) {
      label_pattern <- paste0('<label[^>]+for=["\']', sid, '["\']')
      expect_true(grepl(label_pattern, txt), info = paste("Missing <label for='", sid, "'> in:", pg))
    }
  }
})

# ------------------------------------------------------------------------------
# 4. ZERO BACKEND / ZERO RUNTIME INTEGRITY
# ------------------------------------------------------------------------------

test_that("11: No React, Next.js, npm, or R Shiny runtime artifacts", {
  all_web_files <- list.files(docs_dir, recursive = TRUE, full.names = TRUE)
  # Check file names
  expect_false(any(grepl("react\\.production|next-server|shiny\\.js|package\\.json|package-lock\\.json", all_web_files)))
})

test_that("12: No scientific model-fitting logic in browser JavaScript", {
  js_files <- list.files(file.path(docs_dir, "assets", "js"), pattern = "\\.js$", full.names = TRUE)
  for (f in js_files) {
    txt <- read_file_text(f)
    code_lines <- unlist(strsplit(txt, "\n"))
    code_lines <- code_lines[!grepl("^\\s*//", code_lines)]
    code_clean <- paste(code_lines, collapse = " ")
    expect_false(grepl("\\blm\\s*\\(", code_clean), info = paste("lm() call in:", f))
    expect_false(grepl("\\bglm\\s*\\(", code_clean), info = paste("glm() call in:", f))
    expect_false(grepl("\\bprcomp\\s*\\(", code_clean), info = paste("prcomp() call in:", f))
    expect_false(grepl("\\bkmeans\\s*\\(", code_clean), info = paste("kmeans() call in:", f))
    expect_false(grepl("\\bsvm\\s*\\(", code_clean), info = paste("svm() call in:", f))
  }
})

# ------------------------------------------------------------------------------
# 5. RELEASE VERIFICATION & PROVENANCE ARTIFACTS
# ------------------------------------------------------------------------------

test_that("13: Frozen modeling milestone v0.6-svm-freeze and website freeze v0.7-website-freeze documented", {
  readme_txt <- read_file_text(file.path(repo_root, "README.md"))
  checkpoints_txt <- read_file_text(file.path(docs_dir, "PROJECT_CHECKPOINTS.md"))
  expect_true(grepl("v0.6-svm-freeze", readme_txt, fixed = TRUE))
  expect_true(grepl("v0.7-website-freeze", readme_txt, fixed = TRUE))
  expect_true(grepl("v0.6-svm-freeze", checkpoints_txt, fixed = TRUE))
  expect_true(grepl("v0.7-website-freeze", checkpoints_txt, fixed = TRUE))
})

test_that("14: All 12 multi-viewport review screenshots exist and exceed 10 KB", {
  expected_screens <- c(
    "01_home_desktop_1440x900.png",
    "02_home_mobile_390x844.png",
    "03_explore_aqi_desktop_1440x900.png",
    "04_explore_pm25_mobile_390x844.png",
    "05_stat_drift_desktop_1440x900.png",
    "06_stat_inference_tablet_768x1024.png",
    "07_ml_regression_desktop_1440x900.png",
    "08_ml_classification_india_test_1440x900.png",
    "09_ml_classification_hyd_holdout_1440x900.png",
    "10_ml_regimes_hyderabad_1440x900.png",
    "11_ml_regimes_india_1440x900.png",
    "12_documentation_math_desktop_1440x900.png"
  )
  for (scr in expected_screens) {
    p <- file.path(repo_root, "analysis", "phase6C", "ui_review", scr)
    expect_true(file.exists(p), info = paste("Missing Phase 6C screenshot:", scr))
    expect_gt(file.size(p), 10000, label = paste("Screenshot too small:", scr))
  }
})

test_that("15: Archive dependency audit table exists and is 100% PASS", {
  audit_path <- file.path(repo_root, "analysis", "phase6B", "tables", "phase6B_archive_dependency_audit.csv")
  expect_true(file.exists(audit_path))
  audit_df <- read.csv(audit_path, stringsAsFactors = FALSE)
  expect_equal(nrow(audit_df), 19)
  expect_true(all(audit_df$status == "PASS"))
  expect_true(all(audit_df$in_project == TRUE))
})
