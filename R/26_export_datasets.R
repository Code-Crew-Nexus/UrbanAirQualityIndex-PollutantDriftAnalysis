# Phase 2E: Final Dataset Export Functions
library(readr)
library(dplyr)
library(yaml)

validate_final_dataset <- function(df, expected_rows) {
  # 1. Check row count
  if (nrow(df) != expected_rows) {
    stop(paste("Row count mismatch. Expected:", expected_rows, "Got:", nrow(df)))
  }
  
  # 2. Check duplicate station-date
  dup_count <- df %>% group_by(project_station_id, date) %>% filter(n() > 1) %>% nrow()
  if (dup_count > 0) {
    stop(paste("Duplicate keys found:", dup_count))
  }
  
  # 3. Check for mandatory AQI fields
  required_cols <- c(
    "aqi_uncapped", "aqi_verified", "aqi_category", "dominant_pollutant", 
    "aqi_validity_reason", "aqi_input_policy", "aqi_policy_version",
    "aqi_pollutants_used", "aqi_excluded_pollutants", "aqi_is_verified_subset"
  )
  missing_cols <- setdiff(required_cols, names(df))
  if (length(missing_cols) > 0) {
    stop(paste("Missing required columns:", paste(missing_cols, collapse = ", ")))
  }
  
  # 4. Enforce subset
  if (any(df$aqi_pollutants_used != "pm2_5,pm10,o3")) {
    stop("Invalid aqi_pollutants_used found.")
  }
  if (any(df$aqi_excluded_pollutants != "co,no2,so2")) {
    stop("Invalid aqi_excluded_pollutants found.")
  }
  
  return(TRUE)
}

export_final_dataset <- function(df, path) {
  write_excel_csv(df, path, na = "NA")
  cat(sprintf("Successfully exported %d rows to %s\n", nrow(df), path))
}

export_final_uaqi_datasets <- function(master_df) {
  validate_final_dataset(master_df, 11970)
  
  dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)
  
  # 1. Master
  export_final_dataset(master_df, "data/processed/UAQI_Master_Daily.csv")
  
  # 2. Hyderabad
  hyd <- master_df %>% filter(use_hyderabad == TRUE)
  validate_final_dataset(hyd, 3990)
  export_final_dataset(hyd, "data/processed/UAQI_Hyderabad_Daily.csv")
  
  # 3. India
  ind <- master_df %>% filter(use_india == TRUE)
  validate_final_dataset(ind, 8550)
  export_final_dataset(ind, "data/processed/UAQI_India_Daily.csv")
}
