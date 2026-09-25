source("R/00_setup.R")
source("R/01_utils.R")
source("R/11_station_coverage_audit.R")

test_that("summarize_coverage handles Date and POSIXct equivalently", {
  audit_date <- as.Date("2026-09-24")
  audit_posix <- as.POSIXct("2026-09-24 23:59:59", tz="Asia/Kolkata")
  
  start_date <- audit_date - 29
  start_posix <- audit_posix - (29 * 86400)
  
  dummy_res <- list(
    list(
      period = list(datetimeFrom = list(local = "2026-09-01T00:00:00+05:30")),
      coverage = list(percentComplete = 100, percentCoverage = 100)
    )
  )
  
  out_date <- summarize_coverage(dummy_res, start_date, audit_date)
  out_posix <- summarize_coverage(dummy_res, start_posix, audit_posix)
  
  expect_equal(out_date, out_posix)
  expect_equal(out_date$distinct_valid_dates, 1)
})

test_that("summarize_coverage returns 90% for 27 valid days in 30 day window", {
  # 27 unique dates
  dates <- format(seq(as.Date("2026-08-26"), by="day", length.out=27), "%Y-%m-%dT00:00:00+05:30")
  dummy_res <- lapply(dates, function(d) {
    list(
      period = list(datetimeFrom = list(local = d)),
      coverage = list(percentComplete = 100, percentCoverage = 100)
    )
  })
  
  out <- summarize_coverage(dummy_res, as.Date("2026-08-26"), as.Date("2026-09-24"))
  expect_equal(out$distinct_valid_dates, 27)
  expect_equal(out$days_with_data_pct, 90)
})

test_that("pollutant canonical name normalization", {
  expect_equal(map_pollutant_name("pm25"), "pm2_5")
  expect_equal(map_pollutant_name("PM2.5"), "pm2_5")
  expect_equal(map_pollutant_name("pm2_5"), "pm2_5")
})

test_that("canonical units", {
  expect_equal(get_canonical_unit("pm25"), "µg/m³")
  expect_equal(get_canonical_unit("CO"), "mg/m³")
  expect_equal(get_canonical_unit("wind_speed"), "m/s")
})

test_that("manifest physical file parity", {
  mf <- read.csv("data/metadata/raw_data_manifest.csv", stringsAsFactors=F)
  files <- list.files("data/raw", recursive=TRUE, pattern="\\.(json|csv)$")
  expect_equal(nrow(mf), length(files))
})

test_that("No hard-coded (Estimated) in historical window options", {
  hw <- read.csv("data/metadata/historical_window_options.csv", stringsAsFactors=F)
  expect_false(any(grepl("Estimated", hw$start_date)))
})
test_that('All six core pollutants appear in lineage', {
  sl <- read.csv('data/metadata/sensor_lineage_summary.csv', stringsAsFactors=F)
  polls <- unique(sl$parameter)
  expect_true(all(c('pm2_5', 'pm10', 'no2', 'so2', 'co', 'o3') %in% polls))
})

test_that('Hyderabad decision pack is not limited to national 3-station shortlist', {
  hp <- read.csv('data/metadata/hyderabad_selection_decision_pack.csv', stringsAsFactors=F)
  expect_gt(nrow(hp), 3)
})
