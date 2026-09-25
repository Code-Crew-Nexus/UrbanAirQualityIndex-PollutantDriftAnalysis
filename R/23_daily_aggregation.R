# ==============================================================================
# 23_daily_aggregation.R: Pre-AQI Daily Aggregation
# UrbanAirQualityIndex-PollutantDriftAnalysis
# ==============================================================================

source("R/01_utils.R")

#' Aggregate Pollutant Source Daily (Pre-AQI)
#' 
#' This creates purely descriptive daily source-unit summaries.
#' Regulatory CPCB aggregation is NOT implemented yet.
aggregate_pollutant_source_daily <- function(air_df, start_date, end_date) {
    log_info("Aggregating daily pollution (PRE-AQI)...")
    
    # Calculate days in month to get expected local hours for a given month
    get_exp_hours <- function(d) {
        m <- format(as.Date(d), "%Y-%m")
        if (m == "2026-09") return(24) # September 2026 has full 24h per day expected up to 21st
        return(24)
    }
    
    # We aggregate by project_station_id, date, parameter
    agg_list <- split(air_df, list(air_df$project_station_id, air_df$date_local, air_df$parameter), drop=TRUE)
    
    res_list <- lapply(names(agg_list), function(nm) {
        sub <- agg_list[[nm]]
        if (nrow(sub) == 0) return(NULL)
        
        pid <- sub$project_station_id[1]
        dt <- sub$date_local[1]
        param <- sub$parameter[1]
        unit <- sub$source_unit[1]
        
        exp_hr <- get_exp_hours(dt)
        
        vh_sub <- sub[!is.na(sub$value_source), ]
        vh <- length(unique(vh_sub$timestamp_local))
        sh <- sum(is.na(sub$value_source))
        
        cov_pct <- round((vh / exp_hr) * 100, 2)
        
        dm <- if(vh > 0) mean(vh_sub$value_source, na.rm=TRUE) else NA
        
        data.frame(
            project_station_id = pid,
            date = dt,
            parameter = param,
            source_daily_mean = dm,
            source_unit = unit,
            valid_hour_count = vh,
            source_null_hour_count = sh,
            hourly_coverage_pct = cov_pct,
            stringsAsFactors = FALSE
        )
    })
    
    res <- do.call(rbind, res_list)
    return(res)
}

#' Pivot daily pollution summary into wide features
pivot_daily_pollution <- function(agg_df) {
    if (nrow(agg_df) == 0) return(data.frame())
    
    params <- c("pm2_5", "pm10", "no2", "so2", "co", "o3")
    
    # Base spine
    spine <- unique(agg_df[, c("project_station_id", "date")])
    
    for (p in params) {
        sub <- agg_df[agg_df$parameter == p, ]
        if (nrow(sub) == 0) {
            spine[[paste0(p, "_source_mean")]] <- NA
            spine[[paste0(p, "_valid_hours")]] <- 0
            spine[[paste0(p, "_source_null_hour_count")]] <- 0
            spine[[paste0(p, "_hourly_coverage_pct")]] <- 0
            spine[[paste0(p, "_source_unit")]] <- NA
            next
        }
        
        # Merge
        sub_merge <- sub[, c("project_station_id", "date", "source_daily_mean", "valid_hour_count", "source_null_hour_count", "hourly_coverage_pct", "source_unit")]
        colnames(sub_merge)[3:7] <- c(paste0(p, "_source_mean"), paste0(p, "_valid_hours"), paste0(p, "_source_null_hour_count"), paste0(p, "_hourly_coverage_pct"), paste0(p, "_source_unit"))
        spine <- merge(spine, sub_merge, by=c("project_station_id", "date"), all.x=TRUE)
        
        # Replace NAs in count columns with 0
        spine[[paste0(p, "_valid_hours")]][is.na(spine[[paste0(p, "_valid_hours")]])] <- 0
        spine[[paste0(p, "_source_null_hour_count")]][is.na(spine[[paste0(p, "_source_null_hour_count")]])] <- 0
        spine[[paste0(p, "_hourly_coverage_pct")]][is.na(spine[[paste0(p, "_hourly_coverage_pct")]])] <- 0
    }
    
    return(spine)
}

