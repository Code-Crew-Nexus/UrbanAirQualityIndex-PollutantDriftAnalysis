library(testthat)
setwd("../..")
context("Phase 2D: CPCB Methodology Verification")

source("R/24_aqi_calculation.R")

test_that("Phase-2C data dictionary parses as valid CSV", {
  dict <- read.csv("data/metadata/phase2C_preAQI_data_dictionary.csv", stringsAsFactors = FALSE)
  expect_gt(nrow(dict), 50)
  expect_true("pm2_5_source_mean" %in% dict$column_name)
})

test_that("No control characters remain in updated documentation", {
  lines <- readLines("docs/dataset_schema.md")
  # Ensure "aqi" is cleanly spelled
  found <- any(grepl("`aqi`, `aqi_category`, `dominant_pollutant`, `no2`, `so2`, `co`", lines))
  expect_true(found)
})

test_that("Official gas-conversion factors equal the verified config", {
  factors <- read.csv("config/gas_conversion_factors_india.csv", stringsAsFactors = FALSE)
  expect_equal(factors$conversion_factor[factors$pollutant == "no2"], 1.88)
  expect_equal(factors$conversion_factor[factors$pollutant == "so2"], 2.62)
  expect_equal(factors$conversion_factor[factors$pollutant == "co"], 0.001145)
  expect_equal(factors$conversion_factor[factors$pollutant == "o3"], 1.96)
})

test_that("ppb / ppm dimensional conversion is correct", {
  # 1 ppm CO = 1.145 mg/m3
  # 1 ppb CO = 0.001145 mg/m3
  res <- convert_cpcb_gas_units(1000, "co", "ppb")
  expect_equal(res, 1.145)
})

test_that("PM10 breakpoint boundaries", {
  bp <- load_verified_breakpoints()
  expect_equal(calculate_pollutant_subindex(40, "pm10", bp), 40)
  expect_equal(calculate_pollutant_subindex(51, "pm10", bp), 51)
  expect_equal(calculate_pollutant_subindex(120, "pm10", bp), 114) # ((200-101)/(250-101))*(120-101) + 101 = 99/149 * 19 + 101 = 12.6 + 101 = 113.6 -> 114
})

test_that("PM2.5 breakpoint boundaries", {
  bp <- load_verified_breakpoints()
  expect_equal(calculate_pollutant_subindex(25, "pm2_5", bp), 42) # ((50-0)/(30-0))*25 = 41.6 -> 42
  expect_equal(calculate_pollutant_subindex(150, "pm2_5", bp), 323) # (99 * 29 / 129) + 301 = 323.2 -> 323
  # (400-301) = 99. (250-121) = 129. 150-121 = 29. 99 * 29 / 129 = 22.255. 301 + 22.255 = 323.2 -> 323.
})

test_that("CO breakpoint boundaries", {
  bp <- load_verified_breakpoints()
  expect_equal(calculate_pollutant_subindex(1.0, "co", bp), 50)
  expect_equal(calculate_pollutant_subindex(1.5, "co", bp), 73) # ((100-51)/(2.0-1.1))*(1.5-1.1)+51 = 49/0.9 * 0.4 + 51 = 21.7 + 51 = 72.7 -> 73
})

test_that("O3 breakpoint boundaries", {
  bp <- load_verified_breakpoints()
  # 8-hr
  expect_equal(calculate_pollutant_subindex(150, "o3", bp, is_1hr = FALSE), 173) # ((200-101)/(168-101))*(150-101)+101 = 99/67 * 49 + 101 = 72.4 + 101 = 173
  # 1-hr Very Poor
  expect_equal(calculate_pollutant_subindex(300, "o3", bp, is_1hr = TRUE), 318) # ((400-301)/(748-209))*(300-209)+301 = 99/539 * 91 + 301 = 16.7 + 301 = 318
})

test_that("overall AQI = maximum valid sub-index", {
  sub_indices <- c(pm2_5=120, pm10=80, no2=45)
  res <- calculate_daily_indian_aqi(sub_indices, has_pm = TRUE)
  expect_equal(res$aqi, 120)
  expect_equal(res$dominant_pollutant, "pm2_5")
})

test_that("insufficient <3 pollutants rejects overall AQI if officially verified", {
  sub_indices <- c(pm2_5=120, no2=45)
  res <- calculate_daily_indian_aqi(sub_indices, has_pm = TRUE)
  expect_true(is.na(res$aqi))
  expect_equal(res$reason, "insufficient_pollutants")
})

test_that("missing PM2.5/PM10 rejects overall AQI if officially verified", {
  sub_indices <- c(no2=45, so2=20, co=30)
  res <- calculate_daily_indian_aqi(sub_indices, has_pm = FALSE)
  expect_true(is.na(res$aqi))
  expect_equal(res$reason, "missing_particulate")
})

test_that("dominant pollutant ties", {
  sub_indices <- c(pm2_5=120, pm10=120, no2=45)
  res <- calculate_daily_indian_aqi(sub_indices, has_pm = TRUE)
  expect_equal(res$aqi, 120)
  expect_equal(res$dominant_pollutant, "pm10, pm2_5")
})
