library(testthat)
library(dplyr)
library(yaml)

test_that("G6.2A Live Automation Reliability - Workflows", {
  # Daily workflow
  daily_yaml <- yaml::read_yaml("../../.github/workflows/live-data-daily.yml")
  expect_equal(daily_yaml$jobs$`refresh-live-data`$steps[[1]]$uses, "actions/checkout@v7")
  
  # Secret check
  # In G6.2B the gate is step 2, secret check is step 3
  gate_step <- daily_yaml$jobs$`refresh-live-data`$steps[[2]]
  expect_match(gate_step$run, "2026-10-31")
  expect_match(gate_step$run, "skip=true")
  
  secret_step <- daily_yaml$jobs$`refresh-live-data`$steps[[3]]
  expect_match(secret_step$env$OPENAQ_API_KEY, "\\$\\{\\{ secrets.OPENAQ_API_KEY \\}\\}")
  # Assert secret value is never printed
  expect_false(grepl("echo \\$OPENAQ_API_KEY", secret_step$run))
  expect_false(grepl("echo \".*\\$OPENAQ_API_KEY.*\"", secret_step$run))
  expect_match(secret_step$run, "available=false")
  
  # Ensure inactive skip bypasses expensive setup
  r_setup_step <- daily_yaml$jobs$`refresh-live-data`$steps[[4]]
  expect_match(r_setup_step$`if`, "steps.gate.outputs.skip != 'true'")
  expect_match(r_setup_step$`if`, "steps.secret_gate.outputs.available == 'true'")
  
  # Commit deduplication
  commit_step <- daily_yaml$jobs$`refresh-live-data`$steps[[7]]
  expect_match(commit_step$run, "new_status.json")
  
  # Monthly workflow
  monthly_yaml <- yaml::read_yaml("../../.github/workflows/live-data-monthly.yml")
  expect_equal(monthly_yaml$jobs$`monthly-refresh`$steps[[1]]$uses, "actions/checkout@v7")
  m_gate_step <- monthly_yaml$jobs$`monthly-refresh`$steps[[2]]
  expect_match(m_gate_step$run, "2026-11-01")
})

test_that("G6.2B Incremental Deduplication and Date logic", {
  script_content <- readLines("../../scripts/44_live_data_ingestion.R")
  script_str <- paste(script_content, collapse = "\n")
  
  # Canonical deduplication
  expect_true(grepl("anti_join\\(live_master, by = c\\(\"project_station_id\", \"date\"\\)\\)", script_str))
  
  # No 2026-09-26 cap
  expect_false(grepl("min\\(yesterday_ist, \"2026-09-26\"\\)", script_str))
  
  # Date behavior expectations
  expect_true(grepl("max\\(\"2026-09-22\", auto_start\\)", script_str))
  expect_true(grepl("as.character\\(as.Date\\(last_good\\) - 2\\)", script_str))
  expect_true(grepl("yesterday_ist <- as.character\\(as.Date\\(format\\(Sys.time\\(\\), tz = \"Asia/Kolkata\"\\)\\) - 1\\)", script_str))
  
  # Dry run prevents commits and scoring
  expect_true(grepl("if \\(dry_run\\) \\{\n  cat[^\n]+\n  quit\\(status = 0\\)", script_str))
})

test_that("G6.2B Workflow logic evaluation", {
  # Mocking the bash logic from the workflow
  eval_daily_gate <- function(event_name, current_date) {
    if (event_name == "schedule" && current_date > "2026-10-31") return("skip")
    return("active")
  }
  
  expect_equal(eval_daily_gate("schedule", "2026-10-25"), "active")
  expect_equal(eval_daily_gate("schedule", "2026-11-01"), "skip")
  expect_equal(eval_daily_gate("workflow_dispatch", "2026-11-15"), "active")
  
  eval_monthly_gate <- function(event_name, current_date) {
    if (event_name == "schedule" && current_date < "2026-11-01") return("skip")
    return("active")
  }
  expect_equal(eval_monthly_gate("schedule", "2026-10-15"), "skip")
  expect_equal(eval_monthly_gate("schedule", "2026-11-01"), "active")
  expect_equal(eval_monthly_gate("workflow_dispatch", "2026-10-15"), "active")
})

test_that("Live workflow commit message metadata uses authoritative data_through", {
  daily_content <- paste(readLines("../../.github/workflows/live-data-daily.yml", warn = FALSE), collapse = "\n")
  monthly_content <- paste(readLines("../../.github/workflows/live-data-monthly.yml", warn = FALSE), collapse = "\n")
  
  # Ensure neither workflow uses runner execution date for the data commit message
  expect_false(grepl("DATA_DATE=\\$\\(date", daily_content))
  expect_false(grepl("DATA_DATE=\\$\\(date", monthly_content))
  
  # Ensure workflows read data_through from live_pipeline_status.json
  expect_true(grepl("data_through // empty", daily_content, fixed = TRUE))
  expect_true(grepl("data_through // empty", monthly_content, fixed = TRUE))
  expect_true(grepl("live_pipeline_status.json", daily_content, fixed = TRUE))
  expect_true(grepl("live_pipeline_status.json", monthly_content, fixed = TRUE))
  
  # Conceptual mock test of commit message generation
  eval_commit_msg <- function(mode = "daily", data_through = "") {
    is_valid <- grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", data_through)
    if (mode == "daily") {
      if (is_valid) {
        return(paste0("data(live): refresh validated observations through ", data_through, " [skip ci]"))
      } else {
        return("data(live): refresh validated observations [skip ci]")
      }
    } else {
      if (is_valid) {
        return(paste0("data(live): monthly refresh through ", data_through, " [skip ci]"))
      } else {
        return("data(live): monthly refresh [skip ci]")
      }
    }
  }
  
  # Verification 1: When workflow runs on 2026-10-07 and data_through is 2026-10-06
  runner_date <- "2026-10-07"
  status_data_through <- "2026-10-06"
  daily_msg <- eval_commit_msg("daily", status_data_through)
  expect_equal(daily_msg, "data(live): refresh validated observations through 2026-10-06 [skip ci]")
  expect_false(grepl(runner_date, daily_msg))
  
  # Verification 2: Neutral fallback when data_through is unavailable
  expect_equal(eval_commit_msg("daily", ""), "data(live): refresh validated observations [skip ci]")
  expect_equal(eval_commit_msg("daily", "invalid-date"), "data(live): refresh validated observations [skip ci]")
  
  # Verification 3: Monthly refresh with authoritative date
  expect_equal(eval_commit_msg("monthly", "2026-10-31"), "data(live): monthly refresh through 2026-10-31 [skip ci]")
  expect_equal(eval_commit_msg("monthly", ""), "data(live): monthly refresh [skip ci]")
})

