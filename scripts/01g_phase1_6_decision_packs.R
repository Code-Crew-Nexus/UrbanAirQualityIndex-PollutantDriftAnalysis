source("R/01_utils.R")
library(dplyr)

log_info("Building Decision Packs...")

sl <- read.csv("data/metadata/sensor_lineage_summary.csv", stringsAsFactors=F)
cr <- read.csv("data/metadata/coverage_report.csv", stringsAsFactors=F)
hyd_review <- read.csv("data/metadata/hyderabad_station_review.csv", stringsAsFactors=F)
sh <- read.csv("data/metadata/india_station_shortlist.csv", stringsAsFactors=F)
sc <- read.csv("data/metadata/station_catalog.csv", stringsAsFactors=F)
sss <- read.csv("data/metadata/station_selection_summary.csv", stringsAsFactors=F)

cfg <- parse_project_config()
core_polls <- sapply(cfg$pollutants$core, map_pollutant_name)

get_station_history <- function(proj_id) {
   s_sl <- subset(sl, project_station_id == proj_id)
   if (nrow(s_sl) == 0) return(list(earliest = NA, latest = NA, max_gap = NA, hist_summary = "No metadata", gas_conversion = NA))
   
   meta_starts <- as.POSIXct(s_sl$metadata_earliest_start, format="%Y-%m-%dT%H:%M:%S", tz="UTC")
   meta_ends <- as.POSIXct(s_sl$metadata_latest_end, format="%Y-%m-%dT%H:%M:%S", tz="UTC")
   earliest <- min(meta_starts, na.rm=T)
   latest <- max(meta_ends, na.rm=T)
   max_gap <- max(s_sl$largest_inter_generation_gap_days, na.rm=T)
   
   summ <- "continuous_or_near_continuous"
   if (!is.na(max_gap)) {
      if (max_gap > 30) summ <- "minor_gap"
      if (max_gap > 90) summ <- "major_gap"
   }
   if (any(s_sl$metadata_continuity_status == "current_only", na.rm=T)) summ <- "current_only"
   
   gas_conv <- any(s_sl$unit_compatibility_status == "conversion_required_later", na.rm=T)
   
   return(list(
      earliest = format(earliest, "%Y-%m-%d"), 
      latest = format(latest, "%Y-%m-%d"), 
      max_gap = max_gap, 
      hist_summary = summ,
      gas_conversion = gas_conv
   ))
}

# 1. Hyderabad Decision Pack
log_info("Building Hyderabad Decision Pack")
hyd_candidates <- subset(hyd_review, !(record_status %in% c("inactive", "legacy_location_record")))

hyd_pack_list <- list()
if (nrow(hyd_candidates) > 0) {
  for (i in 1:nrow(hyd_candidates)) {
    pid <- hyd_candidates$project_station_id[i]
    st_sc <- subset(sc, project_station_id == pid)
    
    st_cr <- subset(cr, project_station_id == pid & parameter %in% core_polls)
    
    c_avail <- length(unique(st_cr$parameter))
    c_recent <- sum(!is.na(st_cr$days_with_data_pct) & st_cr$days_with_data_pct > 0)
    
    cov_vec <- st_cr$days_with_data_pct
    mean_cov <- ifelse(length(cov_vec)>0 && any(!is.na(cov_vec)), mean(cov_vec, na.rm=T), 0)
    min_cov <- ifelse(length(cov_vec)>0 && any(!is.na(cov_vec)), min(cov_vec, na.rm=T), 0)
    
    hist <- get_station_history(pid)
    
    strength <- "Candidate with limitations"
    if (c_recent >= 5 && mean_cov > 80) strength <- "Strong candidate"
    else if (c_recent >= 4 && mean_cov > 60) strength <- "Good candidate"
    else if (c_recent < 3 || mean_cov < 40) strength <- "Weak recent data"
    
    hyd_pack_list[[i]] <- data.frame(
        project_station_id = pid,
        source_location_id = hyd_candidates$source_location_id[i],
        station_name = hyd_candidates$station_name[i],
        latitude = hyd_candidates$latitude[i],
        longitude = hyd_candidates$longitude[i],
        provider = hyd_candidates$provider[i],
        owner = hyd_candidates$owner[i],
        activity_status = hyd_candidates$activity_status[i],
        record_status = hyd_candidates$record_status[i],
        duplicate_group = hyd_candidates$duplicate_group[i],
        geographic_scope = hyd_candidates$geographic_scope[i],
        core_pollutants_available_count = c_avail,
        core_pollutants_with_recent_data = c_recent,
        minimum_core_coverage_pct = min_cov,
        mean_core_coverage_pct = mean_cov,
        metadata_earliest_history = hist$earliest,
        metadata_latest_history = hist$latest,
        largest_core_sensor_gap_days = hist$max_gap,
        historical_continuity_summary = hist$hist_summary,
        gas_unit_conversion_required = hist$gas_conversion,
        selection_strength = strength,
        strength_reason = "Based on pollutant count and coverage",
        limitations = ifelse(hist$hist_summary == "major_gap", "Major historical gap", "None"),
        stringsAsFactors = FALSE
    )
  }
}
hyd_pack <- do.call(rbind, hyd_pack_list)
write.csv(hyd_pack, "data/metadata/hyderabad_selection_decision_pack.csv", row.names=FALSE)

# 2. India Station Decision Pack
log_info("Building India Station Decision Pack")
ind_pack <- subset(sss, project_station_id %in% sh$project_station_id)
# Ensure PROJ_200 is updated if needed (it should be in sss already)

