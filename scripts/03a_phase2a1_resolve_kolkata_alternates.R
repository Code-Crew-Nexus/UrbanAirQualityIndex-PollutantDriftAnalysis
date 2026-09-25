source("R/00_setup.R")
source("R/01_utils.R")

cat <- read.csv("data/metadata/sensor_catalog.csv", stringsAsFactors=F)

# We want PROJ_094 (Jadavpur) and PROJ_135 (Victoria)
alt <- cat[cat$project_station_id %in% c("PROJ_094", "PROJ_135") & 
           cat$sensor_generation_status == "preferred_current" & 
           cat$parameter %in% c("pm2_5", "pm10", "no2", "so2", "co", "o3"), ]

if (nrow(alt) != 12) {
    stop("Expected exactly 12 sensors for Kolkata alternates, got ", nrow(alt))
}

out_cols <- c("project_station_id", "source_location_id", "station_name", "parameter", "sensor_id", 
              "sensor_datetime_first", "sensor_datetime_last", "source_unit", "canonical_target_unit", "unit_compatibility_status")

write.csv(alt[, out_cols], "data/metadata/phase2a1_kolkata_alternate_sensors.csv", row.names=FALSE)
log_info("Resolved 12 Kolkata alternate sensors.")
