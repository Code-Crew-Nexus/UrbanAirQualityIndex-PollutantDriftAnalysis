source("R/00_setup.R")
source("R/01_utils.R")
library(httr2)
library(jsonlite)

log_info("Starting Phase 2A Open-Meteo Pilot Acquisition")

sel <- read.csv("config/selected_stations.csv", stringsAsFactors=F)
# Verify we have exactly 21 unique
if (nrow(sel) != 21) stop("Expected exactly 21 selected stations.")

state_file <- "data/metadata/historical_acquisition_state.csv"
manifest_file <- "data/metadata/historical_acquisition_manifest.csv"

# Load state and manifest if exist (should exist from OpenAQ script)
if (!file.exists(state_file) || !file.exists(manifest_file)) {
    stop("State or manifest missing. Run OpenAQ pilot first.")
}

state <- read.csv(state_file, stringsAsFactors=F)

start_date <- "2025-03-01"
end_date <- "2025-03-31"
period_label <- "2025_03"

for (i in 1:nrow(sel)) {
    pid <- sel$project_station_id[i]
    lat <- sel$latitude[i]
    lon <- sel$longitude[i]
    
    # Check state
    state_key <- paste(pid, "weather", "weather", period_label, "1", sep="_")
    existing <- subset(state, paste(project_station_id, sensor_id, parameter, period, page, sep="_") == state_key)
    
    if (nrow(existing) > 0 && existing$status[1] %in% c("completed")) {
        log_info(sprintf("Skipping completed weather for %s", pid))
        next
    }
    
    log_info(sprintf("Fetching weather for %s", pid))
    
    url <- "https://archive-api.open-meteo.com/v1/archive"
    req <- request(url) |>
        req_url_query(
            latitude = lat,
            longitude = lon,
            start_date = start_date,
            end_date = end_date,
            hourly = "temperature_2m,relative_humidity_2m,wind_speed_10m,wind_direction_10m",
            wind_speed_unit = "ms",
            timezone = "Asia/Kolkata"
        ) |>
        req_error(is_error = function(resp) FALSE)
        
    resp <- req_perform(req)
    status_code <- resp_status(resp)
    raw_body <- resp_body_string(resp)
    
    parsed <- tryCatch(fromJSON(raw_body, simplifyVector=F), error=function(e) NULL)
    
    row_count <- 0
    api_found <- NA
    req_status <- "failed"
    state_status <- "failed_terminal"
    out_file <- NA
    
    if (status_code == 200 && !is.null(parsed)) {
        row_count <- length(parsed$hourly$time)
        req_status <- "success"
        state_status <- "completed"
        
        dir_path <- sprintf("data/raw/weather/openmeteo/historical/%s", pid)
        dir.create(dir_path, recursive=TRUE, showWarnings=FALSE)
        ts_str <- format(Sys.time(), "%Y%m%dT%H%M%S")
        fname <- sprintf("%s_weather_%s_%s.json", pid, period_label, ts_str)
        out_file <- file.path(dir_path, fname)
        writeLines(raw_body, out_file)
    } else {
        log_warn(sprintf("HTTP %d for weather %s", status_code, pid))
    }
    
    # Append to manifest
    hash <- ifelse(!is.na(out_file), digest::digest(out_file, algo="sha256", file=TRUE), NA)
    local_file_path <- ifelse(!is.na(out_file), gsub("\\\\", "/", out_file), NA)
    
    mf_row <- data.frame(
        retrieval_id = sprintf("REQ_%s", format(Sys.time(), "%Y%m%d%H%M%S%OS3")),
        local_file = local_file_path,
        source = "openmeteo",
        source_type = "historical_hourly",
        source_endpoint = "/v1/archive",
        retrieved_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
        http_status = as.character(status_code),
        request_start_datetime = start_date,
        request_end_datetime = end_date,
        project_station_id = pid,
        source_location_id = NA,
        sensor_id = NA,
        parameter = "weather",
        page = 1,
        api_found = NA,
        response_row_count = row_count,
        source_unit = NA,
        data_origin = "external_api",
        file_sha256 = hash,
        x_ratelimit_used = NA,
        x_ratelimit_limit = NA,
        x_ratelimit_remaining = NA,
        x_ratelimit_reset = NA,
        request_status = req_status,
        notes = ifelse(status_code==200, "success", sprintf("HTTP %d", status_code)),
        stringsAsFactors = FALSE
    )
    write.table(mf_row, manifest_file, sep=",", append=TRUE, row.names=FALSE, col.names=FALSE)
    
    # Append to state
    st_row <- data.frame(
        project_station_id = pid,
        sensor_id = "weather",
        parameter = "weather",
        period = period_label,
        page = 1,
        status = state_status,
        raw_file = local_file_path,
        completed_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
        stringsAsFactors = FALSE
    )
    state <- rbind(state, st_row)
    write.csv(state, state_file, row.names=FALSE)
    
    Sys.sleep(1)
}
log_info("Open-Meteo Pilot Acquisition Complete")
