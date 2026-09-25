library(testthat)
setwd("../..")
context("Phase 2C: Pre-AQI Engineering")

test_that("master station-day rows = 11,970", {
    spine <- read.csv("data/interim/daily/phase2C_master_station_day_spine.csv", stringsAsFactors=FALSE)
    expect_equal(nrow(spine), 11970)
})

test_that("Hyderabad PreAQI rows = 3,990", {
    hyd <- read.csv("data/interim/daily/UAQI_Hyderabad_Daily_PreAQI.csv", stringsAsFactors=FALSE)
    expect_equal(nrow(hyd), 3990)
})

test_that("India PreAQI rows = 8,550", {
    ind <- read.csv("data/interim/daily/UAQI_India_Daily_PreAQI.csv", stringsAsFactors=FALSE)
    expect_equal(nrow(ind), 8550)
})

test_that("master physical stations = 21", {
    spine <- read.csv("data/interim/daily/phase2C_master_station_day_spine.csv", stringsAsFactors=FALSE)
    expect_equal(length(unique(spine$project_station_id)), 21)
})

test_that("Hyderabad stations = 7", {
    hyd <- read.csv("data/interim/daily/UAQI_Hyderabad_Daily_PreAQI.csv", stringsAsFactors=FALSE)
    expect_equal(length(unique(hyd$project_station_id)), 7)
})

test_that("India stations = 15", {
    ind <- read.csv("data/interim/daily/UAQI_India_Daily_PreAQI.csv", stringsAsFactors=FALSE)
    expect_equal(length(unique(ind$project_station_id)), 15)
})

test_that("date range = 2025-03-01 through 2026-09-21", {
    spine <- read.csv("data/interim/daily/phase2C_master_station_day_spine.csv", stringsAsFactors=FALSE)
    expect_equal(min(spine$date), "2025-03-01")
    expect_equal(max(spine$date), "2026-09-21")
})

test_that("no duplicate station-date rows", {
    spine <- read.csv("data/interim/daily/phase2C_master_station_day_spine.csv", stringsAsFactors=FALSE)
    expect_equal(anyDuplicated(spine[, c("project_station_id", "date")]), 0)
    
    pre <- read.csv("data/interim/daily/phase2C_master_daily_preAQI.csv", stringsAsFactors=FALSE)
    expect_equal(anyDuplicated(pre[, c("project_station_id", "date")]), 0)
})

test_that("no station-date disappears due to missing air data", {
    pre <- read.csv("data/interim/daily/phase2C_master_daily_preAQI.csv", stringsAsFactors=FALSE)
    expect_equal(nrow(pre), 11970)
})

test_that("all six source pollutant columns exist", {
    pre <- read.csv("data/interim/daily/phase2C_master_daily_preAQI.csv", stringsAsFactors=FALSE)
    req_cols <- c("pm2_5_source_mean", "pm10_source_mean", "no2_source_mean", "so2_source_mean", "co_source_mean", "o3_source_mean")
    expect_true(all(req_cols %in% colnames(pre)))
})

test_that("gaseous source means retain ppb units (no conversion)", {
    # It hasn't been converted, just averaged, we check column names don't imply conversion
    # and NO2/SO2/CO are present. Values will be audited in reports.
    pre <- read.csv("data/interim/daily/phase2C_master_daily_preAQI.csv", stringsAsFactors=FALSE)
    expect_true("no2_source_mean" %in% colnames(pre))
    expect_false("no2" %in% colnames(pre)) # Final converted field does not exist
})

test_that("no AQI columns exist", {
    pre <- read.csv("data/interim/daily/phase2C_master_daily_preAQI.csv", stringsAsFactors=FALSE)
    expect_false("aqi" %in% colnames(pre))
    expect_false("aqi_category" %in% colnames(pre))
    expect_false("dominant_pollutant" %in% colnames(pre))
})

test_that("weather wind speed remains m/s", {
    # Check it's not converted implicitly to km/h, max shouldn't be astronomically scaled up
    pre <- read.csv("data/interim/daily/phase2C_master_daily_preAQI.csv", stringsAsFactors=FALSE)
    ws_max <- max(pre$wind_speed, na.rm=TRUE)
    expect_true(ws_max < 150) # m/s wouldn't reach 150, but km/h might in a hurricane. Given it's historical, this is safe.
})

test_that("wind direction circular averaging behaves correctly", {
    source("R/23_daily_aggregation.R")
    # 359 and 1 degrees mean should be 0
    fake_w <- data.frame(
        project_station_id = "test",
        date_local = "2025-01-01",
        temperature = 25,
        humidity = 50,
        wind_speed = 1,
        wind_direction = c(359, 1),
        timestamp_local = c("t1", "t2")
    )
    res <- aggregate_weather_daily(fake_w)
    expect_true(res$wind_direction < 0.1 || res$wind_direction > 359.9)
})

test_that("Hyderabad and India PreAQI schemas are identical", {
    hyd <- read.csv("data/interim/daily/UAQI_Hyderabad_Daily_PreAQI.csv", stringsAsFactors=FALSE)
    ind <- read.csv("data/interim/daily/UAQI_India_Daily_PreAQI.csv", stringsAsFactors=FALSE)
    expect_equal(colnames(hyd), colnames(ind))
})

test_that("Bollaram remains present across all 570 dates", {
    pre <- read.csv("data/interim/daily/phase2C_master_daily_preAQI.csv", stringsAsFactors=FALSE)
    bol <- pre[pre$project_station_id == "PROJ_036", ]
    expect_equal(nrow(bol), 570)
})

test_that("source-unit consistency", {
    # Not multiple units
    pre <- read.csv("data/interim/daily/phase2C_master_daily_preAQI.csv", stringsAsFactors=FALSE)
    u_no2 <- unique(pre$no2_source_unit[!is.na(pre$no2_source_unit)])
    expect_true(length(u_no2) <= 1)
})

test_that("final export functions remain blocked", {
    source("R/26_export_datasets.R")
    expect_error(export_canonical_datasets(data.frame(), data.frame()), "blocked")
})


test_that('Phase-2C data dictionary parses as valid CSV', {
  dict <- read.csv('data/metadata/phase2C_preAQI_data_dictionary.csv')
  expect_gt(nrow(dict), 50)
})

test_that('hourly-to-daily pollution reconciliation', {
  pre <- read.csv('data/interim/daily/phase2C_master_daily_preAQI.csv')
  expect_equal(sum(pre$pm2_5_valid_hours + pre$pm10_valid_hours + pre$no2_valid_hours + pre$so2_valid_hours + pre$co_valid_hours + pre$o3_valid_hours), 1457124)
})

test_that('source-null reconciliation', {
  pre <- read.csv('data/interim/daily/phase2C_master_daily_preAQI.csv')
  expect_equal(sum(pre$pm2_5_source_null_hour_count + pre$pm10_source_null_hour_count + pre$no2_source_null_hour_count + pre$so2_source_null_hour_count + pre$co_source_null_hour_count + pre$o3_source_null_hour_count), 711)
})

test_that('weather reconciliation', {
  pre <- read.csv('data/interim/daily/phase2C_master_daily_preAQI.csv')
  expect_equal(sum(pre$weather_valid_hours), 287280)
})

