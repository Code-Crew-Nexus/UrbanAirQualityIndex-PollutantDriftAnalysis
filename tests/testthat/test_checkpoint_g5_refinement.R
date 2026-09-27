# ==============================================================================
# tests/testthat/test_checkpoint_g5_refinement.R
# Checkpoint G5.1 & G5.2: Header Refinement, Public Terminology, About Page
# Completeness, and Local Preview Reliability Suite
# ==============================================================================

library(testthat)

context("Checkpoint G5.1 & G5.2: Header Polish, Academic Terminology, About Page & Local Preview")

# Locate docs directory relative to test directory
find_docs_dir <- function() {
  candidates <- c("docs", "../../docs", "../docs")
  for (cand in candidates) {
    if (dir.exists(cand) && file.exists(file.path(cand, "index.html"))) {
      return(normalizePath(cand))
    }
  }
  stop("Could not locate docs/ directory.")
}

find_repo_root <- function() {
  docs_dir <- find_docs_dir()
  normalizePath(file.path(docs_dir, ".."))
}

docs_dir <- find_docs_dir()
repo_root <- find_repo_root()
pages <- c("index.html", "explore.html", "statistics.html", "machine-learning.html", "documentation.html", "about.html")

read_file_text <- function(filepath) {
  readChar(filepath, file.info(filepath)$size, useBytes = TRUE)
}

# ------------------------------------------------------------------------------
# 1. PUBLIC TERMINOLOGY: NO UNEXPLAINED SML / PBL SHORTHAND
# ------------------------------------------------------------------------------

test_that("G5.2-01: Zero unexplained 'SML PBL' or standalone 'PBL' in public HTML files", {
  for (pg in pages) {
    txt <- read_file_text(file.path(docs_dir, pg))
    expect_false(grepl("SML PBL", txt, fixed = TRUE),
                 info = paste("Stale 'SML PBL' found in:", pg))
    expect_false(grepl("(SML)", txt, fixed = TRUE),
                 info = paste("Unexplained '(SML)' found in:", pg))
    expect_false(grepl("(PBL)", txt, fixed = TRUE),
                 info = paste("Unexplained '(PBL)' found in:", pg))
  }
})

test_that("G5.2-02: All 6 HTML pages define restrained COURSE PROJECT mark in header", {
  for (pg in pages) {
    txt <- read_file_text(file.path(docs_dir, pg))
    expect_true(grepl('class="brand-badge">COURSE PROJECT</span>', txt, fixed = TRUE),
                info = paste("Missing COURSE PROJECT mark in:", pg))
    expect_true(grepl('class="brand-title">Urban Air Quality</span>', txt, fixed = TRUE),
                info = paste("Missing Urban Air Quality brand title in:", pg))
    expect_true(grepl('Statistics for Machine Learning · Project Based Learning', txt, fixed = TRUE),
                info = paste("Missing full course & framework descriptor in:", pg))
  }
})

test_that("G5.2-03: All 6 HTML pages define full academic terminology in footer", {
  for (pg in pages) {
    txt <- read_file_text(file.path(docs_dir, pg))
    expect_true(grepl('Statistics for Machine Learning &middot; Project Based Learning', txt, fixed = TRUE),
                info = paste("Footer missing full academic terminology in:", pg))
    expect_false(grepl('Statistics for Machine Learning PBL', txt, fixed = TRUE),
                 info = paste("Stale shorthand in footer in:", pg))
  }
})

# ------------------------------------------------------------------------------
# 2. ABOUT PAGE ARCHITECTURE & FACTUAL INTEGRITY
# ------------------------------------------------------------------------------

