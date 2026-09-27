# ==============================================================================
# scripts/44_live_data_ingestion.R
# UrbanAirQualityIndex-PollutantDriftAnalysis
# Checkpoint G6: Live Data Extension Ingestion Engine
#
# Immutable Baseline: v0.6-svm-freeze ends permanently on 2026-09-21.
# Live extension covers 2026-09-22 onward.
# Strict transactional update with schema contract validation and rate pacing.
# ==============================================================================

suppressPackageStartupMessages({
  library(jsonlite)
  library(readr)
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(zoo)
  library(digest)
  library(httr2)
})

# Load core project utilities and AQI calculation helpers
if (file.exists(".Renviron")) {
  readRenviron(".Renviron")
}

source("R/01_utils.R")
source("R/sources/openaq_source.R")
source("R/24_aqi_calculation.R")

cat("============================================================\n")
cat("Checkpoint G6: Live Data Ingestion Pipeline\n")
cat("Authoritative Scientific Baseline: v0.6-svm-freeze (FROZEN)\n")
cat("Live Extension Scope: 2026-09-22 onward\n")
cat("============================================================\n\n")

# ------------------------------------------------------------------------------
# 1. Parse CLI Arguments
# ------------------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)

get_arg <- function(flag, default_val) {
  idx <- which(args == flag)
  if (length(idx) > 0 && idx < length(args)) {
    return(args[idx + 1])
  }
  return(default_val)
}

has_flag <- function(flag) {
  any(args == flag)
}

start_date_arg <- get_arg("--start-date", "2026-09-22")
# Default end-date is yesterday's date in IST
yesterday_ist <- as.character(as.Date(format(Sys.time(), tz = "Asia/Kolkata")) - 1)
# Cap default end date at 2026-09-26 for initial backfill if run before tomorrow
end_date_arg <- get_arg("--end-date", min(yesterday_ist, "2026-09-26"))
dry_run <- has_flag("--dry-run")

cat(sprintf("Configured Window: %s to %s (dry_run = %s)\n", start_date_arg, end_date_arg, dry_run))

# Enforce frozen study boundary: Live data CANNOT precede 2026-09-22
if (as.Date(start_date_arg) < as.Date("2026-09-22")) {
  stop("FATAL: Live data ingestion cannot start before 2026-09-22 (scientific freeze boundary).")
}

# ------------------------------------------------------------------------------
# 2. Directory Setup
# ------------------------------------------------------------------------------
dirs <- c(
  "data/live/processed",
  "data/live/metadata",
  "data/live/staging",
  "docs/web-data"
)
for (d in dirs) {
  ensure_dir(d)
}

status_file <- "docs/web-data/live_pipeline_status.json"

write_status <- function(status, severity, code, message, extra = list()) {
  status_obj <- list(
    status = status,
    severity = severity,
    code = code,
    last_attempt_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    schedule_mode = "daily",
    source = "OpenAQ + Open-Meteo",
    message = message
  )
  for (nm in names(extra)) {
    status_obj[[nm]] <- extra[[nm]]
  }
  write_json(status_obj, status_file, pretty = TRUE, auto_unbox = TRUE)
  cat(sprintf("[STATUS] %s (%s): %s\n", code, severity, message))
}

# ------------------------------------------------------------------------------
# 3. Load Schema Contract and Station Topology
# ------------------------------------------------------------------------------
contract_path <- "config/live_source_contract.json"
if (!file.exists(contract_path)) {
  stop("FATAL: Missing upstream schema contract at ", contract_path)
}
contract <- fromJSON(contract_path, simplifyVector = FALSE)

stations <- read.csv("config/selected_stations.csv", stringsAsFactors = FALSE)
cat(sprintf("Loaded %d selected stations.\n", nrow(stations)))

