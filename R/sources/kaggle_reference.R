# ==============================================================================
# kaggle_reference.R: Kaggle Reference Data Review Adapter
# UrbanAirQualityIndex-PollutantDriftAnalysis
# B.Tech CSE (AI & ML) III Year / I Sem - Statistics for Machine Learning PBL
# ==============================================================================

source("R/01_utils.R")

#' Audit and Inspect a Candidate Kaggle Reference Dataset
#'
#' @param file_path Absolute or relative path to CSV file
#' @return List summarizing schema compatibility, date ranges, and warnings
kaggle_check_compatibility <- function(file_path) {
  if (!file.exists(file_path)) {
    return(list(
      compatible = FALSE,
      error = sprintf("Reference file %s does not exist.", file_path)
    ))
  }
  
  log_info(sprintf("Auditing Kaggle reference file: %s", file_path))
  # Read preview (first 100 rows)
  preview <- read.csv(file_path, nrows = 100, stringsAsFactors = FALSE)
  cols <- colnames(preview)
  
  # Check for core pollutants
  core_present <- list(
    pm2_5 = any(grepl("(?i)pm2[._]?5", cols)),
    pm10  = any(grepl("(?i)pm10", cols)),
    no2   = any(grepl("(?i)no2", cols)),
    so2   = any(grepl("(?i)so2", cols)),
    co    = any(grepl("(?i)\\bco\\b", cols)),
    o3    = any(grepl("(?i)\\bo3\\b|ozone", cols))
  )
  
  # Check for Station / City identifiers
  has_station <- any(grepl("(?i)station", cols))
  has_city    <- any(grepl("(?i)city", cols))
  has_date    <- any(grepl("(?i)date|time", cols))
  
  report <- list(
    file_path = file_path,
    total_cols = length(cols),
    columns = cols,
    core_pollutants_detected = core_present,
    core_count = sum(unlist(core_present)),
    has_station_metadata = has_station,
    has_city_metadata = has_city,
    has_timestamp = has_date,
    compatibility_status = ifelse(sum(unlist(core_present)) >= 5 && has_date, "Potentially Compatible", "Incompatible / Incomplete")
  )
  
  log_info(sprintf("Kaggle Audit Result: %d/6 core pollutants detected. Status: %s", 
                   report$core_count, report$compatibility_status))
  return(report)
}