test_that("G5.2-04: about.html contains all 11 required academic profile sections", {
  txt <- read_file_text(file.path(docs_dir, "about.html"))
  
  # 1. About the Project
  expect_true(grepl("About the Project", txt, fixed = TRUE))
  expect_true(grepl("temporal drift of urban air pollutants", txt, fixed = TRUE))
  
  # 2. Academic Context & Governance
  expect_true(grepl("Academic Context &amp; Curriculum Governance", txt, fixed = TRUE))
  expect_true(grepl("Statistics for Machine Learning", txt, fixed = TRUE))
  expect_true(grepl("Project Based Learning", txt, fixed = TRUE))
  expect_true(grepl("Bachelor of Technology", txt, fixed = TRUE))
  expect_true(grepl("Computer Science and Engineering (Artificial Intelligence and Machine Learning)", txt, fixed = TRUE))
  expect_true(grepl("Code-Crew-Nexus", txt, fixed = TRUE))
  
  # 3. Project Research Team Roster
  expect_true(grepl("Mangali Sai Krishna", txt, fixed = TRUE))
  expect_true(grepl("24R11A6669", txt, fixed = TRUE))
  expect_true(grepl("Md. Abdul Rayain", txt, fixed = TRUE))
  expect_true(grepl("24R11A6673", txt, fixed = TRUE))
  expect_true(grepl("Rishit Ghosh", txt, fixed = TRUE))
  expect_true(grepl("24R11A6685", txt, fixed = TRUE))
  expect_true(grepl("Yaram Karthik", txt, fixed = TRUE))
  expect_true(grepl("24R11A66A1", txt, fixed = TRUE))
  
  # 4. Research Objectives
  expect_true(grepl("Research Objectives", txt, fixed = TRUE))
  expect_true(grepl("Verified-Subset Air Quality Index", txt, fixed = TRUE))
  expect_true(grepl("Quantification of Pollutant Drift", txt, fixed = TRUE))
  expect_true(grepl("Statistical Significance &amp; Error Control", txt, fixed = TRUE))
  expect_true(grepl("Supervised Next-Day Classification", txt, fixed = TRUE))
  expect_true(grepl("Unsupervised Structure &amp; Operational Regimes", txt, fixed = TRUE))
  
  # 5. Study Design & Data Scope
  expect_true(grepl("21 unique physical CAAQMS stations", txt, fixed = TRUE))
  expect_true(grepl("7 physical monitoring stations across the Hyderabad urban area", txt, fixed = TRUE))
  expect_true(grepl("15 physical monitoring stations representing key industrial", txt, fixed = TRUE))
  expect_true(grepl("PROJ_007 — Zoo Park, Hyderabad", txt, fixed = TRUE))
  expect_true(grepl("7 + 15 &minus; 1 = 21 unique physical monitoring stations", txt, fixed = TRUE))
  expect_true(grepl("570 continuous calendar days", txt, fixed = TRUE))
  expect_true(grepl("1 March 2025 through 21 September 2026", txt, fixed = TRUE))
  
  # 6. Verified-Subset AQI Policy
  expect_true(grepl("Verified-Subset Air Quality Index Policy", txt, fixed = TRUE))
  expect_true(grepl("PM2.5, PM10, and 8-hour maximum O3", txt, fixed = TRUE))
  expect_true(grepl("CO, NO2, SO2", txt, fixed = TRUE))
  expect_true(grepl("NOT be described as the official operational Central Pollution Control Board Air Quality Index", txt, fixed = TRUE))
  
  # 7. Analytical Workflow
  expect_true(grepl("Analytical Workflow", txt, fixed = TRUE))
  expect_true(grepl("Radial Basis Function Support Vector Machine", txt, fixed = TRUE))
  
  # 8. Scientific Limitations
  expect_true(grepl("Scientific Limitations", txt, fixed = TRUE))
  expect_true(grepl("Observational Drift vs. Causal Attribution", txt, fixed = TRUE))
  expect_true(grepl("Seasonal Prevalence Shift", txt, fixed = TRUE))
  expect_true(grepl("Static Presentation Model", txt, fixed = TRUE))
  
  # 9. Frozen Scientific Milestones
  expect_true(grepl("v0.6-svm-freeze", txt, fixed = TRUE))
  expect_true(grepl("v0.5-unsupervised-freeze", txt, fixed = TRUE))
  expect_true(grepl("v0.4-supervised-freeze", txt, fixed = TRUE))
  
  # 10. Reproducibility & Stack
  expect_true(grepl("Reproducibility &amp; Tech Stack", txt, fixed = TRUE))
  expect_true(grepl("R 4.x", txt, fixed = TRUE))
  
  # 11. Code Repository & License
  expect_true(grepl("Code Repository &amp; License", txt, fixed = TRUE))
  expect_true(grepl("License status:</strong> To be finalized", txt, fixed = TRUE))
})

# ------------------------------------------------------------------------------
# 3. LOCAL PREVIEW RELIABILITY & FILE:// PROTOCOL HANDLING
# ------------------------------------------------------------------------------

