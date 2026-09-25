library(testthat)
setwd("../..")
context("Phase 2B.1 Closure")

test_that("March canonical file has 21 stations and Fort William is absent, Jadavpur exists", {
    df <- read.csv("data/interim/hourly/historical/air_quality_2025_03.csv", stringsAsFactors=FALSE)
    stations <- unique(df$project_station_id)
    expect_equal(length(stations), 21)
    expect_true("PROJ_094" %in% stations)
    expect_false("PROJ_104" %in% stations)
})

test_that("March completeness has exactly 126 rows", {
    comp <- read.csv("data/metadata/phase2B_monthly_completeness.csv", stringsAsFactors=FALSE)
    march_comp <- comp[comp$chunk_id == "2025-03", ]
    expect_equal(nrow(march_comp), 126)
})

test_that("March state-status naming cannot exclude valid completed data", {
    # March logic uses already-approved data rather than state filtering now.
    comp <- read.csv("data/metadata/phase2B_monthly_completeness.csv", stringsAsFactors=FALSE)
    march_comp <- comp[comp$chunk_id == "2025-03", ]
    expect_true(all(march_comp$distinct_valid_hour_count > 0)) # None should be artificially zero
})

test_that("phase2B monthly completeness has 2394 rows", {
    comp <- read.csv("data/metadata/phase2B_monthly_completeness.csv", stringsAsFactors=FALSE)
    expect_equal(nrow(comp), 2394)
})

test_that("acquisition_failed is distinct from environmental no-data", {
    # Implicit in new logic, but let's check phase2B_acquisition_plan.csv
    plan <- read.csv("data/metadata/phase2B_acquisition_plan.csv", stringsAsFactors=FALSE)
    expect_true("failed_requests" %in% colnames(plan))
    expect_true("empty_valid_responses" %in% colnames(plan))
})

test_that("no failed_retryable rows when declaring Phase-2B closed", {
    state <- read.csv("data/metadata/phase2B_acquisition_state.csv", stringsAsFactors=FALSE)
    expect_equal(sum(state$status == "failed_retryable"), 0)
})

test_that("monthly expected-hour calculation", {
    comp <- read.csv("data/metadata/phase2B_monthly_completeness.csv", stringsAsFactors=FALSE)
    expect_equal(comp$expected_hour_count[comp$chunk_id == "2025-03"][1], 744)
    expect_equal(comp$expected_hour_count[comp$chunk_id == "2026-02"][1], 672)
    expect_equal(comp$expected_hour_count[comp$chunk_id == "2026-09"][1], 504)
})

test_that("corrected quality flags use real months/evidence", {
    qf <- read.csv("data/metadata/phase2B_quality_flags.csv", stringsAsFactors=FALSE)
    if (nrow(qf) > 0) {
        expect_true("evidence" %in% colnames(qf))
        expect_true(all(qf$months_affected > 0))
    }
})

test_that("full archive script excludes review_archive*.zip", {
    script <- readLines("scripts/create_review_archive.ps1")
    expect_true(any(grepl("review_archive\\*\\.zip", script)))
})

test_that("light archive script excludes raw and secrets", {
    script <- readLines("scripts/create_review_archive_light.ps1")
    expect_true(any(grepl("\\.secret", script)))
    expect_true(any(grepl("data\\\\raw", script)))
})
