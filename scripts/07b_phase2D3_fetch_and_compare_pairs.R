source("R/00_setup.R")
library(httr2)
library(jsonlite)
library(dplyr)
library(readr)
library(stringr)

api_key <- Sys.getenv("OPENAQ_API_KEY")
catalog <- read_csv("data/metadata/phase2D3_location_sensor_unit_catalog.csv", show_col_types = FALSE)

# We are only comparing gaseous pollutants where unit ambiguity exists (co, no2, so2)
# and we will do a control comparison for o3.

reconciliation <- data.frame()
audit_dir <- "data/raw/air_quality/openaq/unit_audit"
dir.create(audit_dir, recursive = TRUE, showWarnings = FALSE)

manifest <- data.frame()

# Fetch function
fetch_audit_data <- function(sensor_id, start_dt="2025-03-01T00:00:00Z", end_dt="2025-03-07T23:59:59Z") {
  req <- request(paste0("https://api.openaq.org/v3/sensors/", sensor_id, "/hours")) %>%
    req_headers(`X-API-Key` = api_key) %>%
    req_url_query(
      datetime_from = start_dt,
      datetime_to = end_dt,
      limit = 1000
    ) %>%
    req_retry(max_tries = 3)
  
  resp <- tryCatch({
    req_perform(req)
  }, error = function(e) {
    message("Failed to fetch sensor ", sensor_id, ": ", e$message)
    return(NULL)
  })
  
  if (is.null(resp)) return(data.frame())
  
  body <- resp_body_json(resp)$results
  
  if (length(body) == 0) return(data.frame())
  
  # Save raw response
  filename <- paste0(audit_dir, "/sensor_", sensor_id, "_audit.json")
  write_json(body, filename)
  
  manifest <<- rbind(manifest, data.frame(
    sensor = sensor_id,
    request_interval = paste(start_dt, end_dt, sep=" to "),
    retrieval_timestamp = as.character(Sys.time()),
    HTTP_status = resp_status(resp),
    stringsAsFactors = FALSE
  ))
  
  df <- data.frame(
    sensor_id = sensor_id,
    utc = sapply(body, function(x) x$period$datetimeTo$utc),
    value = sapply(body, function(x) x$value),
    stringsAsFactors = FALSE
  )
  return(df)
}

selected <- catalog %>% filter(selected_sensor == TRUE, parameter_name %in% c("co", "no2", "so2", "o3"))
counterparts <- catalog %>% filter(possible_unit_counterpart == TRUE)

