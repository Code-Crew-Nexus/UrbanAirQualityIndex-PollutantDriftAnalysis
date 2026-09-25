library(testthat)
library(yaml)
library(readr)
library(dplyr)
setwd("../..")
context("Phase 2E: Final AQI Generation")

test_that("1. production semantic loader uses Phase-2D4 table", {
  source("R/24_aqi_calculation.R")
  sem <- load_sensor_semantics()
  expect_equal(nrow(sem), 126)
  expect_true("canonical_aqi_unit" %in% names(sem))
})

test_that("2. policy name correct", {
  pol <- read_yaml("config/final_aqi_input_policy.yml")
  expect_equal(pol$policy_name, "VERIFIED_SUBSET_PM25_PM10_O3")
})

test_that("3. included pollutants exactly PM2.5/PM10/O3", {
  pol <- read_yaml("config/final_aqi_input_policy.yml")
  expect_setequal(pol$included_pollutants, c("pm2_5", "pm10", "o3"))
})

test_that("4. excluded pollutants exactly CO/NO2/SO2", {
  pol <- read_yaml("config/final_aqi_input_policy.yml")
  expect_setequal(pol$excluded_pollutants, c("co", "no2", "so2"))
})

test_that("Datasets schema and counts", {
  df_master <- read_csv("data/processed/UAQI_Master_Daily.csv", show_col_types = FALSE)
  df_hyd <- read_csv("data/processed/UAQI_Hyderabad_Daily.csv", show_col_types = FALSE)
  df_ind <- read_csv("data/processed/UAQI_India_Daily.csv", show_col_types = FALSE)
  
  # 5. 21 stations
  expect_equal(length(unique(df_master$project_station_id)), 21)
  
  # 6. master rows = 11,970
  expect_equal(nrow(df_master), 11970)
  
  # 7. Hyderabad rows = 3,990
  expect_equal(nrow(df_hyd), 3990)
  
  # 8. India rows = 8,550
  expect_equal(nrow(df_ind), 8550)
  
  # 9. no duplicate station-date rows
  expect_equal(nrow(df_master %>% group_by(project_station_id, date) %>% filter(n()>1)), 0)
  
  # 29. Hyderabad/India schema parity
  expect_equal(names(df_hyd), names(df_ind))
  
  # 16-18. no CO/NO2/SO2 subindex column with fabricated values
  expect_false("co_subindex" %in% names(df_master))
  expect_false("no2_subindex" %in% names(df_master))
  expect_false("so2_subindex" %in% names(df_master))
  
  # 27. unresolved gas source values preserved
  expect_true(all(c("co_source_mean", "no2_source_mean", "so2_source_mean") %in% names(df_master)))
  
  # 28. weather unchanged
  expect_true(all(c("temperature", "humidity", "wind_speed", "wind_direction") %in% names(df_master)))
  
  # AQI Validations
  valid_aqi <- df_master %>% filter(aqi_validity_reason == "valid")
  
  # 19. valid AQI requires exactly 3 valid included subindices
  expect_true(all(!is.na(valid_aqi$pm2_5_subindex) & !is.na(valid_aqi$pm10_subindex) & !is.na(valid_aqi$o3_subindex)))
  
  # 20. AQI uncapped = max included subindices
  expect_equal(valid_aqi$aqi_uncapped, pmax(valid_aqi$pm2_5_subindex, valid_aqi$pm10_subindex, valid_aqi$o3_subindex))
  
  # 21. AQI display cap
  expect_equal(valid_aqi$aqi_verified, pmin(valid_aqi$aqi_uncapped, 500))
  
  # 10. PM2.5 >=16-hour rule
  expect_true(all(valid_aqi$pm2_5_valid_hours >= 16))
  expect_true(all(valid_aqi$pm10_valid_hours >= 16))
  
  # 26. missing AQI remains NA
  invalid_aqi <- df_master %>% filter(aqi_validity_reason != "valid")
  expect_true(all(is.na(invalid_aqi$aqi_verified)))
})

test_that("Outputs exist", {
  expect_true(file.exists("data/metadata/phase2E_index400_boundary_trace.csv"))
  expect_true(file.exists("data/metadata/phase2E_o3_path_summary.csv"))
  expect_true(file.exists("data/metadata/phase2E_aqi_validity_summary.csv"))
})
