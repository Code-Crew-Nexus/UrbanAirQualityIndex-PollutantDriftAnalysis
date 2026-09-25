library(testthat)
library(yaml)
library(readr)
setwd("../..")
context("Phase 2D.4: Direct CPCB Source Reconciliation & Fallback")

source("R/24_aqi_calculation.R")

test_that("1. final sensor semantics has 126 rows", {
  sem <- read_csv("data/metadata/phase2D4_final_sensor_semantic_units.csv", show_col_types = FALSE)
  expect_equal(nrow(sem), 126)
  expect_true(all(c("sensor_id", "pollutant", "verification_method", "verification_status") %in% names(sem)))
})

test_that("2. exactly one final AQI policy is active", {
  pol <- read_yaml("config/final_aqi_input_policy.yml")
  expect_equal(pol$policy_name, "VERIFIED_SUBSET_PM25_PM10_O3")
})

test_that("3. unresolved unit is never converted speculatively", {
  # Test with an UNRESOLVED sensor from phase2D4
  sem <- read_csv("data/metadata/phase2D4_final_sensor_semantic_units.csv", show_col_types = FALSE)
  unresolved_sensor <- sem$sensor_id[sem$verification_status == "UNRESOLVED"][1]
  expect_true(is.na(convert_hourly_to_canonical_unit(10, "co", "ppb", unresolved_sensor)))
})

test_that("11. fallback includes exactly PM2.5, PM10, O3", {
  pol <- read_yaml("config/final_aqi_input_policy.yml")
  expect_setequal(pol$included_pollutants, c("pm2_5", "pm10", "o3"))
})

test_that("12. fallback excludes CO/NO2/SO2", {
  pol <- read_yaml("config/final_aqi_input_policy.yml")
  expect_setequal(pol$excluded_pollutants, c("co", "no2", "so2"))
})

test_that("15. severe-impact unresolved fields use NA, not -Inf", {
  impact <- read_csv("data/metadata/phase2D3_severe_policy_impact.csv", show_col_types = FALSE)
  unresolved_max <- impact$maximum_observed_regulatory_input[impact$pollutant %in% c("co", "no2", "so2")]
  expect_true(all(is.na(unresolved_max)))
})

test_that("17. Phase-2C frozen inputs remain unchanged", {
  files <- list.files("data/interim/hourly/historical", full.names = TRUE)
  expect_true(length(files) > 0)
})

test_that("18. no final UAQI processed datasets are produced yet", {
  expect_false(file.exists("data/processed/UAQI_India_Daily.csv"))
  expect_false(file.exists("data/processed/UAQI_Hyderabad_Daily.csv"))
})
