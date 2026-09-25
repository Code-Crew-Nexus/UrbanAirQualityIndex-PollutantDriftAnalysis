#!/usr/bin/env Rscript
# ==============================================================================
# scripts/02_run_sample_ingestion.R: Small-Scale Technical Ingestion Test Runner
# UrbanAirQualityIndex-PollutantDriftAnalysis
# B.Tech CSE (AI & ML) III Year / I Sem - Statistics for Machine Learning PBL
# ==============================================================================

cat("\n====================================================================\n")
cat("  PHASE 1: SMALL-SCALE TECHNICAL INGESTION TEST RUNNER\n")
cat("====================================================================\n\n")

source("R/00_setup.R")
source("R/01_utils.R")
source("R/sources/openmeteo_source.R")
source("R/20_air_quality_ingestion.R")
source("R/21_weather_ingestion.R")
source("R/22_harmonize_data.R")
source("R/25_data_quality.R")

catalog_path <- "data/metadata/station_catalog.csv"
if (!file.exists(catalog_path)) {
  stop("Catalog not found. Run 01_run_station_audit.R first.")
}

full_catalog <- read.csv(catalog_path, stringsAsFactors = FALSE)

# Step 1: Select Sample Stations
if (nrow(full_catalog) >= 2) {
  sample_stations <- head(full_catalog, 2)
} else {
  sample_stations <- full_catalog
}

# Test Window: 7 Days (Sample technical test)
test_start <- as.character(Sys.Date() - 7)
test_end   <- as.character(Sys.Date())

log_info(sprintf("Executing technical ingestion test for %d stations from %s to %s",
                 nrow(sample_stations), test_start, test_end))

if (nrow(sample_stations) > 0) {
  # Step 2: Ingest Sample Air Quality Observations
  log_info("--- Step 2: Air quality sample ingestion ---")
  air_sample <- ingest_air_quality_sample(
    stations   = sample_stations,
    start_date = test_start,
    end_date   = test_end,
    source_name = "openaq"
  )
  
  # Step 3: Ingest Sample Meteorological Observations (Open-Meteo)
  log_info("--- Step 3: Meteorological sample ingestion (Open-Meteo) ---")
  weather_sample <- ingest_weather_sample(
    stations   = sample_stations,
    start_date = test_start,
    end_date   = test_end
  )
  
  # Step 4: Harmonize Sample Data
  log_info("--- Step 4: Harmonizing air quality and weather observations ---")
  harmonized_sample <- harmonize_sample_observations(air_sample, weather_sample)
  
  if (nrow(harmonized_sample) > 0) {
    # Step 5: Execute Quality Control Validation
    log_info("--- Step 5: Running Quality Control audit ---")
    qc_report <- validate_dataset_quality(harmonized_sample, dataset_name = "Sample Ingested Data")
    
    # Save harmonized intermediate table
    out_harmonized <- file.path("data", "interim", "hourly", 
                                sprintf("harmonized_sample_hourly_%s_%s.csv", test_start, test_end))
    write.csv(harmonized_sample, out_harmonized, row.names = FALSE)
    log_info(sprintf("Saved harmonized test output to: %s", out_harmonized))
  } else {
    log_warn("No harmonized records produced.")
  }
} else {
  log_warn("No sample stations available. Test aborted.")
}

cat("\n====================================================================\n")
cat("  SAMPLE INGESTION TEST SUMMARY\n")
cat("====================================================================\n")
cat(sprintf("Stations Ingested:       %d\n", nrow(sample_stations)))
cat("====================================================================\n\n")
