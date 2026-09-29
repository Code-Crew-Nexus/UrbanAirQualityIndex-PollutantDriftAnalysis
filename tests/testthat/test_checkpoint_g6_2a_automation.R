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
