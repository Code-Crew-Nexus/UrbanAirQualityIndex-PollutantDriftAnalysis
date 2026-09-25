# ==============================================================================
# 21_weather_ingestion.R: Weather Data Ingestion (Open-Meteo)
# UrbanAirQualityIndex-PollutantDriftAnalysis
# B.Tech CSE (AI & ML) III Year / I Sem - Statistics for Machine Learning PBL
# ==============================================================================

source("R/01_utils.R")
source("R/20_air_quality_ingestion.R") # for append_to_manifest

ingest_weather_sample <- function(stations, start_date, end_date) {
  ensure_dir("data/raw/weather/openmeteo")
  ensure_dir("data/interim/hourly")
  
  log_info(sprintf("Initiating weather ingestion for %d stations from %s to %s", 
                   nrow(stations), start_date, end_date))
  
  if (!requireNamespace("httr2", quietly = TRUE) || !requireNamespace("jsonlite", quietly = TRUE)) {
    log_warn("Missing httr2 or jsonlite. Cannot fetch weather data.")
    return(data.frame())
  }
  
  all_records <- list()
  
  for (i in seq_len(nrow(stations))) {
    st <- stations[i, ]
    proj_id <- st$project_station_id
    lat <- st$latitude
    lon <- st$longitude
    
    if (is.na(lat) || is.na(lon)) {
      log_warn(sprintf("Skipping %s due to missing coordinates.", proj_id))
      next
    }
    
    url <- "https://archive-api.open-meteo.com/v1/archive"
    
    req <- httr2::request(url) |>
       httr2::req_url_query(
          latitude = lat,
          longitude = lon,
          start_date = start_date,
          end_date = end_date,
          hourly = "temperature_2m,relative_humidity_2m,wind_speed_10m,wind_direction_10m",
          wind_speed_unit = "ms",
          timezone = "Asia/Kolkata"
       )
    
    resp <- tryCatch({ httr2::req_perform(req) }, error = function(e) NULL)
    
    status <- if (is.null(resp)) "Network error" else httr2::resp_status(resp)
    
    if (!is.null(resp) && status == 200) {
      body_text <- httr2::resp_body_string(resp)
      base_dir <- file.path("data", "raw", "weather", "openmeteo")
      base_filename <- sprintf("raw_%s_%s_%s.json", proj_id, start_date, end_date)
      
      raw_file <- save_raw_response_immutable(base_dir, base_filename, body_text)
      log_info(sprintf("Saved raw weather to: %s", raw_file))
      
      parsed <- jsonlite::fromJSON(body_text)
      hourly <- parsed$hourly
      
      if (!is.null(hourly) && length(hourly$time) > 0) {
        row_count <- length(hourly$time)
        req_status <- ifelse(row_count > 0, "http_success_with_data", "http_success_empty")
        append_to_manifest(raw_file, "openmeteo", "weather", "/v1/archive",
                           start_date, end_date, proj_id, NA, row_count, http_status = status, notes = req_status)
                           
        df <- data.frame(
          project_station_id = proj_id,
          timestamp_local = hourly$time, # Open-Meteo returns ISO8601 strings in local tz
          temperature = hourly$temperature_2m,
          relative_humidity = hourly$relative_humidity_2m,
          wind_speed = hourly$wind_speed_10m,
          wind_direction = hourly$wind_direction_10m,
          stringsAsFactors = FALSE
        )
        all_records[[length(all_records) + 1]] <- df
      }
    } else {
      log_warn(sprintf("Open-Meteo request failed for %s: %s", proj_id, status))
    }
  }
  
  if (length(all_records) == 0) {
    log_warn("No weather records retrieved.")
    combined <- data.frame()
  } else {
    combined <- do.call(rbind, all_records)
  }
  
  interim_file <- file.path("data", "interim", "hourly", 
                            sprintf("sample_weather_hourly_%s_%s.csv", start_date, end_date))
  ensure_dir(dirname(interim_file))
  write.csv(combined, interim_file, row.names = FALSE)
  log_info(sprintf("Saved normalized hourly weather to: %s", interim_file))
  
  return(combined)
}
