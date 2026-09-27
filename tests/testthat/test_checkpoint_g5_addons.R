# ==============================================================================
# Checkpoint G5 Add-Ons A, B, C, D Regression Test Suite
# Tests:
#   Add-On A: Dataset Inspector & Row-Level Drill-Down in explore.html/explore.js
#   Add-On B: Professional Global Header Refinement (Light Academic Warm Pearl)
#   Add-On C: Professional Global Footer Refinement (Compact 3-Column Dark Layer)
#   Add-On D: Professional Favicon & Site Icons (AQ Monogram Master SVG & PNGs)
#   Scientific Freeze: Frozen data files remain untouched
# ==============================================================================

library(testthat)

context("Checkpoint G5 Add-Ons: Dataset Inspector, Header, Footer, Favicon & Integrity")

repo_root <- tryCatch({
  rprojroot::find_root(rprojroot::is_git_root)
}, error = function(e) {
  normalizePath(file.path(getwd(), "..", ".."))
})

docs_dir <- file.path(repo_root, "docs")
pages <- c(
  "index.html",
  "explore.html",
  "statistics.html",
  "machine-learning.html",
  "documentation.html",
  "about.html"
)

read_file_text <- function(filepath) {
  readChar(filepath, file.info(filepath)$size, useBytes = TRUE)
}

# ------------------------------------------------------------------------------
# 1. G5 ADD-ON A: DATASET INSPECTOR
# ------------------------------------------------------------------------------

test_that("G5A-01: explore.html contains Dataset Inspector card section with proper heading", {
  txt <- read_file_text(file.path(docs_dir, "explore.html"))
  expect_true(grepl('id="dataset-inspector-card"', txt, fixed = TRUE),
              label = "explore.html has id='dataset-inspector-card'")
  expect_true(grepl('class="chart-card dataset-inspector-card"', txt, fixed = TRUE),
              label = "explore.html has dataset-inspector-card class")
  expect_true(grepl('Dataset Inspector', txt, fixed = TRUE),
              label = "explore.html has 'Dataset Inspector' heading")
  expect_true(grepl('Filtered frozen daily observations used by the visualization above', txt, fixed = TRUE),
              label = "explore.html has authoritative subtitle")
  expect_false(grepl('Raw Dataset', txt, fixed = TRUE),
              label = "explore.html strictly avoids 'Raw Dataset' label")
})

test_that("G5A-02: explore.html contains table with 10 canonical column headers", {
  txt <- read_file_text(file.path(docs_dir, "explore.html"))
  expect_true(grepl('id="dataset-inspector-table"', txt, fixed = TRUE),
              label = "explore.html has id='dataset-inspector-table'")
  expect_true(grepl('<th scope="col" class="sticky-col">Date</th>', txt, fixed = TRUE),
              label = "Table has sticky Date header")
  expect_true(grepl('<th scope="col">AQI</th>', txt, fixed = TRUE),
              label = "Table has AQI header")
  expect_true(grepl('<th scope="col">Category</th>', txt, fixed = TRUE),
              label = "Table has Category header")
  expect_true(grepl('<th scope="col">Dominant</th>', txt, fixed = TRUE),
              label = "Table has Dominant header")
  expect_true(grepl('PM2.5', txt, fixed = TRUE),
              label = "Table has PM2.5 header")
  expect_true(grepl('PM10', txt, fixed = TRUE),
              label = "Table has PM10 header")
  expect_true(grepl('O3 8h Max', txt, fixed = TRUE),
              label = "Table has O3 8h Max header")
  expect_true(grepl('Temperature', txt, fixed = TRUE),
              label = "Table has Temperature header")
  expect_true(grepl('Humidity', txt, fixed = TRUE),
              label = "Table has Humidity header")
  expect_true(grepl('Wind Speed', txt, fixed = TRUE),
              label = "Table has Wind Speed header")
})

