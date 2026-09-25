source("R/00_setup.R")
library(dplyr)
library(readr)

cat <- read_csv("data/metadata/phase2D3_location_sensor_unit_catalog.csv", show_col_types = FALSE)
sem <- read_csv("data/metadata/phase2D3_sensor_semantic_units.csv", show_col_types = FALSE)

target_stations <- c("R K Puram, Delhi - DPCC", "Zoo Park, Hyderabad - TSPCB", "Jadavpur, Kolkata - WBPCB")
target_pols <- c("co", "no2", "so2")

out <- data.frame()

for (st in target_stations) {
  for (pol in target_pols) {
    # Find selected sensor
    sel <- cat %>% filter(station_name == st, parameter_name == pol, selected_sensor == TRUE)
    if (nrow(sel) > 0) {
      sel <- sel[1, ]
      s_id <- sel$sensor_id
      
      # Find semantic row
      s_sem <- sem %>% filter(sensor_id == s_id)
      
      # Did we find a counterpart in reconciliation?
      cp_id <- s_sem$counterpart_sensor_id[1]
      
      if (!is.na(cp_id)) {
        cp_sel <- cat %>% filter(sensor_id == cp_id)
        
        # Load raw json
        sel_file <- paste0("data/raw/air_quality/openaq/unit_audit/sensor_", s_id, "_audit.json")
        cp_file <- paste0("data/raw/air_quality/openaq/unit_audit/sensor_", cp_id, "_audit.json")
        
        if (file.exists(sel_file) && file.exists(cp_file)) {
          sel_data <- jsonlite::read_json(sel_file)
          cp_data <- jsonlite::read_json(cp_file)
          
          if (length(sel_data) > 0 && length(cp_data) > 0) {
            # Pick the first overlapping timestamp
            sel_df <- data.frame(utc = sapply(sel_data, function(x) x$period$datetimeTo$utc),
                                 val = sapply(sel_data, function(x) x$value), stringsAsFactors=FALSE)
            cp_df <- data.frame(utc = sapply(cp_data, function(x) x$period$datetimeTo$utc),
                                val = sapply(cp_data, function(x) x$value), stringsAsFactors=FALSE)
            
            joined <- inner_join(sel_df, cp_df, by="utc", suffix=c("_sel", "_cp"))
            if (nrow(joined) > 0) {
              # take 3 samples
              for (j in 1:min(3, nrow(joined))) {
                out <- rbind(out, data.frame(
                  station = st,
                  pollutant = pol,
                  timestamp = joined$utc[j],
                  selected_sensor_id = s_id,
                  selected_value = joined$val_sel[j],
                  selected_reported_unit = sel$parameter_unit,
                  counterpart_sensor_id = cp_id,
                  counterpart_value = joined$val_cp[j],
                  counterpart_unit = cp_sel$parameter_unit[1],
                  relationship_observed = s_sem$best_fit_relationship[1],
                  verified_semantic_unit = s_sem$verified_semantic_unit[1],
                  stringsAsFactors = FALSE
                ))
              }
            }
          }
        }
      } else {
        # No counterpart available - log unresolved trace
        out <- rbind(out, data.frame(
          station = st,
          pollutant = pol,
          timestamp = NA,
          selected_sensor_id = s_id,
          selected_value = NA,
          selected_reported_unit = sel$parameter_unit,
          counterpart_sensor_id = NA,
          counterpart_value = NA,
          counterpart_unit = NA,
          relationship_observed = "NO_COUNTERPART",
          verified_semantic_unit = NA,
          stringsAsFactors = FALSE
        ))
      }
    }
  }
}

write_csv(out, "data/metadata/phase2D3_unit_trace_examples.csv")
