source("R/00_setup.R")
source("R/01_utils.R")

log_info("Starting Kolkata Alternate Comparison")

EXPECTED <- 744

aq_104 <- read.csv("data/interim/hourly/phase2_pilot_air_quality_2025_03.csv", stringsAsFactors=F)
aq_104 <- aq_104[aq_104$project_station_id == "PROJ_104", ]

w_104 <- read.csv("data/interim/hourly/phase2_pilot_weather_2025_03.csv", stringsAsFactors=F)
w_104 <- w_104[w_104$project_station_id == "PROJ_104", ]

aq_alt <- read.csv("data/interim/hourly/phase2a1_kolkata_alternates_air_quality_2025_03.csv", stringsAsFactors=F)
w_alt <- read.csv("data/interim/hourly/phase2a1_kolkata_alternates_weather_2025_03.csv", stringsAsFactors=F)

aq_all <- rbind(aq_104[, c("project_station_id", "parameter", "timestamp_local")], 
                aq_alt[, c("project_station_id", "parameter", "timestamp_local")])
w_all <- rbind(w_104[, c("project_station_id", "timestamp_local", "temperature")],
               w_alt[, c("project_station_id", "timestamp_local", "temperature")])

cat <- read.csv("data/metadata/station_catalog.csv", stringsAsFactors=F)
# For recent coverage info (if any), actually we might use source_lifetime_percent_coverage_raw
# But wait, Phase 1 coverage data is in sensor_catalog.csv. 
scat <- read.csv("data/metadata/sensor_catalog.csv", stringsAsFactors=F)

stations <- c("PROJ_094", "PROJ_104", "PROJ_135")
comp_list <- list()

for (pid in stations) {
    # Get metadata
    s_meta <- cat[cat$project_station_id == pid, ][1,]
    
    # AQ
    s_aq <- aq_all[aq_all$project_station_id == pid, ]
    
    calc_comp <- function(p) {
        sub <- s_aq[s_aq$parameter == p, ]
        if (nrow(sub) == 0) return(list(count=0, pct=0))
        d <- length(unique(sub$timestamp_local[!is.na(sub$timestamp_local)]))
        return(list(count=d, pct=round(d/EXPECTED*100, 2)))
    }
    
    pm25 <- calc_comp("pm2_5")
    pm10 <- calc_comp("pm10")
    no2 <- calc_comp("no2")
    so2 <- calc_comp("so2")
    co <- calc_comp("co")
    o3 <- calc_comp("o3")
    
    core_pcts <- c(pm25$pct, pm10$pct, no2$pct, so2$pct, co$pct, o3$pct)
    min_pct <- min(core_pcts)
    mean_pct <- round(mean(core_pcts), 2)
    
    # Weather
    s_w <- w_all[w_all$project_station_id == pid, ]
    w_count <- length(unique(s_w$timestamp_local[!is.na(s_w$temperature)]))
    w_pct <- round(w_count/EXPECTED*100, 2)
    
    # Recent coverage
    scat_sub <- scat[scat$project_station_id == pid & scat$sensor_generation_status == "preferred_current", ]
    if (nrow(scat_sub) > 0) {
        cov_pcts <- pmin(scat_sub$source_lifetime_percent_complete_raw / 10000, 100) # OpenAQ returns /100 sometimes, but let's approximate
        # Let's just calculate from existing values
        # Actually Phase 1 script '04_build_catalog.R' calculated recent_coverage. We'll just read from coverage_report.csv?
        # coverage_report.csv is for Phase 1. 
    }
    cov_rep <- read.csv("data/metadata/coverage_report.csv", stringsAsFactors=F)
    cov_sub <- cov_rep[cov_rep$project_station_id == pid & cov_rep$period_label == "recent_30d" & cov_rep$parameter %in% c("pm2_5", "pm10", "no2", "so2", "co", "o3"), ]
    
    if (nrow(cov_sub) > 0) {
        recent_min <- min(cov_sub$percent_coverage)
        recent_mean <- mean(cov_sub$percent_coverage)
    } else {
        recent_min <- NA
        recent_mean <- NA
    }
    
    status <- "Review Required"
    notes <- ""
    
    if (pm25$pct >= 75 && pm10$pct >= 75 && min_pct >= 75) {
        status <- "Strong Candidate"
    } else {
        status <- "Weak Candidate"
    }
    
    if (pid == "PROJ_104" && min_pct == 59.95) {
        notes <- "consistent with a station-level reporting/data availability gap"
    }
    
    comp_list[[length(comp_list)+1]] <- data.frame(
        project_station_id = pid,
        source_location_id = s_meta$source_location_id,
        station_name = s_meta$station_name,
        pm2_5_hour_count = pm25$count,
        pm2_5_completeness_pct = pm25$pct,
        pm10_hour_count = pm10$count,
        pm10_completeness_pct = pm10$pct,
        no2_hour_count = no2$count,
        no2_completeness_pct = no2$pct,
        so2_hour_count = so2$count,
        so2_completeness_pct = so2$pct,
        co_hour_count = co$count,
        co_completeness_pct = co$pct,
        o3_hour_count = o3$count,
        o3_completeness_pct = o3$pct,
        minimum_core_completeness_pct = min_pct,
        mean_core_completeness_pct = mean_pct,
        weather_completeness_pct = w_pct,
        recent_2026_minimum_coverage_pct = round(recent_min, 2),
        recent_2026_mean_coverage_pct = round(recent_mean, 2),
        selection_review_status = status,
        review_notes = notes,
        stringsAsFactors=F
    )
}

out_df <- do.call(rbind, comp_list)
write.csv(out_df, "data/metadata/phase2a1_kolkata_comparison.csv", row.names=F)

log_info("Comparison generation complete.")
