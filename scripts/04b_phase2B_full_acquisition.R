source("R/00_setup.R")
source("R/01_utils.R")
source("R/02_phase2_provenance.R")
library(httr2)
library(jsonlite)

log_info("Starting Phase 2B Full Acquisition (Stage 2)")

# Pre-flight check
log_info("Running pre-flight checks...")
sel <- read.csv("config/selected_stations.csv", stringsAsFactors=FALSE)
if (nrow(sel[sel$city == "Kolkata", ]) != 1 || sel[sel$city == "Kolkata", "project_station_id"] != "PROJ_094") stop("Jadavpur is not the selected Kolkata station.")
if ("PROJ_104" %in% sel$project_station_id) stop("Fort William is still selected.")
if (nrow(sel) != 21) stop(paste("Expected 21 selected stations, got", nrow(sel)))

snap <- read.csv("data/metadata/selected_sensor_snapshot.csv", stringsAsFactors=FALSE)
if (nrow(snap) != 126) stop(paste("Expected 126 selected sensors, got", nrow(snap)))

mf <- read.csv("data/metadata/historical_acquisition_manifest.csv", stringsAsFactors=FALSE)
if (ncol(mf) != 25) stop(paste("Manifest column count mismatch. Expected 25, got", ncol(mf)))

plan <- read.csv("data/metadata/phase2B_acquisition_plan.csv", stringsAsFactors=FALSE)
state_file <- "data/metadata/phase2B_acquisition_state.csv"
if (!file.exists(state_file)) stop("Phase 2B acquisition state not initialized.")
state_df <- read.csv(state_file, stringsAsFactors=FALSE)

openaq_key <- Sys.getenv("OPENAQ_API_KEY")
if (openaq_key == "") stop("OPENAQ_API_KEY not found in environment")

# Helper to update state
update_state <- function(row_idx, status, api_found, response_row_count, page_count, raw_files, http_status, err_msg) {
    state_df$status[row_idx] <<- status
    if (is.na(state_df$first_attempt_at[row_idx])) state_df$first_attempt_at[row_idx] <<- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz="UTC")
    if (status %in% c("completed", "empty_valid_response", "failed_terminal")) {
        state_df$completed_at[row_idx] <<- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz="UTC")
    }
    state_df$attempt_count[row_idx] <<- state_df$attempt_count[row_idx] + 1
    state_df$api_found[row_idx] <<- api_found
    state_df$response_row_count[row_idx] <<- response_row_count
    state_df$page_count[row_idx] <<- page_count
    if (nchar(raw_files) > 0) {
        existing <- state_df$raw_files[row_idx]
        state_df$raw_files[row_idx] <<- ifelse(is.na(existing) || nchar(existing)==0, raw_files, paste(existing, raw_files, sep=";"))
    }
    state_df$last_http_status[row_idx] <<- http_status
    state_df$error_message[row_idx] <<- err_msg
    write.csv(state_df, state_file, row.names=FALSE)
}

# The main acquisition loop
limit <- 1000

