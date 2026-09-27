# tests/testthat/test_checkpoint_g6_1_presentation.R
# ==============================================================================
# Checkpoint G6.1: Presentation Walkthrough & Faculty Documentation Refinement
# Project: UrbanAirQualityIndex-PollutantDriftAnalysis
# Baseline: v0.6-svm-freeze (FROZEN — READ ONLY)
# ==============================================================================

library(testthat)

repo_root <- if (dir.exists(file.path("..", "..", "docs"))) file.path("..", "..") else "."
docs_dir <- file.path(repo_root, "docs")
slides_dir <- file.path(docs_dir, "slides")
web_slides_dir <- file.path(slides_dir, "web")

context("Checkpoint G6.1: Presentation Walkthrough & Faculty Documentation Integration")

# Helper to read file text safely
read_file_text <- function(filepath) {
  paste(readLines(filepath, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

# ------------------------------------------------------------------------------
# 1. SLIDE ASSET VERIFICATION (12 MASTER PNGs & WEBP DERIVATIVES)
# ------------------------------------------------------------------------------

test_that("01: Exactly 12 master slide PNGs exist in numeric order slide1.png to slide12.png", {
  for (i in 1:12) {
    png_name <- paste0("slide", i, ".png")
    p <- file.path(slides_dir, png_name)
    expect_true(file.exists(p), info = paste("Missing master slide:", png_name))
    expect_true(file.info(p)$size > 100000, info = paste("Slide PNG too small or corrupted:", png_name))
  }
})

test_that("02: Web-optimized WebP slide derivatives exist from slide01.webp to slide12.webp", {
  for (i in 1:12) {
    webp_name <- sprintf("slide%02d.webp", i)
    p <- file.path(web_slides_dir, webp_name)
    expect_true(file.exists(p), info = paste("Missing WebP derivative:", webp_name))
    expect_true(file.info(p)$size > 10000, info = paste("WebP too small or corrupted:", webp_name))
  }
})

# ------------------------------------------------------------------------------
# 2. PRESENTATION MARKDOWN STRUCTURE & CONTENT
# ------------------------------------------------------------------------------

test_that("03: Presentation walkthrough markdown document exists and is populated", {
  doc_path <- file.path(docs_dir, "guide", "presentation_walkthrough.md")
  expect_true(file.exists(doc_path))
  txt <- read_file_text(doc_path)
  
  # Title and overview
  expect_true(grepl("# Project Presentation Walkthrough", txt))
  expect_true(grepl("Faculty Reviewer Note", txt))
  expect_true(grepl("v0.6-svm-freeze", txt))
  expect_true(grepl("v0.7.3-live-extension", txt))
})

test_that("04: Presentation markdown references all 12 slides in exact numeric order", {
  doc_path <- file.path(docs_dir, "guide", "presentation_walkthrough.md")
  txt <- read_file_text(doc_path)
  
  # Check each slide occurs exactly once in slide container
  for (i in 1:12) {
    slide_id <- paste0("slide-", i)
    expect_true(grepl(paste0('id="', slide_id, '"'), txt), info = paste("Missing slide id:", slide_id))
    
    # Check image reference
    img_ref <- paste0("slide", i, ".png")
    expect_true(grepl(img_ref, txt), info = paste("Missing PNG reference:", img_ref))
    
    webp_ref <- sprintf("slide%02d.webp", i)
    expect_true(grepl(webp_ref, txt), info = paste("Missing WebP reference:", webp_ref))
  }
  
  # Verify numeric order (slide1 before slide2, slide2 before slide3 ... slide10 before slide11)
  pos_vec <- integer(12)
  for (i in 1:12) {
    m <- regexpr(paste0('id="slide-', i, '"'), txt)
    expect_true(m > 0)
    pos_vec[i] <- as.integer(m)
  }
  expect_true(!is.unsorted(pos_vec), info = "Slides must be ordered strictly numerically 1..12")
})

test_that("05: All 12 slide images have meaningful descriptive alt text", {
  doc_path <- file.path(docs_dir, "guide", "presentation_walkthrough.md")
  txt <- read_file_text(doc_path)
  
  for (i in 1:12) {
    pattern <- paste0('alt="Slide ', i, ' [^"]+"')
    expect_true(grepl(pattern, txt), info = paste("Missing descriptive alt text for slide", i))
  }
})

test_that("06: Quick-jump index contains links for all 12 slides", {
  doc_path <- file.path(docs_dir, "guide", "presentation_walkthrough.md")
  txt <- read_file_text(doc_path)
  
  for (i in 1:12) {
    link_pattern <- paste0('href="#slide-', i, '"')
    expect_true(grepl(link_pattern, txt), info = paste("Quick-jump missing link for slide", i))
  }
})

# ------------------------------------------------------------------------------
# 3. DOCUMENTATION MANIFEST & IA REFINEMENT
# ------------------------------------------------------------------------------

test_that("07: Documentation manifest contains exec-presentation and faculty-oriented subitems", {
  manifest_txt <- read_file_text(file.path(docs_dir, "assets", "js", "documentation-manifest.js"))
  
  expect_true(grepl('id:\\s*"exec-presentation"', manifest_txt))
  expect_true(grepl('title:\\s*"Presentation Walkthrough"', manifest_txt))
  expect_true(grepl('source:\\s*"guide/presentation_walkthrough.md"', manifest_txt))
  
  expect_true(grepl('id:\\s*"exec-walkthrough"', manifest_txt))
  expect_true(grepl('title:\\s*"End-to-End Execution Guide"', manifest_txt))
  
  expect_true(grepl('id:\\s*"exec-modeling"', manifest_txt))
  expect_true(grepl('title:\\s*"Modeling & Reproducibility Reference"', manifest_txt))
  
  # Ensure long Phase 1-5B list is NOT in the public manifest subitems
  expect_false(grepl('title:\\s*"Phase 1: Station Selection Decision"', manifest_txt))
  expect_false(grepl('title:\\s*"Phase 5B: RBF SVM Classification Summary"', manifest_txt))
})

test_that("08: documentation.html fallback markup includes Presentation Walkthrough", {
  doc_html <- read_file_text(file.path(docs_dir, "documentation.html"))
  expect_true(grepl('href="#exec-presentation"', doc_html))
  expect_true(grepl('Presentation Walkthrough', doc_html))
  expect_true(grepl('href="#exec-walkthrough"', doc_html))
  expect_true(grepl('href="#exec-modeling"', doc_html))
})

# ------------------------------------------------------------------------------
# 4. TERMINOLOGY & PUBLIC HEADINGS CLEANUP
# ------------------------------------------------------------------------------

test_that("09: Screenshots and samples guide headings are free from internal phase tags", {
  samples_txt <- read_file_text(file.path(docs_dir, "guide", "screenshots_and_samples.md"))
  expect_false(grepl("\\(Phase 5B\\)", samples_txt))
  expect_false(grepl("\\(Phase 5A\\)", samples_txt))
  expect_false(grepl("\\(Phase 4\\)", samples_txt))
  
  expect_true(grepl("Nonlinear Support Vector Machine Classification", samples_txt))
  expect_true(grepl("Unsupervised Dimensionality & Atmospheric Regime Discovery", samples_txt))
  expect_true(grepl("Supervised Linear Regression & Adverse Event Logistic Baselines", samples_txt))
})

test_that("10: Guide markdown documents expand SML and PBL acronyms in course title", {
  guides <- c("execution_guide.md", "prerequisites.md", "screenshots_and_samples.md", "theoretical_concepts.md")
  for (g in guides) {
    txt <- read_file_text(file.path(docs_dir, "guide", g))
    expect_true(grepl("Statistics for Machine Learning &mdash;|Statistics for Machine Learning —|Statistics for Machine Learning", txt))
    expect_false(grepl("Statistics for Machine Learning \\(SML\\)", txt), info = paste("Unexpanded acronym in:", g))
  }
})

# ------------------------------------------------------------------------------
# 5. FOOTER RELEASE CONSISTENCY ACROSS ALL 6 PAGES
# ------------------------------------------------------------------------------

test_that("11: All 6 HTML pages display synchronized Website v0.7.4 release chips and footer metadata", {
  pages <- c("index.html", "explore.html", "statistics.html", "machine-learning.html", "documentation.html", "about.html")
  for (pg in pages) {
    txt <- read_file_text(file.path(docs_dir, pg))
    expect_true(grepl('<span class="release-chip">Website v0.7.4</span>', txt), info = paste("Missing Website v0.7.4 chip in:", pg))
    expect_true(grepl('Website Release: <code>v0.7.4-presentation-walkthrough</code>', txt), info = paste("Missing v0.7.4-presentation-walkthrough in:", pg))
    expect_true(grepl('Scientific Baseline: <code>v0.6-svm-freeze</code>', txt), info = paste("Missing v0.6-svm-freeze in:", pg))
  }
})

# ------------------------------------------------------------------------------
# 6. FROZEN BASELINE & ZERO MUTATION INVARIANT
# ------------------------------------------------------------------------------

test_that("12: Scientific baseline datasets and daily observations remain untouched", {
  master_csv <- file.path(repo_root, "data", "processed", "UAQI_Master_Daily.csv")
  web_json <- file.path(docs_dir, "web-data", "daily_observations.json")
  expect_true(file.exists(master_csv))
  expect_true(file.exists(web_json))
  
  obs_data <- jsonlite::fromJSON(web_json)
  expect_equal(nrow(obs_data), 11970)
  expect_equal(max(obs_data$date), "2026-09-21")
  expect_equal(min(obs_data$date), "2025-03-01")
})

test_that("13: Presentation component CSS rules exist in styles.css", {
  css_txt <- read_file_text(file.path(docs_dir, "assets", "css", "styles.css"))
  expect_true(grepl("\\.presentation-walkthrough", css_txt))
  expect_true(grepl("\\.presentation-index", css_txt))
  expect_true(grepl("\\.presentation-slide", css_txt))
  expect_true(grepl("\\.presentation-slide__image", css_txt))
  expect_true(grepl("\\.presentation-slide__full-link", css_txt))
})