test_that("G5A-03: explore.html has Filtered CSV download button and empty state container", {
  txt <- read_file_text(file.path(docs_dir, "explore.html"))
  expect_true(grepl('id="btn-download-csv"', txt, fixed = TRUE),
              label = "explore.html has btn-download-csv")
  expect_true(grepl('Download Filtered CSV', txt, fixed = TRUE),
              label = "explore.html has 'Download Filtered CSV' text")
  expect_true(grepl('id="dataset-empty-state"', txt, fixed = TRUE),
              label = "explore.html has id='dataset-empty-state'")
  expect_true(grepl('No station-day records are available for this selected window', txt, fixed = TRUE),
              label = "explore.html has clear empty state message")
})

test_that("G5A-04: explore.js implements DocumentFragment table rendering and reuses dailyObservations", {
  js_txt <- read_file_text(file.path(docs_dir, "assets", "js", "explore.js"))
  expect_true(grepl('renderDatasetInspector', js_txt, fixed = TRUE),
              label = "explore.js defines renderDatasetInspector")
  expect_true(grepl('document.createDocumentFragment()', js_txt, fixed = TRUE),
              label = "explore.js uses DocumentFragment for efficient rendering")
  # Assert no second daily observation fetch is introduced
  matches <- gregexpr('daily_observations\\.json', js_txt)[[1]]
  expect_equal(length(matches), 1,
               info = "daily_observations.json must only be fetched once during initialization")
})

test_that("G5A-05: explore.js implements accessible row expansion with aria-expanded and aria-controls", {
  js_txt <- read_file_text(file.path(docs_dir, "assets", "js", "explore.js"))
  expect_true(grepl('aria-expanded', js_txt, fixed = TRUE),
              label = "explore.js sets aria-expanded")
  expect_true(grepl('aria-controls', js_txt, fixed = TRUE),
              label = "explore.js sets aria-controls")
  expect_true(grepl('row-expand-btn', js_txt, fixed = TRUE),
              label = "explore.js creates .row-expand-btn")
  expect_true(grepl('View complete record for', js_txt, fixed = TRUE),
              label = "explore.js creates accessible aria-label on expand button")
})

test_that("G5A-06: explore.js detail row covers all 4 canonical groups and reveals project_station_id", {
  js_txt <- read_file_text(file.path(docs_dir, "assets", "js", "explore.js"))
  expect_true(grepl('Identification', js_txt, fixed = TRUE),
              label = "Detail row has Identification section")
  expect_true(grepl('AQI Composite', js_txt, fixed = TRUE),
              label = "Detail row has AQI Composite section")
  expect_true(grepl('Pollutant Inputs', js_txt, fixed = TRUE),
              label = "Detail row has Pollutant Inputs section")
  expect_true(grepl('Meteorology', js_txt, fixed = TRUE),
              label = "Detail row has Meteorology section")
  expect_true(grepl('stationObj.project_station_id', js_txt, fixed = TRUE),
              label = "Detail row exposes project_station_id")
  expect_true(grepl('stationObj.station_name', js_txt, fixed = TRUE),
              label = "Detail row exposes station_name")
})

test_that("G5A-07: explore.js missing value handler avoids raw null, undefined, or NaN strings", {
  js_txt <- read_file_text(file.path(docs_dir, "assets", "js", "explore.js"))
  expect_true(grepl('val-missing', js_txt, fixed = TRUE),
              label = "explore.js has val-missing CSS class for missing observations")
  expect_true(grepl('Missing / unavailable', js_txt, fixed = TRUE),
              label = "explore.js has accessible label for missing observations")
})

test_that("G5A-08: explore.js implements client-side CSV export with UAQI filename format", {
  js_txt <- read_file_text(file.path(docs_dir, "assets", "js", "explore.js"))
  expect_true(grepl('setupCsvDownload', js_txt, fixed = TRUE),
              label = "explore.js defines setupCsvDownload")
  expect_true(grepl('UAQI_', js_txt, fixed = TRUE),
              label = "explore.js generates UAQI_ prefixed filename")
  expect_true(grepl('text/csv;charset=utf-8;', js_txt, fixed = TRUE),
              label = "explore.js uses UTF-8 CSV mime type")
})

