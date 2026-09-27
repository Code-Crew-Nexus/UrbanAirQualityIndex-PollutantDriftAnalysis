# ==============================================================================
# tests/testthat/test_checkpoint_g6_live_extension.R
# Checkpoint G6: Cost-Safe Live Data Extension, Deployment Hygiene & Resilience
# ==============================================================================

library(testthat)
library(jsonlite)
library(readr)
library(dplyr)

context("Checkpoint G6: Live Data Extension, Hygiene & Resilience")

find_repo_root <- function() {
  candidates <- c(".", "../..", "..")
  for (cand in candidates) {
    if (file.exists(file.path(cand, "config", "project_config.yml"))) {
      return(normalizePath(cand))
    }
  }
  stop("Could not locate repository root.")
}

repo_root <- find_repo_root()

# ------------------------------------------------------------------------------
# 1. SCIENTIFIC BASELINE IMMUTABILITY
# ------------------------------------------------------------------------------

test_that("G6-01: Frozen baseline dataset remains unchanged and strictly ends on 2026-09-21", {
  master_path <- file.path(repo_root, "data", "processed", "UAQI_Master_Daily.csv")
  expect_true(file.exists(master_path))
  
  master_df <- read_csv(master_path, col_types = cols_only(project_station_id = col_character(), date = col_date()))
  expect_equal(nrow(master_df), 11970)
  expect_equal(min(master_df$date), as.Date("2025-03-01"))
  expect_equal(max(master_df$date), as.Date("2026-09-21"))
  expect_equal(n_distinct(master_df$project_station_id), 21)
  expect_equal(n_distinct(master_df$date), 570)
})

test_that("G6-02: Frozen web daily observations JSON strictly ends on 2026-09-21", {
  daily_json_path <- file.path(repo_root, "docs", "web-data", "daily_observations.json")
  expect_true(file.exists(daily_json_path))
  
  daily_json <- fromJSON(daily_json_path)
  expect_equal(nrow(daily_json), 11970)
  expect_equal(min(daily_json$date), "2025-03-01")
  expect_equal(max(daily_json$date), "2026-09-21")
})

# ------------------------------------------------------------------------------
# 2. LIVE DATA EXTENSION & SEPARATION
# ------------------------------------------------------------------------------

test_that("G6-03: Live daily observations exist and strictly begin on 2026-09-22", {
  live_csv_path <- file.path(repo_root, "data", "live", "processed", "live_daily_observations.csv")
  live_json_path <- file.path(repo_root, "docs", "web-data", "live_daily_observations.json")
  
  expect_true(file.exists(live_csv_path))
  expect_true(file.exists(live_json_path))
  
  live_df <- read_csv(live_csv_path, show_col_types = FALSE)
  expect_true(nrow(live_df) >= 105)
  expect_true(all(live_df$date >= as.Date("2026-09-22")))
  expect_equal(min(live_df$date), as.Date("2026-09-22"))
  
  live_json <- fromJSON(live_json_path)
  expect_true(nrow(live_json) >= 105)
  expect_true(all(live_json$date >= "2026-09-22"))
})

test_that("G6-04: Zero duplicate (station, date) records in live observations", {
  live_csv_path <- file.path(repo_root, "data", "live", "processed", "live_daily_observations.csv")
  live_df <- read_csv(live_csv_path, show_col_types = FALSE)
  
  dups <- live_df %>% count(project_station_id, date) %>% filter(n > 1)
  expect_equal(nrow(dups), 0)
})

# ------------------------------------------------------------------------------
# 3. SCHEMA CONTRACT & PIPELINE STATUS
# ------------------------------------------------------------------------------

test_that("G6-05: Upstream schema contract is valid and defines supported units and drift policy", {
  contract_path <- file.path(repo_root, "config", "live_source_contract.json")
  expect_true(file.exists(contract_path))
  
  contract <- fromJSON(contract_path, simplifyVector = FALSE)
  expect_equal(contract$sources$openaq$api_version, "v3")
  expect_true("µg/m³" %in% contract$sources$openaq$accepted_units$pm2_5)
  expect_equal(contract$sources$openaq$schema_drift_policy$action, "HALT_PUBLICATION")
  expect_equal(contract$sources$openaq$schema_drift_policy$error_code, "UPSTREAM_SCHEMA_CHANGE")
})

