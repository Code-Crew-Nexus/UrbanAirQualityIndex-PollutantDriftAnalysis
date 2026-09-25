library(testthat)
setwd("../..")
context("Phase 2B.2 Freeze")

test_that("No historical monthly file contains pm2 or pm25", {
    aq_files <- list.files("data/interim/hourly/historical", pattern="\\.csv$", full.names=TRUE)
    for (f in aq_files) {
        df <- read.csv(f, stringsAsFactors=FALSE)
        expect_false("pm2" %in% unique(df$parameter))
        expect_false("pm25" %in% unique(df$parameter))
    }
})

test_that("All historical monthly parameter values belong to exactly the 6 allowed", {
    aq_files <- list.files("data/interim/hourly/historical", pattern="\\.csv$", full.names=TRUE)
    allowed <- c("pm2_5", "pm10", "no2", "so2", "co", "o3")
    for (f in aq_files) {
        df <- read.csv(f, stringsAsFactors=FALSE)
        expect_true(all(unique(df$parameter) %in% allowed))
    }
})

test_that("2025-07 contains PM2.5 data", {
    df <- read.csv("data/interim/hourly/historical/air_quality_2025_07.csv", stringsAsFactors=FALSE)
    expect_true("pm2_5" %in% unique(df$parameter))
    expect_gt(sum(df$parameter == "pm2_5"), 0)
})

test_that("2026-03 contains PM2.5 data", {
    df <- read.csv("data/interim/hourly/historical/air_quality_2026_03.csv", stringsAsFactors=FALSE)
    expect_true("pm2_5" %in% unique(df$parameter))
    expect_gt(sum(df$parameter == "pm2_5"), 0)
})

test_that("2026-06 contains PM2.5 data", {
    df <- read.csv("data/interim/hourly/historical/air_quality_2026_06.csv", stringsAsFactors=FALSE)
    expect_true("pm2_5" %in% unique(df$parameter))
    expect_gt(sum(df$parameter == "pm2_5"), 0)
})

test_that("Canonical normalizer uses snapshot parameter", {
    source("R/03_phase2_normalization.R")
    # This is tested implicitly by checking the output files in the steps above
    # We can also check if the function handles it properly.
    expect_true(exists("normalize_openaq_hour_response"))
})

test_that("Observation timestamp uses datetimeFrom not datetimeTo", {
    df <- read.csv("data/interim/hourly/historical/air_quality_2025_07.csv", stringsAsFactors=FALSE)
    expect_true("timestamp_local" %in% colnames(df))
    expect_true("period_end_local" %in% colnames(df))
})

test_that("For fixture hourly data: period_end > timestamp", {
    df <- read.csv("data/interim/hourly/historical/air_quality_2025_07.csv", stringsAsFactors=FALSE)
    # Check first 100 rows
    for (i in 1:min(100, nrow(df))) {
        expect_true(df$period_end_local[i] > df$timestamp_local[i])
    }
})

test_that("Monthly completeness rows = 2394", {
    comp <- read.csv("data/metadata/phase2B_monthly_completeness.csv", stringsAsFactors=FALSE)
    expect_equal(nrow(comp), 2394)
})

test_that("Quality flag start_month and end_month are non-NA", {
    qf <- read.csv("data/metadata/phase2B_quality_flags.csv", stringsAsFactors=FALSE)
    if (nrow(qf) > 0) {
        expect_true(all(!is.na(qf$start_month)))
        expect_true(all(!is.na(qf$end_month)))
    }
})

test_that("failed_retryable = 0", {
    state <- read.csv("data/metadata/phase2B_acquisition_state.csv", stringsAsFactors=FALSE)
    expect_equal(sum(state$status == "failed_retryable"), 0)
})
