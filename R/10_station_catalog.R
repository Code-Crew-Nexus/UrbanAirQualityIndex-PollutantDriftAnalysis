# ==============================================================================
# 10_station_catalog.R: Monitoring Station Discovery & Catalog Construction
# UrbanAirQualityIndex-PollutantDriftAnalysis
# B.Tech CSE (AI & ML) III Year / I Sem - Statistics for Machine Learning PBL
# ==============================================================================

source("R/01_utils.R")
source("R/sources/openaq_source.R")

# ---------------------------------------------------------
# match_candidate_city
# ---------------------------------------------------------
match_candidate_city <- function(locality, station_name, active_cities, aliases) {
   parsed_token <- NA
   if (!is.na(station_name)) {
      part1 <- sub(" - .*$", "", station_name)
      if (grepl(",", part1)) {
         token <- trimws(sub(".*,", "", part1))
         if (nchar(token) > 0) parsed_token <- token
      }
   }
   
   check_match <- function(text) {
      if (is.na(text) || nchar(trimws(text)) == 0) return(NULL)
      for (i in seq_len(nrow(active_cities))) {
         c_city <- active_cities$city[i]
         c_state <- active_cities$state[i]
         if (tolower(trimws(text)) == tolower(c_city)) {
            return(list(city = c_city, state = c_state, alias = NA, scope_status = "exact_city"))
         }
         c_aliases <- subset(aliases, canonical_city == c_city)$alias
         for (al in c_aliases) {
            if (tolower(trimws(text)) == tolower(al)) {
               scope_status <- "verified_alias_same_city"
               if (grepl("navi", tolower(al))) scope_status <- "metro_adjacent"
               return(list(city = c_city, state = c_state, alias = al, scope_status = scope_status))
            }
         }
      }
      return(NULL)
   }
   
   m1 <- check_match(locality)
   if (!is.null(m1)) {
      return(list(city = m1$city, state = m1$state, method = "source_locality_exact", confidence = "high", alias = m1$alias, token = NA, scope = m1$scope_status))
   }
   
   if (!is.na(parsed_token)) {
      m2 <- check_match(parsed_token)
      if (!is.null(m2)) {
         return(list(city = m2$city, state = m2$state, method = "station_name_city_component", confidence = "high", alias = m2$alias, token = parsed_token, scope = m2$scope_status))
      }
      return(list(city = NA, state = NA, method = "mismatch_excluded", confidence = "high", alias = NA, token = parsed_token, scope = "mismatch_excluded"))
   }
   
   if (!is.na(station_name)) {
      for (i in seq_len(nrow(active_cities))) {
         c_city <- active_cities$city[i]
         c_state <- active_cities$state[i]
         pattern <- paste0("\\b", c_city, "\\b")
         if (grepl(pattern, station_name, ignore.case = TRUE)) {
            return(list(city = c_city, state = c_state, method = "name_only_fallback", confidence = "low", alias = NA, token = NA, scope = "exact_city"))
         }
         c_aliases <- subset(aliases, canonical_city == c_city)$alias
         for (al in c_aliases) {
            pattern <- paste0("\\b", al, "\\b")
            if (grepl(pattern, station_name, ignore.case = TRUE)) {
               scope_status <- "verified_alias_same_city"
               if (grepl("navi", tolower(al))) scope_status <- "metro_adjacent"
               return(list(city = c_city, state = c_state, method = "name_only_fallback", confidence = "low", alias = al, token = NA, scope = scope_status))
            }
         }
      }
   }
   return(list(city = NA, state = NA, method = NA, confidence = NA, alias = NA, token = NA, scope = NA))
}

