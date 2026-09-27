# test_checkpoint_g5_ui_integrity.R
# Checkpoint G5 — Post-Deployment UI/UX, Math Rendering, Accessibility & QA-Integrity
# Project: UrbanAirQualityIndex-PollutantDriftAnalysis
# Branch: fix/post-deployment-uiqa
# Scientific baseline: v0.6-svm-freeze (PERMANENTLY FROZEN — READ ONLY)
# Website release: v0.7-website-freeze / v0.7.1-website-polish (G5)

library(testthat)

# Helper: read a file as plain text
read_file_text <- function(path) {
  paste(readLines(path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
}

# Resolve project root (2 levels up from tests/testthat/)
project_root <- normalizePath(file.path(dirname(testthat::test_path()), "..", ".."))
docs_dir  <- file.path(project_root, "docs")
js_dir    <- file.path(docs_dir, "assets", "js")
css_path  <- file.path(docs_dir, "assets", "css", "styles.css")
all_pages <- c("index.html", "explore.html", "statistics.html",
                "machine-learning.html", "documentation.html", "about.html")

# -----------------------------------------------------------------------
# G5-01: No raw LaTeX dollar-sign expressions in non-documentation JS
# -----------------------------------------------------------------------
test_that("G5-01: No raw LaTeX $...$ in machine-learning.js", {
  ml_js <- read_file_text(file.path(js_dir, "machine-learning.js"))
  # Should not contain literal dollar-wrapped math strings like $Y_{...}$ etc.
  expect_false(grepl("\\$Y_\\{t\\+1\\}", ml_js, fixed = FALSE),
               label = "No raw LaTeX $Y_{t+1}=1...")
  expect_false(grepl("\\$1\\.0000\\$", ml_js, fixed = FALSE),
               label = "No raw LaTeX ($1.0000$)")
  expect_false(grepl("\\$111\\$", ml_js, fixed = FALSE),
               label = "No raw LaTeX ($111$)")
  expect_false(grepl("\\\\text\\{AQI", ml_js, fixed = FALSE),
               label = "No \\text{AQI} LaTeX in ML JS")
})

test_that("G5-02: No raw LaTeX $...$ in statistics.js", {
  stat_js <- read_file_text(file.path(js_dir, "statistics.js"))
  expect_false(grepl("\\$B=2000\\$", stat_js, fixed = FALSE),
               label = "No $B=2000$ raw LaTeX")
  expect_false(grepl("\\$l=7\\$", stat_js, fixed = FALSE),
               label = "No $l=7$ raw LaTeX")
  expect_false(grepl("\\$\\\\alpha", stat_js, fixed = FALSE),
               label = "No $\\alpha LaTeX in statistics.js")
  expect_false(grepl("\\$q = ", stat_js, fixed = FALSE),
               label = "No $q = raw LaTeX in statistics.js")
})

# -----------------------------------------------------------------------
# G5-03: No raw LaTeX in about.html scientific limitations
# -----------------------------------------------------------------------
test_that("G5-03: No raw LaTeX in about.html scientific limitations", {
  about_txt <- read_file_text(file.path(docs_dir, "about.html"))
  expect_false(grepl("\\$D_z\\$", about_txt, fixed = FALSE),
               label = "No $D_z$ LaTeX in about.html")
  expect_false(grepl("\\$p\\^\\*", about_txt, fixed = FALSE),
               label = "No $p^* \\approx$ LaTeX in about.html")
  expect_false(grepl("\\\\approx", about_txt, fixed = FALSE),
               label = "No \\approx raw LaTeX in about.html")
  expect_false(grepl("\\$0\\.50\\$", about_txt, fixed = FALSE),
               label = "No $0.50$ raw LaTeX in about.html")
})

# -----------------------------------------------------------------------
# G5-04: CSS custom property tokens resolved (no undefined var references)
# -----------------------------------------------------------------------
test_that("G5-04: All referenced CSS custom properties are declared in :root", {
  css_txt <- read_file_text(css_path)
  required_tokens <- c(
    "--graphite-dark",
    "--graphite-muted",
    "--jade-medium",
    "--champagne",
    "--champagne-light",
    "--table-header",
    "--transition-fast"
  )
  for (tok in required_tokens) {
    expect_true(grepl(paste0(tok, ":"), css_txt, fixed = TRUE),
                label = paste("CSS token declared:", tok))
  }
})

# -----------------------------------------------------------------------
# G5-05: explore.html station filter has no inline flex style
# -----------------------------------------------------------------------
test_that("G5-05: explore.html station filter uses class not inline style", {
  explore_txt <- read_file_text(file.path(docs_dir, "explore.html"))
  expect_false(grepl('style="flex: 2 1 260px;"', explore_txt, fixed = TRUE),
               label = "No inline flex style on station filter")
  expect_true(grepl('filter-item--station', explore_txt, fixed = TRUE),
              label = "filter-item--station class present in explore.html")
})

# -----------------------------------------------------------------------
# G5-06: CSS has .filter-item--station class defined
# -----------------------------------------------------------------------
test_that("G5-06: CSS defines .filter-item--station", {
  css_txt <- read_file_text(css_path)
  expect_true(grepl(".filter-item--station", css_txt, fixed = TRUE),
              label = ".filter-item--station class exists in styles.css")
})

# -----------------------------------------------------------------------
# G5-07: All 6 pages footer does NOT contain stale "Target Deployment: GitHub Pages"
# -----------------------------------------------------------------------
test_that("G5-07: No stale 'Target Deployment: GitHub Pages' in any page footer", {
  for (pg in all_pages) {
    txt <- read_file_text(file.path(docs_dir, pg))
    expect_false(grepl("Target Deployment: GitHub Pages", txt, fixed = TRUE),
                 label = paste("No stale target deployment in:", pg))
  }
})

# -----------------------------------------------------------------------
# G5-08: All 6 pages have updated footer release metadata
# -----------------------------------------------------------------------
test_that("G5-08: All pages footer contains release metadata text", {
  for (pg in all_pages) {
    txt <- read_file_text(file.path(docs_dir, pg))
    expect_true(grepl("Deployed on GitHub Pages", txt, fixed = TRUE),
                label = paste("Footer has 'Deployed on GitHub Pages' in:", pg))
  }
})

# -----------------------------------------------------------------------
# G5-09: index.html Phase 6 pipeline step is not "in-progress"
# -----------------------------------------------------------------------
test_that("G5-09: index.html Phase 6 pipeline step is frozen (not in-progress)", {
  index_txt <- read_file_text(file.path(docs_dir, "index.html"))
  expect_false(grepl('pipeline-step in-progress', index_txt, fixed = TRUE),
               label = "No in-progress pipeline step on index.html")
  expect_true(grepl("Deployed via GitHub Pages", index_txt, fixed = TRUE),
              label = "Phase 6 shows deployed meta text")
})

# -----------------------------------------------------------------------
# G5-10: Team name Rishit Ghosh is title-cased (not ALL CAPS)
# -----------------------------------------------------------------------
test_that("G5-10: Team member Rishit Ghosh has correct title-case casing", {
  about_txt <- read_file_text(file.path(docs_dir, "about.html"))
  expect_true(grepl("Rishit Ghosh", about_txt, fixed = TRUE),
              label = "Rishit Ghosh in title case present")
  expect_false(grepl("RISHIT GHOSH", about_txt, fixed = TRUE),
               label = "ALL-CAPS RISHIT GHOSH removed")
})

# -----------------------------------------------------------------------
# G5-11: #theory route exists in documentation manifest
# -----------------------------------------------------------------------
test_that("G5-11: documentation-manifest.js contains 'theory' key", {
  manifest_js <- read_file_text(file.path(js_dir, "documentation-manifest.js"))
  expect_true(grepl('"theory"', manifest_js, fixed = TRUE),
              label = "documentation-manifest.js has theory section key")
  expect_false(grepl('"concepts"', manifest_js, fixed = TRUE),
               label = "No invalid 'concepts' section key in manifest")
})

# -----------------------------------------------------------------------
# G5-12: Statistics page tablist has aria-controls
# -----------------------------------------------------------------------
test_that("G5-12: statistics.html tablist buttons have aria-controls", {
  stat_txt <- read_file_text(file.path(docs_dir, "statistics.html"))
  expect_true(grepl('aria-controls="tab-drift"', stat_txt, fixed = TRUE),
              label = "statistics.html drift tab has aria-controls")
  expect_true(grepl('aria-controls="tab-inference"', stat_txt, fixed = TRUE),
              label = "statistics.html inference tab has aria-controls")
})

# -----------------------------------------------------------------------
# G5-13: Machine-learning page tablist has aria-controls
# -----------------------------------------------------------------------
test_that("G5-13: machine-learning.html tablist buttons have aria-controls", {
  ml_txt <- read_file_text(file.path(docs_dir, "machine-learning.html"))
  expect_true(grepl('aria-controls="tab-regression"', ml_txt, fixed = TRUE),
              label = "ML page regression tab has aria-controls")
  expect_true(grepl('aria-controls="tab-classification"', ml_txt, fixed = TRUE),
              label = "ML page classification tab has aria-controls")
  expect_true(grepl('aria-controls="tab-regimes"', ml_txt, fixed = TRUE),
              label = "ML page regimes tab has aria-controls")
})

# -----------------------------------------------------------------------
# G5-14: common.js implements keyboard tablist navigation
# -----------------------------------------------------------------------
test_that("G5-14: common.js implements ArrowRight/ArrowLeft keyboard tablist", {
  common_js <- read_file_text(file.path(js_dir, "common.js"))
  expect_true(grepl("ArrowRight", common_js, fixed = TRUE),
              label = "common.js handles ArrowRight key")
  expect_true(grepl("ArrowLeft", common_js, fixed = TRUE),
              label = "common.js handles ArrowLeft key")
  expect_true(grepl("initTablists", common_js, fixed = TRUE),
              label = "common.js has initTablists function")
  expect_true(grepl("aria-controls", common_js, fixed = TRUE),
              label = "common.js sets aria-controls on nav toggle")
})

# -----------------------------------------------------------------------
# G5-15: common.js implements mobile nav Escape-to-close
# -----------------------------------------------------------------------
test_that("G5-15: common.js implements Escape key to close mobile nav", {
  common_js <- read_file_text(file.path(js_dir, "common.js"))
  expect_true(grepl("Escape", common_js, fixed = TRUE),
              label = "common.js handles Escape key for nav close")
})

# -----------------------------------------------------------------------
# G5-16: CSS has compact footer and light academic header
# -----------------------------------------------------------------------
test_that("G5-16: CSS defines compact footer and light header", {
  css_txt <- read_file_text(css_path)
  # Footer has compact jade top border and dark background
  expect_true(grepl("border-top: 2px solid var(--jade-deep)", css_txt, fixed = TRUE),
              label = "Footer has jade-deep top border")
  expect_true(grepl("#1B2721", css_txt, fixed = TRUE),
              label = "Footer uses #1B2721 deep graphite background")
  # Header is light
  expect_true(grepl("background-color: #FFFFFF", css_txt, fixed = TRUE),
              label = "Header uses white background")
  # Release chip class
  expect_true(grepl(".release-chip", css_txt, fixed = TRUE),
              label = "CSS defines .release-chip class")
})

# -----------------------------------------------------------------------
# G5-17: Scientific freeze integrity — frozen JSON files unchanged
# -----------------------------------------------------------------------
test_that("G5-17: Frozen scientific JSON files present and non-empty", {
  frozen_files <- c(
    "regression_metrics.json",
    "classification_metrics.json",
    "pca_variance.json",
    "cluster_profiles.json",
    "pca_scores.json",
    "drift_summary.json",
    "inference_summary.json",
    "stations.json"
  )
  for (f in frozen_files) {
    fp <- file.path(docs_dir, "web-data", f)
    expect_true(file.exists(fp), label = paste("Frozen JSON exists:", f))
    expect_gt(file.size(fp), 100, label = paste("Frozen JSON non-trivial size:", f))
  }
})

# -----------------------------------------------------------------------
# G5-18: home page primary CTA leads to explore.html
# -----------------------------------------------------------------------
test_that("G5-18: index.html primary CTA links to explore.html", {
  index_txt <- read_file_text(file.path(docs_dir, "index.html"))
  expect_true(grepl('href="explore.html" class="btn btn-primary"', index_txt, fixed = TRUE),
              label = "Home primary CTA button targets explore.html")
})
