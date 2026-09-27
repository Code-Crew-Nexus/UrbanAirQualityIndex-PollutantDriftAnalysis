# ==============================================================================
# tests/testthat/test_phase6a_website.R
# UrbanAirQualityIndex-PollutantDriftAnalysis
# B.Tech CSE (AI & ML) III Year / I Sem - Statistics for Machine Learning PBL
# Phase 6A: Static Project Website Foundation & Math Rendering Test Suite
# ==============================================================================

library(testthat)
library(jsonlite)

context("Phase 6A: Static Project Website Foundation")

# Helper paths
docs_dir <- file.path("..", "..", "docs")
if (!dir.exists(docs_dir)) {
  docs_dir <- file.path("docs")
}
repo_root <- if (dir.exists(file.path("..", "..", "docs"))) file.path("..", "..") else "."

read_file_text <- function(filepath) {
  paste(readLines(filepath, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

# ------------------------------------------------------------------------------
# Test 1-8: Core File Existence & Scaffolding
# ------------------------------------------------------------------------------

test_that("1. feature/project-website workflow documentation exists", {
  audit_path <- file.path(docs_dir, "WEBSITE_DOCUMENTATION_AUDIT.md")
  expect_true(file.exists(audit_path))
  content <- read_file_text(audit_path)
  expect_true(grepl("Phase 6A", content, fixed = TRUE))
  expect_true(grepl("feature/project-website", content, fixed = TRUE))
})

test_that("2. six HTML pages exist", {
  required_pages <- c("index.html", "explore.html", "statistics.html", 
                      "machine-learning.html", "documentation.html", "about.html")
  for (page in required_pages) {
    p <- file.path(docs_dir, page)
    expect_true(file.exists(p), info = paste("Missing page:", page))
  }
})

test_that("3. .nojekyll exists", {
  expect_true(file.exists(file.path(docs_dir, ".nojekyll")))
})

test_that("4. shared CSS exists", {
  css_path <- file.path(docs_dir, "assets", "css", "styles.css")
  expect_true(file.exists(css_path))
  expect_gt(file.info(css_path)$size, 1000)
})

test_that("5. required JS files exist", {
  required_js <- c("common.js", "markdown-renderer.js", "home.js", "documentation.js", "about.js")
  for (js in required_js) {
    p <- file.path(docs_dir, "assets", "js", js)
    expect_true(file.exists(p), info = paste("Missing JS:", js))
  }
})

test_that("6. documentation manifest exists", {
  p <- file.path(docs_dir, "assets", "js", "documentation-manifest.js")
  expect_true(file.exists(p))
  content <- read_file_text(p)
  expect_true(grepl("DOCUMENTATION_MANIFEST", content, fixed = TRUE))
})

test_that("7. guide Markdown files exist", {
  required_guides <- c("prerequisites.md", "setup.md", "theoretical_concepts.md", 
                       "execution_guide.md", "screenshots_and_samples.md")
  for (g in required_guides) {
    p <- file.path(docs_dir, "guide", g)
    expect_true(file.exists(p), info = paste("Missing guide:", g))
  }
})

test_that("8. vendor manifest exists", {
  manifest_path <- file.path(docs_dir, "assets", "vendor", "VENDOR_MANIFEST.md")
  expect_true(file.exists(manifest_path))
  content <- read_file_text(manifest_path)
  expect_true(grepl("Marked.js", content, fixed = TRUE))
  expect_true(grepl("KaTeX", content, fixed = TRUE))
  expect_true(grepl("Chart.js", content, fixed = TRUE))
})

# ------------------------------------------------------------------------------
# Test 9-12: Vendored Third-Party Library Assets
# ------------------------------------------------------------------------------

test_that("9. local Marked asset exists", {
  p <- file.path(docs_dir, "assets", "vendor", "marked.min.js")
  expect_true(file.exists(p))
  expect_gt(file.info(p)$size, 10000)
})

test_that("10. local KaTeX JS exists", {
  p <- file.path(docs_dir, "assets", "vendor", "katex", "katex.min.js")
  expect_true(file.exists(p))
  expect_gt(file.info(p)$size, 100000)
})

test_that("11. local KaTeX CSS exists", {
  p <- file.path(docs_dir, "assets", "vendor", "katex", "katex.min.css")
  expect_true(file.exists(p))
  expect_gt(file.info(p)$size, 10000)
})

test_that("12. local Chart.js exists", {
  p <- file.path(docs_dir, "assets", "vendor", "chart.umd.min.js")
  expect_true(file.exists(p))
  expect_gt(file.info(p)$size, 100000)
})

# ------------------------------------------------------------------------------
# Test 13-17: Architecture Invariants (Zero Heavy Runtime)
# ------------------------------------------------------------------------------

test_that("13. no React references in website source", {
  html_files <- list.files(docs_dir, pattern = "\\.html$", full.names = TRUE)
  js_files <- list.files(file.path(docs_dir, "assets", "js"), pattern = "\\.js$", full.names = TRUE)
  all_src <- c(html_files, js_files)
  for (f in all_src) {
    txt <- read_file_text(f)
    expect_false(grepl("react\\.production\\.min\\.js", txt, ignore.case = TRUE),
                 info = paste("React script found in:", f))
    expect_false(grepl("from 'react'", txt),
                 info = paste("React import found in:", f))
  }
})

test_that("14. no Next.js references in website source", {
  html_files <- list.files(docs_dir, pattern = "\\.html$", full.names = TRUE)
  for (f in html_files) {
    txt <- read_file_text(f)
    expect_false(grepl("_next/static", txt), info = paste("Next.js path found in:", f))
  }
})

test_that("15. no npm requirement", {
  expect_false(file.exists(file.path(docs_dir, "package.json")))
  setup_txt <- read_file_text(file.path(docs_dir, "guide", "setup.md"))
  expect_true(grepl("no npm build steps", setup_txt, fixed = TRUE))
})

test_that("16. no Node runtime requirement", {
  setup_txt <- read_file_text(file.path(docs_dir, "guide", "setup.md"))
  expect_true(grepl("no Node.js runtime", setup_txt, fixed = TRUE))
})

test_that("17. no Shiny runtime requirement", {
  html_files <- list.files(docs_dir, pattern = "\\.html$", full.names = TRUE)
  for (f in html_files) {
    txt <- read_file_text(f)
    expect_false(grepl("shiny\\.js", txt, fixed = TRUE))
    expect_false(grepl("shinyServer", txt, fixed = TRUE))
  }
})

# ------------------------------------------------------------------------------
# Test 18-22: Path Safety & Clean Links
# ------------------------------------------------------------------------------

test_that("18. no CDN dependency in final HTML", {
  html_files <- list.files(docs_dir, pattern = "\\.html$", full.names = TRUE)
  for (f in html_files) {
    txt <- read_file_text(f)
    expect_false(grepl("<link[^>]+https?://cdn", txt, ignore.case = TRUE),
                 info = paste("External CDN link stylesheet found in:", f))
    expect_false(grepl("<script[^>]+https?://cdn", txt, ignore.case = TRUE),
                 info = paste("External CDN script tag found in:", f))
    expect_false(grepl("<script[^>]+https?://cdnjs", txt, ignore.case = TRUE),
                 info = paste("External cdnjs script found in:", f))
    expect_false(grepl("<script[^>]+https?://unpkg", txt, ignore.case = TRUE),
                 info = paste("External unpkg script found in:", f))
  }
})

test_that("19. no root-relative /assets URLs", {
  html_files <- list.files(docs_dir, pattern = "\\.html$", full.names = TRUE)
  for (f in html_files) {
    txt <- read_file_text(f)
    expect_false(grepl('href="/assets', txt, fixed = TRUE),
                 info = paste("Root-relative /assets link found in:", f))
    expect_false(grepl('src="/assets', txt, fixed = TRUE),
                 info = paste("Root-relative /assets script found in:", f))
  }
})

test_that("20. no file:/// URLs in website-facing HTML", {
  html_files <- list.files(docs_dir, pattern = "\\.html$", full.names = TRUE)
  for (f in html_files) {
    txt <- read_file_text(f)
    expect_false(grepl("file:///", txt, fixed = TRUE),
                 info = paste("file:/// link found in HTML:", f))
  }
})

test_that("21. no C:\\ paths in website-facing HTML or Markdown", {
  md_files <- list.files(docs_dir, pattern = "\\.md$", full.names = TRUE, recursive = TRUE)
  md_files <- md_files[!grepl("internal_phase_history", md_files)]
  html_files <- list.files(docs_dir, pattern = "\\.html$", full.names = TRUE)
  for (f in c(md_files, html_files)) {
    txt <- read_file_text(f)
    expect_false(grepl("C:\\\\[A-Za-z0-9_]", txt),
                 info = paste("Windows absolute C:\\ path found in:", f))
  }
})

test_that("22. no D:\\ paths in website-facing HTML or Markdown", {
  md_files <- list.files(docs_dir, pattern = "\\.md$", full.names = TRUE, recursive = TRUE)
  md_files <- md_files[!grepl("internal_phase_history", md_files)]
  html_files <- list.files(docs_dir, pattern = "\\.html$", full.names = TRUE)
  for (f in c(md_files, html_files)) {
    txt <- read_file_text(f)
    expect_false(grepl("D:\\\\[A-Za-z0-9_]", txt),
                 info = paste("Windows absolute D:\\ path found in:", f))
  }
})

# ------------------------------------------------------------------------------
# Test 23-26: Navigation, Styling & Palette
# ------------------------------------------------------------------------------

test_that("23. six navigation destinations exact", {
  expected_destinations <- c("index.html", "explore.html", "statistics.html", 
                             "machine-learning.html", "documentation.html", "about.html")
  html_files <- list.files(docs_dir, pattern = "\\.html$", full.names = TRUE)
  for (f in html_files) {
    txt <- read_file_text(f)
    for (dest in expected_destinations) {
      expect_true(grepl(paste0('href="', dest, '"'), txt, fixed = TRUE),
                  info = paste("Destination", dest, "missing in", f))
    }
  }
})

test_that("24. palette contains Graphite/Jade/Champagne tokens", {
  css_path <- file.path(docs_dir, "assets", "css", "styles.css")
  css_txt <- read_file_text(css_path)
  expect_true(grepl("#F6F4EF", css_txt, ignore.case = TRUE)) # Warm Pearl
  expect_true(grepl("#202421", css_txt, ignore.case = TRUE)) # Graphite
  expect_true(grepl("#285F49", css_txt, ignore.case = TRUE)) # Deep Jade
  expect_true(grepl("#B38A52", css_txt, ignore.case = TRUE)) # Champagne
  expect_true(grepl("#DCE0DC", css_txt, ignore.case = TRUE)) # Border
})

test_that("25. no blue primary-theme token introduced", {
  css_path <- file.path(docs_dir, "assets", "css", "styles.css")
  css_txt <- read_file_text(css_path)
  # Deep Jade is primary brand color
  expect_true(grepl("--jade-deep: #285F49", css_txt, fixed = TRUE))
  expect_false(grepl("--primary: #007bff", css_txt, fixed = TRUE))
  expect_false(grepl("--primary: #1890ff", css_txt, fixed = TRUE))
})

test_that("26. math renderer configured", {
  js_path <- file.path(docs_dir, "assets", "js", "markdown-renderer.js")
  js_txt <- read_file_text(js_path)
  expect_true(grepl("throwOnError: false", js_txt, fixed = TRUE))
  expect_true(grepl("output: \"htmlAndMathml\"", js_txt, fixed = TRUE))
})

# ------------------------------------------------------------------------------
# Test 27-35: Mathematical Formulas & Scientific Policies
# ------------------------------------------------------------------------------

test_that("27. inline formula fixture exists", {
  theory_path <- file.path(docs_dir, "guide", "theoretical_concepts.md")
  theory_txt <- read_file_text(theory_path)
  expect_true(grepl("\\$I_p\\$", theory_txt) || grepl("\\$D_z\\$", theory_txt))
})

test_that("28. display formula fixture exists", {
  theory_path <- file.path(docs_dir, "guide", "theoretical_concepts.md")
  theory_txt <- read_file_text(theory_path)
  expect_true(grepl("$$", theory_txt, fixed = TRUE))
})

test_that("29. CPCB formula source exists", {
  theory_path <- file.path(docs_dir, "guide", "theoretical_concepts.md")
  theory_txt <- read_file_text(theory_path)
  expect_true(grepl("BP_{high}-BP_{low}", theory_txt, fixed = TRUE) ||
              grepl("BP_{high} - BP_{low}", theory_txt, fixed = TRUE) ||
              grepl("BP_{high}-BP_{low}", theory_txt))
})

test_that("30. drift formula source exists", {
  theory_path <- file.path(docs_dir, "guide", "theoretical_concepts.md")
  theory_txt <- read_file_text(theory_path)
  expect_true(grepl("D_z", theory_txt, fixed = TRUE))
  expect_true(grepl("s_{baseline}", theory_txt, fixed = TRUE))
})

test_that("31. Logistic target = AQI_(t+1) > 100", {
  theory_path <- file.path(docs_dir, "guide", "theoretical_concepts.md")
  theory_txt <- read_file_text(theory_path)
  expect_true(grepl("AQI_{t+1} > 100", theory_txt, fixed = TRUE) ||
              grepl("AQI_(t+1) > 100", theory_txt, fixed = TRUE) ||
              grepl("\\text{AQI}_{t+1} > 100", theory_txt, fixed = TRUE))
  # Ensure obsolete AQI > 200 is not described as active model target
  expect_false(grepl("Binary classification of high-pollution events (AQI > 200", theory_txt, fixed = TRUE))
})

test_that("32. AQI verified-subset terminology present", {
  theory_path <- file.path(docs_dir, "guide", "theoretical_concepts.md")
  theory_txt <- read_file_text(theory_path)
  expect_true(grepl("verified-subset", theory_txt, ignore.case = TRUE))
})

test_that("33. PM2.5/PM10/O3 documented as AQI inputs", {
  theory_path <- file.path(docs_dir, "guide", "theoretical_concepts.md")
  theory_txt <- read_file_text(theory_path)
  expect_true(grepl("PM", theory_txt) && grepl("2.5", theory_txt))
  expect_true(grepl("PM", theory_txt) && grepl("10", theory_txt))
  expect_true(grepl("O_3", theory_txt) || grepl("O3", theory_txt))
})

test_that("34. CO/NO2/SO2 not represented as AQI inputs", {
  theory_path <- file.path(docs_dir, "guide", "theoretical_concepts.md")
  theory_txt <- read_file_text(theory_path)
  expect_true(grepl("excluded", theory_txt, ignore.case = TRUE))
  expect_true(grepl("CO", theory_txt) && grepl("NO2", theory_txt) && (grepl("SO2", theory_txt) || grepl("SO_2", theory_txt)))
})

test_that("35. no fake data in placeholder pages", {
  placeholder_pages <- c("explore.html", "statistics.html", "machine-learning.html")
  for (p in placeholder_pages) {
    txt <- read_file_text(file.path(docs_dir, p))
    is_phase6b <- grepl("assets/vendor/chart\\.umd\\.min\\.js", txt)
    if (is_phase6b) {
      expect_true(grepl("canvas|chart", txt, ignore.case = TRUE),
                  info = paste("Interactive chart canvas missing in:", p))
    } else {
      expect_true(grepl("Scientific integration is being added in Phase 6B", txt, fixed = TRUE),
                  info = paste("Required placeholder notice missing in:", p))
    }
    expect_false(grepl("lorem ipsum", txt, ignore.case = TRUE))
    expect_false(grepl("dummy", txt, ignore.case = TRUE))
  }
})

# ------------------------------------------------------------------------------
# Test 36-40: Web Data Assets & Statistics
# ------------------------------------------------------------------------------

test_that("36. web JSON exporter script exists", {
  script_path <- file.path(repo_root, "scripts", "30_export_web_assets.R")
  expect_true(file.exists(script_path))
})

test_that("37. project_summary.json parses", {
  summary_path <- file.path(docs_dir, "web-data", "project_summary.json")
  expect_true(file.exists(summary_path))
  summary_data <- fromJSON(summary_path)
  expect_is(summary_data, "list")
  expect_equal(summary_data$project_name, "UrbanAirQualityIndex-PollutantDriftAnalysis")
})

test_that("38. station JSON parses", {
  stations_path <- file.path(docs_dir, "web-data", "stations.json")
  expect_true(file.exists(stations_path))
  stations_data <- fromJSON(stations_path)
  expect_is(stations_data, "data.frame")
  expect_equal(nrow(stations_data), 21)
})

test_that("39. project station counts match canonical project", {
  summary_data <- fromJSON(file.path(docs_dir, "web-data", "project_summary.json"))
  expect_equal(summary_data$study_scope$total_physical_stations, 21)
  expect_equal(summary_data$study_scope$hyderabad_stations, 7)
  expect_equal(summary_data$study_scope$india_representative_stations, 15)
})

test_that("40. study date range matches frozen project", {
  summary_data <- fromJSON(file.path(docs_dir, "web-data", "project_summary.json"))
  expect_equal(summary_data$study_period$start_date, "2025-03-01")
  expect_equal(summary_data$study_period$end_date, "2026-09-21")
  expect_equal(summary_data$study_period$total_study_days, 570)
  expect_equal(summary_data$study_period$total_station_days, 11970)
})

# ------------------------------------------------------------------------------
# Test 41-44: Authorship & Frozen Tags
# ------------------------------------------------------------------------------

test_that("41. exact team members and roll numbers present", {
  about_txt <- read_file_text(file.path(docs_dir, "about.html"))
  expect_true(grepl("Mangali Sai Krishna", about_txt, fixed = TRUE))
  expect_true(grepl("24R11A6669", about_txt, fixed = TRUE))
  expect_true(grepl("Md. Abdul Rayain", about_txt, fixed = TRUE))
  expect_true(grepl("24R11A6673", about_txt, fixed = TRUE))
  expect_true(grepl("Rishit Ghosh", about_txt, fixed = TRUE))  # G5: corrected from ALL-CAPS RISHIT GHOSH
  expect_true(grepl("24R11A6685", about_txt, fixed = TRUE))
  expect_true(grepl("Yaram Karthik", about_txt, fixed = TRUE))
  expect_true(grepl("24R11A66A1", about_txt, fixed = TRUE))
})

test_that("42. v0.4 tag referenced", {
  about_txt <- read_file_text(file.path(docs_dir, "about.html"))
  expect_true(grepl("v0.4-supervised-freeze", about_txt, fixed = TRUE))
})

test_that("43. v0.5 tag referenced", {
  about_txt <- read_file_text(file.path(docs_dir, "about.html"))
  expect_true(grepl("v0.5-unsupervised-freeze", about_txt, fixed = TRUE))
})

test_that("44. v0.6 tag referenced", {
  about_txt <- read_file_text(file.path(docs_dir, "about.html"))
  expect_true(grepl("v0.6-svm-freeze", about_txt, fixed = TRUE))
})

# ------------------------------------------------------------------------------
# Test 45-50: Documentation Engine & Reconciliation Integrity
# ------------------------------------------------------------------------------

test_that("45. Documentation has five required sections", {
  doc_txt <- read_file_text(file.path(docs_dir, "documentation.html"))
  expect_true(grepl("1. Prerequisites", doc_txt, fixed = TRUE))
  expect_true(grepl("2. Setup Guide", doc_txt, fixed = TRUE))
  expect_true(grepl("3. Theoretical Concepts", doc_txt, fixed = TRUE))
  expect_true(grepl("4. Detailed Execution", doc_txt, fixed = TRUE))
  expect_true(grepl("5. Screenshots &amp; Samples", doc_txt, fixed = TRUE) ||
              grepl("5. Screenshots & Samples", doc_txt, fixed = TRUE))
})

test_that("46. faculty walkthrough link resolves", {
  index_txt <- read_file_text(file.path(docs_dir, "index.html"))
  expect_true(grepl('href="documentation.html#execution"', index_txt, fixed = TRUE))
})

test_that("47. Markdown source paths in documentation manifest exist", {
  manifest_path <- file.path(docs_dir, "assets", "js", "documentation-manifest.js")
  manifest_txt <- read_file_text(manifest_path)
  matches <- regmatches(manifest_txt, gregexpr('source:\\s*["\']([^"\']+)["\']', manifest_txt))[[1]]
  sources <- gsub('source:\\s*["\']|["\']', '', matches)
  expect_gt(length(sources), 0)
  for (s in sources) {
    target_path <- file.path(docs_dir, s)
    expect_true(file.exists(target_path), info = paste("Manifest source file missing:", s))
  }
})

test_that("48. internal_phase_history not exposed in navigation", {
  manifest_txt <- read_file_text(file.path(docs_dir, "assets", "js", "documentation-manifest.js"))
  expect_false(grepl("internal_phase_history", manifest_txt, fixed = TRUE))
  html_files <- list.files(docs_dir, pattern = "\\.html$", full.names = TRUE)
  for (f in html_files) {
    txt <- read_file_text(f)
    expect_false(grepl("internal_phase_history", txt, fixed = TRUE),
                 info = paste("internal_phase_history exposed in:", f))
  }
})

test_that("49. README no longer says R Shiny is NEXT", {
  readme_path <- file.path(repo_root, "README.md")
  readme_txt <- read_file_text(readme_path)
  expect_false(grepl("R Shiny — NEXT", readme_txt, fixed = TRUE))
  expect_false(grepl("R Shiny - NEXT", readme_txt, fixed = TRUE))
  expect_true(grepl("Static Project Website", readme_txt, fixed = TRUE))
})

test_that("50. obsolete app Shiny placeholder removed", {
  app_dir <- file.path(repo_root, "app")
  expect_false(dir.exists(app_dir), info = "app/ directory should be completely removed")
})

# ------------------------------------------------------------------------------
# Section 53: Mathematical Syntax & LaTeX Source Verification
# ------------------------------------------------------------------------------

test_that("51. Mathematical delimiter pairs are balanced", {
  theory_txt <- read_file_text(file.path(docs_dir, "guide", "theoretical_concepts.md"))
  # Check display $$ count is even
  double_dollar_count <- lengths(regmatches(theory_txt, gregexpr("\\$\\$", theory_txt)))
  expect_equal(double_dollar_count %% 2, 0,
               info = "Display math delimiter $$ count must be even")
})

test_that("52. Required LaTeX commands present in theoretical guide", {
  theory_txt <- read_file_text(file.path(docs_dir, "guide", "theoretical_concepts.md"))
  expect_true(grepl("\\\\frac", theory_txt), info = "Missing \\frac in theoretical concepts")
  expect_true(grepl("\\\\sum", theory_txt), info = "Missing \\sum in theoretical concepts")
  expect_true(grepl("\\\\exp", theory_txt), info = "Missing \\exp in theoretical concepts")
  expect_true(grepl("\\|", theory_txt), info = "Missing norm notation in theoretical concepts")
})

# ------------------------------------------------------------------------------
# Phase 6A.1: Scientific Integrity, Ground Truth & Math Reconciliation Tests
# ------------------------------------------------------------------------------

test_that("53. Drift metric denominator is strictly baseline SD", {
  theory_txt <- read_file_text(file.path(docs_dir, "guide", "theoretical_concepts.md"))
  p3_txt <- read_file_text(file.path(docs_dir, "reports", "phase3_statistical_analysis_summary.md"))
  method_txt <- read_file_text(file.path(docs_dir, "methodology.md"))
  
  for (txt in list(theory_txt, p3_txt, method_txt)) {
    expect_true(grepl("s_{baseline}", txt, fixed = TRUE) || grepl("s_{\\text{baseline}}", txt, fixed = TRUE))
    expect_false(grepl("s_{pooled}", txt, fixed = TRUE))
    expect_false(grepl("s_{pool}", txt, fixed = TRUE))
  }
})

test_that("54. Drift window eligibility requirements are documented", {
  p3_txt <- read_file_text(file.path(docs_dir, "reports", "phase3_statistical_analysis_summary.md"))
  theory_txt <- read_file_text(file.path(docs_dir, "guide", "theoretical_concepts.md"))
  
  expect_true(grepl("21", p3_txt) && grepl("63", p3_txt))
  expect_true(grepl("21", theory_txt) && grepl("63", theory_txt))
  expect_true(grepl("s_{\\text{baseline}} > 0", p3_txt, fixed = TRUE) || 
              grepl("s_{baseline} > 0", p3_txt, fixed = TRUE) ||
              grepl("s_{baseline}>0", p3_txt, fixed = TRUE))
})

test_that("55. Drift magnitude classes are exact", {
  truth_txt <- read_file_text(file.path(docs_dir, "WEBSITE_SCIENTIFIC_TRUTH.md"))
  theory_txt <- read_file_text(file.path(docs_dir, "guide", "theoretical_concepts.md"))
  p3_txt <- read_file_text(file.path(docs_dir, "reports", "phase3_statistical_analysis_summary.md"))
  
  for (txt in list(truth_txt, theory_txt, p3_txt)) {
    expect_true(grepl("Minimal", txt, fixed = TRUE))
    expect_true(grepl("Mild", txt, fixed = TRUE))
    expect_true(grepl("Moderate", txt, fixed = TRUE))
    expect_true(grepl("Strong", txt, fixed = TRUE))
    expect_false(grepl("Major regime transition", txt, ignore.case = TRUE))
  }
})

test_that("56. Moving-block bootstrap parameters are exact", {
  theory_txt <- read_file_text(file.path(docs_dir, "guide", "theoretical_concepts.md"))
  p3_txt <- read_file_text(file.path(docs_dir, "reports", "phase3_statistical_analysis_summary.md"))
  
  for (txt in list(theory_txt, p3_txt)) {
    expect_true(grepl("2000", txt, fixed = TRUE) || grepl("2{,}000", txt, fixed = TRUE))
    expect_true(grepl("7", txt, fixed = TRUE))
    expect_true(grepl("3", txt, fixed = TRUE))
    expect_true(grepl("14", txt, fixed = TRUE))
  }
})

test_that("57. Supervised temporal split dates are exact", {
  p4_txt <- read_file_text(file.path(docs_dir, "reports", "phase4_supervised_learning_summary.md"))
  truth_txt <- read_file_text(file.path(docs_dir, "WEBSITE_SCIENTIFIC_TRUTH.md"))
  
  for (txt in list(p4_txt, truth_txt)) {
    expect_true(grepl("2025-12-31", txt, fixed = TRUE))
    expect_true(grepl("2026-01-01", txt, fixed = TRUE))
    expect_true(grepl("2026-04-30", txt, fixed = TRUE))
    expect_true(grepl("2026-05-01", txt, fixed = TRUE))
    expect_true(grepl("2026-08-31", txt, fixed = TRUE))
  }
})

test_that("58. Logistic validation-tuned decision thresholds are exact", {
  p4_txt <- read_file_text(file.path(docs_dir, "reports", "phase4_supervised_learning_summary.md"))
  theory_txt <- read_file_text(file.path(docs_dir, "guide", "theoretical_concepts.md"))
  truth_txt <- read_file_text(file.path(docs_dir, "WEBSITE_SCIENTIFIC_TRUTH.md"))
  
  for (txt in list(p4_txt, theory_txt, truth_txt)) {
    expect_true(grepl("0.311268", txt, fixed = TRUE) || grepl("0.311", txt, fixed = TRUE))
    expect_true(grepl("0.713448", txt, fixed = TRUE) || grepl("0.713", txt, fixed = TRUE))
  }
})

test_that("59. PCA variance explained matches Level-1 ground truth", {
  p5a_txt <- read_file_text(file.path(docs_dir, "reports", "phase5_pca_kmeans_summary.md"))
  theory_txt <- read_file_text(file.path(docs_dir, "guide", "theoretical_concepts.md"))
  exec_txt <- read_file_text(file.path(docs_dir, "guide", "execution_guide.md"))
  truth_txt <- read_file_text(file.path(docs_dir, "WEBSITE_SCIENTIFIC_TRUTH.md"))
  
  for (txt in list(p5a_txt, theory_txt, exec_txt, truth_txt)) {
    expect_true(grepl("90.21%", txt, fixed = TRUE) || grepl("90.21", txt, fixed = TRUE))
    expect_true(grepl("88.65%", txt, fixed = TRUE) || grepl("88.65", txt, fixed = TRUE))
  }
})

test_that("60. K-Means cluster count is K=3 for both panels", {
  p5a_txt <- read_file_text(file.path(docs_dir, "reports", "phase5_pca_kmeans_summary.md"))
  theory_txt <- read_file_text(file.path(docs_dir, "guide", "theoretical_concepts.md"))
  audit_txt <- read_file_text(file.path(docs_dir, "WEBSITE_DOCUMENTATION_AUDIT.md"))
  method_txt <- read_file_text(file.path(docs_dir, "methodology.md"))
  truth_txt <- read_file_text(file.path(docs_dir, "WEBSITE_SCIENTIFIC_TRUTH.md"))
  
  for (txt in list(p5a_txt, theory_txt, audit_txt, method_txt, truth_txt)) {
    expect_true(grepl("k = 3", txt, ignore.case = TRUE) || 
                grepl("k=3", txt, ignore.case = TRUE) || 
                grepl("K = 3", txt) || 
                grepl("K=3", txt) ||
                grepl("three clusters", txt, ignore.case = TRUE) ||
                grepl("three regimes", txt, ignore.case = TRUE))
  }
})

test_that("61. Obsolete k=4 and speculative regime labels are prohibited", {
  doc_files <- list.files(docs_dir, pattern = "\\.md$", full.names = TRUE, recursive = TRUE)
  doc_files <- doc_files[!grepl("internal_phase_history", doc_files)]
  
  for (f in doc_files) {
    txt <- read_file_text(f)
    expect_false(grepl("k = 4 regimes", txt, ignore.case = TRUE), info = paste("k=4 regimes in:", f))
    expect_false(grepl("k=4 regimes", txt, ignore.case = TRUE), info = paste("k=4 regimes in:", f))
    expect_false(grepl("Severe Inversion", txt, fixed = TRUE), info = paste("Severe Inversion in:", f))
    expect_false(grepl("Clean / Scavenged", txt, fixed = TRUE), info = paste("Clean / Scavenged in:", f))
  }
})

test_that("62. Universal monsoon scavenging claims are prohibited", {
  p3_txt <- read_file_text(file.path(docs_dir, "reports", "phase3_statistical_analysis_summary.md"))
  theory_txt <- read_file_text(file.path(docs_dir, "guide", "theoretical_concepts.md"))
  exec_txt <- read_file_text(file.path(docs_dir, "guide", "execution_guide.md"))
  
  for (txt in list(p3_txt, theory_txt, exec_txt)) {
    expect_false(grepl("universal monsoon scavenging", txt, ignore.case = TRUE))
    expect_false(grepl("scavenging universally", txt, ignore.case = TRUE))
  }
})

test_that("63. SVM margin classification vs decision ranking score distinction", {
  p5b_txt <- read_file_text(file.path(docs_dir, "reports", "phase5b_svm_summary.md"))
  theory_txt <- read_file_text(file.path(docs_dir, "guide", "theoretical_concepts.md"))
  truth_txt <- read_file_text(file.path(docs_dir, "WEBSITE_SCIENTIFIC_TRUTH.md"))
  
  for (txt in list(p5b_txt, theory_txt, truth_txt)) {
    expect_true(grepl("s(\\mathbf{x}) = 0", txt, fixed = TRUE) || 
                grepl("s(x) = 0", txt, fixed = TRUE) ||
                grepl("s(\\mathbf{x})", txt, fixed = TRUE) ||
                grepl("margin", txt, ignore.case = TRUE))
    expect_true(grepl("ranking", txt, ignore.case = TRUE))
  }
})

test_that("64. WEBSITE_SCIENTIFIC_TRUTH.md exists and is complete", {
  truth_path <- file.path(docs_dir, "WEBSITE_SCIENTIFIC_TRUTH.md")
  expect_true(file.exists(truth_path))
  truth_txt <- read_file_text(truth_path)
  expect_true(grepl("v0.6-svm-freeze", truth_txt, fixed = TRUE))
  expect_true(grepl("21 physical stations", truth_txt, fixed = TRUE))
  expect_true(grepl("570 calendar days", truth_txt, fixed = TRUE))
  expect_true(grepl("s_{baseline}", truth_txt, fixed = TRUE))
  expect_true(grepl("90.21%", truth_txt, fixed = TRUE))
  expect_true(grepl("88.65%", truth_txt, fixed = TRUE))
})

test_that("65. PACKAGE_REQUIREMENTS.md exists and classifies packages", {
  pkg_path <- file.path(docs_dir, "PACKAGE_REQUIREMENTS.md")
  expect_true(file.exists(pkg_path))
  pkg_txt <- read_file_text(pkg_path)
  expect_true(grepl("Tier 1: Core Frozen-Review", pkg_txt, fixed = TRUE))
  expect_true(grepl("Tier 2: Full Reproduction", pkg_txt, fixed = TRUE))
  expect_true(grepl("Tier 3: Raw Acquisition", pkg_txt, fixed = TRUE))
})

test_that("66. WEBSITE_LINK_AUDIT.md exists with zero broken links", {
  audit_path <- file.path(docs_dir, "WEBSITE_LINK_AUDIT.md")
  expect_true(file.exists(audit_path))
  audit_txt <- read_file_text(audit_path)
  expect_true(grepl("ALL_LINKS_VERIFIED_PASS", audit_txt, fixed = TRUE))
  expect_true(grepl("| Broken Links (`BROKEN`) | 0 |", audit_txt, fixed = TRUE))
})

test_that("67. WEBSITE_SCIENTIFIC_TRUTH authority paths exist and match Level-1 assets", {
  truth_path <- file.path(docs_dir, "WEBSITE_SCIENTIFIC_TRUTH.md")
  expect_true(file.exists(truth_path))
  truth_txt <- read_file_text(truth_path)
  
  # A) Must reference actual repository paths
  expect_true(grepl("config/aqi_breakpoints_india.csv", truth_txt, fixed = TRUE))
  expect_true(grepl("config/final_aqi_input_policy.yml", truth_txt, fixed = TRUE))
  expect_true(grepl("scripts/09_phase2E_generate_final_aqi.R", truth_txt, fixed = TRUE))
  expect_true(grepl("scripts/11_phase3B_pollutant_drift.R", truth_txt, fixed = TRUE))
  expect_true(grepl("scripts/12_phase3C_statistical_inference.R", truth_txt, fixed = TRUE))
  expect_true(grepl("config/modeling_specification.yml", truth_txt, fixed = TRUE))
  
  # B) Must NOT reference obsolete paths
  expect_false(grepl("scripts/08_drift_analysis.R", truth_txt, fixed = TRUE))
  expect_false(grepl("scripts/09_statistical_inference.R", truth_txt, fixed = TRUE))
  expect_false(grepl("config/cpcb_breakpoints.csv", truth_txt, fixed = TRUE))
  expect_false(grepl("scripts/06_calculate_aqi.R", truth_txt, fixed = TRUE))
})

test_that("68. Model B feature contract is exact (Model A + aqi_verified, zero rolling stats)", {
  truth_path <- file.path(docs_dir, "WEBSITE_SCIENTIFIC_TRUTH.md")
  truth_txt <- read_file_text(truth_path)
  
  # C & D) Exact feature contract
  expect_true(grepl("Model B = Model A + aqi_verified", truth_txt, fixed = TRUE) ||
              grepl("Model B} = \\text{Model A} + \\text{aqi\\_verified}", truth_txt, fixed = TRUE))
  expect_true(grepl("Zero Rolling Statistics", truth_txt, fixed = TRUE) ||
              grepl("no extra rolling-statistic predictors", truth_txt, fixed = TRUE))
  expect_false(grepl("including lag-1 AQI and rolling statistics", truth_txt, fixed = TRUE))
})

test_that("69. MODELING_FREEZE_SUMMARY does not contain obsolete p*=0.50 threshold", {
  freeze_path <- file.path(docs_dir, "MODELING_FREEZE_SUMMARY.md")
  expect_true(file.exists(freeze_path))
  freeze_txt <- read_file_text(freeze_path)
  
  # E & F) Validation thresholds vs 0.50
  expect_false(grepl("p* = 0.50", freeze_txt, fixed = TRUE))
  expect_false(grepl("p\\* = 0.50", freeze_txt, fixed = TRUE))
  expect_true(grepl("0.311268", freeze_txt, fixed = TRUE))
  expect_true(grepl("0.713448", freeze_txt, fixed = TRUE))
})

test_that("70. MODELING_FREEZE_SUMMARY is free of manufactured R2, monsoon clearing, and speculative PCA/KMeans claims", {
  freeze_path <- file.path(docs_dir, "MODELING_FREEZE_SUMMARY.md")
  freeze_txt <- read_file_text(freeze_path)
  
  # G) Cleaned language
  expect_false(grepl("monsoon clearing", freeze_txt, ignore.case = TRUE))
  expect_false(grepl("0.65–0.72", freeze_txt, fixed = TRUE))
  expect_false(grepl("0.65-0.72", freeze_txt, fixed = TRUE))
  expect_false(grepl("photochemical axis", freeze_txt, ignore.case = TRUE))
  expect_false(grepl("clear separation", freeze_txt, ignore.case = TRUE))
  expect_false(grepl("periods of high environmental inertia", freeze_txt, ignore.case = TRUE))
  
  # Required positive neutral language
  expect_true(grepl("90.21%", freeze_txt, fixed = TRUE))
  expect_true(grepl("88.65%", freeze_txt, fixed = TRUE))
  expect_true(grepl("three-regime partition", freeze_txt, fixed = TRUE) ||
              grepl("K=3", freeze_txt, fixed = TRUE))
})

test_that("71. Execution guide does not claim complete-case daily panel datasets", {
  exec_path <- file.path(docs_dir, "guide", "execution_guide.md")
  expect_true(file.exists(exec_path))
  exec_txt <- read_file_text(exec_path)
  
  # H) Missingness preserved in daily panels
  expect_false(grepl("complete-case, authoritative daily panel datasets", exec_txt, fixed = TRUE))
  expect_true(grepl("missingness preserved", exec_txt, ignore.case = TRUE))
})

test_that("72. Phase 5B Related Figure link in execution guide is deduplicated", {
  exec_path <- file.path(docs_dir, "guide", "execution_guide.md")
  exec_lines <- readLines(exec_path, warn = FALSE)
  phase5b_start <- grep("Phase 5B — Nonlinear Support Vector Machine", exec_lines)
  expect_true(length(phase5b_start) > 0)
  
  phase6_start <- grep("Phase 6 — Static Project Website", exec_lines)
  phase5b_lines <- exec_lines[phase5b_start:phase6_start]
  related_fig_count <- sum(grepl("Related Figure / Screenshot", phase5b_lines))
  expect_equal(related_fig_count, 1)
})

test_that("73. Phase-6A.1 report vendor versions match VENDOR_MANIFEST.md", {
  p6a1_path <- file.path(repo_root, "phase_6A1_website_scientific_integrity_report.md")
  expect_true(file.exists(p6a1_path))
  p6a1_txt <- read_file_text(p6a1_path)
  
  # I) Vendor versions
  expect_true(grepl("12.0.2", p6a1_txt, fixed = TRUE))
  expect_true(grepl("5.0.1", p6a1_txt, fixed = TRUE))
  expect_true(grepl("0.16.11", p6a1_txt, fixed = TRUE))
  expect_true(grepl("4.4.3", p6a1_txt, fixed = TRUE))
  expect_false(grepl("15.0.7", p6a1_txt, fixed = TRUE))
  expect_false(grepl("0.16.21", p6a1_txt, fixed = TRUE))
  expect_false(grepl("4.4.8", p6a1_txt, fixed = TRUE))
  expect_false(grepl("O3 (8-hr max / daily avg)", p6a1_txt, fixed = TRUE))
})

test_that("74. Panel counts remain exactly 21 unique, 7 Hyderabad, 15 India, 1 overlap", {
  truth_path <- file.path(docs_dir, "WEBSITE_SCIENTIFIC_TRUTH.md")
  truth_txt <- read_file_text(truth_path)
  
  # J) Panel counts
  expect_true(grepl("21 physical stations", truth_txt, fixed = TRUE))
  expect_true(grepl("7 stations", truth_txt, fixed = TRUE))
  expect_true(grepl("15 stations", truth_txt, fixed = TRUE))
  expect_true(grepl("Zoo Park", truth_txt, fixed = TRUE) && grepl("both", truth_txt, fixed = TRUE))
})

test_that("75. Drift magnitude cutoff thresholds are strictly 0.5, 1.0, 2.0", {
  truth_path <- file.path(docs_dir, "WEBSITE_SCIENTIFIC_TRUTH.md")
  truth_txt <- read_file_text(truth_path)
  
  # K) Exact numeric cutoffs
  expect_true(grepl("0.5", truth_txt, fixed = TRUE))
  expect_true(grepl("1.0", truth_txt, fixed = TRUE))
  expect_true(grepl("2.0", truth_txt, fixed = TRUE))
  expect_false(grepl("0.20", truth_txt, fixed = TRUE))
  expect_false(grepl("0.80", truth_txt, fixed = TRUE))
})

test_that("76. WEBSITE_SCIENTIFIC_SOURCE_AUDIT.md exists and validates all 11 authority paths", {
  audit_path <- file.path(docs_dir, "WEBSITE_SCIENTIFIC_SOURCE_AUDIT.md")
  expect_true(file.exists(audit_path))
  audit_txt <- read_file_text(audit_path)
  
  expect_true(grepl("AUDIT_COMPLETE_100_PERCENT_PASS", audit_txt, fixed = TRUE))
  expect_true(grepl("Missing Authority Paths:** **0 (ZERO)**", audit_txt, fixed = TRUE))
  
  # Verify every cited authority path actually exists on the filesystem
  cited_paths <- c(
    "data/processed/UAQI_Master_Daily.csv",
    "config/selected_stations.csv",
    "config/aqi_breakpoints_india.csv",
    "config/final_aqi_input_policy.yml",
    "scripts/09_phase2E_generate_final_aqi.R",
    "scripts/11_phase3B_pollutant_drift.R",
    "scripts/12_phase3C_statistical_inference.R",
    "config/modeling_specification.yml",
    "config/phase4B_selected_models.yml",
    "config/phase4C_selected_models.yml",
    "config/phase5B_selected_svm.yml"
  )
  for (cp in cited_paths) {
    expect_true(file.exists(file.path(repo_root, cp)))
  }
})

test_that("77. README.md uses restrained persistence phrasing and references setup.md", {
  readme_path <- file.path(repo_root, "README.md")
  expect_true(file.exists(readme_path))
  readme_txt <- read_file_text(readme_path)
  
  expect_false(grepl("highlighting severe baseline inertia", readme_txt, ignore.case = TRUE))
  expect_true(grepl("showing that persistence remained a strong benchmark", readme_txt, fixed = TRUE))
  expect_true(grepl("docs/guide/setup.md", readme_txt, fixed = TRUE))
})


