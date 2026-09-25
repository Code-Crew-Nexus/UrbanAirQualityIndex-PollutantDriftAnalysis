source("R/00_setup.R")
source("R/01_utils.R")
library(jsonlite)

log_info("Starting Phase 2B Normalization and Audit")

snap <- read.csv("data/metadata/selected_sensor_snapshot.csv", stringsAsFactors=FALSE)
sel <- read.csv("config/selected_stations.csv", stringsAsFactors=FALSE)
plan <- read.csv("data/metadata/phase2B_acquisition_plan.csv", stringsAsFactors=FALSE)

# 1. Normalize Weather
log_info("Normalizing Weather...")
w_dir <- "data/interim/hourly/historical_weather"
dir.create(w_dir, recursive=TRUE, showWarnings=FALSE)

w_raw_files <- list.files("data/raw/weather/openmeteo/historical", pattern="\\.json$", recursive=TRUE, full.names=TRUE)

# Also need the March pilot weather files for full history completeness
w_raw_march <- list.files("data/raw/weather/openmeteo/historical_pilot", pattern="\\.json$", recursive=TRUE, full.names=TRUE)
w_raw_march_alt <- list.files("data/raw/weather/openmeteo/historical_alternate_pilot", pattern="\\.json$", recursive=TRUE, full.names=TRUE)
w_raw_files <- unique(c(w_raw_files, w_raw_march, w_raw_march_alt))

w_list <- list()
for (f in w_raw_files) {
    tryCatch({
        parsed <- fromJSON(f, simplifyVector=FALSE)
        if (is.null(parsed$hourly)) next
        
        fname <- basename(f)
        pid <- paste(strsplit(fname, "_")[[1]][1:2], collapse="_")
        meta_row <- sel[sel$project_station_id == pid, ]
        if (nrow(meta_row) == 0) next
        
        times <- unlist(parsed$hourly$time)
        temp <- unlist(parsed$hourly$temperature_2m)
        hum <- unlist(parsed$hourly$relative_humidity_2m)
        ws <- unlist(parsed$hourly$wind_speed_10m)
        wd <- unlist(parsed$hourly$wind_direction_10m)
        
        times_local <- paste0(times, ":00+05:30")
        dates_local <- substr(times, 1, 10)
        
        df <- data.frame(
            project_station_id = pid,
            timestamp_local = times_local,
            date_local = dates_local,
            temperature = temp,
            humidity = hum,
            wind_speed = ws,
            wind_direction = wd,
            temperature_unit = "°C",
            humidity_unit = "%",
            wind_speed_unit = "m/s",
            wind_direction_unit = "°",
            raw_source_file = f,
            stringsAsFactors=FALSE
        )
        w_list[[length(w_list) + 1]] <- df
    }, error = function(e) log_warn(paste("Weather parse error:", f)))
}

w_all <- do.call(rbind, w_list)
w_all <- w_all[!duplicated(w_all[, c("project_station_id", "timestamp_local")]), ]
w_all$ym <- substr(w_all$date_local, 1, 7)

for (ym in unique(w_all$ym)) {
    if (is.na(ym)) next
    sub <- w_all[w_all$ym == ym, setdiff(names(w_all), "ym")]
    write.csv(sub, file.path(w_dir, paste0("weather_", gsub("-", "_", ym), ".csv")), row.names=FALSE)
}

# 2. Normalize OpenAQ
log_info("Normalizing OpenAQ...")
aq_dir <- "data/interim/hourly/historical"
dir.create(aq_dir, recursive=TRUE, showWarnings=FALSE)

# Include Phase 2A March pilot data, plus all chunks
state <- read.csv("data/metadata/phase2B_acquisition_state.csv", stringsAsFactors=FALSE)
march_state <- read.csv("data/metadata/historical_acquisition_state.csv", stringsAsFactors=FALSE)
alt_state <- read.csv("data/metadata/phase2a1_kolkata_acquisition_state.csv", stringsAsFactors=FALSE)

