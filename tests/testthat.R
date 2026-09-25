#!/usr/bin/env Rscript
# ==============================================================================
# tests/testthat.R: Unit Test Execution Suite
# UrbanAirQualityIndex-PollutantDriftAnalysis
# B.Tech CSE (AI & ML) III Year / I Sem - Statistics for Machine Learning PBL
# ==============================================================================

cat("\n====================================================================\n")
cat("  RUNNING URBAN AIR QUALITY PIPELINE UNIT TESTS\n")
cat("====================================================================\n\n")

if (requireNamespace("testthat", quietly = TRUE)) {
  testthat::test_dir("tests/testthat")
} else {
  # Robust base-R test runner
  test_files <- list.files("tests/testthat", pattern = "^test_.*\\.R$", full.names = TRUE)
  passed_count <- 0
  total_count  <- length(test_files)
  
  for (tf in test_files) {
    cat(sprintf("Running test file: %s ...\n", basename(tf)))
    tryCatch({
      source(tf, local = new.env())
      passed_count <- passed_count + 1
    }, error = function(e) {
      cat(sprintf("[FAIL] %s: %s\n", basename(tf), conditionMessage(e)))
    })
  }
  
  cat("\n====================================================================\n")
  cat(sprintf("TEST RESULTS: %d/%d test suites passed.\n", passed_count, total_count))
  cat("====================================================================\n\n")
  if (passed_count < total_count) {
    quit(status = 1)
  }
}
