source("R/01_utils.R")
source("R/sources/openaq_source.R")
library(dplyr)

log_info("Starting Phase 1.6 Targeted Audits")

# 1. Update Navi Mumbai classification in station catalog
sc <- read.csv("data/metadata/station_catalog.csv", stringsAsFactors=F)
idx <- grep("Navi Mumbai", sc$station_name, ignore.case=TRUE)
if (length(idx) > 0) {
  sc$city_scope_status[idx] <- "metro_adjacent"
  write.csv(sc, "data/metadata/station_catalog.csv", row.names=F)
  log_info(sprintf("Updated %d Navi Mumbai stations to metro_adjacent", length(idx)))
}

# 2. Guwahati Shortlist correction (PROJ_165 is HTTP 500)
sh <- read.csv("data/metadata/india_station_shortlist.csv", stringsAsFactors=F)
if (any(sh$project_station_id == "PROJ_165")) {
  log_info("Demoting PROJ_165 from shortlist due to unreliability.")
  sh <- subset(sh, project_station_id != "PROJ_165")
  # Promote PROJ_200 (LGBI Airport)
  proj200 <- subset(sc, project_station_id == "PROJ_200")
  if (nrow(proj200) > 0) {
    # It lacks some columns that sh has, so use bind_rows
    proj200$activity_status <- "active_recent"
    proj200$shortlist_status <- "selected"
    sh <- bind_rows(sh, proj200)
    log_info("Promoted PROJ_200 to Guwahati shortlist.")
  }
  write.csv(sh, "data/metadata/india_station_shortlist.csv", row.names=F)
}

# 3. Targeted Audit for Hyderabad + PROJ_200
hyd_review <- read.csv("data/metadata/hyderabad_station_review.csv", stringsAsFactors=F)
credible_hyd <- subset(hyd_review, activity_status == "active_recent" & !(record_status %in% c("inactive", "legacy_location_record")))
log_info(sprintf("Found %d credible Hyderabad candidates", nrow(credible_hyd)))

target_locations <- unique(c(credible_hyd$source_location_id, subset(sc, project_station_id == "PROJ_200")$source_location_id))

sensor_cat_path <- "data/metadata/sensor_catalog.csv"
sensor_cat <- read.csv(sensor_cat_path, stringsAsFactors=F)

missing_locs <- setdiff(target_locations, sensor_cat$source_location_id)

