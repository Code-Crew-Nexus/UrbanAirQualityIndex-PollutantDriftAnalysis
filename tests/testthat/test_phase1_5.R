# tests/test_phase1_5.R
library(testthat)

source("R/00_setup.R")
source("R/01_utils.R")
source("R/10_station_catalog.R")
source("R/11_station_coverage_audit.R")

test_that("match_candidate_city handles complex edge cases", {
   active_cities <- data.frame(city = c("Visakhapatnam", "Bhopal", "Mumbai", "Delhi", "Bengaluru"), state = c("AP", "MP", "MH", "DL", "KA"))
   aliases <- data.frame(canonical_city = c("Delhi", "Bengaluru", "Mumbai"), alias = c("New Delhi", "Bangalore", "Navi Mumbai"))
   
   # Patna does NOT match Visakhapatnam
   res <- match_candidate_city(NA, "Patna", active_cities, aliases)
   expect_true(is.na(res$city))
   
   # Bhopal Chauraha, Dewas does NOT match Bhopal
   res <- match_candidate_city(NA, "Bhopal Chauraha, Dewas - MPPCB", active_cities, aliases)
   expect_true(is.na(res$city)) # because Dewas != Bhopal
   
   # Bombay Castel, Ooty does NOT match Mumbai
   res <- match_candidate_city(NA, "Bombay Castel, Ooty - TNPCB", active_cities, aliases)
   expect_true(is.na(res$city)) # because Ooty != Mumbai
   
   # New Delhi maps to Delhi
   res <- match_candidate_city(NA, "RK Puram, New Delhi", active_cities, aliases)
   expect_equal(res$city, "Delhi")
   
   # Bangalore maps to Bengaluru
   res <- match_candidate_city("Bangalore", NA, active_cities, aliases)
   expect_equal(res$city, "Bengaluru")
   
   # GVM Corporation, Visakhapatnam maps to Visakhapatnam
   res <- match_candidate_city(NA, "GVM Corporation, Visakhapatnam - APPCB", active_cities, aliases)
   expect_equal(res$city, "Visakhapatnam")
})

test_that("coverage summarization correctly calculates days and clamps logically", {
   # Fake days_data for 27 distinct valid days in a 30-day interval
   audit_end <- as.Date("2026-09-24")
   audit_start <- audit_end - 29
   
   days_data <- list()
   for (i in seq_len(27)) {
      dt <- as.character(audit_start + i - 1)
      days_data[[i]] <- list(period = list(datetimeFrom = list(local = paste0(dt, "T00:00:00+05:30"))), coverage = list(percentComplete = "100", percentCoverage = "100"))
   }
   
   sum_out <- summarize_coverage(days_data, audit_start, audit_end)
   expect_equal(sum_out$distinct_valid_dates, 27)
   expect_equal(sum_out$days_with_data_pct, 90) # 27 / 30 = 90%
})

test_that("immutable raw writer works", {
   tmp_dir <- tempdir()
   res <- save_raw_response_immutable(tmp_dir, "test_req.json", '{"data": 1}')
   expect_true(file.exists(res))
   
   res2 <- save_raw_response_immutable(tmp_dir, "test_req.json", '{"data": 1}')
   # Might be same second, so same filename
   
   Sys.sleep(1.5)
   res3 <- save_raw_response_immutable(tmp_dir, "test_req.json", '{"data": 2}')
   expect_true(res3 != res) # New timestamped file
})

test_that("manifest verification", {
   mf_path <- "data/metadata/raw_data_manifest.csv"
   if (file.exists(mf_path)) {
      mf <- read.csv(mf_path, stringsAsFactors=F)
      mf <- mf[!is.na(mf$local_file), ]
      if(nrow(mf) > 0) {
         for(i in seq_len(min(10, nrow(mf)))) {
            expect_true(file.exists(mf$local_file[i]))
            expect_equal(digest::digest(mf$local_file[i], algo="sha256", file=TRUE), mf$file_sha256[i])
         }
      }
   }
})
