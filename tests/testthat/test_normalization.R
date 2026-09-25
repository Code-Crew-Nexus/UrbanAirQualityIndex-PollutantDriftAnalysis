setwd(Sys.getenv("PROJ_ROOT", "."))
# test_normalization.R: Unit tests for pollutant name mapping and units

source("R/01_utils.R")

test_pollutant_mapping <- function() {
  # Test PM2.5 aliases
  stopifnot(map_pollutant_name("pm25") == "pm2_5")
  stopifnot(map_pollutant_name("PM2.5") == "pm2_5")
  stopifnot(map_pollutant_name("pm2_5") == "pm2_5")
  stopifnot(map_pollutant_name("Particulate Matter 2.5") == "pm2_5")
  
  # Test PM10 aliases
  stopifnot(map_pollutant_name("pm10") == "pm10")
  stopifnot(map_pollutant_name("PM10") == "pm10")
  stopifnot(map_pollutant_name("pm10.0") == "pm10")
  
  # Test Gaseous criteria pollutants
  stopifnot(map_pollutant_name("no2") == "no2")
  stopifnot(map_pollutant_name("NO_2") == "no2")
  stopifnot(map_pollutant_name("Nitrogen dioxide") == "no2")
  stopifnot(map_pollutant_name("so2") == "so2")
  stopifnot(map_pollutant_name("Sulfur dioxide") == "so2")
  stopifnot(map_pollutant_name("Sulphur dioxide") == "so2")
  stopifnot(map_pollutant_name("co") == "co")
  stopifnot(map_pollutant_name("Carbon monoxide") == "co")
  stopifnot(map_pollutant_name("o3") == "o3")
  stopifnot(map_pollutant_name("Ozone") == "o3")
  stopifnot(map_pollutant_name("nh3") == "nh3")
  stopifnot(map_pollutant_name("Ammonia") == "nh3")
  
  # Test unknown/pass-through
  stopifnot(map_pollutant_name("temperature") == "temperature")
  stopifnot(is.na(map_pollutant_name(NA)))
  
  return(TRUE)
}

if (requireNamespace("testthat", quietly = TRUE)) {
  testthat::test_that("Pollutant name normalization maps all aliases accurately", {
    testthat::expect_true(test_pollutant_mapping())
  })
} else {
  test_pollutant_mapping()
  cat("[TEST PASS] test_normalization.R: All pollutant normalization assertions passed.\n")
}
