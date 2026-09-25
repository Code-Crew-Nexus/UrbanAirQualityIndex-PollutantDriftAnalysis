library(dplyr)
library(readr)
library(tidyr)
source("R/24_aqi_calculation.R")

# Find hourly data for Jadavpur (PROJ_094) and Zoo Park (PROJ_007) and one other (e.g. PROJ_036 or some station missing some data)
stations_to_test <- c("PROJ_094", "PROJ_007", "PROJ_036")

# We will just load one month of hourly data to get a few days
hourly_df <- read_csv("data/interim/hourly/historical/air_quality_2025_03.csv", show_col_types = FALSE) %>%
  filter(project_station_id %in% stations_to_test)

process_diagnostic_day <- function(target_date, loc_id) {
  # Get 24 hours of target date
  day_data <- hourly_df %>%
    filter(project_station_id == loc_id, as.Date(timestamp_local) == as.Date(target_date)) %>%
    arrange(timestamp_local)
  
  if (nrow(day_data) == 0) return(NULL)
  
  # Get previous 7 hours
  target_dt <- as.POSIXct(paste(target_date, "00:00:00"), tz = "UTC")
  start_dt <- target_dt - (7 * 3600)
  
  prev_7h <- hourly_df %>%
    filter(project_station_id == loc_id, timestamp_local >= start_dt,
           timestamp_local < target_dt) %>%
    arrange(timestamp_local)
  
  get_31h_vector <- function(pol) {
    day_pol <- day_data %>% filter(parameter == pol)
    
    # Extract source unit and sensor id (take first non-NA if possible)
    s_unit <- NA
    s_id <- NA
    
    if (nrow(day_pol) > 0) {
      s_unit <- day_pol$source_unit[!is.na(day_pol$source_unit)][1]
      s_id <- day_pol$sensor_id[!is.na(day_pol$sensor_id)][1]
    }
    if (is.na(s_unit) && nrow(prev_7h %>% filter(parameter == pol)) > 0) {
      prev_pol <- prev_7h %>% filter(parameter == pol)
      s_unit <- prev_pol$source_unit[!is.na(prev_pol$source_unit)][1]
      if (is.na(s_id)) s_id <- prev_pol$sensor_id[!is.na(prev_pol$sensor_id)][1]
    }
    
    vec24 <- rep(NA, 24)
    if (nrow(day_pol) > 0) {
      for(i in 1:nrow(day_pol)) {
        hr <- as.POSIXlt(day_pol$timestamp_local[i])$hour
        vec24[hr + 1] <- day_pol$value_source[i]
      }
    }
    
    vec7 <- rep(NA, 7)
    prev_pol <- prev_7h %>% filter(parameter == pol)
    if (nrow(prev_pol) > 0) {
      for(i in 1:nrow(prev_pol)) {
        hr <- as.POSIXlt(prev_pol$timestamp_local[i])$hour
        idx <- hr - 16 # 17:00 is index 1, 18:00 is 2, etc.
        if(idx >= 1 && idx <= 7) vec7[idx] <- prev_pol$value_source[i]
      }
    }
    
    vec31 <- c(vec7, vec24)
    
    # Convert using sensor_id!
    converted <- rep(NA, length(vec31))
    if (!is.na(s_id)) {
      converted <- sapply(vec31, function(val) convert_hourly_to_canonical_unit(val, pol, s_unit, s_id))
    }
    
    return(list(vector=converted, source_unit=s_unit))
  }
  
  pm10_res <- get_31h_vector("pm10")
  pm25_res <- get_31h_vector("pm2_5")
  no2_res <- get_31h_vector("no2")
  so2_res <- get_31h_vector("so2")
  co_res <- get_31h_vector("co")
  o3_res <- get_31h_vector("o3")
  
  pm10_vec <- pm10_res$vector
  pm25_vec <- pm25_res$vector
  no2_vec <- no2_res$vector
  so2_vec <- so2_res$vector
  co_vec <- co_res$vector
  o3_vec <- o3_res$vector
  
  # 24-hour inputs (only current day, which is index 8:31)
  pm10_in <- derive_daily_24h_input(pm10_vec[8:31])
  pm25_in <- derive_daily_24h_input(pm25_vec[8:31])
  no2_in <- derive_daily_24h_input(no2_vec[8:31])
  so2_in <- derive_daily_24h_input(so2_vec[8:31])
  
  # 8-hour inputs
  co_in <- derive_daily_co_aqi_input(co_vec)
  
  bp <- load_verified_breakpoints()
  o3_in <- derive_daily_o3_subindex(o3_vec, bp)
  
  # Sub-indices
  sub_pm10 <- if(pm10_in$validity) calculate_pollutant_subindex(pm10_in$concentration, "pm10", bp) else NA
  sub_pm25 <- if(pm25_in$validity) calculate_pollutant_subindex(pm25_in$concentration, "pm2_5", bp) else NA
  sub_no2 <- if(no2_in$validity) calculate_pollutant_subindex(no2_in$concentration, "no2", bp) else NA
  sub_so2 <- if(so2_in$validity) calculate_pollutant_subindex(so2_in$concentration, "so2", bp) else NA
  sub_co <- if(co_in$validity) calculate_pollutant_subindex(co_in$concentration, "co", bp) else NA
  sub_o3 <- o3_in$subindex
  
  sub_indices <- c(pm10=sub_pm10, pm2_5=sub_pm25, no2=sub_no2, so2=sub_so2, co=sub_co, o3=sub_o3)
  has_pm <- !is.na(sub_pm10) | !is.na(sub_pm25)
  
  overall <- calculate_daily_indian_aqi(sub_indices, has_pm)
  
  cat <- assign_aqi_category(overall$aqi_display)
  
  # Construct result row
  data.frame(
    project_location_id = loc_id,
    date = target_date,
    pm10_source_unit = pm10_res$source_unit,
    pm10_canonical_unit = "µg/m³",
    pm10_hours = pm10_in$valid_hours,
    pm10_conc = pm10_in$concentration,
    pm10_sub = sub_pm10,
    pm2_5_source_unit = pm25_res$source_unit,
    pm2_5_canonical_unit = "µg/m³",
    pm25_hours = pm25_in$valid_hours,
    pm25_conc = pm25_in$concentration,
    pm25_sub = sub_pm25,
    no2_source_unit = no2_res$source_unit,
    no2_canonical_unit = "µg/m³",
    no2_hours = no2_in$valid_hours,
    no2_conc = no2_in$concentration,
    no2_sub = sub_no2,
    so2_source_unit = so2_res$source_unit,
    so2_canonical_unit = "µg/m³",
    so2_hours = so2_in$valid_hours,
    so2_conc = so2_in$concentration,
    so2_sub = sub_so2,
    co_source_unit_reported = co_res$source_unit,
    co_source_unit_verified = "mg/m³",
    co_canonical_unit = "mg/m³",
    co_hours = co_in$valid_hours,
    co_8h_windows = co_in$valid_windows,
    co_max_8h_conc = co_in$concentration,
    co_sub = sub_co,
    o3_source_unit = o3_res$source_unit,
    o3_canonical_unit = "µg/m³",
    o3_hours = sum(!is.na(o3_vec[8:31])),
    o3_8h_max = o3_in$o3_8h_max,
    o3_1h_max = o3_in$o3_1h_max,
    o3_selected_period = o3_in$selected_averaging_period,
    o3_sub = sub_o3,
    overall_aqi = overall$aqi_display,
    aqi_uncapped = overall$aqi_uncapped,
    category = cat,
    dominant_pollutant = overall$dominant_pollutant,
    validity_reason = overall$reason,
    stringsAsFactors = FALSE
  )
}

results <- list()
for (loc in stations_to_test) {
  for (dt in c("2025-03-01", "2025-03-02", "2025-03-03")) {
    res <- process_diagnostic_day(dt, loc)
    if (!is.null(res)) results[[length(results) + 1]] <- res
  }
}

final_df <- bind_rows(results)
write_csv(final_df, "data/metadata/phase2D1_project_aqi_diagnostic_sample.csv")
