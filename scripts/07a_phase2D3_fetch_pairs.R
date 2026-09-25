source("R/00_setup.R")
library(httr2)
library(jsonlite)
library(dplyr)
library(readr)
library(stringr)

api_key <- Sys.getenv("OPENAQ_API_KEY")

snapshot <- read_csv("data/metadata/selected_sensor_snapshot.csv", show_col_types = FALSE)
unique_locs <- unique(snapshot[, c("project_station_id", "source_location_id", "station_name", "city")])

catalog <- data.frame()

for (i in 1:nrow(unique_locs)) {
  loc <- unique_locs[i, ]
  
  req <- request(paste0("https://api.openaq.org/v3/locations/", loc$source_location_id, "/sensors")) %>%
    req_headers(`X-API-Key` = api_key) %>%
    req_retry(max_tries = 3)
  
  resp <- req_perform(req)
  data <- resp_body_json(resp)$results
  
  for (s in data) {
    sensor_id <- s$id
    sensor_name <- s$name
    parameter_id <- s$parameter$id
    parameter_name <- s$parameter$name
    parameter_unit <- s$parameter$units
    
    dt_first <- if(!is.null(s$datetimeFirst$utc)) s$datetimeFirst$utc else NA
    dt_last <- if(!is.null(s$datetimeLast$utc)) s$datetimeLast$utc else NA
    
    # Is it one of our selected sensors?
    selected_row <- snapshot %>% filter(sensor_id == !!sensor_id)
    is_selected <- nrow(selected_row) > 0
    
    catalog <- rbind(catalog, data.frame(
      project_station_id = loc$project_station_id,
      source_location_id = loc$source_location_id,
      station_name = loc$station_name,
      city = loc$city,
      sensor_id = sensor_id,
      sensor_name = sensor_name,
      parameter_id = parameter_id,
      parameter_name = parameter_name,
      parameter_unit = parameter_unit,
      datetime_first = dt_first,
      datetime_last = dt_last,
      selected_sensor = is_selected,
      possible_unit_counterpart = FALSE, # to be populated later
      stringsAsFactors = FALSE
    ))
  }
  Sys.sleep(0.5)
}

# Identify counterparts
# A counterpart is another sensor at the same location for the same parameter (co, no2, so2, o3) with mass units
for (i in 1:nrow(catalog)) {
  if (!catalog$selected_sensor[i]) {
    pol <- catalog$parameter_name[i]
    if (pol %in% c("co", "no2", "so2", "o3")) {
      # Does a selected sensor exist for this pol at this location?
      sel <- catalog %>% filter(project_station_id == catalog$project_station_id[i], 
                                parameter_name == pol, selected_sensor == TRUE)
      if (nrow(sel) > 0) {
        # Mark as counterpart
        catalog$possible_unit_counterpart[i] <- TRUE
      }
    }
  }
}

write_csv(catalog, "data/metadata/phase2D3_location_sensor_unit_catalog.csv")
