source("R/00_setup.R")
source("R/01_utils.R")
source("R/02_phase2_provenance.R")
library(httr2)
library(jsonlite)

log_info("Starting Phase 2B Weather Acquisition")

sel <- read.csv("config/selected_stations.csv", stringsAsFactors=FALSE)
if (nrow(sel) != 21) stop(paste("Expected 21 selected stations, got", nrow(sel)))

start_date <- "2025-04-01"
end_date <- "2026-09-21"
start_utc <- "2025-04-01T00:00:00Z"
end_utc <- "2026-09-21T23:59:59Z"

out_dir <- "data/raw/weather/openmeteo/historical"
dir.create(out_dir, recursive=TRUE, showWarnings=FALSE)

for (i in 1:nrow(sel)) {
    pid <- sel$project_station_id[i]
    lat <- sel$latitude[i]
    lon <- sel$longitude[i]
    
    # Check if already acquired for this period (we can just check if file exists with this date range)
    existing <- list.files(out_dir, pattern=sprintf("^%s_weather_%s_to_%s_.*\\.json$", pid, start_date, end_date), full.names=TRUE)
    if (length(existing) > 0) {
        log_info(sprintf("Skipping %s, already acquired", pid))
        next
    }
    
    log_info(sprintf("Fetching weather for %s", pid))
    
    url <- sprintf("https://archive-api.open-meteo.com/v1/archive?latitude=%f&longitude=%f&start_date=%s&end_date=%s&hourly=temperature_2m,relative_humidity_2m,wind_speed_10m,wind_direction_10m&wind_speed_unit=ms&timezone=Asia%%2FKolkata",
                   lat, lon, start_date, end_date)
    
    req <- request(url) |> req_timeout(30) |> req_error(is_error = function(resp) FALSE)
    resp <- tryCatch(req_perform(req), error = function(e) e)
    
    if (inherits(resp, "error")) {
        log_error(sprintf("Network error for %s: %s", pid, conditionMessage(resp)))
        Sys.sleep(5)
        next
    }
    
    status_code <- resp_status(resp)
    if (status_code == 200) {
        body_txt <- resp_body_string(resp)
        parsed <- tryCatch(fromJSON(body_txt, simplifyVector=FALSE), error=function(e) NULL)
        if (is.null(parsed)) next
        
        ts_str <- format(Sys.time(), "%Y%m%dT%H%M%S", tz="Asia/Kolkata")
        fname <- sprintf("%s_weather_%s_to_%s_%s.json", pid, start_date, end_date, ts_str)
        fpath <- file.path(out_dir, fname)
        writeLines(body_txt, fpath)
        
        rec <- list(
            retrieval_id = sprintf("openmeteo_%s", ts_str),
            local_file = fpath,
            source = "openmeteo",
            source_type = "historical_hourly",
            source_endpoint = "/v1/archive",
            retrieved_at = Sys.time(),
            http_status = status_code,
            request_start_datetime = start_utc,
            request_end_datetime = end_utc,
            project_station_id = pid,
            source_location_id = NA,
            sensor_id = NA,
            parameter = NA,
            page = NA,
            api_found = NA,
            response_row_count = length(parsed$hourly$time),
            source_unit = NA,
            data_origin = "phase2B_historical_acquisition",
            file_sha256 = digest::digest(fpath, algo="sha256", file=TRUE),
            request_status = "SUCCESS"
        )
        append_historical_manifest(rec)
        
    } else {
        log_warn(sprintf("HTTP %d for %s", status_code, pid))
    }
    
    Sys.sleep(1) # Be nice
}

log_info("Phase 2B Weather Acquisition Complete.")