build_station_catalog <- function(candidate_file = "config/candidate_india_cities.csv",
                                  output_catalog = "data/metadata/station_catalog.csv") {
  log_info("Beginning Station Discovery and Catalog Construction via OpenAQ v3...")
  
  if (!file.exists(candidate_file)) {
    stop(sprintf("Candidate cities file '%s' not found.", candidate_file))
  }
  
  cities_df <- read.csv(candidate_file, stringsAsFactors = FALSE)
  active_cities <- cities_df[cities_df$include_in_audit == TRUE, ]
  log_info(sprintf("Loaded %d candidate cities for station discovery.", nrow(active_cities)))
  
  resp <- openaq_discover_locations(iso = "IN", limit = 1000)
  
  if (!resp$success || length(resp$locations) == 0) {
    log_warn("Failed to fetch stations from OpenAQ or no stations found. Returning empty catalog.")
    df <- data.frame(
      project_station_id = character(),
      source = character(),
      source_station_id = character(),
      source_location_id = character(),
      station_name = character(),
      locality = character(),
      city = character(),
      state = character(),
      city_match_method = character(),
      city_match_confidence = character(),
      matched_alias = character(),
      parsed_location_token = character(),
      city_scope_status = character(),
      country = character(),
      latitude = numeric(),
      longitude = numeric(),
      timezone = character(),
      first_observation_date = character(),
      last_observation_date = character(),
      provider = character(),
      owner = character(),
      core_sensor_records_count = numeric(),
      core_pollutants_available_count = numeric(),
      verified_at = character(),
      verification_method = character(),
      stringsAsFactors = FALSE
    )
    ensure_dir(dirname(output_catalog))
    write.csv(df, output_catalog, row.names = FALSE)
    return(df)
  }
  
  locs <- resp$locations
  catalog_rows <- list()
  project_idx <- 1
  
  # Helper to safely extract values
  safe_extract <- function(x) {
    if (is.null(x) || length(x) == 0) return(NA)
    if (is.na(x[[1]])) return(NA)
    return(as.character(x[[1]]))
  }

  # Load aliases
  alias_file <- "config/city_aliases.csv"
  if (file.exists(alias_file)) {
    aliases <- read.csv(alias_file, stringsAsFactors = FALSE)
  } else {
    aliases <- data.frame(canonical_city = character(), alias = character(), stringsAsFactors = FALSE)
  }

  
  # Convert locs to list if it's a dataframe to simplify iteration
  if (is.data.frame(locs)) {
    locs_list <- split(locs, seq(nrow(locs)))
  } else {
    locs_list <- locs
  }
  
  for (row in locs_list) {
    if (is.data.frame(row)) {
      # Handle if split from df
      row <- as.list(row)
    }
    
    loc_id <- safe_extract(row$id)
    name <- safe_extract(row$name)
    locality <- safe_extract(row$locality)
    
    # Handle nested coordinates safely
    lat <- NA
    lon <- NA
    if (!is.null(row$coordinates) && is.list(row$coordinates)) {
      lat <- if (!is.null(row$coordinates$latitude)) as.numeric(row$coordinates$latitude) else NA
      lon <- if (!is.null(row$coordinates$longitude)) as.numeric(row$coordinates$longitude) else NA
    } else if ("coordinates.latitude" %in% names(row)) {
      lat <- as.numeric(row$coordinates.latitude)
      lon <- as.numeric(row$coordinates.longitude)
    }
    
    tz <- safe_extract(row$timezone)
    dt_first <- safe_extract(row$datetimeFirst$utc)
    if (is.na(dt_first)) dt_first <- safe_extract(row$datetimeFirst)
    dt_last <- safe_extract(row$datetimeLast$utc)
    if (is.na(dt_last)) dt_last <- safe_extract(row$datetimeLast)
    
    provider <- safe_extract(row$provider$name)
    owner <- safe_extract(row$owner$name)
    
    core_sensor_records <- 0
    available_polls <- c()
    sensors_list <- row$sensors
    if (!is.null(sensors_list) && length(sensors_list) > 0) {
       for (s in sensors_list) {
          param <- safe_extract(s$parameter$name)
          if (!is.na(param) && param %in% c("pm25", "pm10", "no2", "so2", "co", "o3")) {
             core_sensor_records <- core_sensor_records + 1
             available_polls <- c(available_polls, param)
          }
       }
    }
    core_polls_count <- length(unique(available_polls))
    

    match_result <- match_candidate_city(locality, name, active_cities, aliases)
    
    if (is.na(match_result$city)) next
    
    catalog_rows[[length(catalog_rows) + 1]] <- data.frame(
      project_station_id = sprintf("PROJ_%03d", project_idx),
      source = "openaq",
      source_station_id = NA,
      source_location_id = loc_id,
      station_name = name,
      locality = locality,
      city = match_result$city,
      state = match_result$state,
      city_match_method = match_result$method,
      city_match_confidence = match_result$confidence,
      matched_alias = match_result$alias,
      parsed_location_token = match_result$token,
      city_scope_status = match_result$scope,
      country = "India",
      latitude = lat,
      longitude = lon,
      timezone = tz,
      first_observation_date = dt_first,
      last_observation_date = dt_last,
      provider = provider,
      owner = owner,
      core_sensor_records_count = core_sensor_records,
      core_pollutants_available_count = core_polls_count,
      verified_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "Asia/Kolkata"),
      verification_method = "openaq_v3_api",
      stringsAsFactors = FALSE
    )
    project_idx <- project_idx + 1
  }
  
  if (length(catalog_rows) == 0) {
    log_warn("No matching stations found for candidate cities.")
    df <- data.frame(
      project_station_id = character(),
      source = character(),
      source_station_id = character(),
      source_location_id = character(),
      station_name = character(),
      locality = character(),
      city = character(),
      state = character(),
      city_match_method = character(),
      city_match_confidence = character(),
      matched_alias = character(),
      parsed_location_token = character(),
      city_scope_status = character(),
      country = character(),
      latitude = numeric(),
      longitude = numeric(),
      timezone = character(),
      first_observation_date = character(),
      last_observation_date = character(),
      provider = character(),
      owner = character(),
      core_sensor_records_count = numeric(),
      core_pollutants_available_count = numeric(),
      verified_at = character(),
      verification_method = character(),
      stringsAsFactors = FALSE
    )
  } else {
    df <- do.call(rbind, catalog_rows)
  }
  
  ensure_dir(dirname(output_catalog))
  write.csv(df, output_catalog, row.names = FALSE)
  
  log_info(sprintf("Successfully constructed station catalog with %d stations.", nrow(df)))
  log_info(sprintf("Saved to: %s", output_catalog))
  
  return(df)
}

