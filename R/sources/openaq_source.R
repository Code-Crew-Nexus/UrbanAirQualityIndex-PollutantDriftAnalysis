# ==============================================================================
# openaq_source.R: OpenAQ Platform API v3 Source Adapter
# UrbanAirQualityIndex-PollutantDriftAnalysis
# B.Tech CSE (AI & ML) III Year / I Sem - Statistics for Machine Learning PBL
# ==============================================================================

source("R/01_utils.R")

OPENAQ_BASE_URL <- "https://api.openaq.org/v3"

#' Retrieve OpenAQ API Key from Environment
openaq_get_api_key <- function() {
  key <- Sys.getenv("OPENAQ_API_KEY", unset = "")
  if (nchar(trimws(key)) == 0) {
    log_warn("OPENAQ_API_KEY is not set in environment or .Renviron.")
    return(NULL)
  }
  return(trimws(key))
}

#' Authenticated httr2 Request Helper
#' 
#' @param endpoint API endpoint (e.g., "/locations")
#' @param query_params List of query parameters
#' @return httr2 response object
openaq_request <- function(endpoint, query_params = list()) {
  if (!requireNamespace("httr2", quietly = TRUE)) {
    stop("httr2 package is missing. Cannot proceed with OpenAQ authenticated requests.")
  }
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("jsonlite package is missing.")
  }
  
  api_key <- openaq_get_api_key()
  if (is.null(api_key)) {
    stop("OPENAQ_API_KEY is missing. Cannot perform authenticated request.")
  }
  
  req_url <- paste0(OPENAQ_BASE_URL, endpoint)
  req <- httr2::request(req_url) |>
    httr2::req_url_query(!!!query_params) |>
    httr2::req_headers("X-API-Key" = api_key, "Accept" = "application/json") |>
    httr2::req_error(is_error = function(resp) FALSE) # Handle errors manually
    
  max_retries <- 3
  attempt <- 1
  
  while (attempt <= max_retries) {
    resp <- httr2::req_perform(req)
    status <- httr2::resp_status(resp)
    
    rem <- httr2::resp_header(resp, "x-ratelimit-remaining")
    lim <- httr2::resp_header(resp, "x-ratelimit-limit")
    
    # log_info(sprintf("OpenAQ API %s - Status: %d, Quota: %s/%s", endpoint, status, ifelse(is.null(rem), "?", rem), ifelse(is.null(lim), "?", lim)))
    
    if (status == 429) {
      if (attempt == max_retries) return(resp)
      reset <- httr2::resp_header(resp, "x-ratelimit-reset")
      wait_time <- 60
      if (!is.null(reset)) {
         # if it is seconds to reset
         r_val <- as.numeric(reset)
         if (!is.na(r_val) && r_val < 3600 && r_val > 0) {
            wait_time <- r_val + 2
         } else if (!is.na(r_val) && r_val > 1000000000) {
            # Unix timestamp
            now <- as.numeric(Sys.time())
            if (r_val > now && r_val - now < 3600) {
               wait_time <- ceiling(r_val - now) + 2
            }
         }
      }
      log_warn(sprintf("HTTP 429 received on %s. Quota: %s/%s. Waiting %d sec...", endpoint, ifelse(is.null(rem), "?", rem), ifelse(is.null(lim), "?", lim), wait_time))
      Sys.sleep(wait_time)
      attempt <- attempt + 1
    } else if (status >= 500) {
      if (attempt == max_retries) return(resp)
      Sys.sleep(5 * attempt)
      attempt <- attempt + 1
    } else {
      # Add small delay if quota is low
      if (!is.null(rem)) {
         r_rem <- as.numeric(rem)
         if (!is.na(r_rem) && r_rem < 10) {
            Sys.sleep(2)
         }
      }
      # Pacing
      Sys.sleep(1)
      return(resp)
    }
  }
  return(resp)
}

