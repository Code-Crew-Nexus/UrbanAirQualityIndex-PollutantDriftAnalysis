source("R/00_setup.R")
source("R/01_utils.R")
source("R/sources/openaq_source.R")
source("R/20_air_quality_ingestion.R")
source("R/10_station_catalog.R")

log_info("Starting Stage B: Shortlist Coverage Audit (1.5E Corrected)")

shortlist_path <- "data/metadata/india_station_shortlist.csv"
if (!file.exists(shortlist_path)) {
  stop("india_station_shortlist.csv not found")
}

shortlist <- read.csv(shortlist_path, stringsAsFactors = FALSE)
shortlist <- subset(shortlist, shortlist_status == "Recommended for coverage audit")

# 1. Fetch all sensors for the shortlist
sensor_list <- list()

for (i in seq_len(nrow(shortlist))) {
  row <- shortlist[i, ]
  loc_id <- row$source_location_id
  proj_id <- row$project_station_id
  
  log_info(sprintf("Fetching sensor metadata for %s (Location %s)", proj_id, loc_id))
  
  resp <- openaq_request(sprintf("/locations/%s/sensors", loc_id))
  if (httr2::resp_status(resp) == 200) {
     body_text <- httr2::resp_body_string(resp)
     parsed <- jsonlite::fromJSON(body_text, simplifyVector = FALSE)
     sensors <- parsed$results
     if (!is.null(sensors)) {
       for (s in sensors) {
          sid <- as.character(s$id)
          param <- safe_extract(s$parameter$name)
          unit <- safe_extract(s$parameter$units)
          dt_first <- safe_extract(s$datetimeFirst$utc)
          dt_last <- safe_extract(s$datetimeLast$utc)
          
          # Safely parse raw lifetime coverage which can be > 100%
          cov_exp <- suppressWarnings(as.numeric(safe_extract(s$coverage$expectedCount)))
          cov_obs <- suppressWarnings(as.numeric(safe_extract(s$coverage$observedCount)))
          cov_pc_comp <- suppressWarnings(as.numeric(safe_extract(s$coverage$percentComplete)))
          cov_pc_cov <- suppressWarnings(as.numeric(safe_extract(s$coverage$percentCoverage)))
          
          # Detect anomalies
          anom <- FALSE
          if (!is.na(cov_pc_comp) && (cov_pc_comp > 100 || cov_pc_comp < 0)) anom <- TRUE
          if (!is.na(cov_pc_cov) && (cov_pc_cov > 100 || cov_pc_cov < 0)) anom <- TRUE
          
          sensor_list[[length(sensor_list) + 1]] <- data.frame(
             project_station_id = proj_id,
             source_location_id = loc_id,
             station_name = row$station_name,
             city = row$city,
             sensor_id = sid,
             parameter = param,
             source_unit = unit,
             canonical_target_unit = "µg/m³",
             unit_compatibility_status = ifelse(!is.na(unit) && unit %in% c("µg/m³", "ug/m³", "ug/m3", "µg/m3", "mg/m³", "mg/m3"), "canonical", "conversion_required_later"),
             sensor_datetime_first = dt_first,
             sensor_datetime_last = dt_last,
             source_lifetime_coverage_expected_count = cov_exp,
             source_lifetime_coverage_observed_count = cov_obs,
             source_lifetime_percent_complete_raw = cov_pc_comp,
             source_lifetime_percent_coverage_raw = cov_pc_cov,
             source_lifetime_coverage_anomalous = anom,
             stringsAsFactors = FALSE
          )
       }
     }
  }
}

if (length(sensor_list) == 0) {
   stop("No sensors retrieved from API.")
}
sc_df <- do.call(rbind, sensor_list)

# 2. Assign preferred sensor generations
sc_df$sensor_generation_status <- "inactive"
sc_df$dt_last_parsed <- as.POSIXct(sc_df$sensor_datetime_last, format="%Y-%m-%dT%H:%M:%S", tz="UTC")

sc_df <- select_preferred_sensor(sc_df)
sc_df$dt_last_parsed <- NULL # clean up

write.csv(sc_df, "data/metadata/sensor_catalog.csv", row.names = FALSE)
log_info("Created data/metadata/sensor_catalog.csv with generation statuses.")

# 3. Fetch 30-day coverage ONLY for preferred_current core pollutants
core_polls <- c("pm25", "pm10", "no2", "so2", "co", "o3")
pref_sensors <- subset(sc_df, sensor_generation_status == "preferred_current" & parameter %in% core_polls)

coverage_report <- list()
audit_end <- Sys.Date()
audit_start <- audit_end - 29 # Exact 30 days inclusive
audit_start_str <- format(audit_start, "%Y-%m-%d")
audit_end_str <- format(audit_end, "%Y-%m-%d")

ensure_dir("data/raw/air_quality/openaq/coverage")
source("R/11_station_coverage_audit.R")