test_that("G6-06: Live pipeline status JSON is valid with required operational fields", {
  status_path <- file.path(repo_root, "docs", "web-data", "live_pipeline_status.json")
  expect_true(file.exists(status_path))
  
  status <- fromJSON(status_path, simplifyVector = FALSE)
  expect_equal(status$status, "ok")
  expect_equal(status$code, "LIVE_DATA_CURRENT")
  expect_equal(status$severity, "info")
  expect_true(!is.null(status$data_through))
  expect_true(as.Date(status$data_through) >= as.Date("2026-09-26"))
  expect_equal(status$source, "OpenAQ + Open-Meteo")
})

# ------------------------------------------------------------------------------
# 4. DETERMINISTIC FROZEN-MODEL INFERENCE
# ------------------------------------------------------------------------------

test_that("G6-07: Live predictions JSON contains deterministic frozen-model scores and disclaimer", {
  pred_path <- file.path(repo_root, "docs", "web-data", "live_predictions.json")
  expect_true(file.exists(pred_path))
  
  pred_obj <- fromJSON(pred_path, simplifyVector = FALSE)
  expect_equal(pred_obj$metadata$model_baseline, "v0.6-svm-freeze")
  expect_equal(pred_obj$metadata$inference_type, "DETERMINISTIC_FROZEN_INFERENCE")
  expect_true(grepl("frozen", pred_obj$metadata$disclaimer, ignore.case = TRUE))
  expect_true(pred_obj$metadata$total_scored_records > 0)
  expect_true(length(pred_obj$predictions) > 0)
})

test_that("G6-08: Candidate model architecture enforces AUTO_PROMOTE_MODEL = FALSE", {
  readme_path <- file.path(repo_root, "models", "live_candidate", "README.md")
  expect_true(file.exists(readme_path))
  
  content <- readChar(readme_path, file.info(readme_path)$size)
  expect_true(grepl("AUTO_PROMOTE_MODEL = FALSE", content))
  expect_true(grepl("v0.6-svm-freeze", content))
})

# ------------------------------------------------------------------------------
# 5. COST & WORKFLOW GUARDRAILS
# ------------------------------------------------------------------------------

test_that("G6-09: Cost and automation guardrails document exists", {
  guardrail_path <- file.path(repo_root, "docs", "ops", "COST_AND_AUTOMATION_GUARDRAILS.md")
  expect_true(file.exists(guardrail_path))
  
  content <- readChar(guardrail_path, file.info(guardrail_path)$size)
  expect_true(grepl("ubuntu-latest", content))
  expect_true(grepl("timeout-minutes: 20", content))
  expect_true(grepl("live-data-refresh", content))
})

test_that("G6-10: Daily workflow uses free runner, 20m timeout, concurrency, and 2026-10-31 cutoff", {
  daily_path <- file.path(repo_root, ".github", "workflows", "live-data-daily.yml")
  expect_true(file.exists(daily_path))
  
  content <- readChar(daily_path, file.info(daily_path)$size)
  expect_true(grepl("runs-on:\\s*ubuntu-latest", content))
  expect_true(grepl("timeout-minutes:\\s*20", content))
  expect_true(grepl("group:\\s*live-data-refresh", content))
  expect_true(grepl("17 2 \\* \\* \\*", content))
  expect_true(grepl("2026-10-31", content))
})

test_that("G6-11: Monthly workflow uses free runner, 20m timeout, concurrency, and 2026-11-01 start", {
  monthly_path <- file.path(repo_root, ".github", "workflows", "live-data-monthly.yml")
  expect_true(file.exists(monthly_path))
  
  content <- readChar(monthly_path, file.info(monthly_path)$size)
  expect_true(grepl("runs-on:\\s*ubuntu-latest", content))
  expect_true(grepl("timeout-minutes:\\s*20", content))
  expect_true(grepl("group:\\s*live-data-refresh", content))
  expect_true(grepl("47 2 1 \\* \\*", content))
  expect_true(grepl("2026-11-01", content))
})

