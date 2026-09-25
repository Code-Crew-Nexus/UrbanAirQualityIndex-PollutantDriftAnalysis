library(testthat)
setwd("../..")
context("Phase 2D.3: Paired-Sensor Unit Reconciliation")

source("R/24_aqi_calculation.R")

test_that("1. sensor-level provenance has 126 rows and 2. unique sensor_id", {
  df <- read.csv("data/metadata/phase2D3_sensor_semantic_units.csv", stringsAsFactors=FALSE)
  expect_equal(nrow(df), 126)
  expect_equal(length(unique(df$sensor_id)), 126)
})

test_that("3. reported unit preserved and 4. verified method is explicit", {
  df <- read.csv("data/metadata/phase2D3_sensor_semantic_units.csv", stringsAsFactors=FALSE)
  expect_true(all(!is.na(df$openaq_reported_unit)))
  expect_true(all(df$verification_method %in% c("PAIRED_OPENAQ_SENSOR", "CANONICAL_METADATA", "NO_COUNTERPART", "PAIRED_OPENAQ_SENSOR_CONTROL")))
})

test_that("12. O3 mass pass-through and 13. unresolved blocks", {
  # Assuming 12234785 is O3 at R K Puram
  val <- convert_hourly_to_canonical_unit(50, "o3", "µg/m³", 12234785)
  expect_equal(val, 50)
  
  # Negative concentration invalid
  val_neg <- convert_hourly_to_canonical_unit(-10, "o3", "µg/m³", 12234785)
  expect_true(is.na(val_neg))
})

test_that("19. source_unit_verified no longer globally NA and 20. status not pending", {
  dist <- read.csv("data/metadata/phase2D3_source_unit_distribution.csv", stringsAsFactors=FALSE)
  # For VERIFIED sensors, source_unit_verified shouldn't be NA
  ver <- dist[dist$canonical_conversion_status %in% c("canonical_pass_through", "conversion_ready"), ]
  if (nrow(ver) > 0) {
    expect_true(all(!is.na(ver$source_unit_verified)))
  }
  expect_true(all(dist$canonical_conversion_status != "pending"))
})

test_that("27. Official Worked Example Traceability check", {
  # pg 39 of National Air Quality Index (2014) report
  # The inputs are PM10=120, PM2.5=150, NO2=80, O3=100, CO=2.0
  # Expected AQI = 322 (PM2.5)
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
})
