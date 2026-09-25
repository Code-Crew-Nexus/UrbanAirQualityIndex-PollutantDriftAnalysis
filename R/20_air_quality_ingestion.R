# ==============================================================================
# 20_air_quality_ingestion.R: Air Quality Ingestion Workflow
# UrbanAirQualityIndex-PollutantDriftAnalysis
# ==============================================================================

source("R/01_utils.R")
source("R/sources/openaq_source.R")

append_to_manifest <- function(local_file, source, source_type, endpoint, req_start, req_end, loc_id, sensor_id, row_count, http_status = 200, notes = "Live authenticated ingestion", manifest_path = "data/metadata/raw_data_manifest.csv") {
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest package missing")
  ensure_dir(dirname(manifest_path))
  ensure_dir(dirname(manifest_path))
  
  if (is.na(local_file) || !file.exists(local_file)) {
     sha256 <- NA_character_
  } else {
     sha256 <- digest::digest(file = local_file, algo = "sha256")
  }
  
  new_row <- data.frame(
    local_file = local_file,
    source = source,
    source_type = source_type,
    source_endpoint = endpoint,
    retrieved_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z", tz = "Asia/Kolkata"),
    http_status = as.character(http_status),
    request_start_date = req_start,
    request_end_date = req_end,
    station_or_location_id = loc_id,
    sensor_id = ifelse(is.null(sensor_id) || is.na(sensor_id), NA, as.character(sensor_id)),
    response_row_count = row_count,
    data_origin = "external_api",
    file_sha256 = sha256,
    notes = notes,
    stringsAsFactors = FALSE
  )
  
  if (file.exists(manifest_path)) {
    write.table(new_row, manifest_path, append = TRUE, sep = ",", col.names = FALSE, row.names = FALSE)
  } else {
    write.csv(new_row, manifest_path, row.names = FALSE)
  }
}

fetch_sensor_hours <- function(proj_id, loc_id, sensor_id, param, start_date, end_date) {
   base_dir <- "data/raw/air_quality/openaq"
   base_filename <- sprintf("raw_%s_sensor_%s_%s_%s.json", proj_id, sensor_id, start_date, end_date)
   
   log_info(sprintf("Fetching hourly data for sensor %s (%s)", sensor_id, param))
   resp <- openaq_request(sprintf("/sensors/%s/hours", sensor_id), list(
       datetime_from = sprintf("%sT00:00:00Z", start_date),
       datetime_to = sprintf("%sT23:59:59Z", end_date),
       limit = 1000
   ))
   
   status <- httr2::resp_status(resp)
   if (status == 200) {
       content <- httr2::resp_body_string(resp)
       raw_file <- save_raw_response_immutable(base_dir, base_filename, content)
       parsed <- jsonlite::fromJSON(content, simplifyVector = FALSE)
       results <- parsed$results
       row_count <- length(results)
       
       req_status <- ifelse(row_count > 0, "http_success_with_data", "http_success_empty")
       append_to_manifest(raw_file, "openaq", "air_quality", sprintf("/sensors/%s/hours", sensor_id), start_date, end_date, loc_id, sensor_id, row_count, http_status = status, notes = req_status)
       
       if (row_count > 0) {
           df_list <- lapply(results, function(r) {
               ts_utc <- safe_extract(r$period$datetimeFrom$utc)
               ts_loc <- safe_extract(r$period$datetimeFrom$local)
               
               if (is.na(ts_utc) && is.na(ts_loc)) {
                  # Log or explicitly flag NA timestamps
                  # Here we just pass it as NA but they should exist in valid records
               }
               
               data.frame(
                   project_station_id = proj_id,
                   source_location_id = loc_id,
                   sensor_id = as.character(sensor_id),
                   pollutant = param,
                   timestamp_utc = ts_utc,
                   timestamp_local = ts_loc,
                   period_end_utc = safe_extract(r$period$datetimeTo$utc),
                   period_end_local = safe_extract(r$period$datetimeTo$local),
                   value = as.numeric(safe_extract(r$value)),
                   source_unit = safe_extract(r$parameter$units),
                   stringsAsFactors = FALSE
               )
           })
           out_df <- do.call(rbind, df_list)
           # Filter out rows with no timestamp at all
           out_df <- subset(out_df, !is.na(timestamp_utc))
           return(out_df)
       }
   } else {
       log_warn(sprintf("HTTP %d for sensor %s", status, sensor_id))
       # Cannot save an immutable raw file for a failed response unless we want to, so we just log NA for local_file
       append_to_manifest(NA, "openaq", "air_quality", sprintf("/sensors/%s/hours", sensor_id), start_date, end_date, loc_id, sensor_id, 0, http_status = status, notes = "Failed request")
   }
   return(data.frame())
}
