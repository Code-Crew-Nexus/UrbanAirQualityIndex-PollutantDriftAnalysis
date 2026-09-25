# Phase 2D.1: CPCB AQI Verified Functions
library(utils)

# Helper: exact half-up rounding (base R round() is round-to-even)
round_half_up <- function(x, digits = 0) {
  posneg <- sign(x)
  z <- abs(x) * 10^digits
  z <- z + 0.5 + sqrt(.Machine$double.eps)
  z <- trunc(z)
  z <- z / 10^digits
  z * posneg
}

load_verified_breakpoints <- function() {
  read.csv("config/aqi_breakpoints_india.csv", stringsAsFactors = FALSE)
}

load_verified_conversion_factors <- function() {
  read.csv("config/gas_conversion_factors_india.csv", stringsAsFactors = FALSE)
}

load_sensor_semantics <- function() {
  read.csv("data/metadata/phase2D4_final_sensor_semantic_units.csv", stringsAsFactors = FALSE)
}

convert_hourly_to_canonical_unit <- function(concentration, pollutant, reported_unit, sensor_id) {
  if (is.na(concentration)) return(NA)
  if (concentration < 0) return(NA) # Negative values are invalid for AQI

  semantics <- load_sensor_semantics()
  row <- semantics[semantics$sensor_id == sensor_id, ]
  
  if (nrow(row) == 1) {
    if (row$verification_status != "VERIFIED") {
      # Unresolved or failed verification blocks conversion
      return(NA)
    }
    
    target_unit <- row$verified_semantic_unit
    
    # Is the target already the canonical CPCB unit?
    if (target_unit == row$canonical_aqi_unit) {
      return(concentration)
    }
    
    # If it still needs conversion
    factors <- load_verified_conversion_factors()
    f_row <- factors[factors$pollutant == pollutant & factors$source_unit == target_unit, ]
    if (nrow(f_row) == 1) {
      return(concentration * f_row$conversion_factor)
    }
    
    stop(paste("No verified conversion factor for", pollutant, "from", target_unit))
  }

  
  stop(paste("Sensor ID", sensor_id, "not found in sensor semantics table."))
}

normalize_cpcb_input_precision <- function(concentration, pollutant) {
  if (is.na(concentration)) return(NA)
  if (pollutant == "co") {
    return(round_half_up(concentration, 1))
  } else {
    return(round_half_up(concentration, 0))
  }
}

calculate_pollutant_subindex <- function(concentration, pollutant, breakpoint_table, is_1hr = FALSE) {
  if (is.na(concentration)) return(NA)
  
  c_val <- normalize_cpcb_input_precision(concentration, pollutant)
  
  sub_table <- breakpoint_table[breakpoint_table$pollutant == pollutant, ]
  
  if (pollutant == "o3") {
    if (is_1hr) {
      sub_table <- sub_table[sub_table$averaging_period == "1-hour", ]
    } else {
      sub_table <- sub_table[sub_table$averaging_period == "8-hour", ]
    }
  }
  
  # Find matching band
  # For severe (is_open_ended == TRUE), concentration_high is NA
  band <- sub_table[!is.na(sub_table$concentration_low) & 
                    c_val >= sub_table$concentration_low & 
                    (is.na(sub_table$concentration_high) | c_val <= sub_table$concentration_high), ]
  
  if (nrow(band) == 0) {
    return(NA) # Negative or invalid
  }
  
  band <- band[1, ]
  BLO <- band$concentration_low
  BHI <- band$concentration_high
  
  # CPCB ILO Adjustment: Subtract 1 from ILO if ILO > 50
  ILO_table <- band$index_low
  ILO_eff <- ifelse(ILO_table > 50, ILO_table - 1, ILO_table)
  IHI <- band$index_high
  
  if (band$is_open_ended) {
    # Project Policy: Extrapolate Severe slope from the preceding Very Poor band
    vp_band <- sub_table[sub_table$aqi_category == "Very Poor", ]
    vp_BLO <- vp_band$concentration_low
    vp_BHI <- vp_band$concentration_high
    vp_ILO_eff <- ifelse(vp_band$index_low > 50, vp_band$index_low - 1, vp_band$index_low)
    vp_IHI <- vp_band$index_high
    
    slope <- (vp_IHI - vp_ILO_eff) / (vp_BHI - vp_BLO)
    
    # Calculate uncapped sub-index using Very Poor slope
    Ip <- (slope * (c_val - BLO)) + ILO_eff
  } else {
    Ip <- ((IHI - ILO_eff) / (BHI - BLO)) * (c_val - BLO) + ILO_eff
  }
  
  return(round_half_up(Ip, 0))
}

derive_daily_24h_input <- function(hourly_values) {
  valid_vals <- hourly_values[!is.na(hourly_values)]
  if (length(valid_vals) < 16) {
    return(list(concentration = NA, valid_hours = length(valid_vals), validity = FALSE, invalid_reason = "insufficient_source_hours"))
  }
  return(list(concentration = mean(valid_vals), valid_hours = length(valid_vals), validity = TRUE, invalid_reason = "valid"))
}