for (i in 1:nrow(state_df)) {
    rec <- state_df[i, ]
    
    if (rec$status %in% c("completed", "empty_valid_response", "failed_terminal")) {
        next
    }
    
    chunk <- plan[plan$chunk_id == rec$chunk_id, ]
    chunk_label <- format(as.Date(chunk$local_start_date), "%Y_%m")
    
    pid <- rec$project_station_id
    sid <- rec$sensor_id
    param <- rec$parameter
    
    page <- rec$page_count + 1
    if (is.na(page) || page < 1) page <- 1
    
    # We use while loop for pagination
    while (TRUE) {
        log_info(sprintf("Fetching %s | %s | %s | %s | page %d", pid, param, sid, chunk_label, page))
        url <- sprintf("https://api.openaq.org/v3/sensors/%s/hours?datetime_from=%s&datetime_to=%s&limit=%d&page=%d",
                       sid, rec$request_start_datetime, rec$request_end_datetime, limit, page)
        
        req <- request(url) |>
               req_headers("X-API-Key" = openaq_key) |>
               req_timeout(30) |>
               req_error(is_error = function(resp) FALSE) # manual handling
        
        req_start <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz="UTC")
        resp <- tryCatch(req_perform(req), error = function(e) e)
        req_end <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz="UTC")
        
        if (inherits(resp, "error")) {
            log_error(sprintf("Network error: %s", conditionMessage(resp)))
            update_state(i, "failed_retryable", NA, NA, page - 1, "", NA, conditionMessage(resp))
            Sys.sleep(5)
            break # break inner pagination loop, will resume on script rerun
        }
        
        status_code <- resp_status(resp)
        headers <- resp_headers(resp)
        
        rl_used <- as.numeric(headers$`x-ratelimit-used`)
        rl_limit <- as.numeric(headers$`x-ratelimit-limit`)
        rl_rem <- as.numeric(headers$`x-ratelimit-remaining`)
        rl_reset <- as.numeric(headers$`x-ratelimit-reset`) # Seconds until reset!
        
        if (status_code == 200) {
            body_txt <- resp_body_string(resp)
            parsed <- tryCatch(fromJSON(body_txt, simplifyVector = FALSE), error = function(e) NULL)
            if (is.null(parsed)) {
                log_error("Invalid JSON response")
                update_state(i, "failed_retryable", NA, NA, page - 1, "", 200, "Invalid JSON response")
                break
            }
            
            found <- parsed$meta$found
            returned <- length(parsed$results)
            
            # Storage
            ts_str <- format(Sys.time(), "%Y%m%dT%H%M%S", tz="Asia/Kolkata")
            fname <- sprintf("%s_%s_%s_%s_p%d_%s.json", pid, sid, param, chunk_label, page, ts_str)
            target_dir <- file.path("data/raw/air_quality/openaq/historical", pid, param)
            dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)
            fpath <- file.path(target_dir, fname)
            writeLines(body_txt, fpath)
            
            # Find meta info
            meta_row <- snap[snap$project_station_id == pid & snap$sensor_id == sid, ]
            
            mf_rec <- list(
                retrieval_id = sprintf("openaq_%s", ts_str),
                local_file = fpath,
                source = "openaq",
                source_type = "historical_hourly",
                source_endpoint = "/sensors/hours",
                retrieved_at = Sys.time(),
                http_status = status_code,
                request_start_datetime = rec$request_start_datetime,
                request_end_datetime = rec$request_end_datetime,
                project_station_id = pid,
                source_location_id = meta_row$source_location_id[1],
                sensor_id = sid,
                parameter = param,
                page = page,
                api_found = found,
                response_row_count = returned,
                source_unit = meta_row$source_unit[1],
                data_origin = "phase2B_historical_acquisition",
                file_sha256 = digest::digest(fpath, algo="sha256", file=TRUE),
                x_ratelimit_used = rl_used,
                x_ratelimit_limit = rl_limit,
                x_ratelimit_remaining = rl_rem,
                x_ratelimit_reset = rl_reset,
                request_status = "SUCCESS",
                notes = ""
            )
            append_historical_manifest(mf_rec)
            
            final_status <- "in_progress"
            if (is.null(found) || found == 0) {
                final_status <- "empty_valid_response"
            } else if (found <= (page * limit)) {
                final_status <- "completed"
            }
            
            update_state(i, final_status, found, returned, page, fpath, 200, "")
            
            if (final_status %in% c("completed", "empty_valid_response")) {
                Sys.sleep(2) # Safe pacing
                break
            } else {
                page <- page + 1
                Sys.sleep(2)
                next
            }
            
        } else if (status_code == 429) {
            wait_time <- if (!is.na(rl_reset) && rl_reset > 0) rl_reset + 2 else 60
            if (!is.null(headers$`retry-after`)) wait_time <- as.numeric(headers$`retry-after`) + 2
            log_warn(sprintf("Rate limit hit! Sleeping %s seconds...", wait_time))
            Sys.sleep(wait_time)
            next
        } else if (status_code %in% c(408, 500, 502, 503, 504)) {
            log_warn(sprintf("Transient HTTP %d. Will retry later.", status_code))
            update_state(i, "failed_retryable", NA, NA, page - 1, "", status_code, "Transient server error")
            Sys.sleep(5)
            break
        } else {
            log_warn(sprintf("Terminal HTTP %d for %s", status_code, sid))
            
            mf_rec <- list(
                retrieval_id = sprintf("openaq_%s", format(Sys.time(), "%Y%m%dT%H%M%S", tz="Asia/Kolkata")),
                local_file = NA,
                source = "openaq",
                source_type = "historical_hourly",
                source_endpoint = "/sensors/hours",
                retrieved_at = Sys.time(),
                http_status = status_code,
                request_start_datetime = rec$request_start_datetime,
                request_end_datetime = rec$request_end_datetime,
                project_station_id = pid,
                source_location_id = meta_row$source_location_id[1],
                sensor_id = sid,
                parameter = param,
                page = page,
                api_found = NA,
                response_row_count = 0,
                source_unit = NA,
                data_origin = "phase2B_historical_acquisition",
                file_sha256 = NA,
                x_ratelimit_used = rl_used,
                x_ratelimit_limit = rl_limit,
                x_ratelimit_remaining = rl_rem,
                x_ratelimit_reset = rl_reset,
                request_status = "FAILED",
                notes = "Terminal error"
            )
            append_historical_manifest(mf_rec)
            update_state(i, "failed_terminal", NA, 0, page - 1, "", status_code, "Terminal HTTP code")
            break
        }
    }
}

log_info("Phase 2B OpenAQ Acquisition Script Finished/Interrupted.")
