source("R/00_setup.R")
source("R/01_utils.R")
library(httr2)
library(jsonlite)

log_info("Starting Kolkata Alternate Pilot Acquisition (OpenAQ)")

# Load alternate sensors
snap <- read.csv("data/metadata/phase2a1_kolkata_alternate_sensors.csv", stringsAsFactors = FALSE)

# Setup date range (same as pilot)
date_start <- "2025-03-01"
date_end <- "2025-03-31"
utc_from <- format(as.POSIXct(paste0(date_start, " 00:00:00"), tz="Asia/Kolkata"), tz="UTC", format="%Y-%m-%dT%H:%M:%SZ")
utc_to <- format(as.POSIXct(paste0(date_end, " 23:59:59"), tz="Asia/Kolkata"), tz="UTC", format="%Y-%m-%dT%H:%M:%SZ")

openaq_key <- Sys.getenv("OPENAQ_API_KEY")
if (openaq_key == "") stop("OPENAQ_API_KEY not found in environment")

# File paths
state_file <- "data/metadata/phase2a1_kolkata_acquisition_state.csv"
manifest_file <- "data/metadata/historical_acquisition_manifest.csv"
raw_dir <- "data/raw/air_quality/openaq/historical_alternate_pilot"
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

# Load existing state if any
if (file.exists(state_file)) {
    state_df <- read.csv(state_file, stringsAsFactors = FALSE)
} else {
    state_df <- data.frame(project_station_id=character(), sensor_id=character(), parameter=character(), 
                           period=character(), page=integer(), status=character(), raw_file=character(), 
                           completed_at=character(), stringsAsFactors=FALSE)
}

append_manifest <- function(record) {
    if (!file.exists(manifest_file)) {
        write.csv(record, manifest_file, row.names = FALSE)
    } else {
        write.table(record, manifest_file, append = TRUE, sep = ",", col.names = FALSE, row.names = FALSE)
    }
}

update_state <- function(pid, sid, param, period, page, status, raw_file) {
    row <- data.frame(
        project_station_id = pid, sensor_id = sid, parameter = param,
        period = period, page = page, status = status, raw_file = raw_file,
        completed_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ"), stringsAsFactors = FALSE
    )
    if (!file.exists(state_file)) {
        write.csv(row, state_file, row.names = FALSE)
    } else {
        write.table(row, state_file, append = TRUE, sep = ",", col.names = FALSE, row.names = FALSE)
    }
}

fetch_openaq_hours <- function(pid, sid, param, p_start, p_end, period_label) {
    page <- 1
    limit <- 1000
    
    repeat {
        # Check state
        is_done <- FALSE
        if (nrow(state_df) > 0) {
            match <- state_df[state_df$project_station_id == pid & state_df$sensor_id == sid & 
                              state_df$period == period_label & state_df$page == page & state_df$status == "SUCCESS", ]
            if (nrow(match) > 0) is_done <- TRUE
        }
        
        if (is_done) {
            log_info(sprintf("Skipping %s | %s | %s | page %d (already downloaded)", pid, param, sid, page))
            # Just read the file to figure out if we need to paginate further?
            # We assume if page 1 is done, maybe page 2 was needed. To be safe we should check the file.
            # But there's only 744 hours per month. Limit is 1000. It will fit in 1 page.
            break
        }
        
        log_info(sprintf("Fetching %s | %s | %s | page %d", pid, param, sid, page))
        url <- sprintf("https://api.openaq.org/v3/sensors/%s/hours?datetime_from=%s&datetime_to=%s&limit=%d&page=%d",
                       sid, p_start, p_end, limit, page)
        
        req <- request(url) |>
               req_headers("X-API-Key" = openaq_key) |>
               req_error(is_error = function(resp) FALSE) # manual handling
        
        resp <- req_perform(req)
        status_code <- resp_status(resp)
        headers <- resp_headers(resp)
        rl_limit <- headers$`x-ratelimit-limit`
        rl_remaining <- headers$`x-ratelimit-remaining`
        
        if (status_code == 200) {
            body_txt <- resp_body_string(resp)
            parsed <- fromJSON(body_txt, simplifyVector = FALSE)
            found <- parsed$meta$found
            returned <- length(parsed$results)
            
            # Save raw file
            ts_str <- format(Sys.time(), "%Y%m%dT%H%M%S")
            fname <- sprintf("%s_%s_%s_%s_p%d_%s.json", pid, sid, param, period_label, page, ts_str)
            target_dir <- file.path(raw_dir, pid, param)
            dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)
            fpath <- file.path(target_dir, fname)
            writeLines(body_txt, fpath)
            
            # Hash
            h <- unname(tools::md5sum(fpath))
            
            # Manifest
            mf_row <- data.frame(
                retrieval_id = sprintf("openaq_%s", ts_str),
                source = "openaq",
                endpoint = "/v3/sensors/hours",
                project_station_id = pid,
                sensor_id = sid,
                period_label = period_label,
                page = page,
                request_timestamp_utc = format(Sys.time(), tz="UTC", format="%Y-%m-%dT%H:%M:%SZ"),
                http_status = as.character(status_code),
                response_row_count = returned,
                x_ratelimit_limit = ifelse(is.null(rl_limit), NA, rl_limit),
                x_ratelimit_remaining = ifelse(is.null(rl_remaining), NA, rl_remaining),
                local_file = fpath,
                file_hash_md5 = h,
                notes = "phase2a1_kolkata_alternate_pilot",
                stringsAsFactors = FALSE
            )
            append_manifest(mf_row)
            
            # State
            update_state(pid, sid, param, period_label, page, "SUCCESS", fpath)
            
            if (!is.null(found) && !is.null(returned) && found > (page * limit)) {
                page <- page + 1
                Sys.sleep(1) # Be nice
                next
            } else {
                break
            }
            
        } else if (status_code == 429) {
            log_warn("Rate limit hit! Sleeping 60s...")
            Sys.sleep(60)
            next
        } else {
            log_warn(sprintf("HTTP %d for %s", status_code, sid))
            update_state(pid, sid, param, period_label, page, "FAILED", NA)
            break
        }
    }
}

for (i in 1:nrow(snap)) {
    fetch_openaq_hours(snap$project_station_id[i], snap$sensor_id[i], snap$parameter[i], utc_from, utc_to, "2025_03")
    Sys.sleep(1.5)
}

log_info("Alternate OpenAQ Pilot Acquisition Complete")
