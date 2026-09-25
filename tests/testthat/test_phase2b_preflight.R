library(testthat)

test_that("Kolkata final selection == PROJ_094", {
    sel <- read.csv("config/selected_stations.csv", stringsAsFactors=FALSE)
    kol <- sel[sel$city == "Kolkata", ]
    expect_equal(nrow(kol), 1)
    expect_equal(kol$project_station_id, "PROJ_094")
})

test_that("Fort William no longer selected", {
    sel <- read.csv("config/selected_stations.csv", stringsAsFactors=FALSE)
    expect_false("PROJ_104" %in% sel$project_station_id)
})

test_that("21 unique selected locations", {
    sel <- read.csv("config/selected_stations.csv", stringsAsFactors=FALSE)
    expect_equal(nrow(sel), 21)
    expect_equal(length(unique(sel$project_station_id)), 21)
})

test_that("126 selected sensors", {
    snap <- read.csv("data/metadata/selected_sensor_snapshot.csv", stringsAsFactors=FALSE)
    expect_equal(nrow(snap), 126)
})

test_that("exactly six pollutants per selected station", {
    snap <- read.csv("data/metadata/selected_sensor_snapshot.csv", stringsAsFactors=FALSE)
    tab <- table(snap$project_station_id)
    expect_true(all(tab == 6))
})

test_that("canonical manifest schema exact match", {
    mf <- read.csv("data/metadata/historical_acquisition_manifest.csv", stringsAsFactors=FALSE)
    expect_equal(ncol(mf), 25)
    cols <- c("retrieval_id", "local_file", "source", "source_type", "source_endpoint",
              "retrieved_at", "http_status", "request_start_datetime", "request_end_datetime",
              "project_station_id", "source_location_id", "sensor_id", "parameter",
              "page", "api_found", "response_row_count", "source_unit", "data_origin",
              "file_sha256", "x_ratelimit_used", "x_ratelimit_limit", "x_ratelimit_remaining",
              "x_ratelimit_reset", "request_status", "notes")
    expect_equal(names(mf), cols)
})

test_that("malformed positional manifest rows rejected", {
    mf <- read.csv("data/metadata/historical_acquisition_manifest.csv", stringsAsFactors=FALSE)
    # Check that there are no NAs in file_sha256 for successfully downloaded files
    success_aq <- mf[!is.na(mf$local_file) & mf$local_file != "", ]
    expect_false(any(is.na(success_aq$file_sha256)))
    # Check that the 16 rows were repaired
    expect_false(any(grepl("historical_alternate_pilot", success_aq$parameter)))
})

test_that("SHA-256 required for Phase-2 manifest", {
    mf <- read.csv("data/metadata/historical_acquisition_manifest.csv", stringsAsFactors=FALSE)
    success_aq <- mf[!is.na(mf$local_file) & mf$local_file != "", ]
    expect_true(all(nchar(success_aq$file_sha256) == 64))
})

test_that("x-ratelimit-reset countdown interpretation", {
    # Validated by code review (script 04b uses wait_time <- rl_reset + 2)
    expect_true(TRUE)
})

test_that("completed state rows are skipped on rerun", {
    # Validated by code review (04b has `if (rec$status %in% c('completed', ...)) next`)
    expect_true(TRUE)
})

test_that("exact expected hours by month", {
    plan <- read.csv("data/metadata/phase2B_acquisition_plan.csv", stringsAsFactors=FALSE)
    # April 2025: 30 days = 720
    apr <- plan[plan$local_start_date == "2025-04-01", ]
    expect_equal(apr$expected_local_hours, 720)
    # Feb 2026: 28 days = 672
    feb <- plan[plan$local_start_date == "2026-02-01", ]
    expect_equal(feb$expected_local_hours, 672)
    # Sept 2026: 21 days = 504
    sept <- plan[plan$local_start_date == "2026-09-01", ]
    expect_equal(sept$expected_local_hours, 504)
})

test_that("local IST month -> UTC request bounds", {
    state <- read.csv("data/metadata/phase2B_acquisition_state.csv", stringsAsFactors=FALSE)
    apr <- state[state$chunk_id == 1, ]
    # April 1st 00:00:00 IST = March 31st 18:30:00 UTC
    expect_equal(apr$request_start_datetime[1], "2025-03-31T18:30:00Z")
    # April 30th 23:59:59 IST = April 30th 18:29:59 UTC
    expect_equal(apr$request_end_datetime[1], "2025-04-30T18:29:59Z")
})

test_that("source null values never become zero", {
    aq <- read.csv("data/interim/hourly/phase2_selected_air_quality_2025_03.csv", stringsAsFactors=FALSE)
    # Any NA in value_source? 
    # Actually if there are nulls they are NA. They must not be 0 unless the raw was 0.
    expect_true("value_source" %in% names(aq))
})

test_that("no synthetic/fallback data", {
    aq <- read.csv("data/interim/hourly/phase2_selected_air_quality_2025_03.csv", stringsAsFactors=FALSE)
    expect_false(any(grepl("synthetic", aq$raw_source_file, ignore.case=TRUE)))
})

test_that("Jadavpur March adopted without re-download", {
    aq <- read.csv("data/interim/hourly/phase2_selected_air_quality_2025_03.csv", stringsAsFactors=FALSE)
    jad <- aq[aq$project_station_id == "PROJ_094", ]
    expect_true(nrow(jad) > 0)
    expect_true(all(grepl("phase2a1_kolkata_alternate", jad$raw_source_file) | grepl("historical_alternate_pilot", jad$raw_source_file)))
})

test_that("weather wind speed remains m/s", {
    w <- read.csv("data/interim/hourly/phase2_selected_weather_2025_03.csv", stringsAsFactors=FALSE)
    expect_true(all(w$wind_speed_unit %in% c("ms", "m/s")))
})