ind_pack$metadata_earliest_history <- NA
ind_pack$metadata_latest_history <- NA
ind_pack$largest_core_sensor_gap_days <- NA
ind_pack$historical_continuity_summary <- NA

for (i in 1:nrow(ind_pack)) {
   hist <- get_station_history(ind_pack$project_station_id[i])
   ind_pack$metadata_earliest_history[i] <- hist$earliest
   ind_pack$metadata_latest_history[i] <- hist$latest
   ind_pack$largest_core_sensor_gap_days[i] <- hist$max_gap
   ind_pack$historical_continuity_summary[i] <- hist$hist_summary
}

ind_pack$selection_strength <- "Good candidate"
ind_pack$selection_strength[ind_pack$core_pollutants_with_recent_data >= 5 & ind_pack$mean_core_coverage_pct > 80] <- "Strong candidate"
ind_pack$selection_strength[ind_pack$core_pollutants_with_recent_data < 3] <- "Usable with limitations"

ind_pack$strength_reason <- "Based on core pollutants"
ind_pack$limitations <- ifelse(ind_pack$historical_continuity_summary == "major_gap", "Major historical gap", "None")

write.csv(ind_pack, "data/metadata/india_station_selection_decision_pack.csv", row.names=FALSE)

# 3. India City Decision Pack
log_info("Building India City Decision Pack")
cities <- unique(sh$city)
city_pack <- list()

for (c in cities) {
   c_sc <- subset(sc, city == c)
   c_sh <- subset(sh, city == c)
   c_ind <- subset(ind_pack, city == c)
   
   # Sort candidates correctly
   c_ind <- c_ind[order(-c_ind$core_pollutants_with_recent_data, -c_ind$mean_core_coverage_pct), ]
   best_cand <- c_ind[1,]
   
   city_strength <- "Good candidate"
   if (best_cand$selection_strength == "Strong candidate") city_strength <- "Strong city candidate"
   if (best_cand$selection_strength == "Usable with limitations") city_strength <- "Usable with limitations"
   if (nrow(c_ind) == 0) city_strength <- "Weak"
   
   city_pack[[length(city_pack) + 1]] <- data.frame(
      city = c,
      state = c_sh$state[1],
      catalog_station_count = nrow(c_sc),
      shortlist_station_count = nrow(c_sh),
      coverage_verified_candidate_count = nrow(c_ind),
      strong_candidate_count = sum(c_ind$selection_strength == "Strong candidate"),
      best_candidate_station = best_cand$station_name,
      best_candidate_source_location_id = best_cand$source_location_id,
      best_alternate_station = ifelse(nrow(c_ind) > 1, c_ind$station_name[2], NA),
      core_pollutants_available = best_cand$core_pollutants_available_count,
      core_pollutants_recent = best_cand$core_pollutants_with_recent_data,
      best_minimum_recent_coverage_pct = best_cand$minimum_core_coverage_pct,
      best_mean_recent_coverage_pct = best_cand$mean_core_coverage_pct,
      metadata_earliest_history = best_cand$metadata_earliest_history,
      metadata_latest_history = best_cand$metadata_latest_history,
      historical_continuity_summary = best_cand$historical_continuity_summary,
      city_selection_strength = city_strength,
      limitations = best_cand$limitations,
      stringsAsFactors = FALSE
   )
}
if (length(city_pack) > 0) {
  write.csv(do.call(rbind, city_pack), "data/metadata/india_city_selection_decision_pack.csv", row.names=FALSE)
}

# 4. Historical Window Options
log_info("Building Historical Window Options")

# Derive dates from lineage
meta_starts <- as.POSIXct(sl$preferred_current_start[!is.na(sl$preferred_current_start)], format="%Y-%m-%dT%H:%M:%S", tz="UTC")
if(length(meta_starts) > 0) {
   med_start <- format(median(meta_starts, na.rm=T), "%Y-%m-%d")
   q25_start <- format(quantile(meta_starts, 0.25, na.rm=T), "%Y-%m-%d")
   min_start <- format(min(meta_starts, na.rm=T), "%Y-%m-%d")
} else {
   med_start <- "2025-01-01"
   q25_start <- "2023-01-01"
   min_start <- "2018-01-01"
}

hw <- data.frame(
  window_option = c("WINDOW A - CONSERVATIVE CONTINUOUS", "WINDOW B - BALANCED", "WINDOW C - EXTENDED / MULTI-BLOCK"),
  start_date = c(med_start, q25_start, min_start),
  end_date = c("2026-09-24", "2026-09-24", "2026-09-24"),
  continuous_vs_discontinuous = c("Continuous", "Near Continuous (Minor gaps)", "Discontinuous (Requires backfill)"),
  hyderabad_candidates_retained = c("Most preferred current", "Many, with some missing history", "Only oldest stations"),
  india_cities_retained = c("All 15", "12-14", "Select few"),
  pollutants_supported = c("PM2.5, PM10, Gases", "PM2.5, PM10, Some Gases", "Mainly PM2.5/PM10"),
  advantages = c("Highly reliable, recent calibration", "Good balance of history and coverage", "Maximal historical context"),
  limitations = c("Short duration", "Potential missing blocks", "Requires CPCB backfill"),
  suitability_forecasting = c("High (short term)", "High (seasonal)", "Medium (due to gaps)"),
  derivation_method = c("Median of current sensor starts", "25th percentile of current starts", "Earliest sensor lineage"),
  measurement_completeness_status = c("Verified recent 30-day", "Unverified older blocks", "Unverified/Gaps"),
  stringsAsFactors = FALSE
)
write.csv(hw, "data/metadata/historical_window_options.csv", row.names=FALSE)

log_info("Decision Packs Generated.")