for (i in 1:nrow(selected)) {
  sel <- selected[i, ]
  
  # find counterpart
  cp <- counterparts %>% filter(project_station_id == sel$project_station_id, parameter_name == sel$parameter_name)
  
  if (nrow(cp) > 0) {
    cp <- cp[1, ] # take first counterpart
    
    # We will use Mar 1 to Mar 7 as our test window
    start_dt <- "2025-03-01T00:00:00Z"
    end_dt <- "2025-03-07T23:59:59Z"
    
    sel_data <- fetch_audit_data(sel$sensor_id, start_dt, end_dt)
    cp_data <- fetch_audit_data(cp$sensor_id, start_dt, end_dt)
    
    if (nrow(sel_data) > 0 && nrow(cp_data) > 0) {
      joined <- inner_join(sel_data, cp_data, by="utc", suffix=c("_sel", "_cp"))
      
      matched_count <- nrow(joined)
      
      if (matched_count >= 24) {
        sel_med <- median(joined$value_sel, na.rm=TRUE)
        cp_med <- median(joined$value_cp, na.rm=TRUE)
        
        ratio <- ifelse(sel_med > 0, cp_med / sel_med, NA)
        
        # Hypotheses
        # If cp is mass (e.g. ug/m3) and sel is ppb
        # H1: sel is ppb
        # H2: sel is ppm
        # H3: sel is mg/m3
        # H4: sel is ug/m3
        
        err_identity <- median(abs(joined$value_cp - joined$value_sel) / joined$value_cp, na.rm=TRUE)
        
        factor <- 1
        if (sel$parameter_name == "co") {
          factor <- 1.145
          # H1: sel is ppb -> cp should be sel * 1.145
          err_ppb <- median(abs(joined$value_cp - (joined$value_sel * 1.145)) / joined$value_cp, na.rm=TRUE)
          # H2: sel is ppm -> cp should be sel * 1145
          err_ppm <- median(abs(joined$value_cp - (joined$value_sel * 1145)) / joined$value_cp, na.rm=TRUE)
          # H3: sel is mg/m3 -> cp should be sel * 1000
          err_mg <- median(abs(joined$value_cp - (joined$value_sel * 1000)) / joined$value_cp, na.rm=TRUE)
          # H4: identity (sel is ug/m3)
          err_ug <- err_identity
          
          errors <- c("ppb"=err_ppb, "ppm"=err_ppm, "mg/m³"=err_mg, "µg/m³"=err_ug)
          best_unit <- names(errors)[which.min(errors)]
          best_err <- min(errors)
          
        } else if (sel$parameter_name == "no2") {
          factor <- 1.88
          err_ppb <- median(abs(joined$value_cp - (joined$value_sel * 1.88)) / joined$value_cp, na.rm=TRUE)
          err_ug <- err_identity
          
          errors <- c("ppb"=err_ppb, "µg/m³"=err_ug)
          best_unit <- names(errors)[which.min(errors)]
          best_err <- min(errors)
          
        } else if (sel$parameter_name == "so2") {
          factor <- 2.62
          err_ppb <- median(abs(joined$value_cp - (joined$value_sel * 2.62)) / joined$value_cp, na.rm=TRUE)
          err_ug <- err_identity
          
          errors <- c("ppb"=err_ppb, "µg/m³"=err_ug)
          best_unit <- names(errors)[which.min(errors)]
          best_err <- min(errors)
          
        } else if (sel$parameter_name == "o3") {
          factor <- 1.96
          err_ppb <- median(abs(joined$value_cp - (joined$value_sel * 1.96)) / joined$value_cp, na.rm=TRUE)
          err_ug <- err_identity
          
          errors <- c("ppb"=err_ppb, "µg/m³"=err_ug)
          best_unit <- names(errors)[which.min(errors)]
          best_err <- min(errors)
        }
        
        status <- if(best_err < 0.1) "VERIFIED" else "UNRESOLVED"
        
        reconciliation <- rbind(reconciliation, data.frame(
          project_station_id = sel$project_station_id,
          station_name = sel$station_name,
          city = sel$city,
          pollutant = sel$parameter_name,
          selected_sensor_id = sel$sensor_id,
          selected_reported_unit = sel$parameter_unit,
          counterpart_sensor_id = cp$sensor_id,
          counterpart_reported_unit = cp$parameter_unit,
          overlap_start = start_dt,
          overlap_end = end_dt,
          matched_timestamp_count = matched_count,
          selected_median = sel_med,
          counterpart_median = cp_med,
          median_ratio_counterpart_to_selected = ratio,
          median_absolute_relative_error_identity = err_identity,
          median_absolute_relative_error_expected_conversion = errors[1], # first is usually ppb
          best_supported_semantic_unit = best_unit,
          verification_status = status,
          evidence_notes = paste("Lowest error:", round(best_err*100,2), "% for hypothesis", best_unit),
          stringsAsFactors = FALSE
        ))
      }
    }
    Sys.sleep(1) # ratelimit
  }
}

if (nrow(manifest) > 0) write_csv(manifest, "data/metadata/phase2D3_unit_audit_manifest.csv")
if (nrow(reconciliation) > 0) write_csv(reconciliation, "data/metadata/phase2D3_paired_unit_reconciliation.csv")
