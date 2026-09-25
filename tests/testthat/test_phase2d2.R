library(testthat)
setwd("../..")
context("Phase 2D.2: Source-Unit & Provenance Audit")

source("R/24_aqi_calculation.R")

test_that("11. canonical pass-through tests", {
  # O3 at R K Puram is natively verified metadata
  expect_equal(convert_hourly_to_canonical_unit(50, "o3", "µg/m³", 12234785), 50)
  
  # NO2/SO2/CO at R K Puram lack counterparts, so they should block conversion
  expect_true(is.na(convert_hourly_to_canonical_unit(80, "no2", "ppb", 12234784)))
  expect_true(is.na(convert_hourly_to_canonical_unit(40, "so2", "ppb", 12234789)))
  expect_true(is.na(convert_hourly_to_canonical_unit(1.2, "co", "ppb", 12234782)))
  
  # Negative concentration check
  expect_true(is.na(convert_hourly_to_canonical_unit(-5, "o3", "µg/m³", 12234785)))
})

test_that("23. diagnostic test placeholder fixed", {
  df <- read.csv("data/metadata/phase2D1_project_aqi_diagnostic_sample.csv")
  expect_true(nrow(df) > 0)
  expect_true("co_source_unit_reported" %in% names(df))
  expect_true("co_canonical_unit" %in% names(df))
  expect_equal(df$o3_source_unit[1], "µg/m³")
  expect_equal(df$o3_canonical_unit[1], "µg/m³")
})

test_that("22. official worked example test", {
  # Actual verifiable official example from CPCB NAQI Report (pg 39)
  # PM10 = 120 -> 113, PM2.5 = 150 -> 322, NO2 = 80 -> 100, O3 = 100 -> 100, CO = 2.0 -> 100
  bp <- load_verified_breakpoints()
  sub_pm10 <- calculate_pollutant_subindex(120, "pm10", bp)
  sub_pm25 <- calculate_pollutant_subindex(150, "pm2_5", bp)
  sub_no2 <- calculate_pollutant_subindex(80, "no2", bp)
  sub_o3 <- calculate_pollutant_subindex(100, "o3", bp, is_1hr = FALSE)
  sub_co <- calculate_pollutant_subindex(2.0, "co", bp)
  
  expect_equal(sub_pm10, 113)
  expect_equal(sub_pm25, 322)
  expect_equal(sub_no2, 100)
  expect_equal(sub_o3, 100)
  expect_equal(sub_co, 100)
  
  # Overall AQI = 322
  aqi <- calculate_daily_indian_aqi(c(pm10=sub_pm10, pm2_5=sub_pm25, no2=sub_no2, o3=sub_o3, co=sub_co), TRUE)
  expect_equal(aqi$aqi_display, 322)
})

test_that('26. Verify Category / Severe Edge Cases', {
  bp <- load_verified_breakpoints()
  aqi431 <- calculate_pollutant_subindex(431, 'pm10', bp)
  expect_equal(aqi431, 400)
  
  o3_sev <- calculate_pollutant_subindex(749, 'o3', bp, is_1hr = TRUE)
  expect_equal(o3_sev, 400)
  
  pm25_sev <- calculate_pollutant_subindex(251, 'pm2_5', bp)
  expect_equal(pm25_sev, 400)
})
