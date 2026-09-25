# ==============================================================================
# cpcb_source.R: CPCB / data.gov.in Source Adapter
# UrbanAirQualityIndex-PollutantDriftAnalysis
# B.Tech CSE (AI & ML) III Year / I Sem - Statistics for Machine Learning PBL
# ==============================================================================

source("R/01_utils.R")

CPCB_RESOURCE_ID <- "3b01bcb8-0b14-4abf-b6f2-c1bfd384ba69"
CPCB_API_BASE    <- "https://api.data.gov.in/resource"

#' Retrieve data.gov.in API Key
cpcb_get_api_key <- function() {
  key <- Sys.getenv("DATAGOV_API_KEY", unset = "")
  if (nchar(trimws(key)) == 0) {
    log_warn("DATAGOV_API_KEY is not set in environment or .Renviron.")
    log_warn("Accessing CPCB resource via data.gov.in requires a registered API key.")
    log_warn("Register at https://data.gov.in to obtain a free API key.")
    return(NULL)
  }
  return(trimws(key))
}

#' Fetch Real-Time CAAQMS Air Quality Bulletin
#'
#' @param city Optional city filter (e.g. "Hyderabad")
#' @param state Optional state filter (e.g. "Telangana")
#' @param limit Number of records (default 100)
#' @return List with status, raw response, and limitations notice
cpcb_fetch_realtime <- function(city = NULL, state = NULL, limit = 100) {
  api_key <- cpcb_get_api_key()
  if (is.null(api_key)) {
    return(list(
      success = FALSE,
      error = "Missing DATAGOV_API_KEY.",
      note = "CPCB data.gov.in API requires authentication.",
      records = data.frame()
    ))
  }
  
  query_url <- sprintf("%s/%s?api-key=%s&format=json&limit=%d", CPCB_API_BASE, CPCB_RESOURCE_ID, api_key, limit)
  if (!is.null(city)) {
    query_url <- paste0(query_url, "&filters[city]=", URLencode(city))
  }
  if (!is.null(state)) {
    query_url <- paste0(query_url, "&filters[state]=", URLencode(state))
  }
  
  resp <- safe_http_get(query_url)
  
  # Crucial documentation note on source limitation:
  log_info("[SOURCE NOTICE] CPCB resource 3b01bcb8-0b14-4abf-b6f2-c1bfd384ba69 provides real-time snapshots only.")
  log_info("[SOURCE NOTICE] It does NOT support historical time-series retrieval. Use for provenance and live cross-validation.")
  
  return(resp)
}
