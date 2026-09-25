source("R/00_setup.R")
source("R/20_air_quality_ingestion.R")
source("R/21_weather_ingestion.R")

log_info("Starting Authentic Sample Ingestion")

cr_path <- "data/metadata/coverage_report.csv"
sc_path <- "data/metadata/sensor_catalog.csv"
if (!file.exists(cr_path) || !file.exists(sc_path)) {
   stop("Coverage report or sensor catalog not found.")
}

cr <- read.csv(cr_path, stringsAsFactors = FALSE)
sc <- read.csv(sc_path, stringsAsFactors = FALSE)

# Filter for preferred_current PM2.5 and PM10
pref_sc <- subset(sc, sensor_generation_status == "preferred_current" & parameter %in% c("pm25", "pm10"))

# Ensure station has both PM2.5 and PM10 if possible, or at least one
# Let's get Hyderabad stations
hyd_catalog <- read.csv("data/metadata/hyderabad_station_review.csv", stringsAsFactors = FALSE)
hyd_active <- subset(hyd_catalog, record_status == "preferred_current_location" | record_status == "unique_current" | activity_status == "active_recent")$project_station_id

ind_catalog <- read.csv("data/metadata/india_station_shortlist.csv", stringsAsFactors = FALSE)
other_cities <- subset(ind_catalog, city != "Hyderabad")$project_station_id

valid_hyd <- unique(subset(pref_sc, project_station_id %in% hyd_active)$project_station_id)
valid_oth <- unique(subset(pref_sc, project_station_id %in% other_cities)$project_station_id)

hyd_sel <- head(valid_hyd, 1)
oth_sel <- head(valid_oth, 1)

if (length(hyd_sel) == 0 || length(oth_sel) == 0) {
   stop("Could not find suitable stations for smoke test.")
}

log_info(sprintf("Selected Hyderabad Station: %s", hyd_sel))
log_info(sprintf("Selected Other City Station: %s", oth_sel))

test_stations <- c(hyd_sel, oth_sel)
air_data <- list()
weather_stations <- ind_catalog[ind_catalog$project_station_id %in% test_stations, ]
if (!hyd_sel %in% weather_stations$project_station_id) {
   weather_stations <- rbind(weather_stations, hyd_catalog[hyd_catalog$project_station_id == hyd_sel, ])
}

weather_date_ranges <- list()

for (st in test_stations) {
   sensors <- subset(pref_sc, project_station_id == st)
   
   for (i in seq_len(nrow(sensors))) {
      s <- sensors[i, ]
      loc_id <- s$source_location_id
      sid <- s$sensor_id
      param <- s$parameter
      dt_last <- s$sensor_datetime_last
      
      if (is.na(dt_last) || dt_last == "") {
         log_warn(sprintf("No datetime_last for sensor %s", sid))
         next
      }
      
      end_date <- as.Date(substr(dt_last, 1, 10))
      start_date <- end_date - 6
      
      # Save range for weather
      weather_date_ranges[[st]] <- c(as.character(start_date), as.character(end_date))
      
      log_info(sprintf("Fetching Air Quality: Sensor %s (%s) from %s to %s", sid, param, start_date, end_date))
      df <- fetch_sensor_hours(st, loc_id, sid, param, start_date, end_date)
      if (nrow(df) > 0) {
         air_data[[length(air_data) + 1]] <- df
      }
   }
}

if (length(air_data) > 0) {
   air_df <- do.call(rbind, air_data)
   out_file <- "data/interim/hourly/smoke_test_air_quality.csv"
   write.csv(air_df, out_file, row.names = FALSE)
   log_info(sprintf("Saved %d rows of authentic air quality to %s", nrow(air_df), out_file))
} else {
   log_warn("No authentic air quality data retrieved.")
}

log_info("Fetching Weather for Smoke Test Stations")
weather_data <- list()
for (st in test_stations) {
    if (!is.null(weather_date_ranges[[st]])) {
        st_info <- subset(weather_stations, project_station_id == st)
        start_d <- weather_date_ranges[[st]][1]
        end_d <- weather_date_ranges[[st]][2]
        
        log_info(sprintf("Fetching Weather for %s from %s to %s", st, start_d, end_d))
        wdf <- ingest_weather_sample(st_info, start_d, end_d)
        if (nrow(wdf) > 0) {
            weather_data[[length(weather_data) + 1]] <- wdf
        }
    }
}

if (length(weather_data) > 0) {
   weather_df <- do.call(rbind, weather_data)
   out_file <- "data/interim/hourly/smoke_test_weather.csv"
   write.csv(weather_df, out_file, row.names = FALSE)
   log_info(sprintf("Saved %d rows of authentic weather to %s", nrow(weather_df), out_file))
}