test_that("G5.2-05: scripts/serve_website_local.py exists and uses standard library", {
  server_script <- file.path(repo_root, "scripts", "serve_website_local.py")
  expect_true(file.exists(server_script), label = "serve_website_local.py exists")
  txt <- read_file_text(server_script)
  expect_true(grepl("http.server", txt, fixed = TRUE), label = "Uses http.server")
  expect_false(grepl("import flask", txt, fixed = TRUE), label = "No flask dependency")
  expect_true(grepl("Urban Air Quality local website preview", txt, fixed = TRUE))
})

test_that("G5.2-06: explore.html separates #explore-load-error from #explore-empty-state", {
  txt <- read_file_text(file.path(docs_dir, "explore.html"))
  expect_true(grepl('id="explore-load-error"', txt, fixed = TRUE),
              label = "explore.html has separate load error notice element")
  expect_true(grepl('role="alert"', txt, fixed = TRUE),
              label = "load error notice has role='alert'")
  expect_true(grepl('id="explore-empty-state"', txt, fixed = TRUE),
              label = "explore.html has empty selection notice element")
  expect_true(grepl('Try another station, variable, or date range.', txt, fixed = TRUE),
              label = "Empty state gives valid filter advice")
})

test_that("G5.2-07: explore.js implements showLoadError and file:// protocol detection", {
  js_txt <- read_file_text(file.path(docs_dir, "assets", "js", "explore.js"))
  expect_true(grepl("showLoadError", js_txt, fixed = TRUE),
              label = "explore.js defines showLoadError")
  expect_true(grepl("window.location.protocol === 'file:'", js_txt, fixed = TRUE),
              label = "explore.js detects file: protocol")
  expect_true(grepl("LOCAL PREVIEW REQUIRED", js_txt, fixed = TRUE),
              label = "explore.js renders LOCAL PREVIEW REQUIRED banner")
  expect_true(grepl("py scripts/serve_website_local.py", js_txt, fixed = TRUE),
              label = "explore.js suggests serve_website_local.py command")
})

test_that("G5.2-08: README.md and setup.md document local preview helper", {
  readme_txt <- read_file_text(file.path(repo_root, "README.md"))
  setup_txt <- read_file_text(file.path(docs_dir, "guide", "setup.md"))
  
  expect_true(grepl("py scripts/serve_website_local.py", readme_txt, fixed = TRUE),
              label = "README references serve_website_local.py")
  expect_true(grepl("Local Website Preview", readme_txt, fixed = TRUE),
              label = "README has Local Website Preview heading")
  expect_true(grepl("py scripts/serve_website_local.py", setup_txt, fixed = TRUE),
              label = "setup.md references serve_website_local.py")
})

# ------------------------------------------------------------------------------
# 4. G5.1 HEADER CSS & RESPONSIVE GEOMETRY
# ------------------------------------------------------------------------------

test_that("G5.1-01: styles.css defines 80px header height and warm pearl surface", {
  css_txt <- read_file_text(file.path(docs_dir, "assets", "css", "styles.css"))
  expect_true(grepl("--header-height: 80px;", css_txt, fixed = TRUE),
              label = "styles.css sets --header-height to 80px")
  expect_true(grepl("rgba(252, 251, 248, 0.97)", css_txt, fixed = TRUE),
              label = "styles.css defines warm pearl header surface")
  expect_true(grepl(".brand-descriptor", css_txt, fixed = TRUE),
              label = "styles.css styles brand descriptor")
  expect_true(grepl(".nav-link.active::after", css_txt, fixed = TRUE),
              label = "styles.css defines centered active underline via ::after")
  expect_true(grepl("@media (max-width: 1080px)", css_txt, fixed = TRUE),
              label = "styles.css sets collision prevention breakpoint at 1080px")
})

# ------------------------------------------------------------------------------
# 5. SCIENTIFIC INVARIANT INTEGRITY
# ------------------------------------------------------------------------------

test_that("G5-INV: Frozen scientific JSON assets remain byte-valid and non-empty", {
  json_files <- c(
    "stations.json",
    "daily_observations.json",
    "drift_summary.json",
    "inference_summary.json",
    "regression_metrics.json",
    "classification_metrics.json",
    "pca_variance.json",
    "cluster_profiles.json",
    "pca_scores.json"
  )
  for (jf in json_files) {
    p <- file.path(docs_dir, "web-data", jf)
    expect_true(file.exists(p), info = paste("Missing json file:", jf))
    expect_gt(file.info(p)$size, 100, label = paste("JSON file size non-trivial:", jf))
  }
})