#' Aggregate Weather Daily
aggregate_weather_daily <- function(w_df) {
    log_info("Aggregating daily weather...")
    
    agg_list <- split(w_df, list(w_df$project_station_id, w_df$date_local), drop=TRUE)
    
    res_list <- lapply(names(agg_list), function(nm) {
        sub <- agg_list[[nm]]
        if (nrow(sub) == 0) return(NULL)
        
        pid <- sub$project_station_id[1]
        dt <- sub$date_local[1]
        
        vh_sub <- sub[!is.na(sub$temperature) | !is.na(sub$humidity) | !is.na(sub$wind_speed) | !is.na(sub$wind_direction), ]
        vh <- length(unique(vh_sub$timestamp_local))
        
        t_mean <- mean(sub$temperature, na.rm=TRUE)
        h_mean <- mean(sub$humidity, na.rm=TRUE)
        ws_mean <- mean(sub$wind_speed, na.rm=TRUE)
        
        # Wind direction circular averaging (weighted by speed if available)
        sub_wd <- sub[!is.na(sub$wind_direction), ]
        wd_mean <- NA
        str_val <- NA
        if (nrow(sub_wd) > 0) {
            rad <- sub_wd$wind_direction * pi / 180
            spd <- sub_wd$wind_speed
            spd[is.na(spd)] <- 1 # Uniform weighting if speed missing
            
            u <- -spd * sin(rad)
            v <- -spd * cos(rad)
            
            u_mean <- mean(u)
            v_mean <- mean(v)
            
            if (u_mean == 0 && v_mean == 0) {
                wd_mean <- NA
                str_val <- 0
            } else {
                wd_rad <- atan2(-u_mean, -v_mean)
                wd_deg <- (wd_rad * 180 / pi) %% 360
                wd_mean <- wd_deg
                str_val <- sqrt(u_mean^2 + v_mean^2)
            }
        }
        
        data.frame(
            project_station_id = pid,
            date = dt,
            temperature = if(is.nan(t_mean)) NA else t_mean,
            humidity = if(is.nan(h_mean)) NA else h_mean,
            wind_speed = if(is.nan(ws_mean)) NA else ws_mean,
            wind_direction = wd_mean,
            wind_direction_resultant_strength = str_val,
            weather_valid_hours = vh,
            weather_completeness_pct = round((vh / 24) * 100, 2),
            stringsAsFactors = FALSE
        )
    })
    
    res <- do.call(rbind, res_list)
    return(res)
}

#' Add Availability Columns
add_availability_columns <- function(df) {
    df$core_pollutants_with_any_data <- 0
    df$all_six_have_any_data <- FALSE
    df$pm_pair_have_any_data <- FALSE
    
    for (i in 1:nrow(df)) {
        c_any <- 0
        if (!is.na(df$pm2_5_source_mean[i])) c_any <- c_any + 1
        if (!is.na(df$pm10_source_mean[i])) c_any <- c_any + 1
        if (!is.na(df$no2_source_mean[i])) c_any <- c_any + 1
        if (!is.na(df$so2_source_mean[i])) c_any <- c_any + 1
        if (!is.na(df$co_source_mean[i])) c_any <- c_any + 1
        if (!is.na(df$o3_source_mean[i])) c_any <- c_any + 1
        
        df$core_pollutants_with_any_data[i] <- c_any
        df$all_six_have_any_data[i] <- (c_any == 6)
        df$pm_pair_have_any_data[i] <- (!is.na(df$pm2_5_source_mean[i]) && !is.na(df$pm10_source_mean[i]))
        
        status <- "no_air_observations"
        if (c_any == 6) status <- "all_6_observed"
        else if (c_any >= 4) status <- "4_or_5_observed"
        else if (c_any >= 1) status <- "1_to_3_observed"
        df$daily_air_availability_status[i] <- status
    }
    
    return(df)
}

#' Build Daily Pre-AQI Master
build_daily_preaqi_master <- function(spine, daily_air, daily_weather) {
    spine_m <- merge(spine, daily_air, by=c("project_station_id", "date"), all.x=TRUE)
    spine_m <- merge(spine_m, daily_weather, by=c("project_station_id", "date"), all.x=TRUE)
    
    # Fill missing values from join
    params <- c("pm2_5", "pm10", "no2", "so2", "co", "o3")
    for (p in params) {
        vh_col <- paste0(p, "_valid_hours")
        spine_m[[vh_col]][is.na(spine_m[[vh_col]])] <- 0
        sh_col <- paste0(p, "_source_null_hour_count")
        spine_m[[sh_col]][is.na(spine_m[[sh_col]])] <- 0
        cp_col <- paste0(p, "_hourly_coverage_pct")
        spine_m[[cp_col]][is.na(spine_m[[cp_col]])] <- 0
    }
    spine_m$weather_valid_hours[is.na(spine_m$weather_valid_hours)] <- 0
    spine_m$weather_completeness_pct[is.na(spine_m$weather_completeness_pct)] <- 0
    
    spine_m <- add_availability_columns(spine_m)
    return(spine_m)
}
