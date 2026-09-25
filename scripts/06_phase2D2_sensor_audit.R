source("R/00_setup.R")
source("R/01_utils.R")
library(httr2)
library(jsonlite)
library(dplyr)
library(tidyr)
library(readr)

snapshot <- read_csv("data/metadata/selected_sensor_snapshot.csv", show_col_types = FALSE)
api_key <- Sys.getenv("OPENAQ_API_KEY")

audit_results <- data.frame()

for (i in 1:nrow(snapshot)) {
  row <- snapshot[i, ]
  
  req <- request(paste0("https://api.openaq.org/v3/sensors/", row$sensor_id)) %>%
    req_headers(`X-API-Key` = api_key) %>%
    req_retry(max_tries = 3)
  
  resp <- req_perform(req)
  data <- resp_body_json(resp)$results[[1]]
  
  openaq_parameter_id <- data$parameter$id
  openaq_parameter_name <- data$parameter$name
  openaq_parameter_unit <- data$parameter$units
  
  metadata_unit_match <- (row$source_unit == openaq_parameter_unit)
  
  # Audit Status based on unit combinations and numeric review need
  status <- "UNIT_MATCHED"
  if (!metadata_unit_match) status <- "UNIT_MISMATCH"
  if (row$parameter == "co") status <- "DECLARED_UNIT_NUMERIC_SCALE_REVIEW_REQUIRED"
  if (row$parameter %in% c("no2", "so2", "o3")) status <- "NUMERIC_SCALE_REVIEW_REQUIRED"
  
  audit_results <- rbind(audit_results, data.frame(
    project_station_id = row$project_station_id,
    source_location_id = row$source_location_id,
    station_name = row$station_name,
    sensor_id = row$sensor_id,
    parameter = row$parameter,
    openaq_parameter_id = openaq_parameter_id,
    openaq_parameter_name = openaq_parameter_name,
    openaq_parameter_unit = openaq_parameter_unit,
    stored_source_unit = row$source_unit,
    canonical_target_unit = row$canonical_target_unit,
    metadata_unit_match = metadata_unit_match,
    unit_audit_status = status,
    notes = NA,
    stringsAsFactors = FALSE
  ))
  
  Sys.sleep(0.5) # rate limit
}

write_csv(audit_results, "data/metadata/phase2D2_sensor_unit_audit.csv")

# 2. Critical CO Audit + NO2/SO2/O3 Audit
# Load the hourly data and summarize
files <- list.files("data/interim/hourly/historical", full.names = TRUE, pattern = "\\.csv$")
all_air <- do.call(rbind, lapply(files, read_csv, show_col_types = FALSE))

dist_results <- data.frame()

for (i in 1:nrow(snapshot)) {
  row <- snapshot[i, ]
  
  # get data for this sensor
  sensor_data <- all_air %>%
    filter(sensor_id == row$sensor_id, !is.na(value_source))
  
  numeric_count <- nrow(sensor_data)
  
  if (numeric_count > 0) {
    min_val <- min(sensor_data$value_source)
    p01 <- quantile(sensor_data$value_source, 0.01, na.rm=TRUE)
    p05 <- quantile(sensor_data$value_source, 0.05, na.rm=TRUE)
    med_val <- median(sensor_data$value_source)
    p95 <- quantile(sensor_data$value_source, 0.95, na.rm=TRUE)
    p99 <- quantile(sensor_data$value_source, 0.99, na.rm=TRUE)
    max_val <- max(sensor_data$value_source)
  } else {
    min_val <- NA; p01 <- NA; p05 <- NA; med_val <- NA; p95 <- NA; p99 <- NA; max_val <- NA
  }
  
  canonical_status <- "pending"
  audit_status <- "pending"
  
  # Check if CO ppb
  if (row$parameter == "co") {
    if (med_val < 5 && row$source_unit == "ppb") {
      audit_status <- "IMPLAUSIBLE_NUMERIC_SCALE_FOR_DECLARED_UNIT"
    } else {
      audit_status <- "PLAUSIBLE_SCALE"
    }
  } else if (row$parameter %in% c("no2", "so2")) {
    if (med_val < 200 && row$source_unit == "ppb") { # typical is 10-100 ppb
      audit_status <- "PLAUSIBLE_SCALE"
    } else {
      audit_status <- "REVIEW_REQUIRED"
    }
  } else if (row$parameter == "o3") {
    if (row$source_unit == "g/m3" || row$source_unit == "µg/m³") {
      audit_status <- "PLAUSIBLE_SCALE"
    } else {
      audit_status <- "REVIEW_REQUIRED"
    }
  } else {
    audit_status <- "PLAUSIBLE_SCALE"
  }
  
  dist_results <- rbind(dist_results, data.frame(
    project_station_id = row$project_station_id,
    station_name = row$station_name,
    city = row$city,
    pollutant = row$parameter,
    source_unit_reported = row$source_unit,
    source_unit_verified = NA,
    numeric_count = numeric_count,
    min = min_val, p01 = p01, p05 = p05, median = med_val, p95 = p95, p99 = p99, max = max_val,
    canonical_conversion_status = canonical_status,
    audit_status = audit_status,
    notes = NA,
    stringsAsFactors = FALSE
  ))
}

write_csv(dist_results, "data/metadata/phase2D2_source_unit_distribution.csv")
