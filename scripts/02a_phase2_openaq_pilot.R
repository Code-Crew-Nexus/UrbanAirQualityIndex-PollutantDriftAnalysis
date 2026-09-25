source("R/00_setup.R")
source("R/01_utils.R")
library(httr2)
library(jsonlite)

log_info("Starting Phase 2A OpenAQ Pilot Acquisition")

# Load snapshots and state
snapshot <- read.csv("data/metadata/selected_sensor_snapshot.csv", stringsAsFactors=F)
state_file <- "data/metadata/historical_acquisition_state.csv"
manifest_file <- "data/metadata/historical_acquisition_manifest.csv"

if (!file.exists(state_file)) {
    state <- data.frame(
        project_station_id = character(),
        sensor_id = character(),
        parameter = character(),
        period = character(),
        page = integer(),
        status = character(),
        raw_file = character(),
        completed_at = character(),
        stringsAsFactors = F
    )
} else {
    state <- read.csv(state_file, stringsAsFactors=F)
}

if (!file.exists(manifest_file)) {
    manifest <- data.frame(
        retrieval_id = character(),
        local_file = character(),
        source = character(),
        source_type = character(),
        source_endpoint = character(),
        retrieved_at = character(),
        http_status = character(),
        request_start_datetime = character(),
        request_end_datetime = character(),
        project_station_id = character(),
        source_location_id = character(),
        sensor_id = character(),
        parameter = character(),
        page = integer(),
        api_found = character(),
        response_row_count = integer(),
        source_unit = character(),
        data_origin = character(),
        file_sha256 = character(),
        x_ratelimit_used = character(),
        x_ratelimit_limit = character(),
        x_ratelimit_remaining = character(),
        x_ratelimit_reset = character(),
        request_status = character(),
        notes = character(),
        stringsAsFactors = F
    )
    write.csv(manifest, manifest_file, row.names=F)
}

api_key <- Sys.getenv("OPENAQ_API_KEY")
has_key <- nchar(api_key) > 0

dt_from_utc <- "2025-02-28T18:30:00Z"
dt_to_utc <- "2025-03-31T18:29:59Z"
period_label <- "2025_03"

# Rate limit helper
handle_rate_limit <- function(resp) {
    if (is.null(resp)) return(NULL)
    rem <- resp_header(resp, "x-ratelimit-remaining")
    reset <- resp_header(resp, "x-ratelimit-reset")
    if (!is.null(rem) && as.numeric(rem) < 5) {
        if (!is.null(reset)) {
            reset_time <- as.numeric(reset)
            now <- as.numeric(Sys.time())
            wait <- max(0, reset_time - now) + 2
            log_warn(sprintf("Rate limit low. Waiting %d seconds.", round(wait)))
            Sys.sleep(wait)
        }
    }
}