# API CONTRACT TEST FOR /days
if (nrow(pref_sensors) > 0) {
   test_sensor <- pref_sensors$sensor_id[1]
   log_info(sprintf("Running API contract test for /days endpoint on sensor %s", test_sensor))
   test_resp <- openaq_request(sprintf("/sensors/%s/days", test_sensor), list(date_from = audit_start_str, date_to = audit_end_str, limit = 5))
   if (httr2::resp_status(test_resp) != 200) {
      stop("API Contract Test failed: Did not return HTTP 200.")
   }
   test_parsed <- jsonlite::fromJSON(httr2::resp_body_string(test_resp), simplifyVector = FALSE)
   test_results <- test_parsed$results
   if (length(test_results) > 0) {
      test_dt_loc <- safe_extract(test_results[[1]]$period$datetimeFrom$local)
      if (!is.na(test_dt_loc)) {
         test_date <- as.Date(substr(test_dt_loc, 1, 10))
         if (test_date < audit_start || test_date > audit_end) {
            stop(sprintf("API Contract Test failed: Returned date %s falls outside requested interval %s to %s.", test_date, audit_start, audit_end))
         }
      }
   }
   log_info("API Contract Test passed.")
}


for (i in seq_len(nrow(pref_sensors))) {
   s <- pref_sensors[i, ]
   sid <- s$sensor_id
   param <- s$parameter
   
   log_info(sprintf("Fetching daily coverage for preferred sensor %s (%s)", sid, param))
   
   # Correct query parameters for /days: date_from, date_to
   day_resp <- openaq_request(sprintf("/sensors/%s/days", sid), list(date_from = audit_start_str, date_to = audit_end_str, limit = 100))
   
   distinct_valid_dates <- 0
   days_with_data_pct <- NA
   api_pc_comp_mean <- NA
   api_pc_cov_mean <- NA
   api_cov_anom <- 0
   
   recent_data_present <- FALSE
   
   if (httr2::resp_status(day_resp) == 200) {
      body_text <- httr2::resp_body_string(day_resp)
      
      # Save EVERY coverage response used
      base_dir <- "data/raw/air_quality/openaq/coverage"
      base_filename <- sprintf("sensor_%s_days_%s_%s.json", sid, audit_start_str, audit_end_str)
      raw_file <- save_raw_response_immutable(base_dir, base_filename, body_text)
      
      day_parsed <- jsonlite::fromJSON(body_text, simplifyVector = FALSE)
      days_data <- day_parsed$results
      row_count <- length(days_data)
      
      req_status <- ifelse(row_count > 0, "http_success_with_data", "http_success_empty")
      append_to_manifest(raw_file, "openaq", "daily_coverage", "/sensors/days", audit_start_str, audit_end_str, s$source_location_id, sid, row_count, http_status = 200, notes = req_status)
      
      sum_out <- summarize_coverage(days_data, audit_start, audit_end)
      distinct_valid_dates <- sum_out$distinct_valid_dates
      days_with_data_pct <- sum_out$days_with_data_pct
      api_pc_comp_mean <- sum_out$api_pc_comp_mean
      api_pc_cov_mean <- sum_out$api_pc_cov_mean
      api_cov_anom <- sum_out$api_cov_anom
      recent_data_present <- distinct_valid_dates > 0
   } else {
      # Log failed request
      append_to_manifest(NA, "openaq", "daily_coverage", "/sensors/days", audit_start_str, audit_end_str, s$source_location_id, sid, 0, http_status = httr2::resp_status(day_resp), notes = "Failed request")
   }
   
   rec_stat <- "Not recommended"
   rec_reason <- "Insufficient coverage"
   if (!is.na(days_with_data_pct) && days_with_data_pct >= 50) {
      rec_stat <- "Recommended"
      rec_reason <- "Adequate recent daily coverage"
   }
   
   coverage_report[[length(coverage_report) + 1]] <- data.frame(
      project_station_id = s$project_station_id,
      source_location_id = s$source_location_id,
      station_name = s$station_name,
      city = s$city,
      sensor_id = sid,
      parameter = param,
      sensor_status = s$sensor_generation_status,
      audit_window_start = audit_start_str,
      audit_window_end = audit_end_str,
      audit_generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z", tz = "Asia/Kolkata"),
      days_with_data = distinct_valid_dates,
      days_expected = as.numeric(audit_end - audit_start) + 1,
      days_with_data_pct = days_with_data_pct,
      api_percent_complete_mean = api_pc_comp_mean,
      api_percent_coverage_mean = api_pc_cov_mean,
      api_coverage_anomaly_count = api_cov_anom,
      recent_data_present = recent_data_present,
      coverage_verified = TRUE,
      recommendation_status = rec_stat,
      recommendation_reason = rec_reason,
      stringsAsFactors = FALSE
   )
}

if (length(coverage_report) > 0) {
   cr_df <- do.call(rbind, coverage_report)
   write.csv(cr_df, "data/metadata/coverage_report.csv", row.names = FALSE)
   log_info("Created data/metadata/coverage_report.csv")
} else {
   log_warn("No coverage data retrieved.")
}