if (length(missing_locs) > 0) {
  log_info(sprintf("Fetching sensor metadata for %d missing locations...", length(missing_locs)))
  sensor_list <- list()
  for (loc_id in missing_locs) {
    log_info(sprintf("Fetching sensor metadata for location %s", loc_id))
    Sys.sleep(1.2)
    resp <- openaq_request(sprintf("/locations/%s/sensors", loc_id))
    if (httr2::resp_status(resp) == 200) {
       body_text <- httr2::resp_body_string(resp)
       parsed <- jsonlite::fromJSON(body_text, simplifyVector = FALSE)
       sensors <- parsed$results
       if (!is.null(sensors) && length(sensors) > 0) {
         # Find project station ID for this loc
         proj_id <- subset(sc, source_location_id == loc_id)$project_station_id[1]
         row <- subset(sc, source_location_id == loc_id)[1,]
         
         for (s in sensors) {
            sid <- as.character(s$id)
            param <- safe_extract(s$parameter$name)
            unit <- safe_extract(s$parameter$units)
            dt_first <- safe_extract(s$datetimeFirst$utc)
            dt_last <- safe_extract(s$datetimeLast$utc)
            
            cov_exp <- suppressWarnings(as.numeric(safe_extract(s$coverage$expectedCount)))
            cov_obs <- suppressWarnings(as.numeric(safe_extract(s$coverage$observedCount)))
            cov_pc_comp <- suppressWarnings(as.numeric(safe_extract(s$coverage$percentComplete)))
            cov_pc_cov <- suppressWarnings(as.numeric(safe_extract(s$coverage$percentCoverage)))
            
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
  
  if (length(sensor_list) > 0) {
    new_sensors_df <- do.call(rbind, sensor_list)
    new_sensors_df$sensor_generation_status <- "inactive"
    new_sensors_df$dt_last_parsed <- as.POSIXct(new_sensors_df$sensor_datetime_last, format="%Y-%m-%dT%H:%M:%S", tz="UTC")
    
    # We must select preferred sensors just for the newly appended ones? Or the whole set?
    # Better to bind and select for all.
    sensor_cat$sensor_id <- as.character(sensor_cat$sensor_id)
    new_sensors_df$sensor_id <- as.character(new_sensors_df$sensor_id)
    sensor_cat <- bind_rows(sensor_cat, new_sensors_df)
    
    # We need to re-run select_preferred_sensor. Wait, select_preferred_sensor is not globally exported.
    # It's inside 01b. Let's just implement a quick select_preferred_sensor here.
    
    select_preferred <- function(df) {
       df$sensor_generation_status <- "inactive"
       df$dt_last_parsed <- as.POSIXct(df$sensor_datetime_last, format="%Y-%m-%dT%H:%M:%S", tz="UTC")
       stats <- unique(df$source_location_id)
       for (loc in stats) {
          loc_sensors <- df[df$source_location_id == loc, ]
          params <- unique(loc_sensors$parameter)
          for (p in params) {
             p_sens <- loc_sensors[loc_sensors$parameter == p, ]
             if (nrow(p_sens) > 0) {
                p_sens <- p_sens[order(p_sens$dt_last_parsed, decreasing = TRUE), ]
                latest_sid <- p_sens$sensor_id[1]
                df$sensor_generation_status[df$sensor_id == latest_sid] <- "preferred_current"
                if (nrow(p_sens) > 1) {
                   df$sensor_generation_status[df$sensor_id %in% p_sens$sensor_id[-1]] <- "legacy"
                }
             }
          }
       }
       df$dt_last_parsed <- NULL
       return(df)
    }
    
    sensor_cat <- select_preferred(sensor_cat)
    write.csv(sensor_cat, sensor_cat_path, row.names=F)
    log_info(sprintf("Added %d new sensors to sensor_catalog.csv", nrow(new_sensors_df)))
  }
} else {
  log_info("No new sensor metadata needed.")
}

# 4. Targeted Coverage Audit
cfg <- parse_project_config()
source("R/11_station_coverage_audit.R")

coverage_path <- "data/metadata/coverage_report.csv"
cr <- read.csv(coverage_path, stringsAsFactors=F)

# We need coverage for preferred current sensors for these target locations
target_sensors <- subset(sensor_cat, source_location_id %in% target_locations & 
                         sensor_generation_status == "preferred_current" & 
                         parameter %in% c(cfg$pollutants$core, cfg$pollutants$optional))

missing_sensors <- setdiff(target_sensors$sensor_id, cr$sensor_id)

if (length(missing_sensors) > 0) {
  log_info(sprintf("Fetching 30-day coverage for %d missing sensors...", length(missing_sensors)))
  
  audit_end <- as.Date("2026-09-24")
  audit_start <- audit_end - 29 # Ensure it's 30 days inclusive exactly matching previous 01b logic
  audit_start_str <- as.character(audit_start)
  audit_end_str <- as.character(audit_end)
  
  base_dir <- "data/raw/air_quality/openaq/coverage"
  
  new_coverage <- list()
  for (i in seq_along(missing_sensors)) {
    s_id <- missing_sensors[i]
    s_row <- subset(sensor_cat, sensor_id == s_id)[1,]
    log_info(sprintf("Auditing coverage for sensor %s (%d/%d)", s_id, i, length(missing_sensors)))
    Sys.sleep(1.2)
    
    day_resp <- openaq_request(sprintf("/sensors/%s/days", s_id), list(date_from = audit_start_str, date_to = audit_end_str, limit = 100))
    if (httr2::resp_status(day_resp) == 200) {
       body_text <- httr2::resp_body_string(day_resp)
       base_filename <- sprintf("sensor_%s_days_%s_%s.json", s_id, audit_start_str, audit_end_str)
       raw_file <- save_raw_response_immutable(base_dir, base_filename, body_text)
       
       day_parsed <- jsonlite::fromJSON(body_text, simplifyVector = FALSE)
       days_data <- day_parsed$results
       row_count <- length(days_data)
       
       req_status <- ifelse(row_count > 0, "http_success_with_data", "http_success_empty")
       append_to_manifest(raw_file, "openaq", "daily_coverage", "/sensors/days", audit_start_str, audit_end_str, s_row$source_location_id, s_id, row_count, http_status = 200, notes = req_status)
       
       sum_out <- summarize_coverage(days_data, audit_start, audit_end)
       
       rec_stat <- "Not recommended"
       if (!is.na(sum_out$days_with_data_pct) && sum_out$days_with_data_pct >= 50) rec_stat <- "Recommended"
       
       new_coverage[[length(new_coverage) + 1]] <- data.frame(
          project_station_id = s_row$project_station_id,
          source_location_id = s_row$source_location_id,
          station_name = s_row$station_name,
          city = s_row$city,
          sensor_id = s_id,
          parameter = s_row$parameter,
          sensor_status = s_row$sensor_generation_status,
          audit_window_start = audit_start_str,
          audit_window_end = audit_end_str,
          audit_generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z", tz = "Asia/Kolkata"),
          days_with_data = sum_out$distinct_valid_dates,
          days_expected = as.numeric(audit_end - audit_start) + 1,
          days_with_data_pct = sum_out$days_with_data_pct,
          api_percent_complete_mean = sum_out$api_pc_comp_mean,
          api_percent_coverage_mean = sum_out$api_pc_cov_mean,
          api_coverage_anomaly_count = sum_out$api_cov_anom,
          recent_data_present = (sum_out$distinct_valid_dates > 0),
          recommendation_status = rec_stat,
          recommendation_reason = ifelse(rec_stat == "Recommended", "Adequate recent daily coverage", "Insufficient coverage"),
          stringsAsFactors = FALSE
       )
    } else {
       append_to_manifest(NA, "openaq", "daily_coverage", "/sensors/days", audit_start_str, audit_end_str, s_row$source_location_id, s_id, 0, http_status = httr2::resp_status(day_resp), notes = "Failed request")
    }
  }
  
  if (length(new_coverage) > 0) {
    new_cov_df <- do.call(rbind, new_coverage)
    cr <- bind_rows(cr, new_cov_df)
    write.csv(cr, coverage_path, row.names=F)
    log_info(sprintf("Added %d new coverage rows to coverage_report.csv", nrow(new_cov_df)))
  }
} else {
  log_info("No new coverage needed.")
}

log_info("Targeted Audits Complete.")
