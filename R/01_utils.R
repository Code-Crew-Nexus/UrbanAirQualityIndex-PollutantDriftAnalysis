# ==============================================================================
# 01_utils.R: Core Utility Functions
# UrbanAirQualityIndex-PollutantDriftAnalysis
# B.Tech CSE (AI & ML) III Year / I Sem - Statistics for Machine Learning PBL
# ==============================================================================

#' Ensure a directory exists
ensure_dir <- function(path) {
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
  invisible(path)
}


#' Simple, secure logger (Never prints credentials)
log_msg <- function(level = c("INFO", "WARN", "ERROR"), msg, log_file = "logs/pipeline.log") {
  level <- match.arg(level)
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
  formatted <- sprintf("[%s] [%s] %s", timestamp, level, msg)
  
  # Print to console
  cat(formatted, "\n")
  
  # Append to file
  ensure_dir(dirname(log_file))
  tryCatch({
    cat(formatted, "\n", file = log_file, append = TRUE)
  }, error = function(e) {
    # Silently continue if log file write fails
  })
  invisible(formatted)
}

log_info  <- function(msg) log_msg("INFO", msg)
log_warn  <- function(msg) log_msg("WARN", msg)
log_error <- function(msg) log_msg("ERROR", msg)

#' Robust timestamp conversion to Indian Standard Time (Asia/Kolkata)
#'
#' @param time_str Character vector of ISO8601 or standard datetime strings
#' @param src_tz Source timezone, default "UTC"
#' @return POSIXct vector in Asia/Kolkata timezone
to_ist <- function(time_str, src_tz = "UTC") {
  if (is.null(time_str) || length(time_str) == 0) return(as.POSIXct(character(0)))
  
  # Clean potential trailing Z or formatting
  # Try parsing with lubridate or base as.POSIXct
  dt <- tryCatch({
    # Check if string contains standard ISO format
    as.POSIXct(time_str, format = "%Y-%m-%dT%H:%M:%OS", tz = src_tz)
  }, error = function(e) {
    as.POSIXct(time_str, tz = src_tz)
  })
  
  # Fallback for standard space-separated format
  na_idx <- which(is.na(dt))
  if (length(na_idx) > 0) {
    dt[na_idx] <- as.POSIXct(time_str[na_idx], format = "%Y-%m-%d %H:%M:%S", tz = src_tz)
  }
  
  # Fallback for ISO without seconds
  na_idx <- which(is.na(dt))
  if (length(na_idx) > 0) {
    dt[na_idx] <- as.POSIXct(time_str[na_idx], format = "%Y-%m-%dT%H:%M", tz = src_tz)
  }
  
  # Format in Asia/Kolkata
  dt_ist <- as.POSIXct(format(dt, tz = "Asia/Kolkata", usetz = FALSE), tz = "Asia/Kolkata")
  return(dt_ist)
}

#' Convert datetime or string safely to Asia/Kolkata calendar Date
#'
#' @param dt POSIXct or character datetime
#' @return Date object aligned with Indian Standard Time
to_ist_date <- function(dt) {
  if (is.character(dt)) {
    dt <- to_ist(dt)
  }
  as.Date(dt, tz = "Asia/Kolkata")
}

#' Standardize pollutant aliases to canonical names
#'
#' @param alias Raw pollutant string from source
#' @return Canonical name (pm2_5, pm10, no2, so2, co, o3, nh3) or original lowercase
map_pollutant_name <- function(alias) {
  if (is.null(alias) || is.na(alias)) return(NA_character_)
  clean <- tolower(trimws(as.character(alias)))
  clean <- gsub("[^a-z0-9_.]", "", clean)
  
  mapping <- list(
    pm2_5 = c("pm25", "pm2.5", "pm2_5", "particulatematter2.5", "particulatematter25"),
    pm10  = c("pm10", "pm10.0", "particulatematter10"),
    no2   = c("no2", "no_2", "nitrogendioxide"),
    so2   = c("so2", "so_2", "sulfurdioxide", "sulphurdioxide"),
    co    = c("co", "carbonmonoxide"),
    o3    = c("o3", "ozone", "groundlevelozone"),
    nh3   = c("nh3", "nh_3", "ammonia")
  )
  
  for (canon in names(mapping)) {
    if (clean %in% mapping[[canon]]) {
      return(canon)
    }
  }
  return(clean)
}

