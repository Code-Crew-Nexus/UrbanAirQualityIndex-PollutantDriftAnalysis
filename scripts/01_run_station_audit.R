#!/usr/bin/env Rscript
# ==============================================================================
# scripts/01_run_station_audit.R: Orchestrate Station Discovery and Coverage Audit
# UrbanAirQualityIndex-PollutantDriftAnalysis
# B.Tech CSE (AI & ML) III Year / I Sem - Statistics for Machine Learning PBL
# ==============================================================================

cat("\n====================================================================\n")
cat("  PHASE 1: MONITORING STATION DISCOVERY & COVERAGE AUDIT RUNNER\n")
cat("====================================================================\n\n")

source("R/00_setup.R")
source("R/01_utils.R")
source("R/10_station_catalog.R")
source("R/11_station_coverage_audit.R")

# Step 1: Discover and Catalog Stations
log_info("--- Step 1: Discovering monitoring stations ---")
catalog_df <- build_station_catalog(
  candidate_file = "config/candidate_india_cities.csv",
  output_catalog = "data/metadata/station_catalog.csv"
)

# Step 2: Audit Station Pollutant Coverage and Completeness
log_info("--- Step 2: Running 90-day coverage & completeness audit ---")
coverage_df <- audit_station_coverage(
  catalog_path = "data/metadata/station_catalog.csv",
  output_coverage = "data/metadata/coverage_report.csv",
  audit_window_days = 90
)

# Step 3: Display Summary Table
cat("\n====================================================================\n")
cat("  AUDIT SUMMARY RESULTS\n")
cat("====================================================================\n")
cat(sprintf("Total Stations Audited:     %d\n", nrow(coverage_df)))
cat(sprintf("Total Cities Represented:    %d\n", length(unique(coverage_df$city))))
cat(sprintf("Hyderabad Stations Audited:  %d\n", sum(coverage_df$city == "Hyderabad")))
cat(sprintf("Recommended Stations:        %d\n", sum(coverage_df$recommended == "Recommended")))
cat(sprintf("Usable with Limitations:     %d\n", sum(coverage_df$recommended == "Usable with limitations")))
cat(sprintf("Not Recommended:             %d\n", sum(coverage_df$recommended == "Not recommended")))
cat("====================================================================\n")
cat("Metadata artifacts written:\n")
cat("  -> data/metadata/station_catalog.csv\n")
cat("  -> data/metadata/coverage_report.csv\n")
cat("====================================================================\n\n")