semantics <- read.csv("data/metadata/phase2D4_final_sensor_semantic_units.csv", stringsAsFactors = FALSE)
verified_sensors <- semantics %>%
  filter(verification_status == "VERIFIED", pollutant %in% c("pm2_5", "pm10", "o3")) %>%
  left_join(stations %>% select(project_station_id, station_name, city, latitude, longitude), by = "project_station_id")

cat(sprintf("Loaded %d verified sensors across 21 stations (PM2.5, PM10, O3).\n", nrow(verified_sensors)))
stopifnot(nrow(verified_sensors) == 63)

# ------------------------------------------------------------------------------
# 4. Probe Verification & Authentication Gate
# ------------------------------------------------------------------------------
api_key <- openaq_get_api_key()
if (is.null(api_key) || nchar(api_key) == 0) {
  write_status("auth_error", "critical", "AUTH_ERROR",
               "Live data refresh paused: OPENAQ_API_KEY is not configured.",
               list(data_through = if (file.exists("data/live/processed/live_daily_observations.csv")) {
                 max(read.csv("data/live/processed/live_daily_observations.csv")$date, na.rm=TRUE)
               } else "2026-09-21"))
  stop("FATAL: OPENAQ_API_KEY is not configured in environment or .Renviron.")
}

cat("Probing OpenAQ API v3 endpoint with probe sensor 12235581...\n")
probe_resp <- openaq_request("/sensors/12235581/hours", list(
  datetime_from = sprintf("%sT00:00:00Z", start_date_arg),
  datetime_to = sprintf("%sT02:00:00Z", start_date_arg),
  limit = 2
))

probe_status <- httr2::resp_status(probe_resp)
if (probe_status %in% c(401, 403)) {
  write_status("auth_error", "critical", "AUTH_ERROR",
               "Live data refresh paused: Upstream authentication failed (HTTP 401/403).")
  stop("FATAL: OpenAQ authentication failed with HTTP ", probe_status)
} else if (probe_status == 429) {
  write_status("rate_limited", "warning", "RATE_LIMITED",
               "Live data refresh paused: OpenAQ API rate limit encountered (HTTP 429).")
  stop("FATAL: OpenAQ rate limited.")
} else if (probe_status >= 500) {
  write_status("upstream_unavailable", "warning", "UPSTREAM_UNAVAILABLE",
               "Live data refresh paused: OpenAQ service temporarily unavailable (HTTP 5xx).")
  stop("FATAL: OpenAQ upstream service unavailable.")
} else if (probe_status != 200) {
  write_status("update_failed", "warning", "PROBE_FAILED",
               sprintf("Live data probe failed with HTTP status %d.", probe_status))
  stop("FATAL: Probe failed with HTTP ", probe_status)
}

probe_body <- httr2::resp_body_string(probe_resp)
probe_json <- fromJSON(probe_body, simplifyVector = FALSE)

# Schema contract validation on probe
req_root <- contract$sources$openaq$payload_root$required_fields
if (!all(req_root %in% names(probe_json))) {
  write_status("schema_drift", "critical", "UPSTREAM_SCHEMA_CHANGE",
               "OpenAQ payload root structure missing required fields.")
  stop("FATAL: OpenAQ payload root schema drift.")
}

if (length(probe_json$results) > 0) {
  sample_rec <- probe_json$results[[1]]
  req_item <- contract$sources$openaq$result_item_contract$required_fields
  if (!all(req_item %in% names(sample_rec))) {
    write_status("schema_drift", "critical", "UPSTREAM_SCHEMA_CHANGE",
                 "OpenAQ result item structure missing required fields.")
    stop("FATAL: OpenAQ result item schema drift.")
  }
  sample_unit <- sample_rec$parameter$units
  if (!sample_unit %in% c("µg/m³", "ug/m3")) {
    write_status("schema_drift", "critical", "UPSTREAM_SCHEMA_CHANGE",
                 sprintf("OpenAQ returned unsupported unit: '%s'", sample_unit))
    stop("FATAL: OpenAQ unsupported unit: ", sample_unit)
  }
}
cat("[OK] OpenAQ probe and schema contract validated successfully.\n")