test_that("G5A-09: CSS contains Dataset Inspector viewport, sticky header, and sticky Date column rules", {
  css_txt <- read_file_text(file.path(docs_dir, "assets", "css", "styles.css"))
  expect_true(grepl('.dataset-table-wrapper', css_txt, fixed = TRUE),
              label = "CSS defines .dataset-table-wrapper")
  expect_true(grepl('max-height: 460px', css_txt, fixed = TRUE),
              label = "CSS defines fixed table viewport height")
  expect_true(grepl('overflow-y: auto', css_txt, fixed = TRUE),
              label = "CSS defines vertical scroll on table viewport")
  expect_true(grepl('overflow-x: auto', css_txt, fixed = TRUE),
              label = "CSS defines horizontal scroll on table viewport")
  expect_true(grepl('position: sticky', css_txt, fixed = TRUE),
              label = "CSS defines sticky table positioning")
  expect_true(grepl('.sticky-col', css_txt, fixed = TRUE),
              label = "CSS defines .sticky-col for sticky Date column")
})

# ------------------------------------------------------------------------------
# 2. G5 ADD-ON B: GLOBAL HEADER REFINEMENT
# ------------------------------------------------------------------------------

test_that("G5B-01: All 6 HTML pages have inline SVG hamburger icon in nav toggle", {
  for (pg in pages) {
    txt <- read_file_text(file.path(docs_dir, pg))
    expect_true(grepl('<svg class="hamburger-icon"', txt, fixed = TRUE),
                info = paste("Missing SVG hamburger icon in:", pg))
    expect_true(grepl('aria-controls="primary-navigation"', txt, fixed = TRUE),
                info = paste("Missing aria-controls in nav toggle in:", pg))
    expect_true(grepl('id="primary-navigation"', txt, fixed = TRUE),
                info = paste("Missing id='primary-navigation' in:", pg))
  }
})

test_that("G5B-02: CSS defines warm pearl header surface and active jade underline", {
  css_txt <- read_file_text(file.path(docs_dir, "assets", "css", "styles.css"))
  expect_true(grepl('rgba(252, 251, 248, 0.97)', css_txt, fixed = TRUE),
              label = "CSS defines warm pearl header background")
  expect_true(grepl('border-bottom: 2.5px solid var(--jade-deep)', css_txt, fixed = TRUE),
              label = "CSS defines active jade underline on nav links")
  expect_true(grepl('.nav-toggle .hamburger-icon', css_txt, fixed = TRUE),
              label = "CSS styles hamburger icon")
})

# ------------------------------------------------------------------------------
# 3. G5 ADD-ON C: GLOBAL FOOTER REFINEMENT
# ------------------------------------------------------------------------------

test_that("G5C-01: All 6 HTML pages have 3-column footer with correct link grouping", {
  for (pg in pages) {
    txt <- read_file_text(file.path(docs_dir, pg))
    expect_true(grepl('class="footer-col footer-col--project"', txt, fixed = TRUE),
                info = paste("Missing footer project column in:", pg))
    expect_true(grepl('<h4>Explore</h4>', txt, fixed = TRUE),
                info = paste("Missing Explore column in:", pg))
    expect_true(grepl('<h4>Resources</h4>', txt, fixed = TRUE),
                info = paste("Missing Resources column in:", pg))
    expect_true(grepl('documentation.html#theory', txt, fixed = TRUE),
                info = paste("Missing Theoretical Concepts link to #theory in:", pg))
  }
})

test_that("G5C-02: All 6 HTML pages have updated release chips and bottom bar", {
  for (pg in pages) {
    txt <- read_file_text(file.path(docs_dir, pg))
    expect_true(grepl('Scientific v0.6', txt, fixed = TRUE),
                info = paste("Missing Scientific v0.6 chip in:", pg))
    expect_true(grepl('Website v0.7.1', txt, fixed = TRUE),
                info = paste("Missing Website v0.7.1 chip in:", pg))
    expect_true(grepl('v0.7.1-website-polish', txt, fixed = TRUE),
                info = paste("Missing v0.7.1-website-polish release in footer bottom in:", pg))
    expect_true(grepl('Deployed on GitHub Pages', txt, fixed = TRUE),
                info = paste("Missing 'Deployed on GitHub Pages' in footer bottom in:", pg))
    expect_false(grepl('Target Deployment: GitHub Pages', txt, fixed = TRUE),
                 info = paste("Stale 'Target Deployment' text found in:", pg))
  }
})

