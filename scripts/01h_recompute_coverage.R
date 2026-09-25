source("R/01_utils.R")
source("R/sources/openaq_source.R")
source("R/11_station_coverage_audit.R")
source("R/20_air_quality_ingestion.R") # For append_to_manifest

log_info("Starting Phase 1.6B Coverage Recomputation...")

# Recompute from local files
coverage_path <- "data/metadata/coverage_report.csv"
cr <- read.csv(coverage_path, stringsAsFactors=F)
cr$sensor_id <- as.character(cr$sensor_id)

raw_cov_dir <- "data/raw/air_quality/openaq/coverage"
files <- list.files(raw_cov_dir, full.names = TRUE, pattern = "\\.json$")

recomputed_count <- 0
untracked_fixed <- 0

# Track manifest
manifest_path <- "data/metadata/raw_data_manifest.csv"
manifest <- data.frame()
if (file.exists(manifest_path)) {
  manifest <- read.csv(manifest_path, stringsAsFactors=F)
}

for (f in files) {
  # filename format: sensor_12235505_days_2026-08-26_2026-09-24_retrieved_20260924T183626.json
  # Extract sensor_id, start, end
  fname <- basename(f)
  parts <- strsplit(fname, "_")[[1]]
  if (length(parts) < 6) next
  
  if (parts[1] == "sensor" && parts[3] == "days") {
    sid <- parts[2]
    audit_start_str <- parts[4]
    audit_end_str <- parts[5]
    
    # Check if this file is in manifest
    if (nrow(manifest) > 0 && !(fname %in% manifest$filename)) {
       # We need to append it
       # But what is loc_id? We can get it from sensor_catalog
       sc <- read.csv("data/metadata/sensor_catalog.csv", stringsAsFactors=F)
       s_row <- subset(sc, as.character(sensor_id) == sid)
       loc_id <- ifelse(nrow(s_row)>0, s_row$source_location_id[1], NA)
       
       # Parse to get row count
       body_text <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
       parsed <- jsonlite::fromJSON(body_text, simplifyVector = FALSE)
       row_count <- length(parsed$results)
       
       req_status <- ifelse(row_count > 0, "http_success_with_data", "http_success_empty")
       append_to_manifest(f, "openaq", "daily_coverage", "/sensors/days", audit_start_str, audit_end_str, loc_id, sid, row_count, http_status = 200, notes = req_status)
       untracked_fixed <- untracked_fixed + 1
       
       manifest <- read.csv(manifest_path, stringsAsFactors=F) # reload
    }
    
    # Only recompute if this sensor is in the targeted Phase 1.6 run (which used 2026-08-26 to 2026-09-24)
    # Actually, we can just recompute for all of them that match our target dates or just recompute everything we read
    # Find the corresponding row in cr
    idx <- which(cr$sensor_id == sid & cr$audit_window_start == audit_start_str & cr$audit_window_end == audit_end_str)
    
    if (length(idx) > 0) {
      body_text <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
      parsed <- jsonlite::fromJSON(body_text, simplifyVector = FALSE)
      
      sum_out <- summarize_coverage(parsed$results, audit_start_str, audit_end_str)
      
      rec_stat <- "Not recommended"
      if (!is.na(sum_out$days_with_data_pct) && sum_out$days_with_data_pct >= 50) rec_stat <- "Recommended"
      
      for (i in idx) {
        cr$days_with_data[i] <- sum_out$distinct_valid_dates
        cr$days_with_data_pct[i] <- sum_out$days_with_data_pct
        cr$api_percent_complete_mean[i] <- sum_out$api_pc_comp_mean
        cr$api_percent_coverage_mean[i] <- sum_out$api_pc_cov_mean
        cr$api_coverage_anomaly_count[i] <- sum_out$api_cov_anom
        cr$recent_data_present[i] <- (sum_out$distinct_valid_dates > 0)
        cr$recommendation_status[i] <- rec_stat
        cr$recommendation_reason[i] <- ifelse(rec_stat == "Recommended", "Adequate recent daily coverage", "Insufficient coverage")
        recomputed_count <- recomputed_count + 1
      }
    }
  }
}

write.csv(cr, coverage_path, row.names = FALSE)
log_info(sprintf("Recomputed %d coverage rows from existing raw files.", recomputed_count))
log_info(sprintf("Fixed %d untracked manifest entries.", untracked_fixed))
