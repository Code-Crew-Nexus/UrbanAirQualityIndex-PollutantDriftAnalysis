source("R/00_setup.R")
library(dplyr)
library(readr)

# Load existing D3 semantics
d3 <- read_csv("data/metadata/phase2D3_sensor_semantic_units.csv", show_col_types = FALSE)

# Generate final semantics
final <- d3 %>%
  mutate(
    verification_method = case_when(
      pollutant %in% c("pm2_5", "pm10", "o3") ~ "OPENAQ_CANONICAL_METADATA",
      TRUE ~ "FALLBACK_UNRESOLVED"
    ),
    best_relationship = best_fit_relationship,
    canonical_aqi_unit = canonical_target_unit,
    notes = ifelse(pollutant %in% c("co", "no2", "so2"), "CPCB CCR reconciliation unfeasible; fallback locked", notes)
  ) %>%
  select(
    project_station_id,
    sensor_id,
    pollutant,
    openaq_reported_unit,
    verified_semantic_unit,
    canonical_aqi_unit,
    verification_method,
    matched_timestamp_count,
    best_relationship,
    median_relative_error,
    verification_status,
    evidence_source,
    notes
  )

write_csv(final, "data/metadata/phase2D4_final_sensor_semantic_units.csv")