all_states <- list()

# Prepare chunk lookup
chunks <- data.frame(
    chunk_id = 0,
    ym = "2025-03",
    expected = 744,
    stringsAsFactors=FALSE
)
for (i in 1:nrow(plan)) {
    chunks <- rbind(chunks, data.frame(
        chunk_id = plan$chunk_id[i],
        ym = substr(plan$local_start_date[i], 1, 7),
        expected = plan$expected_local_hours[i],
        stringsAsFactors=FALSE
    ))
}

process_aq_file <- function(f, pid, sid, param) {
    parsed <- tryCatch(fromJSON(f, simplifyVector=FALSE), error=function(e) NULL)
    if (is.null(parsed) || is.null(parsed$results)) return(NULL)
    
    meta_row <- snap[snap$project_station_id == pid & snap$sensor_id == sid, ]
    if (nrow(meta_row) == 0) return(NULL)
    
    res_list <- list()
    for (res in parsed$results) {
        res_list[[length(res_list)+1]] <- data.frame(
            project_station_id = pid,
            source_location_id = meta_row$source_location_id[1],
            station_name = meta_row$station_name[1],
            city = meta_row$city[1],
            state = meta_row$state[1],
            sensor_id = sid,
            parameter = map_pollutant_name(res$parameter$name),
            value_source = ifelse(is.null(res$value), NA, as.numeric(res$value)),
            source_unit = meta_row$source_unit[1],
            timestamp_utc = ifelse(is.null(res$period$datetimeFrom$utc), NA, res$period$datetimeFrom$utc),
            timestamp_local = ifelse(is.null(res$period$datetimeFrom$local), NA, res$period$datetimeFrom$local),
            period_end_utc = ifelse(is.null(res$period$datetimeTo$utc), NA, res$period$datetimeTo$utc),
            period_end_local = ifelse(is.null(res$period$datetimeTo$local), NA, res$period$datetimeTo$local),
            date_local = ifelse(is.null(res$period$datetimeFrom$local), NA, substr(res$period$datetimeFrom$local, 1, 10)),
            api_percent_complete = ifelse(is.null(res$coverage$percentComplete), NA, as.numeric(res$coverage$percentComplete)),
            api_percent_coverage = ifelse(is.null(res$coverage$percentCoverage), NA, as.numeric(res$coverage$percentCoverage)),
            raw_source_file = basename(f),
            stringsAsFactors=FALSE
        )
    }
    if (length(res_list) > 0) return(do.call(rbind, res_list))
    return(NULL)
}

# Instead of loading everything into RAM, we iterate chunk by chunk
monthly_comp_list <- list()