# Probe Open-Meteo
cat("Probing Open-Meteo archive API for PROJ_007...\n")
sample_lat <- stations$latitude[stations$project_station_id == "PROJ_007"][1]
sample_lon <- stations$longitude[stations$project_station_id == "PROJ_007"][1]

meteo_url <- "https://archive-api.open-meteo.com/v1/archive"
meteo_req <- httr2::request(meteo_url) |>
  httr2::req_url_query(
    latitude = sample_lat,
    longitude = sample_lon,
    start_date = start_date_arg,
    end_date = start_date_arg,
    hourly = "temperature_2m,relative_humidity_2m,wind_speed_10m,wind_direction_10m",
    wind_speed_unit = "ms",
    timezone = "Asia/Kolkata"
  )
meteo_resp <- tryCatch({ httr2::req_perform(meteo_req) }, error = function(e) NULL)
if (is.null(meteo_resp) || httr2::resp_status(meteo_resp) != 200) {
  cat("[NOTE] Open-Meteo archive probe returned status ", ifelse(is.null(meteo_resp), "NULL", httr2::resp_status(meteo_resp)), "; attempting forecast endpoint fallback...\n")
  meteo_url <- "https://api.open-meteo.com/v1/forecast"
  meteo_req <- httr2::request(meteo_url) |>
    httr2::req_url_query(
      latitude = sample_lat,
      longitude = sample_lon,
      past_days = 7,
      hourly = "temperature_2m,relative_humidity_2m,wind_speed_10m,wind_direction_10m",
      wind_speed_unit = "ms",
      timezone = "Asia/Kolkata"
    )
  meteo_resp <- tryCatch({ httr2::req_perform(meteo_req) }, error = function(e) NULL)
}
if (is.null(meteo_resp) || httr2::resp_status(meteo_resp) != 200) {
  write_status("upstream_unavailable", "warning", "UPSTREAM_UNAVAILABLE",
               "Open-Meteo weather endpoint unavailable.")
  stop("FATAL: Open-Meteo service unavailable.")
}
cat("[OK] Open-Meteo probe and schema validated successfully.\n")

if (dry_run) {
  cat("\n=== DRY RUN MODE: Pre-flight checks and schema validations passed. Exiting without modifying data. ===\n")
  quit(status = 0)
}

# ------------------------------------------------------------------------------
# 5. Fetch OpenAQ Air Quality Data (Batch with Rate Pacing)
# ------------------------------------------------------------------------------
cat(sprintf("\n--- Fetching OpenAQ hourly data for %d sensors (%s to %s) ---\n",
            nrow(verified_sensors), start_date_arg, end_date_arg))

manifest_records <- list()
aq_hourly_list <- list()
api_call_count <- 0

# Manifest helper for live ingestion
live_manifest_path <- "data/live/metadata/live_ingestion_manifest.csv"

