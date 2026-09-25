source("R/00_setup.R")
source("R/01_utils.R")
library(jsonlite)
library(dplyr)

log_info("Starting Phase 2A Pilot Normalization")

snapshot <- read.csv("data/metadata/selected_sensor_snapshot.csv", stringsAsFactors=F)

aq_files <- list.files("data/raw/air_quality/openaq/historical", pattern="\\.json$", recursive=TRUE, full.names=TRUE)
weather_files <- list.files("data/raw/weather/openmeteo/historical", pattern="\\.json$", recursive=TRUE, full.names=TRUE)

# 1. Normalize OpenAQ
log_info("Normalizing OpenAQ...")
aq_list <- list()
for (f in aq_files) {
    tryCatch({
        parsed <- fromJSON(f, simplifyVector=F)
        if (is.null(parsed$results) || length(parsed$results) == 0) next
        
        # Extract pid, sid, param from filename
        fname <- basename(f)
        parts <- strsplit(fname, "_")[[1]]
        pid <- paste(parts[1], parts[2], sep="_")
        sid <- parts[3]
        
        meta_row <- snapshot[snapshot$project_station_id == pid & snapshot$sensor_id == sid, ]
        if (nrow(meta_row) == 0) next
        
        for (res in parsed$results) {
            # Skip invalid
            if (is.null(res$period$datetimeFrom$utc) || is.null(res$value)) next
            
            aq_list[[length(aq_list) + 1]] <- data.frame(
                project_station_id = pid,
                source_location_id = meta_row$source_location_id[1],
                station_name = meta_row$station_name[1],
                city = meta_row$city[1],
                state = meta_row$state[1],
                sensor_id = sid,
                parameter = map_pollutant_name(res$parameter$name),
                value_source = as.numeric(res$value),
                source_unit = res$parameter$units,
                timestamp_utc = res$period$datetimeFrom$utc,
                timestamp_local = res$period$datetimeFrom$local,
                period_end_utc = res$period$datetimeTo$utc,
                period_end_local = res$period$datetimeTo$local,
                date_local = substr(res$period$datetimeFrom$local, 1, 10),
                api_percent_complete = ifelse(!is.null(res$coverage$percentComplete), as.numeric(res$coverage$percentComplete), NA),
                api_percent_coverage = ifelse(!is.null(res$coverage$percentCoverage), as.numeric(res$coverage$percentCoverage), NA),
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
} else {
    aq_df <- data.frame(project_station_id=character(), timestamp_local=character())
}
dir.create("data/interim/hourly", recursive=TRUE, showWarnings=FALSE)
write.csv(aq_df, "data/interim/hourly/phase2_pilot_air_quality_2025_03.csv", row.names=F)


# 2. Normalize Open-Meteo
log_info("Normalizing Open-Meteo...")
w_list <- list()
for (f in weather_files) {
    tryCatch({
        parsed <- fromJSON(f, simplifyVector=F)
        if (is.null(parsed$hourly)) next
        
        fname <- basename(f)
        pid <- paste(strsplit(fname, "_")[[1]][1:2], collapse="_")
        meta_row <- snapshot[snapshot$project_station_id == pid, ]
        if (nrow(meta_row) == 0) next
        
        times <- unlist(parsed$hourly$time)
        temp <- unlist(parsed$hourly$temperature_2m)
        hum <- unlist(parsed$hourly$relative_humidity_2m)
        ws <- unlist(parsed$hourly$wind_speed_10m)
        wd <- unlist(parsed$hourly$wind_direction_10m)
        
        # Open-Meteo times are like "2025-03-01T00:00"
        # Let's align format with OpenAQ: "2025-03-01T00:00:00+05:30"
        times_local <- paste0(times, ":00+05:30")
        dates_local <- substr(times, 1, 10)
        
        w_df <- data.frame(
            project_station_id = pid,
            source_location_id = meta_row$source_location_id[1],
            station_name = meta_row$station_name[1],
            city = meta_row$city[1],
            state = meta_row$state[1],
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
write.csv(w_df, "data/interim/hourly/phase2_pilot_weather_2025_03.csv", row.names=F)


# 3. Join Pilot
log_info("Joining pilot data...")
if (nrow(aq_df) > 0 && nrow(w_df) > 0) {
    joined <- merge(aq_df, w_df[, c("project_station_id", "timestamp_local", "temperature", "humidity", "wind_speed", "wind_direction", "temperature_unit", "humidity_unit", "wind_speed_unit", "wind_direction_unit", "raw_source_file")], 
                    by=c("project_station_id", "timestamp_local"), all.x=TRUE, suffixes=c("", ".weather"))
} else {
    joined <- aq_df
}
write.csv(joined, "data/interim/hourly/phase2_pilot_joined_2025_03.csv", row.names=F)


# 4. Completeness Audit
log_info("Auditing completeness...")
EXPECTED_HOURS <- 31 * 24 # 744

comp_list <- list()
for (i in 1:nrow(snapshot)) {
    pid <- snapshot$project_station_id[i]
    param <- snapshot$parameter[i]
    
    sub_aq <- aq_df[aq_df$project_station_id == pid & aq_df$parameter == param, ]
    
    distinct_hours <- length(unique(sub_aq$timestamp_local))
    first_obs <- if(nrow(sub_aq) > 0) min(sub_aq$timestamp_local) else NA
    last_obs <- if(nrow(sub_aq) > 0) max(sub_aq$timestamp_local) else NA
    
    comp_list[[i]] <- data.frame(
        project_station_id = pid,
        parameter = param,
        distinct_hour_count = distinct_hours,
        expected_hour_count = EXPECTED_HOURS,
        hourly_completeness_pct = round(distinct_hours / EXPECTED_HOURS * 100, 2),
        first_observed_timestamp = first_obs,
        last_observed_timestamp = last_obs,
        missing_hour_count = EXPECTED_HOURS - distinct_hours,
        stringsAsFactors = F
    )
}
comp_df <- do.call(rbind, comp_list)
write.csv(comp_df, "data/metadata/phase2_pilot_completeness.csv", row.names=F)


w_comp_list <- list()
sel <- unique(snapshot$project_station_id)
for (pid in sel) {
    sub_w <- w_df[w_df$project_station_id == pid, ]
    obs_hours <- length(unique(sub_w$timestamp_local[!is.na(sub_w$temperature)]))
    
    w_comp_list[[length(w_comp_list) + 1]] <- data.frame(
        project_station_id = pid,
        observed_hour_count = obs_hours,
        expected_hour_count = EXPECTED_HOURS,
        completeness_pct = round(obs_hours / EXPECTED_HOURS * 100, 2),
        missing_weather_hours = EXPECTED_HOURS - obs_hours,
        stringsAsFactors = F
    )
}
w_comp_df <- do.call(rbind, w_comp_list)
write.csv(w_comp_df, "data/metadata/phase2_pilot_weather_completeness.csv", row.names=F)

log_info("Pilot Normalization Complete")
