# ==============================================================================
# openmeteo_source.R: Open-Meteo Historical Weather Source Adapter
# UrbanAirQualityIndex-PollutantDriftAnalysis
# B.Tech CSE (AI & ML) III Year / I Sem - Statistics for Machine Learning PBL
# ==============================================================================

source("R/01_utils.R")

OPENMETEO_ARCHIVE_BASE <- "https://archive-api.open-meteo.com/v1/archive"

#' Fetch Historical Weather from Open-Meteo Archive API
#'
#' @param latitude Numeric WGS84 latitude coordinate
#' @param longitude Numeric WGS84 longitude coordinate
#' @param start_date Date string (YYYY-MM-DD)
#' @param end_date Date string (YYYY-MM-DD)
#' @param timezone Timezone identifier, default "Asia/Kolkata"
#' @return List containing raw JSON string, parsed data frame, and units metadata
openmeteo_fetch_weather <- function(latitude, longitude, start_date, end_date, timezone = "Asia/Kolkata") {
  ensure_dir("data/raw/weather/openmeteo")
  
  query_url <- sprintf(
    "%s?latitude=%.4f&longitude=%.4f&start_date=%s&end_date=%s&hourly=temperature_2m,relative_humidity_2m,wind_speed_10m,wind_direction_10m&timezone=%s",
    OPENMETEO_ARCHIVE_BASE,
    as.numeric(latitude),
    as.numeric(longitude),
    as.character(start_date),
    as.character(end_date),
    URLencode(timezone, reserved = TRUE)
  )
  
  log_info(sprintf("Querying Open-Meteo for Lat: %.4f, Lon: %.4f from %s to %s", latitude, longitude, start_date, end_date))
  resp <- safe_http_get(query_url)
  
  if (!resp$success) {
    log_error(sprintf("Open-Meteo request failed: %s", resp$error))
    return(list(
      success = FALSE,
      error = resp$error,
      weather = data.frame()
    ))
  }
  
  # Save untouched raw response
  raw_filename <- sprintf("openmeteo_lat%.4f_lon%.4f_%s_%s.json", latitude, longitude, start_date, end_date)
  raw_path <- file.path("data", "raw", "weather", "openmeteo", raw_filename)
  writeLines(resp$body, raw_path, useBytes = TRUE)
  log_info(sprintf("Saved raw weather payload to: %s", raw_path))
  
  # Parse weather table
  parsed_df <- openmeteo_parse_weather(resp$body)
  
  return(list(
    success = TRUE,
    raw_path = raw_path,
    weather = parsed_df
  ))
}

#' Parse Open-Meteo JSON payload into standardized data frame
#'
#' @param raw_json Character string containing Open-Meteo response
#' @return Clean data frame with canonical weather columns
openmeteo_parse_weather <- function(raw_json) {
  if (is.null(raw_json) || nchar(raw_json) == 0) return(data.frame())
  
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    parsed <- tryCatch({
      jsonlite::fromJSON(raw_json, simplifyVector = TRUE)
    }, error = function(e) {
      log_error(sprintf("Failed to parse Open-Meteo JSON: %s", conditionMessage(e)))
      NULL
    })
    
    if (is.null(parsed) || is.null(parsed$hourly)) return(data.frame())
    
    hourly <- parsed$hourly
    df <- data.frame(
      timestamp_str  = hourly$time,
      temperature    = as.numeric(hourly$temperature_2m),
      humidity       = as.numeric(hourly$relative_humidity_2m),
      wind_speed     = as.numeric(hourly$wind_speed_10m),
      wind_direction = as.numeric(hourly$wind_direction_10m),
      stringsAsFactors = FALSE
    )
    
    # Standardize timestamp to Asia/Kolkata
    df$datetime_ist <- to_ist(df$timestamp_str, src_tz = "Asia/Kolkata")
    df$date         <- as.Date(df$datetime_ist)
    return(df)
  }
  
  log_warn("jsonlite not available; returning raw weather payload unparsed.")
  return(data.frame())
}