for (i in 1:nrow(chunks)) {
    cid <- chunks$chunk_id[i]
    ym <- chunks$ym[i]
    exp_hr <- chunks$expected[i]
    log_info(sprintf("Processing chunk %s...", ym))
    
    if (cid == 0) {
        # March
        files <- c()
        m_s <- march_state[march_state$project_station_id != "PROJ_104" & march_state$status == "SUCCESS", ]
        files <- c(files, unlist(strsplit(m_s$raw_file, ";")))
        a_s <- alt_state[alt_state$project_station_id == "PROJ_094" & alt_state$status == "SUCCESS", ]
        files <- c(files, unlist(strsplit(a_s$raw_file, ";")))
        files <- files[files != "" & !is.na(files)]
    } else {
        # Other months
        c_s <- state[state$chunk_id == cid & state$status %in% c("completed", "empty_valid_response"), ]
        files <- unlist(strsplit(c_s$raw_files, ";"))
        files <- files[files != "" & !is.na(files)]
    }
    
    raw_count <- 0
    null_count <- 0
    miss_ts_count <- 0
    
    chunk_dfs <- list()
    for (f in unique(files)) {
        if (!file.exists(f)) next
        fname <- basename(f)
        parts <- strsplit(fname, "_")[[1]]
        pid <- paste(parts[1], parts[2], sep="_")
        sid <- parts[3]
        param <- parts[4]
        
        df <- process_aq_file(f, pid, sid, param)
        if (!is.null(df)) {
            raw_count <- raw_count + nrow(df)
            null_count <- null_count + sum(is.na(df$value_source))
            miss_ts_count <- miss_ts_count + sum(is.na(df$timestamp_local))
            chunk_dfs[[length(chunk_dfs)+1]] <- df
        }
    }
    
    if (length(chunk_dfs) > 0) {
        chunk_all <- do.call(rbind, chunk_dfs)
        dup_count <- sum(duplicated(chunk_all[, c("project_station_id", "sensor_id", "parameter", "timestamp_local")]))
        chunk_all <- chunk_all[!duplicated(chunk_all[, c("project_station_id", "sensor_id", "parameter", "timestamp_local")]), ]
        valid_count <- nrow(chunk_all)
        
        write.csv(chunk_all, file.path(aq_dir, paste0("air_quality_", gsub("-", "_", ym), ".csv")), row.names=FALSE)
        
        # Calculate Completeness
        for (pid in unique(snap$project_station_id)) {
            s_city <- sel[sel$project_station_id == pid, "city"]
            for (p in c("pm2_5", "pm10", "no2", "so2", "co", "o3")) {
                sub <- chunk_all[chunk_all$project_station_id == pid & chunk_all$parameter == p, ]
                if (nrow(sub) == 0) {
                    d <- 0
                    n_null <- 0
                    m_hour <- exp_hr
                    ts_first <- NA
                    ts_last <- NA
                } else {
                    d <- length(unique(sub$timestamp_local[!is.na(sub$timestamp_local) & !is.na(sub$value_source)]))
                    n_null <- sum(is.na(sub$value_source))
                    m_hour <- max(0, exp_hr - d)
                    ts_first <- min(sub$timestamp_local, na.rm=TRUE)
                    ts_last <- max(sub$timestamp_local, na.rm=TRUE)
                }
                
                pct <- round(d/exp_hr*100, 2)
                cls <- "No Data"
                if (pct >= 75) cls <- "Strong"
                else if (pct >= 50) cls <- "Usable"
                else if (pct > 0) cls <- "Weak"
                
                monthly_comp_list[[length(monthly_comp_list)+1]] <- data.frame(
                    chunk_id = cid,
                    ym = ym,
                    project_station_id = pid,
                    city = s_city,
                    parameter = p,
                    expected_hour_count = exp_hr,
                    distinct_valid_hour_count = d,
                    source_null_value_count = n_null,
                    missing_hour_count = m_hour,
                    hourly_completeness_pct = pct,
                    first_observed_timestamp = ts_first,
                    last_observed_timestamp = ts_last,
                    quality_class = cls,
                    stringsAsFactors=FALSE
                )
            }
        }
    } else {
        # Empty chunk (might happen if completely failed or skipped)
        for (pid in unique(snap$project_station_id)) {
            s_city <- sel[sel$project_station_id == pid, "city"]
            for (p in c("pm2_5", "pm10", "no2", "so2", "co", "o3")) {
                monthly_comp_list[[length(monthly_comp_list)+1]] <- data.frame(
                    chunk_id = cid, ym = ym, project_station_id = pid, city = s_city, parameter = p,
                    expected_hour_count = exp_hr, distinct_valid_hour_count = 0, source_null_value_count = 0,
                    missing_hour_count = exp_hr, hourly_completeness_pct = 0, first_observed_timestamp = NA,
                    last_observed_timestamp = NA, quality_class = "No Data", stringsAsFactors=FALSE
                )
            }
        }
    }
}

m_comp <- do.call(rbind, monthly_comp_list)
write.csv(m_comp, "data/metadata/phase2B_monthly_completeness.csv", row.names=FALSE)

log_info("Generating Station History Summaries...")

