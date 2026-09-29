test_that("G6.2A Live Automation Reliability - Workflows", {
  # Daily workflow
  daily_yaml <- yaml::read_yaml("../../.github/workflows/live-data-daily.yml")
  expect_equal(daily_yaml$jobs$`refresh-live-data`$steps[[1]]$uses, "actions/checkout@v7")
  
  # Secret check
  secret_step <- daily_yaml$jobs$`refresh-live-data`$steps[[2]]
  expect_match(secret_step$run, "OPENAQ_API_KEY")
  expect_match(secret_step$run, "exit 1")
  
  # Skip gate
  gate_step <- daily_yaml$jobs$`refresh-live-data`$steps[[3]]
  expect_match(gate_step$run, "skip=true")
  
  # Commit deduplication
  commit_step <- daily_yaml$jobs$`refresh-live-data`$steps[[7]]
  expect_match(commit_step$run, "new_status.json")
  
  # Monthly workflow
  monthly_yaml <- yaml::read_yaml("../../.github/workflows/live-data-monthly.yml")
  expect_equal(monthly_yaml$jobs$`monthly-refresh`$steps[[1]]$uses, "actions/checkout@v7")
})

test_that("G6.2A Incremental Deduplication logic is present", {
  script_content <- readLines("../../scripts/44_live_data_ingestion.R")
  expect_true(any(grepl("anti_join\\(live_master, by = c\\(\"project_station_id\", \"date\"\\)\\)", script_content)))
  expect_false(any(grepl("min\\(yesterday_ist, \"2026-09-26\"\\)", script_content)))
})
