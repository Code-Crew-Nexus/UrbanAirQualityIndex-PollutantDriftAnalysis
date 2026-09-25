# ==============================================================================
# 22_harmonize_data.R: Data Harmonization
# UrbanAirQualityIndex-PollutantDriftAnalysis
# ==============================================================================

source("R/01_utils.R")

#' Build a complete grid of stations and dates
build_station_day_spine <- function(stations_df, start_date, end_date) {
  log_info("Building master station-day spine...")
  dates <- seq(as.Date(start_date), as.Date(end_date), by = "day")
  spine <- expand.grid(
    date = dates,
    project_station_id = unique(stations_df$project_station_id),
    stringsAsFactors = FALSE
  )
  
  # Join station metadata
  spine <- merge(spine, stations_df[, c("project_station_id", "source_location_id", "station_name", "city", "state", "latitude", "longitude", "use_hyderabad", "use_india")], by = "project_station_id", all.x = TRUE)
  
  spine$date <- as.character(spine$date)
  
  return(spine)
}

#' Add temporal calendar features (day of week, month, year, season)
add_temporal_features <- function(df) {
  d <- as.Date(df$date)
  df$day_of_week <- weekdays(d)
  df$month_name <- months(d)
  df$month <- format(d, "%m")
  df$month_number <- as.integer(df$month)
  df$year <- as.integer(format(d, "%Y"))
  
  get_season <- function(m) {
    if (m %in% c(12, 1, 2)) return("Winter")
    if (m %in% c(3, 4, 5)) return("Summer / Pre-monsoon")
    if (m %in% c(6, 7, 8, 9)) return("Monsoon")
    return("Post-monsoon")
  }
  df$season <- vapply(df$month_number, get_season, FUN.VALUE = character(1))
  
  return(df)
}

#' Join Weather Data to Daily Air Quality
join_daily_weather <- function(daily_air, daily_weather) {
  log_info("Joining daily weather to master daily air...")
  # Assumes both dataframes have project_station_id and date
  merged <- merge(daily_air, daily_weather, by = c("project_station_id", "date"), all.x = TRUE)
  return(merged)
}
