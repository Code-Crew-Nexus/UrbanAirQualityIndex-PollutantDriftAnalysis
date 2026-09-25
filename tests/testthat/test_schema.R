setwd(Sys.getenv("PROJ_ROOT", "."))
# test_schema.R: Unit tests for dataset schema and QC validation

source("R/01_utils.R")
source("R/25_data_quality.R")
source("R/26_export_datasets.R")

test_schema_validation <- function() {
  # Create mock valid dataset matching canonical schema specification
  valid_df <- data.frame(
    date             = as.Date("2024-01-01"),
    state            = "Telangana",
    city             = "Hyderabad",
    station_id       = "TG001",
    station_name     = "Sanathnagar, Hyderabad - TSPCB",
    latitude         = 17.4589,
    longitude        = 78.4419,
    pm2_5            = 45.2,
    pm10             = 92.1,
    no2              = 28.4,
    so2              = 11.2,
    co               = 0.75,
    o3               = 34.0,
    nh3              = 14.5,
    temperature      = 24.5,
    humidity         = 55.0,
    wind_speed       = 8.2,
    wind_direction   = 120.0,
    pm25_subindex    = 75.0,
    pm10_subindex    = 92.0,
    no2_subindex     = 35.0,
    so2_subindex     = 14.0,
    co_subindex      = 38.0,
    o3_subindex      = 34.0,
    aqi              = 92.0,
    aqi_category     = "Satisfactory",
    dominant_pollutant = "PM10",
    day_of_week      = "Monday",
    month            = "January",
    season           = "Winter",
    air_data_source  = "cpcb_caaqms",
    weather_source   = "openmeteo_archive",
    data_quality_flag = "valid",
    stringsAsFactors = FALSE
  )
  
  # Validate canonical schema validator
  stopifnot(validate_canonical_schema(valid_df) == TRUE)
  
  # Test error on missing required column
  broken_df <- valid_df
  broken_df$pm2_5 <- NULL
  error_caught <- FALSE
  tryCatch({
    validate_canonical_schema(broken_df)
  }, error = function(e) {
    error_caught <<- TRUE
  })
  stopifnot(error_caught == TRUE)
  
  # Test QC audit function
  qc <- validate_dataset_quality(valid_df, "Mock Canonical Table")
  stopifnot(qc$passed == TRUE)
  stopifnot(length(qc$issues_detected) == 0)
  
  return(TRUE)
}

if (requireNamespace("testthat", quietly = TRUE)) {
  testthat::test_that("Canonical schema validation enforces all 33 target fields", {
    testthat::expect_true(test_schema_validation())
  })
} else {
  test_schema_validation()
  cat("[TEST PASS] test_schema.R: All schema and QC validation assertions passed.\n")
}