#' Safe HTTP GET request wrapper
#'
#' @param url Target URL
#' @param headers Named list or character vector of headers
#' @param timeout_sec Timeout in seconds
#' @return List with status_code, body, and error message if any
safe_http_get <- function(url, headers = list(), timeout_sec = 15) {
  # Redact any API keys from logging
  redacted_url <- gsub("api-key=[^&]+", "api-key=REDACTED", url)
  log_info(sprintf("Initiating GET request to: %s", redacted_url))
  
  res <- list(
    status_code = NA_integer_,
    body = NULL,
    error = NULL,
    success = FALSE
  )
  
  # Use httr2 if installed
  if (requireNamespace("httr2", quietly = TRUE)) {
    tryCatch({
      req <- httr2::request(url)
      req <- httr2::req_timeout(req, timeout_sec)
      for (h_name in names(headers)) {
        req <- httr2::req_headers(req, !!h_name := headers[[h_name]])
      }
      resp <- httr2::req_perform(req)
      res$status_code <- httr2::resp_status(resp)
      res$body <- httr2::resp_body_string(resp)
      res$success <- (res$status_code >= 200 && res$status_code < 300)
    }, error = function(e) {
      res$error <- conditionMessage(e)
      log_warn(sprintf("HTTP request error: %s", res$error))
    })
    return(res)
  }
  
  # Base R fallback using download.file
  tmp_file <- tempfile()
  on.exit(unlink(tmp_file), add = TRUE)
  
  tryCatch({
    # Set headers if needed via options
    old_timeout <- getOption("timeout")
    options(timeout = timeout_sec)
    on.exit(options(timeout = old_timeout), add = TRUE)
    
    # Try download.file
    suppressWarnings({
      dl_code <- download.file(url, destfile = tmp_file, quiet = TRUE, mode = "wb")
    })
    
    if (dl_code == 0 && file.exists(tmp_file)) {
      res$status_code <- 200L
      res$body <- paste(readLines(tmp_file, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
      res$success <- TRUE
    } else {
      res$status_code <- 500L
      res$error <- "Download failed or non-zero exit code"
    }
  }, error = function(e) {
    res$error <- conditionMessage(e)
    log_warn(sprintf("Base HTTP download failed: %s", res$error))
  })
  
  return(res)
}

#' Read simple project configuration file
parse_project_config <- function(config_path = "config/project_config.yml") {
  if (!file.exists(config_path)) {
    log_warn(sprintf("Config file %s does not exist. Using defaults.", config_path))
    return(list(
      project = list(timezone = "Asia/Kolkata"),
      pollutants = list(core = c("PM2.5", "PM10", "NO2", "SO2", "CO", "O3"), optional = "NH3")
    ))
  }
  
  if (requireNamespace("yaml", quietly = TRUE)) {
    return(yaml::read_yaml(config_path))
  }
  
  # Basic fallback: read lines and parse essential keys
  lines <- readLines(config_path, warn = FALSE)
  cfg <- list(
    project = list(
      name = "UrbanAirQualityIndex-PollutantDriftAnalysis",
      timezone = "Asia/Kolkata"
    ),
    pollutants = list(
      core = c("PM2.5", "PM10", "NO2", "SO2", "CO", "O3"),
      optional = c("NH3")
    ),
    audit = list(
      audit_window_days = 90,
      sample_window_days = 7
    )
  )
  return(cfg)
}


safe_extract <- function(x) {
  if (is.null(x)) return(NA)
  if (length(x) == 0) return(NA)
  if (is.list(x)) return(x[[1]])
  if (is.na(x[[1]])) return(NA)
  val <- as.character(x[[1]])
  if (nchar(trimws(val)) == 0) return(NA)
  return(val)
}

#' Save raw response to an immutable file
save_raw_response_immutable <- function(base_dir, base_filename, content) {
  ensure_dir(base_dir)
  retrieval_ts <- format(Sys.time(), "%Y%m%dT%H%M%S", tz = "Asia/Kolkata")
  ext_idx <- regexpr("\\.[^\\.]*$", base_filename)
  if (ext_idx > 0) {
     name_part <- substr(base_filename, 1, ext_idx - 1)
     ext_part <- substr(base_filename, ext_idx, nchar(base_filename))
  } else {
     name_part <- base_filename
     ext_part <- ""
  }
  
  final_filename <- sprintf("%s_retrieved_%s%s", name_part, retrieval_ts, ext_part)
  full_path <- file.path(base_dir, final_filename)
  
  if (file.exists(full_path)) {
     existing_hash <- digest::digest(full_path, algo = "sha256", file = TRUE)
     new_hash <- digest::digest(content, algo = "sha256", serialize = FALSE)
     if (existing_hash != new_hash) {
        rand_suffix <- paste0(sample(letters, 4), collapse="")
        final_filename <- sprintf("%s_retrieved_%s_%s%s", name_part, retrieval_ts, rand_suffix, ext_part)
        full_path <- file.path(base_dir, final_filename)
     }
  }
  
  if (!file.exists(full_path)) {
     writeLines(content, full_path)
  }
  return(full_path)
}

#' Get Canonical Unit for a Pollutant or Weather Parameter
#'
#' @param param Parameter name (will be normalized first)
#' @return Canonical unit string
get_canonical_unit <- function(param) {
  canon_name <- map_pollutant_name(param)
  cfg <- parse_project_config()
  if (!is.null(cfg$units$canonical[[canon_name]])) {
     return(cfg$units$canonical[[canon_name]])
  }
  
  # Weather parameters might come straight as "temperature" etc.
  clean_param <- tolower(trimws(param))
  if (clean_param %in% c('temperature', 'relativehumidity', 'wind_speed', 'wind_direction', 'humidity')) {
      if (clean_param == 'temperature') return('°C')
      if (clean_param %in% c('relativehumidity', 'humidity')) return('%')
      if (clean_param == 'wind_speed') return('m/s')
      if (clean_param == 'wind_direction') return('°')
  }
  
  return(NA_character_)
}