for (i in seq_len(nrow(verified_sensors))) {
  s_row <- verified_sensors[i, ]
  s_id <- s_row$sensor_id
  p_id <- s_row$project_station_id
  param <- s_row$pollutant
  
  api_call_count <- api_call_count + 1
  if (api_call_count > 250) {
    stop("Defensive threshold exceeded: Accidental loop guard tripped.")
  }
  
  # Pacing: 0.20s sleep between requests
  Sys.sleep(0.20)
  
  resp <- openaq_request(sprintf("/sensors/%s/hours", s_id), list(
    datetime_from = sprintf("%sT00:00:00Z", start_date_arg),
    datetime_to = sprintf("%sT23:59:59Z", end_date_arg),
    limit = 500
  ))
  
  st_code <- httr2::resp_status(resp)
  body_str <- httr2::resp_body_string(resp)
  p_json <- tryCatch({ fromJSON(body_str, simplifyVector = FALSE) }, error = function(e) list(results = list()))
  res_cnt <- length(p_json$results)
  
  # Log to live manifest
  manifest_records[[length(manifest_records) + 1]] <- data.frame(
    timestamp_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    project_station_id = p_id,
    sensor_id = as.character(s_id),
    pollutant = param,
    start_date = start_date_arg,
    end_date = end_date_arg,
    http_status = st_code,
    records_received = res_cnt,
    stringsAsFactors = FALSE
  )
  
  if (st_code == 200 && res_cnt > 0) {
    df_rows <- lapply(p_json$results, function(r) {
      val <- as.numeric(r$value)
      # Bounds check
      if (is.na(val) || val < 0 || val > 2000) val <- NA_real_
      data.frame(
        project_station_id = p_id,
        sensor_id = as.character(s_id),
        parameter = param,
        timestamp_utc = as.character(r$period$datetimeFrom$utc),
        timestamp_local = as.character(r$period$datetimeFrom$local),
        value = val,
        unit = as.character(r$parameter$units),
        stringsAsFactors = FALSE
      )
    })
    aq_hourly_list[[length(aq_hourly_list) + 1]] <- bind_rows(df_rows)
  }
  
  if (i %% 10 == 0 || i == nrow(verified_sensors)) {
    cat(sprintf("  Processed %d / %d sensors (%d API calls)...\n", i, nrow(verified_sensors), api_call_count))
  }
}

aq_hourly_df <- if (length(aq_hourly_list) > 0) bind_rows(aq_hourly_list) else data.frame()
cat(sprintf("Total air quality hourly records collected: %d\n", nrow(aq_hourly_df)))

# ------------------------------------------------------------------------------
# 6. Fetch Open-Meteo Meteorology Data
# ------------------------------------------------------------------------------
cat(sprintf("\n--- Fetching Open-Meteo weather data for %d stations (%s to %s) ---\n",
            nrow(stations), start_date_arg, end_date_arg))

weather_hourly_list <- list()

for (i in seq_len(nrow(stations))) {
  st <- stations[i, ]
  p_id <- st$project_station_id
  lat <- st$latitude
  lon <- st$longitude
  
  # Try archive first, then fallback to forecast endpoint
  meteo_url <- "https://archive-api.open-meteo.com/v1/archive"
  m_req <- httr2::request(meteo_url) |>
    httr2::req_url_query(
      latitude = lat,
      longitude = lon,
      start_date = start_date_arg,
      end_date = end_date_arg,
      hourly = "temperature_2m,relative_humidity_2m,wind_speed_10m,wind_direction_10m",
      wind_speed_unit = "ms",
      timezone = "Asia/Kolkata"
    )
  m_resp <- tryCatch({ httr2::req_perform(m_req) }, error = function(e) NULL)
  
  if (is.null(m_resp) || httr2::resp_status(m_resp) != 200) {
    # Fallback to forecast with past_days
    meteo_url <- "https://api.open-meteo.com/v1/forecast"
    m_req <- httr2::request(meteo_url) |>
      httr2::req_url_query(
        latitude = lat,
        longitude = lon,
        past_days = 7,
        hourly = "temperature_2m,relative_humidity_2m,wind_speed_10m,wind_direction_10m",
        wind_speed_unit = "ms",
        timezone = "Asia/Kolkata"
      )
    m_resp <- tryCatch({ httr2::req_perform(m_req) }, error = function(e) NULL)
  }
  
  if (!is.null(m_resp) && httr2::resp_status(m_resp) == 200) {
    b_txt <- httr2::resp_body_string(m_resp)
    m_json <- fromJSON(b_txt)
    h <- m_json$hourly
    if (!is.null(h) && length(h$time) > 0) {
      w_df <- data.frame(
        project_station_id = p_id,
        timestamp_local = h$time,
        temperature = h$temperature_2m,
        humidity = h$relative_humidity_2m,
        wind_speed = h$wind_speed_10m,
        wind_direction = h$wind_direction_10m,
        stringsAsFactors = FALSE
      )
      # Filter to requested local date range
      w_df$local_date <- as.Date(substr(w_df$timestamp_local, 1, 10))
      w_df <- w_df %>% filter(local_date >= as.Date(start_date_arg) & local_date <= as.Date(end_date_arg))
      weather_hourly_list[[length(weather_hourly_list) + 1]] <- w_df
    }
  } else {
    cat(sprintf("  [WARN] Open-Meteo weather fetch failed for station %s\n", p_id))
  }
  Sys.sleep(0.1)
}