# 3. History Summary
hist_list <- list()
for (pid in unique(snap$project_station_id)) {
    for (p in c("pm2_5", "pm10", "no2", "so2", "co", "o3")) {
        sub <- m_comp[m_comp$project_station_id == pid & m_comp$parameter == p, ]
        sub <- sub[order(sub$ym), ]
        
        tot_exp <- sum(sub$expected_hour_count)
        tot_val <- sum(sub$distinct_valid_hour_count)
        pct <- round(tot_val/tot_exp*100, 2)
        
        strong <- sum(sub$quality_class == "Strong")
        usable <- sum(sub$quality_class == "Usable")
        weak <- sum(sub$quality_class == "Weak")
        nd <- sum(sub$quality_class == "No Data")
        
        r <- rle(sub$quality_class %in% c("Weak", "No Data"))
        longest <- if (any(r$values)) max(r$lengths[r$values]) else 0
        
        ts_f <- min(sub$first_observed_timestamp, na.rm=TRUE)
        ts_l <- max(sub$last_observed_timestamp, na.rm=TRUE)
        
        readiness <- if (pct >= 75) "Ready" else if (pct >= 50) "Review" else "Reject"
        
        hist_list[[length(hist_list)+1]] <- data.frame(
            project_station_id = pid,
            parameter = p,
            total_expected_hours = tot_exp,
            total_valid_hours = tot_val,
            overall_completeness_pct = pct,
            months_strong = strong,
            months_usable = usable,
            months_weak = weak,
            months_no_data = nd,
            longest_consecutive_weak_months = longest,
            first_valid_timestamp = ts_f,
            last_valid_timestamp = ts_l,
            historical_readiness = readiness,
            stringsAsFactors=FALSE
        )
    }
}

h_comp <- do.call(rbind, hist_list)
write.csv(h_comp, "data/metadata/phase2B_station_history_summary.csv", row.names=FALSE)

hyd_sel <- sel$project_station_id[sel$use_hyderabad]
ind_sel <- sel$project_station_id[sel$use_india]

write.csv(h_comp[h_comp$project_station_id %in% hyd_sel, ], "data/metadata/phase2B_hyderabad_history_summary.csv", row.names=FALSE)
write.csv(h_comp[h_comp$project_station_id %in% ind_sel, ], "data/metadata/phase2B_india_history_summary.csv", row.names=FALSE)

log_info("Generating Quality Flags...")
# Quality flags
qf_list <- list()
for (pid in unique(snap$project_station_id)) {
    sub <- h_comp[h_comp$project_station_id == pid, ]
    pm25 <- sub[sub$parameter == "pm2_5", ]
    pm10 <- sub[sub$parameter == "pm10", ]
    
    if (nrow(pm25) > 0 && pm25$months_weak + pm25$months_no_data > 0) {
        qf_list[[length(qf_list)+1]] <- data.frame(project_station_id=pid, issue="PM2.5 has weak/no-data months", severity="Medium")
    }
    if (nrow(pm10) > 0 && pm10$months_weak + pm10$months_no_data > 0) {
        qf_list[[length(qf_list)+1]] <- data.frame(project_station_id=pid, issue="PM10 has weak/no-data months", severity="Medium")
    }
    if (max(sub$longest_consecutive_weak_months) >= 3) {
        qf_list[[length(qf_list)+1]] <- data.frame(project_station_id=pid, issue="3 or more consecutive weak/no-data months", severity="High")
    }
    if (all(sub$overall_completeness_pct < 50)) {
        qf_list[[length(qf_list)+1]] <- data.frame(project_station_id=pid, issue="All six pollutants weak overall", severity="Critical")
    }
}
qf <- if(length(qf_list)>0) do.call(rbind, qf_list) else data.frame(project_station_id=character(), issue=character(), severity=character())
write.csv(qf, "data/metadata/phase2B_quality_flags.csv", row.names=FALSE)

log_info("Phase 2B Normalization Complete.")
