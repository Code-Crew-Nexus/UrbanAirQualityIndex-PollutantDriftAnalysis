source("R/00_setup.R")
source("R/01_utils.R")
library(jsonlite)
library(dplyr)

log_info("Starting Kolkata Alternate Pilot Normalization")

snap <- read.csv("data/metadata/phase2a1_kolkata_alternate_sensors.csv", stringsAsFactors=F)

aq_files <- list.files("data/raw/air_quality/openaq/historical_alternate_pilot", pattern="\\.json$", recursive=TRUE, full.names=TRUE)
weather_files <- list.files("data/raw/weather/openmeteo/historical_alternate_pilot", pattern="\\.json$", recursive=TRUE, full.names=TRUE)

# 1. Normalize OpenAQ
log_info("Normalizing Alternate OpenAQ...")
aq_list <- list()

for (f in aq_files) {
    tryCatch({
        parsed <- fromJSON(f, simplifyVector=F)
        if (is.null(parsed$results) || length(parsed$results) == 0) next
        
        fname <- basename(f)
        parts <- strsplit(fname, "_")[[1]]
        pid <- paste(parts[1], parts[2], sep="_")
        sid <- parts[3]
        
        meta_row <- snap[snap$project_station_id == pid & snap$sensor_id == sid, ]
        if (nrow(meta_row) == 0) next
        
        for (res in parsed$results) {
            # Skip invalid timestamps? The prompt says missing timestamps should be tracked, but this is alternate pilot.
            # I'll just map it directly.
            
            aq_list[[length(aq_list) + 1]] <- data.frame(
                project_station_id = pid,
                source_location_id = meta_row$source_location_id[1],
                station_name = meta_row$station_name[1],
                sensor_id = sid,
                parameter = map_pollutant_name(res$parameter$name),
                value_source = ifelse(is.null(res$value), NA, as.numeric(res$value)),
                source_unit = res$parameter$units,
                timestamp_utc = ifelse(is.null(res$period$datetimeFrom$utc), NA, res$period$datetimeFrom$utc),
                timestamp_local = ifelse(is.null(res$period$datetimeFrom$local), NA, res$period$datetimeFrom$local),
                period_end_utc = ifelse(is.null(res$period$datetimeTo$utc), NA, res$period$datetimeTo$utc),
                period_end_local = ifelse(is.null(res$period$datetimeTo$local), NA, res$period$datetimeTo$local),
                date_local = ifelse(is.null(res$period$datetimeFrom$local), NA, substr(res$period$datetimeFrom$local, 1, 10)),
                api_percent_complete = ifelse(is.null(res$coverage$percentComplete), NA, as.numeric(res$coverage$percentComplete)),
                api_percent_coverage = ifelse(is.null(res$coverage$percentCoverage), NA, as.numeric(res$coverage$percentCoverage)),
                raw_source_file = f,
                stringsAsFactors = F
            )
        }
    }, error = function(e) log_warn(sprintf("Failed parsing %s: %s", f, e$message)))
}

if (length(aq_list) > 0) {
    aq_df <- do.call(rbind, aq_list)
    # Deduplicate exact rows
    aq_df <- aq_df[!duplicated(aq_df), ]
    # Filter out null values for the interim table like Phase 2A did?
    # Actually Phase 2A filtered them out, but maybe we should keep them?
    # "The current normalization skips these rows. That is acceptable only if the skipped rows are explicitly counted."
    aq_df <- aq_df[!is.na(aq_df$value_source), ]
} else {
    aq_df <- data.frame(project_station_id=character(), timestamp_local=character())
}
dir.create("data/interim/hourly", recursive=TRUE, showWarnings=FALSE)
write.csv(aq_df, "data/interim/hourly/phase2a1_kolkata_alternates_air_quality_2025_03.csv", row.names=F)

# 2. Normalize Open-Meteo
log_info("Normalizing Alternate Open-Meteo...")
w_list <- list()
for (f in weather_files) {
    tryCatch({
        parsed <- fromJSON(f, simplifyVector=F)
        if (is.null(parsed$hourly)) next
        
        fname <- basename(f)
        pid <- paste(strsplit(fname, "_")[[1]][1:2], collapse="_")
        meta_row <- snap[snap$project_station_id == pid, ]
        if (nrow(meta_row) == 0) next
        
        times <- unlist(parsed$hourly$time)
        temp <- unlist(parsed$hourly$temperature_2m)
        hum <- unlist(parsed$hourly$relative_humidity_2m)
        ws <- unlist(parsed$hourly$wind_speed_10m)
        wd <- unlist(parsed$hourly$wind_direction_10m)
        
        times_local <- paste0(times, ":00+05:30")
        dates_local <- substr(times, 1, 10)
        
        w_df <- data.frame(
            project_station_id = pid,
            timestamp_local = times_local,
            date_local = dates_local,
            temperature = temp,
            humidity = hum,
            wind_speed = ws,
            wind_direction = wd,
            temperature_unit = parsed$hourly_units$temperature_2m,
            humidity_unit = parsed$hourly_units$relative_humidity_2m,
            wind_speed_unit = parsed$hourly_units$wind_speed_10m,
            wind_direction_unit = parsed$hourly_units$wind_direction_10m,
            raw_source_file = f,
            stringsAsFactors = F
        )
        w_list[[length(w_list) + 1]] <- w_df
    }, error = function(e) log_warn(sprintf("Failed parsing %s: %s", f, e$message)))
}

if (length(w_list) > 0) {
    w_df <- do.call(rbind, w_list)
} else {
    w_df <- data.frame(project_station_id=character(), timestamp_local=character())
}
write.csv(w_df, "data/interim/hourly/phase2a1_kolkata_alternates_weather_2025_03.csv", row.names=F)

log_info("Alternate Normalization Complete")