weather_hourly_df <- if (length(weather_hourly_list) > 0) bind_rows(weather_hourly_list) else data.frame()
cat(sprintf("Total weather hourly records collected: %d\n", nrow(weather_hourly_df)))

# ------------------------------------------------------------------------------
# 7. Aggregation & AQI Calculation (Exact CPCB Verified-Subset Methodology)
# ------------------------------------------------------------------------------
cat("\n--- Aggregating hourly observations and computing verified AQI ---\n")

breakpoints <- load_verified_breakpoints()

# Parse local time for air quality
if (nrow(aq_hourly_df) > 0) {
  aq_hourly_df <- aq_hourly_df %>%
    mutate(
      local_time = as.POSIXct(timestamp_local, tz = "Asia/Kolkata"),
      local_date = as.Date(local_time, tz = "Asia/Kolkata")
    ) %>%
    filter(local_date >= as.Date(start_date_arg) & local_date <= as.Date(end_date_arg))
}

# Daily PM2.5 and PM10
pm_daily <- if (nrow(aq_hourly_df) > 0) {
  aq_hourly_df %>%
    filter(parameter %in% c("pm2_5", "pm10")) %>%
    group_by(project_station_id, local_date, parameter) %>%
    summarize(
      valid_hours = sum(!is.na(value)),
      daily_mean = ifelse(valid_hours >= 16, round_half_up(mean(value, na.rm = TRUE), 0), NA_real_),
      .groups = "drop"
    ) %>%
    mutate(
      subindex = map2_dbl(daily_mean, parameter, ~ if (is.na(.x)) NA_real_ else calculate_pollutant_subindex(.x, .y, breakpoints))
    )
} else {
  data.frame()
}

pm25_df <- if (nrow(pm_daily) > 0) {
  pm_daily %>% filter(parameter == "pm2_5") %>%
    select(project_station_id, date = local_date, pm2_5_aqi_input = daily_mean, pm2_5_subindex = subindex)
} else {
  data.frame(project_station_id = character(), date = as.Date(character()), pm2_5_aqi_input = numeric(), pm2_5_subindex = numeric())
}

pm10_df <- if (nrow(pm_daily) > 0) {
  pm_daily %>% filter(parameter == "pm10") %>%
    select(project_station_id, date = local_date, pm10_aqi_input = daily_mean, pm10_subindex = subindex)
} else {
  data.frame(project_station_id = character(), date = as.Date(character()), pm10_aqi_input = numeric(), pm10_subindex = numeric())
}