calculate_running_8h <- function(hourly_vector) {
  # Given a vector of 24 + 7 = 31 hourly values (trailing 7 hours from prev day + 24 hours of current day)
  # Computes the 24 rolling 8-hour averages for the current day.
  # Returns a vector of 24 values.
  res <- rep(NA, 24)
  for (i in 1:24) {
    window <- hourly_vector[i:(i+7)]
    valid_count <- sum(!is.na(window))
    if (valid_count >= 6) { # PROJECT_IMPLEMENTATION_CHOICE: 6/8 completeness for window
      res[i] <- mean(window, na.rm = TRUE)
    }
  }
  return(res)
}

derive_daily_co_aqi_input <- function(hourly_vector_31) {
  # requires 31 hourly values
  running_8h <- calculate_running_8h(hourly_vector_31)
  valid_count <- sum(!is.na(hourly_vector_31[8:31])) # CPCB Official: minimum 16 source hours in the day
  
  if (valid_count < 16) {
    return(list(concentration = NA, valid_hours = valid_count, valid_windows = sum(!is.na(running_8h)), validity = FALSE, invalid_reason = "insufficient_co_hours"))
  }
  
  valid_windows <- running_8h[!is.na(running_8h)]
  if (length(valid_windows) == 0) {
    return(list(concentration = NA, valid_hours = valid_count, valid_windows = 0, validity = FALSE, invalid_reason = "no_valid_co_8h_window"))
  }
  
  return(list(concentration = max(valid_windows), valid_hours = valid_count, valid_windows = length(valid_windows), validity = TRUE, invalid_reason = "valid"))
}

derive_daily_o3_subindex <- function(hourly_vector_31, breakpoint_table) {
  valid_count <- sum(!is.na(hourly_vector_31[8:31]))
  if (valid_count < 16) {
    return(list(subindex = NA, aqi_display = NA, 
                o3_8h_max = NA, o3_1h_max = NA, 
                o3_8h_subindex = NA, o3_1h_subindex = NA,
                selected_averaging_period = NA,
                validity = FALSE, invalid_reason = "insufficient_o3_hours"))
  }
  
  running_8h <- calculate_running_8h(hourly_vector_31)
  valid_windows <- running_8h[!is.na(running_8h)]
  if (length(valid_windows) == 0) {
    return(list(subindex = NA, aqi_display = NA, 
                o3_8h_max = NA, o3_1h_max = NA, 
                o3_8h_subindex = NA, o3_1h_subindex = NA,
                selected_averaging_period = NA,
                validity = FALSE, invalid_reason = "no_valid_o3_8h_window"))
  }
  
  o3_8h_max <- max(valid_windows)
  o3_1h_max <- max(hourly_vector_31[8:31], na.rm = TRUE)
  
  o3_8h_subindex <- calculate_pollutant_subindex(o3_8h_max, "o3", breakpoint_table, is_1hr = FALSE)
  o3_1h_subindex <- calculate_pollutant_subindex(o3_1h_max, "o3", breakpoint_table, is_1hr = TRUE)
  
  # CPCB Policy: If 1-hour subindex > Poor (i.e. > 300, which corresponds to > 208 ug/m3 8-hour, but 1-hour Very Poor starts at 209 concentration, 301 subindex)
  # We evaluate 1-hr for Very Poor / Severe.
  # "The higher of the 8-hour or 1-hour evaluation becomes the final O3 sub-index."
  if (!is.na(o3_1h_subindex) && o3_1h_subindex >= 301 && o3_1h_subindex > o3_8h_subindex) {
    subindex <- o3_1h_subindex
    selected_period <- "1-hour"
  } else {
    subindex <- o3_8h_subindex
    selected_period <- "8-hour"
  }
  
  aqi_disp <- ifelse(subindex > 500, 500, subindex)
  
  return(list(subindex = subindex, aqi_display = aqi_disp,
              o3_8h_max = o3_8h_max, o3_1h_max = o3_1h_max,
              o3_8h_subindex = o3_8h_subindex, o3_1h_subindex = o3_1h_subindex,
              selected_averaging_period = selected_period,
              validity = TRUE, invalid_reason = "valid"))
}

calculate_daily_indian_aqi <- function(sub_indices, has_pm) {
  valid_indices <- sub_indices[!is.na(sub_indices)]
  
  if (length(valid_indices) < 3) {
    return(list(aqi_uncapped = NA, aqi_display = NA, dominant_pollutant = NA, reason = "insufficient_pollutants"))
  }
  if (!has_pm) {
    return(list(aqi_uncapped = NA, aqi_display = NA, dominant_pollutant = NA, reason = "missing_particulate"))
  }
  
  aqi_uncapped <- max(valid_indices)
  aqi_display <- ifelse(aqi_uncapped > 500, 500, aqi_uncapped)
  
  dom_polls <- names(valid_indices)[valid_indices == aqi_uncapped]
  dom_pollutant <- paste(sort(dom_polls), collapse = ", ")
  
  return(list(aqi_uncapped = aqi_uncapped, aqi_display = aqi_display, dominant_pollutant = dom_pollutant, reason = "valid"))
}

assign_aqi_category <- function(aqi) {
  if (is.na(aqi)) return(NA)
  if (aqi < 0) return(NA)
  if (aqi <= 50) return("Good")
  if (aqi <= 100) return("Satisfactory")
  if (aqi <= 200) return("Moderately Polluted")
  if (aqi <= 300) return("Poor")
  if (aqi <= 400) return("Very Poor")
  return("Severe") # Anything > 400 is Severe
}