# ---------------------------------------------------------
# select_preferred_sensor
# ---------------------------------------------------------
select_preferred_sensor <- function(df) {
   df_out <- df
   # Group by station and parameter
   keys <- unique(paste(df_out$project_station_id, df_out$parameter, sep="_"))
   for (k in keys) {
      idx <- which(paste(df_out$project_station_id, df_out$parameter, sep="_") == k)
      sub_df <- df_out[idx, ]
      
      # Valid units (very rough heuristic: exclude weird units if better ones exist)
      valid_idx <- which(!is.na(sub_df$dt_last_parsed))
      
      if (length(valid_idx) == 0) {
         # All NA dates, mark all inactive
         df_out$sensor_generation_status[idx] <- "inactive"
      } else {
         # Sort by datetime last descending
         sorted_valid <- valid_idx[order(sub_df$dt_last_parsed[valid_idx], decreasing = TRUE)]
         pref_i <- sorted_valid[1]
         
         df_out$sensor_generation_status[idx[pref_i]] <- "preferred_current"
         
         # Others with data
         if (length(sorted_valid) > 1) {
            for (alt_i in sorted_valid[-1]) {
               # If it's very close in time, it's alternate, else legacy
               diff_days <- as.numeric(difftime(sub_df$dt_last_parsed[pref_i], sub_df$dt_last_parsed[alt_i], units="days"))
               if (!is.na(diff_days) && diff_days < 30) {
                  df_out$sensor_generation_status[idx[alt_i]] <- "alternate_current"
               } else {
                  df_out$sensor_generation_status[idx[alt_i]] <- "legacy"
               }
            }
         }
         # NA ones
         na_idx <- setdiff(seq_len(nrow(sub_df)), valid_idx)
         if (length(na_idx) > 0) {
            df_out$sensor_generation_status[idx[na_idx]] <- "inactive"
         }
      }
   }
   return(df_out)
}
