source("R/01_utils.R")
library(dplyr)

log_info("Starting Phase 1.6 Sensor Lineage Analysis")

sensor_cat <- read.csv("data/metadata/sensor_catalog.csv", stringsAsFactors=F)
sc <- read.csv("data/metadata/station_catalog.csv", stringsAsFactors=F)

# Merge city/state info just in case
sensor_cat <- merge(sensor_cat, sc[, c("source_location_id", "state")], by="source_location_id", all.x=TRUE)

cfg <- parse_project_config()
core_polls <- sapply(cfg$pollutants$core, map_pollutant_name)

# Filter to core pollutants
sensor_cat <- subset(sensor_cat, parameter %in% core_polls)

# Process by station and pollutant
results <- list()
stations <- unique(sensor_cat$project_station_id)

for (st in stations) {
  st_sensors <- subset(sensor_cat, project_station_id == st)
  params <- unique(st_sensors$parameter)
  
  for (p in params) {
    p_sens <- subset(st_sensors, parameter == p)
    # Sort by first observation
    p_sens$dt_start <- as.POSIXct(p_sens$sensor_datetime_first, format="%Y-%m-%dT%H:%M:%S", tz="UTC")
    p_sens$dt_end <- as.POSIXct(p_sens$sensor_datetime_last, format="%Y-%m-%dT%H:%M:%S", tz="UTC")
    p_sens <- p_sens[order(p_sens$dt_start), ]
    
    gen_count <- nrow(p_sens)
    leg_ids <- paste(p_sens$sensor_id[p_sens$sensor_generation_status != "preferred_current"], collapse=",")
    curr_id <- p_sens$sensor_id[p_sens$sensor_generation_status == "preferred_current"][1]
    
    meta_start <- min(p_sens$dt_start, na.rm=T)
    meta_end <- max(p_sens$dt_end, na.rm=T)
    
    curr_start <- NA
    curr_end <- NA
    curr_unit <- NA
    canon_unit <- NA
    unit_status <- NA
    
    if (!is.na(curr_id)) {
       curr_row <- p_sens[p_sens$sensor_id == curr_id, ][1,]
       curr_start <- curr_row$dt_start
       curr_end <- curr_row$dt_end
       curr_unit <- curr_row$source_unit
       canon_unit <- curr_row$canonical_target_unit
       unit_status <- curr_row$unit_compatibility_status
    }
    
    # Gap analysis
    max_gap <- 0
    num_gaps <- 0
    if (gen_count > 1) {
       for (i in 2:gen_count) {
          prev_end <- p_sens$dt_end[i-1]
          next_start <- p_sens$dt_start[i]
          if (!is.na(prev_end) && !is.na(next_start)) {
             gap <- as.numeric(difftime(next_start, prev_end, units="days"))
             if (gap > 0) {
                num_gaps <- num_gaps + 1
                if (gap > max_gap) max_gap <- gap
             }
          }
       }
    }
    
    # Continuity status
    cont_status <- "insufficient_metadata"
    if (gen_count == 1) {
       if (is.na(curr_id)) cont_status <- "legacy_only"
       else cont_status <- "current_only"
    } else {
       if (max_gap <= 30) cont_status <- "continuous_or_near_continuous"
       else if (max_gap <= 90) cont_status <- "minor_gap"
       else cont_status <- "major_gap"
       
       if (is.na(curr_id)) cont_status <- "legacy_only"
    }
    
    results[[length(results) + 1]] <- data.frame(
      project_station_id = st,
      source_location_id = p_sens$source_location_id[1],
      station_name = p_sens$station_name[1],
      city = p_sens$city[1],
      state = p_sens$state[1],
      parameter = p,
      sensor_generation_count = gen_count,
      legacy_sensor_ids = leg_ids,
      current_sensor_id = curr_id,
      metadata_earliest_start = format(meta_start, "%Y-%m-%dT%H:%M:%S%z", tz="UTC"),
      metadata_latest_end = format(meta_end, "%Y-%m-%dT%H:%M:%S%z", tz="UTC"),
      preferred_current_start = format(curr_start, "%Y-%m-%dT%H:%M:%S%z", tz="UTC"),
      preferred_current_end = format(curr_end, "%Y-%m-%dT%H:%M:%S%z", tz="UTC"),
      largest_inter_generation_gap_days = max_gap,
      number_of_inter_generation_gaps = num_gaps,
      metadata_continuity_status = cont_status,
      current_source_unit = curr_unit,
      canonical_target_unit = canon_unit,
      unit_compatibility_status = unit_status,
      stringsAsFactors = FALSE
    )
  }
}

if (length(results) > 0) {
  final_df <- do.call(rbind, results)
  write.csv(final_df, "data/metadata/sensor_lineage_summary.csv", row.names=F)
  log_info("Created sensor_lineage_summary.csv")
} else {
  log_info("No sensor lineage generated.")
}

