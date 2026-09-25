source("R/00_setup.R")
source("R/01_utils.R")
library(httr2)
library(jsonlite)

log_info("Starting Alternate Open-Meteo Acquisition")

# Load existing selections to get coords
cat <- read.csv("data/metadata/station_catalog.csv", stringsAsFactors=F)
coords <- cat[cat$project_station_id %in% c("PROJ_094", "PROJ_135"), c("project_station_id", "station_name", "latitude", "longitude")]
coords <- coords[!duplicated(coords$project_station_id), ]

date_start <- "2025-03-01"
date_end <- "2025-03-31"

manifest_file <- "data/metadata/historical_acquisition_manifest.csv"
raw_dir <- "data/raw/weather/openmeteo/historical_alternate_pilot"
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

append_manifest <- function(record) {
    if (!file.exists(manifest_file)) {
        write.csv(record, manifest_file, row.names = FALSE)
    } else {
        write.table(record, manifest_file, append = TRUE, sep = ",", col.names = FALSE, row.names = FALSE)
    }
}

fetch_weather <- function(pid, lat, lon) {
    log_info(sprintf("Fetching weather for %s", pid))
    
    url <- sprintf("https://archive-api.open-meteo.com/v1/archive?latitude=%f&longitude=%f&start_date=%s&end_date=%s&hourly=temperature_2m,relative_humidity_2m,wind_speed_10m,wind_direction_10m&timezone=Asia%%2FKolkata&wind_speed_unit=ms",
                   lat, lon, date_start, date_end)
                   
    req <- request(url) |>
           req_error(is_error = function(resp) FALSE)
    
    resp <- req_perform(req)
    status_code <- resp_status(resp)
    
    if (status_code == 200) {
        body_txt <- resp_body_string(resp)
        ts_str <- format(Sys.time(), "%Y%m%dT%H%M%S")
        fname <- sprintf("%s_weather_2025_03_%s.json", pid, ts_str)
        fpath <- file.path(raw_dir, fname)
        writeLines(body_txt, fpath)
        
        h <- unname(tools::md5sum(fpath))
        
        parsed <- fromJSON(body_txt, simplifyVector=F)
        returned <- length(parsed$hourly$time)
        
        mf_row <- data.frame(
            retrieval_id = sprintf("openmeteo_%s", ts_str),
            source = "openmeteo",
            endpoint = "/v1/archive",
            project_station_id = pid,
            sensor_id = NA,
            period_label = "2025_03",
            page = 1,
            request_timestamp_utc = format(Sys.time(), tz="UTC", format="%Y-%m-%dT%H:%M:%SZ"),
            http_status = as.character(status_code),
            response_row_count = returned,
            x_ratelimit_limit = NA,
            x_ratelimit_remaining = NA,
            local_file = fpath,
            file_hash_md5 = h,
            notes = "phase2a1_kolkata_alternate_pilot",
            stringsAsFactors = FALSE
        )
        append_manifest(mf_row)
    } else {
        log_warn(sprintf("HTTP %d for %s", status_code, pid))
    }
}

for (i in 1:nrow(coords)) {
    fetch_weather(coords$project_station_id[i], coords$latitude[i], coords$longitude[i])
    Sys.sleep(1)
}

log_info("Alternate Open-Meteo Acquisition Complete")
