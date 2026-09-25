# ==============================================================================
# 11_station_coverage_audit.R: Station Pollutant Coverage & Availability Audit
# UrbanAirQualityIndex-PollutantDriftAnalysis
# B.Tech CSE (AI & ML) III Year / I Sem - Statistics for Machine Learning PBL
# ==============================================================================

source("R/01_utils.R")
source("R/sources/openaq_source.R")

audit_station_coverage <- function(catalog_path = "data/metadata/station_catalog.csv",
                                   output_coverage = "data/metadata/coverage_report.csv",
                                   audit_window_days = 90) {
  log_info("Starting Station Pollutant Coverage and Completeness Audit...")
  
  if (!file.exists(catalog_path)) {
    stop(sprintf("Station catalog file '%s' not found.", catalog_path))
  }
  
  catalog <- read.csv(catalog_path, stringsAsFactors = FALSE)
  log_info(sprintf("Auditing %d stations from catalog.", nrow(catalog)))
  
  audit_end   <- Sys.Date()
  audit_start <- audit_end - audit_window_days + 1
  expected_days <- audit_window_days
  
  audit_rows <- list()
  
  if (nrow(catalog) == 0) {
    log_warn("Catalog is empty. Producing empty coverage report.")
    audit_df <- data.frame()
    ensure_dir(dirname(output_coverage))
    write.csv(audit_df, output_coverage, row.names = FALSE)
    return(audit_df)
  }
  
  for (i in seq_len(nrow(catalog))) {
    row <- catalog[i, ]
    src_loc_id <- row$source_location_id
    
    # We fetch location details which includes sensors
    # In OpenAQ v3, /locations/{id} provides sensor metadata
    endpoint <- sprintf("/locations/%s", as.character(src_loc_id))
    resp <- tryCatch({ openaq_request(endpoint) }, error = function(e) NULL)
    
    # Initialize metrics to NA
    pollutants <- c("pm25", "pm10", "no2", "so2", "co", "o3", "nh3")
    metrics <- list()
    for (p in pollutants) {
      metrics[[paste0(p, "_present")]] <- FALSE
      metrics[[paste0(p, "_count")]] <- NA
      metrics[[paste0(p, "_completeness_pct")]] <- NA
    }
    
    core_count <- NA
    overall_core_pct <- NA
    rec_status <- "Not Verifiable"
    rec_reason <- "External API keys missing or network unavailable; actual record counts unverified."
    
    if (!is.null(resp) && httr2::resp_status(resp) == 200) {
      body <- jsonlite::fromJSON(httr2::resp_body_string(resp), flatten = TRUE)
      loc_data <- body$results
      if (is.data.frame(loc_data) && nrow(loc_data) > 0 && "sensors" %in% colnames(loc_data)) {
        sensors <- loc_data$sensors[[1]]
        if (is.data.frame(sensors) && "parameter.name" %in% colnames(sensors)) {
          # Evaluate sensors
          c_count <- 0
          c_pct_sum <- 0
          valid_pcts <- 0
          
          for (p in pollutants) {
            # Find sensor matching pollutant name
            # OpenAQ usually uses "pm25", "pm10", "no2", "o3" etc.
            s_match <- sensors[tolower(sensors$parameter.name) == p, ]
            if (nrow(s_match) > 0) {
              metrics[[paste0(p, "_present")]] <- TRUE
              # Check if coverage is provided by source
              # OpenAQ v3 includes latest/summary info sometimes, but if not we leave count=NA
              # We will leave count as NA for now to comply with "If completeness cannot be validly calculated: completeness_pct = NA"
              metrics[[paste0(p, "_count")]] <- NA
              metrics[[paste0(p, "_completeness_pct")]] <- NA
              
              if (p %in% c("pm25", "pm10", "no2", "so2", "co", "o3")) {
                c_count <- c_count + 1
              }
            }
          }
          core_count <- c_count
          rec_status <- "Audited"
          rec_reason <- sprintf("Found %d core pollutants in source metadata.", core_count)
        }
      }
    }
    
    audit_rows[[i]] <- data.frame(
      project_station_id               = row$project_station_id,
      station_name                     = row$station_name,
      city                             = row$city,
      state                            = row$state,
      source_location_id               = src_loc_id,
      audit_window_start               = as.character(audit_start),
      audit_window_end                 = as.character(audit_end),
      pm2_5_present                    = metrics$pm25_present,
      pm2_5_count                      = metrics$pm25_count,
      pm2_5_completeness_pct           = metrics$pm25_completeness_pct,
      pm10_present                     = metrics$pm10_present,
      pm10_count                       = metrics$pm10_count,
      pm10_completeness_pct            = metrics$pm10_completeness_pct,
      no2_present                      = metrics$no2_present,
      no2_count                        = metrics$no2_count,
      no2_completeness_pct             = metrics$no2_completeness_pct,
      so2_present                      = metrics$so2_present,
      so2_count                        = metrics$so2_count,
      so2_completeness_pct             = metrics$so2_completeness_pct,
      co_present                       = metrics$co_present,
      co_count                         = metrics$co_count,
      co_completeness_pct              = metrics$co_completeness_pct,
      o3_present                       = metrics$o3_present,
      o3_count                         = metrics$o3_count,
      o3_completeness_pct              = metrics$o3_completeness_pct,
      nh3_present                      = metrics$nh3_present,
      nh3_count                        = metrics$nh3_count,
      nh3_completeness_pct             = metrics$nh3_completeness_pct,
      core_pollutants_available_count  = core_count,
      overall_core_completeness_pct    = overall_core_pct,
      recommended                      = rec_status,
      recommendation_reason            = rec_reason,
      stringsAsFactors = FALSE
    )
  }
  
  audit_df <- do.call(rbind, audit_rows)
  ensure_dir(dirname(output_coverage))
  write.csv(audit_df, output_coverage, row.names = FALSE)
  log_info(sprintf("Saved coverage report to: %s", output_coverage))
  
  return(audit_df)
}