# Rolling 8h O3
o3_daily <- if (nrow(aq_hourly_df) > 0) {
  o3_hourly <- aq_hourly_df %>% filter(parameter == "o3")
  
  if (nrow(o3_hourly) > 0) {
    # Generate full station-hour grid for proper 8-hour rolling window
    grid_start <- as.POSIXct(paste(as.Date(start_date_arg) - 1, "17:00:00"), tz = "Asia/Kolkata")
    grid_end <- as.POSIXct(paste(end_date_arg, "23:00:00"), tz = "Asia/Kolkata")
    st_spine <- expand_grid(
      project_station_id = unique(stations$project_station_id),
      local_time = seq(grid_start, grid_end, by = "1 hour")
    )
    
    o3_joined <- st_spine %>%
      left_join(o3_hourly %>% select(project_station_id, local_time, value), by = c("project_station_id", "local_time")) %>%
      arrange(project_station_id, local_time) %>%
      group_by(project_station_id) %>%
      mutate(
        o3_8h_mean = zoo::rollapply(value, width = 8, FUN = function(x) {
          if (sum(!is.na(x)) >= 6) mean(x, na.rm = TRUE) else NA_real_
        }, fill = NA, align = "right")
      ) %>%
      ungroup() %>%
      mutate(local_date = as.Date(local_time, tz = "Asia/Kolkata")) %>%
      filter(local_date >= as.Date(start_date_arg) & local_date <= as.Date(end_date_arg))
    
    o3_joined %>%
      group_by(project_station_id, local_date) %>%
      summarize(
        valid_hours = sum(!is.na(value)),
        valid_8h_windows = sum(!is.na(o3_8h_mean)),
        o3_8h_max = ifelse(valid_hours >= 16 & valid_8h_windows > 0, round_half_up(max(o3_8h_mean, na.rm = TRUE), 0), NA_real_),
        o3_1h_max = ifelse(valid_hours >= 16, round_half_up(max(value, na.rm = TRUE), 0), NA_real_),
        .groups = "drop"
      ) %>%
      mutate(
        o3_8h_subindex = map_dbl(o3_8h_max, ~ if (is.na(.x)) NA_real_ else calculate_pollutant_subindex(.x, "o3", breakpoints)),
        o3_1h_subindex = map_dbl(o3_1h_max, ~ if (is.na(.x)) NA_real_ else calculate_pollutant_subindex(.x, "o3_1h", breakpoints)),
        o3_subindex = case_when(
          !is.na(o3_1h_subindex) & o3_1h_subindex > 200 & (is.na(o3_8h_subindex) | o3_1h_subindex > o3_8h_subindex) ~ o3_1h_subindex,
          !is.na(o3_8h_subindex) ~ o3_8h_subindex,
          TRUE ~ NA_real_
        )
      ) %>%
      select(project_station_id, date = local_date, o3_8h_max, o3_subindex)
  } else {
    data.frame()
  }
} else {
  data.frame()
}

if (nrow(o3_daily) == 0) {
  o3_daily <- data.frame(project_station_id = character(), date = as.Date(character()), o3_8h_max = numeric(), o3_subindex = numeric())
}

# Daily Weather Aggregation
weather_daily <- if (nrow(weather_hourly_df) > 0) {
  weather_hourly_df %>%
    group_by(project_station_id, local_date) %>%
    summarize(
      temperature = round(mean(temperature, na.rm = TRUE), 2),
      humidity = round(mean(humidity, na.rm = TRUE), 2),
      wind_speed = round(mean(wind_speed, na.rm = TRUE), 2),
      wind_direction = round(atan2(mean(sin(wind_direction * pi / 180), na.rm=TRUE), mean(cos(wind_direction * pi / 180), na.rm=TRUE)) * 180 / pi %% 360, 1),
      .groups = "drop"
    ) %>%
    rename(date = local_date)
} else {
  data.frame(project_station_id = character(), date = as.Date(character()), temperature = numeric(), humidity = numeric(), wind_speed = numeric(), wind_direction = numeric())
}

# Construct Station x Date Master Spine for Live Period
dates_seq <- seq(as.Date(start_date_arg), as.Date(end_date_arg), by = "1 day")
spine_live <- expand_grid(
  project_station_id = stations$project_station_id,
  date = dates_seq
)

live_master <- spine_live %>%
  left_join(pm25_df, by = c("project_station_id", "date")) %>%
  left_join(pm10_df, by = c("project_station_id", "date")) %>%
  left_join(o3_daily, by = c("project_station_id", "date")) %>%
  left_join(weather_daily, by = c("project_station_id", "date"))