# ------------------------------------------------------------------------------
# 6. WEBSITE UX & ACCESSIBILITY
# ------------------------------------------------------------------------------

test_that("G6-12: common.js initializes operational status banner", {
  common_path <- file.path(repo_root, "docs", "assets", "js", "common.js")
  content <- readChar(common_path, file.info(common_path)$size)
  expect_true(grepl("initLiveStatusBanner", content))
  expect_true(grepl("live-status-banner", content))
  expect_true(grepl("live_pipeline_status.json", content))
})

test_that("G6-13: styles.css contains live status banner and mode styling", {
  css_path <- file.path(repo_root, "docs", "assets", "css", "styles.css")
  content <- readChar(css_path, file.info(css_path)$size)
  expect_true(grepl(".live-status-banner", content, fixed = TRUE))
  expect_true(grepl(".live-status-ok", content, fixed = TRUE))
  expect_true(grepl(".live-status-warning", content, fixed = TRUE))
  expect_true(grepl(".live-status-danger", content, fixed = TRUE))
  expect_true(grepl(".data-mode-callout", content, fixed = TRUE))
  expect_true(grepl(".frozen-baseline-notice", content, fixed = TRUE))
  expect_true(grepl(".stream-badge--live", content, fixed = TRUE))
})

test_that("G6-14: explore.html includes data mode selector and callout", {
  explore_path <- file.path(repo_root, "docs", "explore.html")
  content <- readChar(explore_path, file.info(explore_path)$size)
  expect_true(grepl("filter-data-mode", content))
  expect_true(grepl("data-mode-callout", content))
  expect_true(grepl("<th scope=\"col\">Stream</th>", content, fixed = TRUE))
})

test_that("G6-15: explore.js supports Data Mode switching and stream badges", {
  explore_js_path <- file.path(repo_root, "docs", "assets", "js", "explore.js")
  content <- readChar(explore_js_path, file.info(explore_js_path)$size)
  expect_true(grepl("applyDataMode", content))
  expect_true(grepl("ensureLiveObservationsLoaded", content))
  expect_true(grepl("live_daily_observations.json", content))
  expect_true(grepl("stream-badge", content))
})

test_that("G6-16: statistics.html and machine-learning.html include frozen baseline notice", {
  stat_path <- file.path(repo_root, "docs", "statistics.html")
  ml_path <- file.path(repo_root, "docs", "machine-learning.html")
  
  stat_content <- readChar(stat_path, file.info(stat_path)$size)
  ml_content <- readChar(ml_path, file.info(ml_path)$size)
  
  expect_true(grepl("frozen-baseline-notice", stat_content))
  expect_true(grepl("v0.6-svm-freeze", stat_content))
  expect_true(grepl("frozen-baseline-notice", ml_content))
  expect_true(grepl("v0.6-svm-freeze", ml_content))
})

# ------------------------------------------------------------------------------
# 7. DEPLOYMENT DECLUTTER & INVENTORY
# ------------------------------------------------------------------------------

test_that("G6-17: Deployment inventories and declutter script exist", {
  before_path <- file.path(repo_root, "checkpoint_G6_deployment_inventory_before.csv")
  after_path <- file.path(repo_root, "checkpoint_G6_deployment_inventory_after.csv")
  script_path <- file.path(repo_root, "scripts", "43_declutter_deployments.py")
  
  expect_true(file.exists(before_path))
  expect_true(file.exists(after_path))
  expect_true(file.exists(script_path))
  
  before_df <- read_csv(before_path, show_col_types = FALSE)
  after_df <- read_csv(after_path, show_col_types = FALSE)
  
  expect_equal(nrow(before_df), 13)
  expect_equal(nrow(after_df), 3)
  expect_true("active" %in% after_df$active_state)
})