# ---------------------------------------------------------
# summarize_coverage
# ---------------------------------------------------------
summarize_coverage <- function(days_data, audit_start, audit_end) {
   # days_data is the parsed$results array from openaq /days
   audit_start_date <- as.Date(audit_start, tz = "Asia/Kolkata")
   audit_end_date   <- as.Date(audit_end, tz = "Asia/Kolkata")

   valid_dates <- c()
   pc_comp_list <- c()
   pc_cov_list <- c()
   api_cov_anom <- 0
   
   if (length(days_data) > 0) {
      for (d in days_data) {
         # Extract local period start
         dt_loc <- safe_extract(d$period$datetimeFrom$local)
         if (!is.na(dt_loc)) {
            # 2024-01-01T00:00:00+05:30
            date_only <- as.Date(substr(dt_loc, 1, 10))
            
            # VERIFY date filtering!
            if (date_only >= audit_start_date && date_only <= audit_end_date) {
               valid_dates <- c(valid_dates, as.character(date_only))
               
               c_comp <- suppressWarnings(as.numeric(safe_extract(d$coverage$percentComplete)))
               c_cov <- suppressWarnings(as.numeric(safe_extract(d$coverage$percentCoverage)))
               
               if (!is.na(c_comp)) {
                  if (c_comp >= 0 && c_comp <= 100) pc_comp_list <- c(pc_comp_list, c_comp) else api_cov_anom <- api_cov_anom + 1
               }
               if (!is.na(c_cov)) {
                  if (c_cov >= 0 && c_cov <= 100) pc_cov_list <- c(pc_cov_list, c_cov) else api_cov_anom <- api_cov_anom + 1
               }
            }
         }
      }
   }
   
   unique_dates <- unique(valid_dates)
   distinct_valid_dates <- length(unique_dates)
   days_in_interval <- as.numeric(audit_end_date - audit_start_date) + 1 # e.g. 30 days
   
   days_with_data_pct <- NA
   if (days_in_interval > 0) {
      days_with_data_pct <- round((distinct_valid_dates / days_in_interval) * 100, 2)
   }
   
   api_pc_comp_mean <- NA
   api_pc_cov_mean <- NA
   if (length(pc_comp_list) > 0) api_pc_comp_mean <- round(mean(pc_comp_list), 2)
   if (length(pc_cov_list) > 0) api_pc_cov_mean <- round(mean(pc_cov_list), 2)
   
   return(list(
      distinct_valid_dates = distinct_valid_dates,
      days_with_data_pct = days_with_data_pct,
      api_pc_comp_mean = api_pc_comp_mean,
      api_pc_cov_mean = api_pc_cov_mean,
      api_cov_anom = api_cov_anom
   ))
}