# Calculate verified AQI and dominant pollutant
live_master <- live_master %>%
  mutate(
    all_three_valid = !is.na(pm2_5_subindex) & !is.na(pm10_subindex) & !is.na(o3_subindex),
    aqi_uncapped = ifelse(all_three_valid, pmax(pm2_5_subindex, pm10_subindex, o3_subindex), NA_real_),
    aqi_verified = ifelse(!is.na(aqi_uncapped), pmin(aqi_uncapped, 500), NA_real_)
  ) %>%
  rowwise() %>%
  mutate(
    dominant_pollutant = {
      if (is.na(aqi_uncapped)) {
        NA_character_
      } else {
        d <- c()
        if (!is.na(pm2_5_subindex) && pm2_5_subindex == aqi_uncapped) d <- c(d, "pm2_5")
        if (!is.na(pm10_subindex) && pm10_subindex == aqi_uncapped) d <- c(d, "pm10")
        if (!is.na(o3_subindex) && o3_subindex == aqi_uncapped) d <- c(d, "o3")
        paste(sort(d), collapse = ",")
      }
    }
  ) %>%
  ungroup() %>%
  mutate(
    aqi_category = case_when(
      is.na(aqi_verified) ~ NA_character_,
      aqi_verified <= 50 ~ "Good",
      aqi_verified <= 100 ~ "Satisfactory",
      aqi_verified <= 200 ~ "Moderately Polluted",
      aqi_verified <= 300 ~ "Poor",
      aqi_verified <= 400 ~ "Very Poor",
      TRUE ~ "Severe"
    )
  )

# ------------------------------------------------------------------------------
# 8. Data Quality & Integrity Gates
# ------------------------------------------------------------------------------
cat("\n--- Running quality and integrity gates ---\n")

# Gate 1: Strict date boundary check (all dates must be >= 2026-09-22)
if (any(live_master$date < as.Date("2026-09-22"))) {
  stop("FATAL QUALITY GATE FAILURE: Detected dates earlier than 2026-09-22 in live extension!")
}

# Gate 2: Station ID check
if (!all(live_master$project_station_id %in% stations$project_station_id)) {
  stop("FATAL QUALITY GATE FAILURE: Unknown station ID detected in live records!")
}

# Gate 3: Deduplication check
dups <- live_master %>% count(project_station_id, date) %>% filter(n > 1)
if (nrow(dups) > 0) {
  stop("FATAL QUALITY GATE FAILURE: Duplicate (station, date) rows detected!")
}

# Gate 4: Plausibility bounds
invalid_aqi <- live_master %>% filter(!is.na(aqi_verified) & (aqi_verified < 0 | aqi_verified > 500))
if (nrow(invalid_aqi) > 0) {
  stop("FATAL QUALITY GATE FAILURE: AQI values out of [0, 500] range!")
}

cat("[PASS] All Quality Gates Passed:\n")
cat(sprintf("  - Total Station-Days in batch: %d\n", nrow(live_master)))
cat(sprintf("  - Valid AQI records: %d (%.1f%%)\n", sum(!is.na(live_master$aqi_verified)), 100 * mean(!is.na(live_master$aqi_verified))))
cat(sprintf("  - Stations with >= 1 valid record: %d / %d\n",
            n_distinct(live_master$project_station_id[!is.na(live_master$aqi_verified)]), nrow(stations)))

# ------------------------------------------------------------------------------
# 9. Incremental Merge & Atomic Serialization
# ------------------------------------------------------------------------------
processed_csv_path <- "data/live/processed/live_daily_observations.csv"
staging_csv_path <- "data/live/staging/live_daily_observations.csv"
staging_json_path <- "data/live/staging/live_daily_observations.json"
web_json_path <- "docs/web-data/live_daily_observations.json"

# Merge with existing live data if present
if (file.exists(processed_csv_path)) {
  prev_live <- read_csv(processed_csv_path, show_col_types = FALSE)
  # Assert previous data is strictly live
  stopifnot(all(prev_live$date >= as.Date("2026-09-22")))
  
  # Remove overlapping records that are being updated
  combined_live <- prev_live %>%
    filter(!(paste(project_station_id, date) %in% paste(live_master$project_station_id, live_master$date))) %>%
    bind_rows(live_master) %>%
    arrange(date, project_station_id)
} else {
  combined_live <- live_master %>% arrange(date, project_station_id)
}

