# ==============================================================================
# 25_data_quality.R: Phase 2C Data Quality Profiling
# UrbanAirQualityIndex-PollutantDriftAnalysis
# ==============================================================================

source("R/01_utils.R")

#' Profile Station-Day Missingness
profile_station_day_missingness <- function(spine_df) {
    log_info("Profiling station-day missingness...")
    
    rows <- list()
    for (pid in unique(spine_df$project_station_id)) {
        sub <- spine_df[spine_df$project_station_id == pid, ]
        
        tot <- nrow(sub)
        d_all6 <- sum(sub$daily_air_availability_status == "all_6_observed")
        d_45 <- sum(sub$daily_air_availability_status == "4_or_5_observed")
        d_13 <- sum(sub$daily_air_availability_status == "1_to_3_observed")
        d_none <- sum(sub$daily_air_availability_status == "no_air_observations")
        
        w_comp <- sum(sub$weather_completeness_pct >= 100)
        w_incomp <- sum(sub$weather_completeness_pct < 100)
        
        sub_air <- sub[sub$daily_air_availability_status != "no_air_observations", ]
        f_d <- if (nrow(sub_air) > 0) min(sub_air$date, na.rm=TRUE) else NA
        l_d <- if (nrow(sub_air) > 0) max(sub_air$date, na.rm=TRUE) else NA
        
        rows[[length(rows)+1]] <- data.frame(
            project_station_id = pid,
            total_days = tot,
            days_all_6_observed = d_all6,
            days_4_or_5_observed = d_45,
            days_1_to_3_observed = d_13,
            days_no_air_observations = d_none,
            days_weather_complete = w_comp,
            days_weather_incomplete = w_incomp,
            first_day_with_air_data = f_d,
            last_day_with_air_data = l_d,
            stringsAsFactors = FALSE
        )
    }
    do.call(rbind, rows)
}

#' Profile Daily Quality
profile_daily_quality <- function(spine_df) {
    log_info("Profiling daily quality per parameter...")
    
    rows <- list()
    params <- c("pm2_5", "pm10", "no2", "so2", "co", "o3")
    
    for (pid in unique(spine_df$project_station_id)) {
        sub <- spine_df[spine_df$project_station_id == pid, ]
        
        for (p in params) {
            v_col <- paste0(p, "_valid_hours")
            c_col <- paste0(p, "_hourly_coverage_pct")
            m_col <- paste0(p, "_source_mean")
            
            vh <- sub[[v_col]]
            cp <- sub[[c_col]]
            sm <- sub[[m_col]]
            
            d_any <- sum(vh > 0)
            d_24 <- sum(vh == 24)
            d_18 <- sum(vh >= 18)
            d_12 <- sum(vh >= 12)
            
            m_vh <- mean(vh[vh > 0], na.rm=TRUE)
            med_vh <- median(vh[vh > 0], na.rm=TRUE)
            
            min_cp <- min(cp[vh > 0], na.rm=TRUE)
            mean_cp <- mean(cp[vh > 0], na.rm=TRUE)
            
            # Longest consecutive no data
            cw <- 0
            mcw <- 0
            for (v in vh) {
                if (v == 0) {
                    cw <- cw + 1
                    if (cw > mcw) mcw <- cw
                } else {
                    cw <- 0
                }
            }
            
            if (d_any == 0) {
                m_vh <- NA
                med_vh <- NA
                min_cp <- NA
                mean_cp <- NA
            }
            
            rows[[length(rows)+1]] <- data.frame(
                project_station_id = pid,
                parameter = p,
                total_study_days = nrow(sub),
                days_with_any_data = d_any,
                days_with_24_valid_hours = d_24,
                days_with_18_or_more_valid_hours = d_18,
                days_with_12_or_more_valid_hours = d_12,
                mean_valid_hours = m_vh,
                median_valid_hours = med_vh,
                minimum_daily_coverage_pct = min_cp,
                mean_daily_coverage_pct = mean_cp,
                longest_consecutive_no_data_days = mcw,
                stringsAsFactors = FALSE
            )
        }
    }
    do.call(rbind, rows)
}

#' Perform Value Integrity Audit (No Outlier Deletion)
audit_value_integrity <- function(spine_df) {
    log_info("Auditing daily value integrity...")
    rows <- list()
    params <- c("pm2_5", "pm10", "no2", "so2", "co", "o3")
    
    for (pid in unique(spine_df$project_station_id)) {
        sub <- spine_df[spine_df$project_station_id == pid, ]
        for (p in params) {
            m_col <- paste0(p, "_source_mean")
            vals <- sub[[m_col]]
            
            n_neg <- sum(vals < 0, na.rm=TRUE)
            n_zero <- sum(vals == 0, na.rm=TRUE)
            n_pos <- sum(vals > 0, na.rm=TRUE)
            n_na <- sum(is.na(vals))
            
            v_real <- vals[!is.na(vals)]
            
            v_min <- if(length(v_real) > 0) min(v_real) else NA
            v_med <- if(length(v_real) > 0) median(v_real) else NA
            v_mean <- if(length(v_real) > 0) mean(v_real) else NA
            v_max <- if(length(v_real) > 0) max(v_real) else NA
            
            rows[[length(rows)+1]] <- data.frame(
                project_station_id = pid,
                parameter = p,
                negative_count = n_neg,
                zero_count = n_zero,
                positive_count = n_pos,
                na_count = n_na,
                min_value = v_min,
                median_value = v_med,
                mean_value = v_mean,
                max_value = v_max,
                stringsAsFactors = FALSE
            )
        }
    }
    do.call(rbind, rows)
}
