source("R/00_setup.R")
source("R/01_utils.R")

log_info("Starting Stage C: Station Selection Summary")

shortlist <- read.csv("data/metadata/india_station_shortlist.csv", stringsAsFactors = FALSE)
cr <- read.csv("data/metadata/coverage_report.csv", stringsAsFactors = FALSE)
cat <- read.csv("data/metadata/station_catalog.csv", stringsAsFactors = FALSE)
hyd <- read.csv("data/metadata/hyderabad_station_review.csv", stringsAsFactors = FALSE)

summary_rows <- list()

for (i in seq_len(nrow(shortlist))) {
   pid <- shortlist$project_station_id[i]
   c_row <- subset(cat, project_station_id == pid)
   h_row <- subset(hyd, project_station_id == pid)
   
   act_stat <- "unknown"
   geo_scope <- NA
   dup_stat <- "unique_current"
   
   if (nrow(h_row) > 0) {
      act_stat <- h_row$activity_status[1]
      geo_scope <- h_row$geographic_scope[1]
      dup_stat <- h_row$record_status[1]
   } else if (nrow(c_row) > 0) {
      # station_catalog doesn't save activity_status, derive from last_observation_date
      days_since <- as.numeric(difftime(Sys.time(), as.POSIXct(c_row$last_observation_date[1], format="%Y-%m-%dT%H:%M:%S", tz="UTC"), units="days"))
      act_stat <- ifelse(is.na(days_since), "unknown", ifelse(days_since <= 180, "active_recent", "inactive_or_stale"))
   }
   
   cr_st <- subset(cr, project_station_id == pid)
   
   get_pct <- function(p) {
      r <- subset(cr_st, parameter == p)
      if (nrow(r) > 0) return(r$days_with_data_pct[1]) else return(NA)
   }
   
   get_recent <- function(p) {
      r <- subset(cr_st, parameter == p)
      if (nrow(r) > 0) return(isTRUE(as.logical(r$recent_data_present[1]))) else return(FALSE)
   }
   
   pm25 <- get_pct("pm25")
   pm10 <- get_pct("pm10")
   no2 <- get_pct("no2")
   so2 <- get_pct("so2")
   co <- get_pct("co")
   o3 <- get_pct("o3")
   
   pm25_r <- get_recent("pm25")
   pm10_r <- get_recent("pm10")
   no2_r <- get_recent("no2")
   so2_r <- get_recent("so2")
   co_r <- get_recent("co")
   o3_r <- get_recent("o3")
   
   recent_flags <- c(pm25_r, pm10_r, no2_r, so2_r, co_r, o3_r)
   core_recent_count <- sum(recent_flags, na.rm = TRUE)
   
   pcts <- c(pm25, pm10, no2, so2, co, o3)
   # Only compute min/mean from pollutants that genuinely have recent data
   valid_pcts <- pcts[recent_flags]
   
   min_cov <- if(length(valid_pcts) > 0) min(valid_pcts, na.rm=TRUE) else NA
   mean_cov <- if(length(valid_pcts) > 0) round(mean(valid_pcts, na.rm=TRUE), 2) else NA
   
   readiness <- "Insufficient recent data"
   if (core_recent_count >= 3 && !is.na(min_cov) && min_cov >= 50) {
      readiness <- "Strong candidate"
   } else if (core_recent_count > 0 && !is.na(mean_cov) && mean_cov >= 30) {
      readiness <- "Candidate with limitations"
   }
   
   if (act_stat == "inactive_or_stale") readiness <- "Legacy/inactive"
   if (!is.na(geo_scope) && geo_scope %in% c("peripheral_candidate", "uncertain")) readiness <- "Needs human geographic decision"
   
   first_obs <- if(nrow(c_row)>0) c_row$first_observation_date[1] else NA
   last_obs <- if(nrow(c_row)>0) c_row$last_observation_date[1] else NA
   c_state <- if(nrow(c_row)>0) c_row$state[1] else NA
   c_conf <- if(nrow(c_row)>0) c_row$city_match_confidence[1] else NA
   c_scope <- if(nrow(c_row)>0) c_row$city_scope_status[1] else NA
   c_polls_avail <- if(nrow(c_row)>0) c_row$core_pollutants_available_count[1] else 0
   
   summary_rows[[length(summary_rows) + 1]] <- data.frame(
      project_station_id = pid,
      source_location_id = shortlist$source_location_id[i],
      station_name = shortlist$station_name[i],
      city = shortlist$city[i],
      state = c_state,
      city_match_confidence = c_conf,
      city_scope_status = c_scope,
      activity_status = act_stat,
      geographic_scope = geo_scope,
      duplicate_status = dup_stat,
      core_pollutants_available_count = c_polls_avail,
      core_pollutants_with_recent_data = core_recent_count,
      pm2_5_days_with_data_pct = pm25,
      pm10_days_with_data_pct = pm10,
      no2_days_with_data_pct = no2,
      so2_days_with_data_pct = so2,
      co_days_with_data_pct = co,
      o3_days_with_data_pct = o3,
      minimum_core_coverage_pct = min_cov,
      mean_core_coverage_pct = mean_cov,
      first_observation_date = first_obs,
      last_observation_date = last_obs,
      selection_readiness = readiness,
      selection_notes = "",
      stringsAsFactors = FALSE
   )
}

if (length(summary_rows) > 0) {
   s_df <- do.call(rbind, summary_rows)
   write.csv(s_df, "data/metadata/station_selection_summary.csv", row.names = FALSE)
   log_info("Created data/metadata/station_selection_summary.csv")
}