# Select and round columns for clean export
export_df <- combined_live %>%
  select(
    project_station_id,
    date,
    aqi_verified,
    aqi_category,
    dominant_pollutant,
    pm2_5_aqi_input,
    pm10_aqi_input,
    o3_8h_max,
    temperature,
    humidity,
    wind_speed,
    wind_direction
  ) %>%
  mutate(
    date = as.character(date),
    aqi_verified = ifelse(is.na(aqi_verified), NA_real_, round(aqi_verified, 1)),
    pm2_5_aqi_input = ifelse(is.na(pm2_5_aqi_input), NA_real_, round(pm2_5_aqi_input, 2)),
    pm10_aqi_input = ifelse(is.na(pm10_aqi_input), NA_real_, round(pm10_aqi_input, 2)),
    o3_8h_max = ifelse(is.na(o3_8h_max), NA_real_, round(o3_8h_max, 2)),
    temperature = ifelse(is.na(temperature), NA_real_, round(temperature, 2)),
    humidity = ifelse(is.na(humidity), NA_real_, round(humidity, 2)),
    wind_speed = ifelse(is.na(wind_speed), NA_real_, round(wind_speed, 2)),
    wind_direction = ifelse(is.na(wind_direction), NA_real_, round(wind_direction, 1))
  )

# Write to staging
write_csv(combined_live, staging_csv_path)

# Web export format matches daily_observations.json exactly
web_export_df <- export_df %>%
  select(
    project_station_id,
    date,
    aqi_verified,
    aqi_category,
    dominant_pollutant,
    pm2_5_aqi_input,
    pm10_aqi_input,
    o3_8h_max,
    temperature,
    humidity,
    wind_speed
  )
write_json(web_export_df, staging_json_path, na = "null", auto_unbox = TRUE, pretty = FALSE)

# Atomic replace
file.copy(staging_csv_path, processed_csv_path, overwrite = TRUE)
file.copy(staging_json_path, web_json_path, overwrite = TRUE)

# Write live manifest
if (length(manifest_records) > 0) {
  manifest_df <- bind_rows(manifest_records)
  if (file.exists(live_manifest_path)) {
    write.table(manifest_df, live_manifest_path, append = TRUE, sep = ",", col.names = FALSE, row.names = FALSE)
  } else {
    write.csv(manifest_df, live_manifest_path, row.names = FALSE)
  }
}

# Update pipeline status
latest_live_date <- max(combined_live$date, na.rm = TRUE)
write_status(
  status = "ok",
  severity = "info",
  code = "LIVE_DATA_CURRENT",
  message = "Live extension updated successfully.",
  extra = list(
    last_success_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    data_through = as.character(latest_live_date),
    total_stations = n_distinct(combined_live$project_station_id),
    total_live_station_days = nrow(combined_live),
    valid_aqi_count = sum(!is.na(combined_live$aqi_verified)),
    date_range = list(
      start = as.character(min(combined_live$date, na.rm = TRUE)),
      end = as.character(latest_live_date)
    )
  )
)

cat(sprintf("\n[SUCCESS] Live data extension updated:\n"))
cat(sprintf("  - Target path: %s (%.2f KB)\n", processed_csv_path, file.size(processed_csv_path) / 1024))
cat(sprintf("  - Web JSON path: %s (%.2f KB)\n", web_json_path, file.size(web_json_path) / 1024))
cat(sprintf("  - Manifest: %s\n", live_manifest_path))
cat(sprintf("  - Pipeline status: %s\n", status_file))
cat(sprintf("  - Live observations span: %s to %s (%d records)\n",
            min(combined_live$date), latest_live_date, nrow(combined_live)))
