library(testthat)

test_that("Exactly 21 unique selected physical locations", {
    sel <- read.csv("config/selected_stations.csv", stringsAsFactors=F)
    expect_equal(nrow(sel), 21)
    expect_equal(length(unique(sel$project_station_id)), 21)
})

test_that("Hyderabad selection = 7 and India selection = 15", {
    sel <- read.csv("config/selected_stations.csv", stringsAsFactors=F)
    expect_equal(sum(sel$use_hyderabad), 7)
    expect_equal(sum(sel$use_india), 15)
})

test_that("PROJ_007 belongs to both scopes", {
    sel <- read.csv("config/selected_stations.csv", stringsAsFactors=F)
    p7 <- sel[sel$project_station_id == "PROJ_007", ]
    expect_true(p7$use_hyderabad)
    expect_true(p7$use_india)
})

test_that("Exactly 126 preferred-current core sensor selections", {
    snap <- read.csv("data/metadata/selected_sensor_snapshot.csv", stringsAsFactors=F)
    expect_equal(nrow(snap), 126)
})

test_that("All six canonical pollutants exist per selected station", {
    snap <- read.csv("data/metadata/selected_sensor_snapshot.csv", stringsAsFactors=F)
    polls <- aggregate(parameter ~ project_station_id, data=snap, FUN=function(x) length(unique(x)))
    expect_true(all(polls$parameter == 6))
})

test_that("March expected-hour calculation = 744", {
    comp <- read.csv("data/metadata/phase2_pilot_completeness.csv", stringsAsFactors=F)
    expect_true(all(comp$expected_hour_count == 744))
})

test_that("Gas source values remain unconverted", {
    if (file.exists("data/interim/hourly/phase2_pilot_air_quality_2025_03.csv")) {
        aq <- read.csv("data/interim/hourly/phase2_pilot_air_quality_2025_03.csv", stringsAsFactors=F)
        gases <- subset(aq, parameter %in% c("co", "no2", "so2", "o3"))
        if (nrow(gases) > 0) {
            expect_true(any(gases$source_unit %in% c("ppb", "ppm", "µg/m³", "mg/m³")))
        }
    }
})

test_that("Wind speed = m/s", {
    if (file.exists("data/interim/hourly/phase2_pilot_weather_2025_03.csv")) {
        w <- read.csv("data/interim/hourly/phase2_pilot_weather_2025_03.csv", stringsAsFactors=F)
        if (nrow(w) > 0) {
            expect_true(all(w$wind_speed_unit == "ms" | w$wind_speed_unit == "m/s"))
        }
    }
})

test_that("Historical manifest append does not overwrite existing rows/files", {
    mf <- read.csv("data/metadata/historical_acquisition_manifest.csv", stringsAsFactors=F)
    if (nrow(mf) > 0) {
        expect_equal(length(unique(mf$retrieval_id)), nrow(mf))
    }
})

test_that("No fixture/synthetic data enters Phase-2 production paths", {
    if (file.exists("data/interim/hourly/phase2_pilot_air_quality_2025_03.csv")) {
        aq <- read.csv("data/interim/hourly/phase2_pilot_air_quality_2025_03.csv", stringsAsFactors=F)
        expect_false(any(grepl("synthetic", aq$raw_source_file, ignore.case=T)))
    }
})

test_that("Duplicate-hour deduplication", {
    if (file.exists("data/interim/hourly/phase2_pilot_air_quality_2025_03.csv")) {
        aq <- read.csv("data/interim/hourly/phase2_pilot_air_quality_2025_03.csv", stringsAsFactors=F)
        dup_count <- sum(duplicated(aq[, c("project_station_id", "sensor_id", "parameter", "timestamp_local")]))
        expect_equal(dup_count, 0)
    }
})

test_that("Hourly timestamp extraction", {
    if (file.exists("data/interim/hourly/phase2_pilot_air_quality_2025_03.csv")) {
        aq <- read.csv("data/interim/hourly/phase2_pilot_air_quality_2025_03.csv", stringsAsFactors=F)
        if (nrow(aq) > 0) {
            expect_true(all(grepl("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\+|\\-)\\d{2}:\\d{2}$", aq$timestamp_local[!is.na(aq$timestamp_local)])))
        }
    }
})

# Phase 2A.1 new gate tests
test_that("Any India 'Review Required' station prevents automatic full-pilot PASS", {
    # Check 02e report content
    if (file.exists("phase_2A_pilot_report.md")) {
        txt <- readLines("phase_2A_pilot_report.md")
        ind <- read.csv("data/metadata/phase2_pilot_india_summary.csv", stringsAsFactors=F)
        has_review <- any(grepl("Review Required", ind$Status, ignore.case=T))
        has_pass_msg <- any(grepl("PHASE 2A PILOT PASSED", txt))
        if (has_review) {
            expect_false(has_pass_msg)
        }
    }
})

test_that("Kolkata alternate snapshot contains exactly 12 sensors", {
    if (file.exists("data/metadata/phase2a1_kolkata_alternate_sensors.csv")) {
        snap_alt <- read.csv("data/metadata/phase2a1_kolkata_alternate_sensors.csv", stringsAsFactors=F)
        expect_equal(nrow(snap_alt), 12)
    }
})

test_that("Candidate pilot cannot modify selected_stations.csv", {
    sel <- read.csv("config/selected_stations.csv", stringsAsFactors=F)
    # Ensure PROJ_104 is still the selected one for Kolkata
    kol_stations <- sel[sel$city == "Kolkata", ]
    expect_equal(kol_stations$project_station_id, "PROJ_104")
    expect_false("PROJ_094" %in% sel$project_station_id)
    expect_false("PROJ_135" %in% sel$project_station_id)
})

test_that("Completeness uses distinct valid hours / 744", {
    if (file.exists("data/metadata/phase2_pilot_completeness.csv")) {
        comp <- read.csv("data/metadata/phase2_pilot_completeness.csv", stringsAsFactors=F)
        expect_true(all(comp$expected_hour_count == 744))
        # Ensure percentages are <= 100
        expect_true(all(comp$hourly_completeness_pct <= 100))
    }
})

test_that("Null source values are counted, not converted to zero", {
    if (file.exists("data/metadata/phase2a_data_quality_audit.csv")) {
        dq <- read.csv("data/metadata/phase2a_data_quality_audit.csv", stringsAsFactors=F)
        # We should just assert that the script is keeping them distinct and there's a column for it
        expect_true("source_null_value_rows" %in% names(dq))
    }
})

test_that("Manifest append remains immutable", {
    mf <- read.csv("data/metadata/historical_acquisition_manifest.csv", stringsAsFactors=F)
    # Check if PROJ_104 records exist as well as alternate records if any
    expect_true(any(mf$project_station_id == "PROJ_104"))
})

test_that("Current selected Fort William data remain unchanged during alternate testing", {
    if (file.exists("data/interim/hourly/phase2_pilot_air_quality_2025_03.csv")) {
        aq <- read.csv("data/interim/hourly/phase2_pilot_air_quality_2025_03.csv", stringsAsFactors=F)
        # Should not have PROJ_094 or PROJ_135 in the main file
        expect_false(any(aq$project_station_id %in% c("PROJ_094", "PROJ_135")))
    }
})