#' Discover OpenAQ Monitoring Locations
#'
#' @param iso Country ISO code, default "IN"
#' @param limit Maximum locations to retrieve
#' @param bbox Optional bounding box
#' @return List with status, raw response, and parsed locations table
openaq_discover_locations <- function(iso = "IN", limit = 1000, bbox = NULL) {
  # Avoid making the request if no key exists (safeguard)
  if (is.null(openaq_get_api_key())) {
    return(list(success = FALSE, error = "Missing OPENAQ_API_KEY.", locations = data.frame()))
  }
  
  all_locs <- list()
  page <- 1
  limit <- 1000
  
  while (TRUE) {
    query_params <- list(iso = iso, limit = limit, page = page)
    if (!is.null(bbox)) {
      query_params$bbox <- bbox
    }
    
    resp <- tryCatch({
      openaq_request("/locations", query_params)
    }, error = function(e) {
      log_error(sprintf("OpenAQ locations discovery failed with hard error on page %d: %s", page, conditionMessage(e)))
      return(NULL)
    })
    
    if (is.null(resp)) {
      if (page == 1) return(list(success = FALSE, error = "Request failed", locations = data.frame()))
      break # Return what we have so far
    }
    
    status <- httr2::resp_status(resp)
    body_text <- httr2::resp_body_string(resp)
    
    if (status >= 400) {
      err_msg <- sprintf("HTTP %s. Body: %s", status, substr(body_text, 1, 200))
      log_warn(sprintf("OpenAQ locations API error on page %d: %s", page, err_msg))
      if (page == 1) return(list(success = FALSE, error = err_msg, locations = data.frame()))
      break # Return what we have so far
    }
    
    parsed <- jsonlite::fromJSON(body_text, simplifyVector = FALSE)
    if (is.null(parsed$results) || length(parsed$results) == 0) {
      break
    }
    
    all_locs <- c(all_locs, parsed$results)
    
    # If fewer results than limit, we've hit the last page
    if (length(parsed$results) < limit) {
      break
    }
    page <- page + 1
  }
  
  return(list(success = TRUE, raw = "Paginated payload", locations = all_locs))
}

#' Fetch Measurements from a Specific Sensor
#'
#' @param sensor_id Unique sensor ID
#' @param datetime_from ISO8601 start timestamp
#' @param datetime_to ISO8601 end timestamp
#' @param limit Number of records to retrieve
#' @return List with success status, raw payload, and data frame
openaq_fetch_measurements <- function(sensor_id, datetime_from = NULL, datetime_to = NULL, limit = 1000) {
  if (is.null(openaq_get_api_key())) {
    return(list(success = FALSE, error = "Missing OPENAQ_API_KEY.", measurements = data.frame()))
  }
  
  endpoint <- sprintf("/sensors/%s/measurements", as.character(sensor_id))
  query_params <- list(limit = limit)
  if (!is.null(datetime_from)) query_params$datetime_from <- datetime_from
  if (!is.null(datetime_to)) query_params$datetime_to <- datetime_to
  
  resp <- tryCatch({
    openaq_request(endpoint, query_params)
  }, error = function(e) {
    log_error(sprintf("OpenAQ measurements fetch failed with hard error: %s", conditionMessage(e)))
    return(NULL)
  })
  
  if (is.null(resp)) {
    return(list(success = FALSE, error = "Request failed", measurements = data.frame()))
  }
  
  status <- httr2::resp_status(resp)
  body_text <- httr2::resp_body_string(resp)
  
  if (status >= 400) {
    err_msg <- sprintf("HTTP %s. Body: %s", status, substr(body_text, 1, 200))
    if (status == 401) err_msg <- "Authentication problem (401)"
    if (status == 403) err_msg <- "Authorization/access problem (403)"
    if (status == 429) err_msg <- "Rate limit exceeded (429)"
    if (status >= 500) err_msg <- "Upstream service problem (5xx)"
    log_warn(sprintf("OpenAQ measurements API error for sensor %s: %s", sensor_id, err_msg))
    return(list(success = FALSE, error = err_msg, measurements = data.frame()))
  }
  
  return(list(success = TRUE, raw = body_text, status_code = status))
}