for (i in 1:nrow(snapshot)) {
    pid <- snapshot$project_station_id[i]
    sid <- snapshot$sensor_id[i]
    param <- snapshot$parameter[i]
    loc_id <- snapshot$source_location_id[i]
    
    page <- 1
    more_pages <- TRUE
    
    while(more_pages) {
        # Check state
        state_key <- paste(pid, sid, param, period_label, page, sep="_")
        existing <- subset(state, paste(project_station_id, sensor_id, parameter, period, page, sep="_") == state_key)
        
        if (nrow(existing) > 0 && existing$status[1] %in% c("completed", "empty_valid_response")) {
            page <- page + 1
            if (existing$status[1] == "empty_valid_response") more_pages <- FALSE
            next
        }
        
        log_info(sprintf("Fetching %s | %s | %s | page %d", pid, param, sid, page))
        
        url <- sprintf("https://api.openaq.org/v3/sensors/%s/hours", sid)
        req <- request(url) |>
            req_url_query(datetime_from = dt_from_utc, datetime_to = dt_to_utc, limit = 1000, page = page) |>
            req_error(is_error = function(resp) FALSE) # Handle errors manually
            
        if (has_key) req <- req |> req_headers("X-API-Key" = api_key)
        
        resp <- req_perform(req)
        status_code <- resp_status(resp)
        
        # Log rate limit info
        rl_used <- resp_header(resp, "x-ratelimit-used")
        rl_limit <- resp_header(resp, "x-ratelimit-limit")
        rl_rem <- resp_header(resp, "x-ratelimit-remaining")
        rl_reset <- resp_header(resp, "x-ratelimit-reset")
        
        if (status_code == 429) {
            log_warn("429 Too Many Requests. Waiting and retrying...")
            handle_rate_limit(resp)
            Sys.sleep(60) # Fallback wait
            next
        }
        
        raw_body <- resp_body_string(resp)
        parsed <- tryCatch(fromJSON(raw_body, simplifyVector=F), error=function(e) NULL)
        
        row_count <- 0
        api_found <- NA
        req_status <- "failed"
        state_status <- "failed_terminal"
        out_file <- NA
        
        if (status_code == 200 && !is.null(parsed)) {
            row_count <- length(parsed$results)
            api_found <- as.character(parsed$meta$found)
            if (is.null(api_found)) api_found <- "0"
            
            req_status <- "success"
            state_status <- ifelse(row_count > 0, "completed", "empty_valid_response")
            
            # Save raw file
            dir_path <- sprintf("data/raw/air_quality/openaq/historical/%s/%s", pid, param)
            dir.create(dir_path, recursive=TRUE, showWarnings=FALSE)
            ts_str <- format(Sys.time(), "%Y%m%dT%H%M%S")
            fname <- sprintf("%s_%s_%s_%s_p%d_%s.json", pid, sid, param, period_label, page, ts_str)
            out_file <- file.path(dir_path, fname)
            writeLines(raw_body, out_file)
            
            if (row_count < 1000) {
                more_pages <- FALSE
            }
        } else {
            log_warn(sprintf("HTTP %d for %s", status_code, sid))
            more_pages <- FALSE
        }
        
        # Append to manifest
        hash <- ifelse(!is.na(out_file), digest::digest(out_file, algo="sha256", file=TRUE), NA)
        local_file_path <- ifelse(!is.na(out_file), gsub("\\\\", "/", out_file), NA)
        
        mf_row <- data.frame(
            retrieval_id = sprintf("REQ_%s", format(Sys.time(), "%Y%m%d%H%M%S")),
            local_file = local_file_path,
            source = "openaq",
            source_type = "historical_hourly",
            source_endpoint = "/sensors/hours",
            retrieved_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
            http_status = as.character(status_code),
            request_start_datetime = dt_from_utc,
            request_end_datetime = dt_to_utc,
            project_station_id = pid,
            source_location_id = as.character(loc_id),
            sensor_id = as.character(sid),
            parameter = param,
            page = page,
            api_found = api_found,
            response_row_count = row_count,
            source_unit = snapshot$source_unit[i],
            data_origin = "external_api",
            file_sha256 = hash,
            x_ratelimit_used = as.character(rl_used),
            x_ratelimit_limit = as.character(rl_limit),
            x_ratelimit_remaining = as.character(rl_rem),
            x_ratelimit_reset = as.character(rl_reset),
            request_status = req_status,
            notes = ifelse(status_code==200, "success", sprintf("HTTP %d", status_code)),
            stringsAsFactors = FALSE
        )
        write.table(mf_row, manifest_file, sep=",", append=TRUE, row.names=FALSE, col.names=FALSE)
        
        # Append to state
        st_row <- data.frame(
            project_station_id = pid,
            sensor_id = as.character(sid),
            parameter = param,
            period = period_label,
            page = page,
            status = state_status,
            raw_file = local_file_path,
            completed_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
            stringsAsFactors = FALSE
        )
        state <- rbind(state, st_row)
        write.csv(state, state_file, row.names=FALSE)
        
        if (more_pages) page <- page + 1
        
        handle_rate_limit(resp)
        Sys.sleep(1) # Gentle pacing
    }
}
log_info("OpenAQ Pilot Acquisition Complete")
