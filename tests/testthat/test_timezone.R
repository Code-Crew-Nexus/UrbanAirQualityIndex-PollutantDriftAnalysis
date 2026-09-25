setwd(Sys.getenv("PROJ_ROOT", "."))
# test_timezone.R: Unit tests for Indian Standard Time (Asia/Kolkata) conversion

source("R/01_utils.R")

test_timezone_conversion <- function() {
  # Test UTC to IST (UTC + 5:30)
  utc_time <- "2024-01-01T00:00:00Z"
  ist_result <- to_ist(utc_time, src_tz = "UTC")
  
  # Format in IST
  formatted <- format(ist_result, "%Y-%m-%d %H:%M:%S", tz = "Asia/Kolkata")
  stopifnot(formatted == "2024-01-01 05:30:00")
  
  # Test UTC midnight rollover into IST morning
  utc_evening <- "2024-01-01T20:00:00Z"
  ist_nextday <- to_ist(utc_evening, src_tz = "UTC")
  formatted_next <- format(ist_nextday, "%Y-%m-%d %H:%M:%S", tz = "Asia/Kolkata")
  stopifnot(formatted_next == "2024-01-02 01:30:00")
  
  # Test calendar date alignment (critical for daily aggregation)
  stopifnot(to_ist_date(ist_nextday) == as.Date("2024-01-02"))
  stopifnot(as.Date(ist_nextday, tz = "Asia/Kolkata") == as.Date("2024-01-02"))
  
  # Test handling empty vector
  stopifnot(length(to_ist(character(0))) == 0)
  
  return(TRUE)
}

if (requireNamespace("testthat", quietly = TRUE)) {
  testthat::test_that("Timezone normalization accurately converts UTC to Asia/Kolkata", {
    testthat::expect_true(test_timezone_conversion())
  })
} else {
  test_timezone_conversion()
  cat("[TEST PASS] test_timezone.R: All timezone conversion assertions passed.\n")
}