test_that("G5C-03: All 6 HTML pages include common.js", {
  for (pg in pages) {
    txt <- read_file_text(file.path(docs_dir, pg))
    expect_true(grepl('<script src="assets/js/common.js"></script>', txt, fixed = TRUE),
                info = paste("Missing common.js script in:", pg))
  }
})

# ------------------------------------------------------------------------------
# 4. G5 ADD-ON D: FAVICON & SITE ICONS
# ------------------------------------------------------------------------------

test_that("G5D-01: All 6 HTML pages declare the complete favicon set in <head>", {
  for (pg in pages) {
    txt <- read_file_text(file.path(docs_dir, pg))
    expect_true(grepl('<link rel="icon" type="image/svg+xml" href="favicon.svg">', txt, fixed = TRUE),
                info = paste("Missing SVG favicon link in:", pg))
    expect_true(grepl('<link rel="icon" type="image/png" sizes="32x32" href="favicon-32x32.png">', txt, fixed = TRUE),
                info = paste("Missing 32x32 favicon link in:", pg))
    expect_true(grepl('<link rel="icon" type="image/png" sizes="16x16" href="favicon-16x16.png">', txt, fixed = TRUE),
                info = paste("Missing 16x16 favicon link in:", pg))
    expect_true(grepl('<link rel="apple-touch-icon" sizes="180x180" href="apple-touch-icon.png">', txt, fixed = TRUE),
                info = paste("Missing apple-touch-icon link in:", pg))
    expect_true(grepl('<link rel="shortcut icon" href="favicon.ico">', txt, fixed = TRUE),
                info = paste("Missing shortcut icon favicon.ico link in:", pg))
  }
})

test_that("G5D-02: Favicon asset files exist on disk and are non-empty", {
  icon_files <- c(
    "favicon.svg",
    "favicon-16x16.png",
    "favicon-32x32.png",
    "favicon-48x48.png",
    "apple-touch-icon.png",
    "favicon.ico"
  )
  for (f in icon_files) {
    p <- file.path(docs_dir, f)
    expect_true(file.exists(p), info = paste("Favicon asset missing:", f))
    expect_gt(file.info(p)$size, 100, label = paste("Favicon asset too small:", f))
  }
})

test_that("G5D-03: Master SVG contains AQ monogram on deep jade background", {
  svg_txt <- read_file_text(file.path(docs_dir, "favicon.svg"))
  expect_true(grepl('AQ', svg_txt, fixed = TRUE), label = "Favicon SVG contains 'AQ' monogram")
  expect_true(grepl('#14261D', svg_txt, fixed = TRUE) || grepl('#193D30', svg_txt, fixed = TRUE),
              label = "Favicon SVG uses deep jade background palette")
  expect_true(grepl('#B38A52', svg_txt, fixed = TRUE),
              label = "Favicon SVG uses champagne accent dot")
})

# ------------------------------------------------------------------------------
# 5. SCIENTIFIC DATA FREEZE INTEGRITY
# ------------------------------------------------------------------------------

test_that("G5-FREEZE: All frozen scientific JSON files remain present and non-empty", {
  frozen_files <- c(
    "daily_observations.json",
    "stations.json",
    "regression_metrics.json",
    "classification_metrics.json",
    "pca_variance.json",
    "cluster_profiles.json",
    "pca_scores.json",
    "drift_summary.json",
    "inference_summary.json"
  )
  for (f in frozen_files) {
    p <- file.path(docs_dir, "web-data", f)
    expect_true(file.exists(p), info = paste("Missing frozen scientific JSON:", f))
    expect_gt(file.info(p)$size, 50, label = paste("Scientific JSON empty:", f))
  }
})
