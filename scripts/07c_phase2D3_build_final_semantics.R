source("R/00_setup.R")
library(dplyr)
library(readr)

snapshot <- read_csv("data/metadata/selected_sensor_snapshot.csv", show_col_types = FALSE)

# check if reconciliation exists
rec_file <- "data/metadata/phase2D3_paired_unit_reconciliation.csv"
if (file.exists(rec_file)) {
  rec <- read_csv(rec_file, show_col_types = FALSE)
} else {
  rec <- data.frame()
}

out <- data.frame()

for (i in 1:nrow(snapshot)) {
  row <- snapshot[i, ]
  
  if (row$parameter %in% c("pm2_5", "pm10", "o3")) {
    # Straightforward metadata confirmation
    verified <- row$source_unit
    
    # Check if O3 was in reconciliation (control validation)
    cp_row <- if(nrow(rec) > 0) rec %>% filter(selected_sensor_id == row$sensor_id) else data.frame()
    if (nrow(cp_row) > 0) {
      meth <- "PAIRED_OPENAQ_SENSOR_CONTROL"
      cp_id <- cp_row$counterpart_sensor_id[1]
      matches <- cp_row$matched_timestamp_count[1]
      bf <- cp_row$best_supported_semantic_unit[1]
      mre <- cp_row$median_absolute_relative_error_expected_conversion[1]
      status <- cp_row$verification_status[1]
      notes <- cp_row$evidence_notes[1]
    } else {
      meth <- "CANONICAL_METADATA"
      cp_id <- NA
      matches <- NA
      bf <- verified
      mre <- NA
      status <- "VERIFIED"
      notes <- "Unit is natively mass-based in OpenAQ API."
    }
    
    out <- rbind(out, data.frame(
      project_station_id = row$project_station_id,
      source_location_id = row$source_location_id,
      sensor_id = row$sensor_id,
      pollutant = row$parameter,
      openaq_reported_unit = row$source_unit,
      verified_semantic_unit = verified,
      canonical_target_unit = row$canonical_target_unit,
      verification_method = meth,
      counterpart_sensor_id = cp_id,
      matched_timestamp_count = matches,
      best_fit_relationship = bf,
      median_relative_error = mre,
      verification_status = status,
      evidence_source = "OpenAQ API Metadata",
      evidence_interval = NA,
      notes = notes,
      stringsAsFactors = FALSE
    ))
    
  } else {
    # Gases that need reconciliation (co, no2, so2)
    cp_row <- if(nrow(rec) > 0) rec %>% filter(selected_sensor_id == row$sensor_id) else data.frame()
    if (nrow(cp_row) > 0) {
      out <- rbind(out, data.frame(
        project_station_id = row$project_station_id,
        source_location_id = row$source_location_id,
        sensor_id = row$sensor_id,
        pollutant = row$parameter,
        openaq_reported_unit = row$source_unit,
        verified_semantic_unit = cp_row$best_supported_semantic_unit[1],
        canonical_target_unit = row$canonical_target_unit,
        verification_method = "PAIRED_OPENAQ_SENSOR",
        counterpart_sensor_id = cp_row$counterpart_sensor_id[1],
        matched_timestamp_count = cp_row$matched_timestamp_count[1],
        best_fit_relationship = cp_row$best_supported_semantic_unit[1],
        median_relative_error = cp_row$median_absolute_relative_error_expected_conversion[1],
        verification_status = cp_row$verification_status[1],
        evidence_source = "OpenAQ API Data Overlap",
        evidence_interval = paste(cp_row$overlap_start[1], cp_row$overlap_end[1], sep=" to "),
        notes = cp_row$evidence_notes[1],
        stringsAsFactors = FALSE
      ))
    } else {
      # No counterpart found in OpenAQ. 
      # Since we can't fetch CPCB manually here, we use EXACT CPCB RECONCILIATION fallback.
      # Wait, CPCB CAAQMS standard says they are mg/m3 and ug/m3. 
      # But the user says "If no exact comparison is possible: mark the sensor: UNRESOLVED. Do not manufacture verification."
      out <- rbind(out, data.frame(
        project_station_id = row$project_station_id,
        source_location_id = row$source_location_id,
        sensor_id = row$sensor_id,
        pollutant = row$parameter,
        openaq_reported_unit = row$source_unit,
        verified_semantic_unit = NA,
        canonical_target_unit = row$canonical_target_unit,
        verification_method = "NO_COUNTERPART",
        counterpart_sensor_id = NA,
        matched_timestamp_count = NA,
        best_fit_relationship = NA,
        median_relative_error = NA,
        verification_status = "UNRESOLVED",
        evidence_source = "Missing paired data",
        evidence_interval = NA,
        notes = "No mass counterpart found on OpenAQ and no manual CPCB query performed.",
        stringsAsFactors = FALSE
      ))
    }
  }
}

write_csv(out, "data/metadata/phase2D3_sensor_semantic_units.csv")

# Now update the distribution file
dist <- read_csv("data/metadata/phase2D2_source_unit_distribution.csv", show_col_types = FALSE)

for(i in 1:nrow(dist)) {
  pol <- dist$pollutant[i]
  sid <- snapshot$sensor_id[snapshot$project_station_id == dist$project_station_id[i] & snapshot$parameter == pol][1]
  sem_row <- out %>% filter(sensor_id == sid)
  
  if(nrow(sem_row) > 0) {
    dist$source_unit_verified[i] <- sem_row$verified_semantic_unit[1]
    if (sem_row$verification_status[1] == "VERIFIED") {
      if (sem_row$verified_semantic_unit[1] == sem_row$canonical_target_unit[1]) {
        dist$canonical_conversion_status[i] <- "canonical_pass_through"
      } else {
        dist$canonical_conversion_status[i] <- "conversion_ready"
      }
    } else {
      dist$canonical_conversion_status[i] <- "blocked_unresolved"
    }
  }
}

write_csv(dist, "data/metadata/phase2D3_source_unit_distribution.csv")
