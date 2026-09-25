source("R/00_setup.R")
source("R/01_utils.R")

log_info("Starting Pilot Summary Generation")

aq_comp <- read.csv("data/metadata/phase2_pilot_completeness.csv", stringsAsFactors=F)
w_comp <- read.csv("data/metadata/phase2_pilot_weather_completeness.csv", stringsAsFactors=F)
snap <- read.csv("data/metadata/selected_sensor_snapshot.csv", stringsAsFactors=F)

# Pilot Classification
classify_coverage <- function(pct) {
    if (is.na(pct)) return("Pilot failure")
    if (pct >= 75) return("Strong pilot coverage")
    if (pct >= 50) return("Usable pilot coverage")
    return("Weak pilot coverage")
}
aq_comp$pilot_status <- sapply(aq_comp$hourly_completeness_pct, classify_coverage)

# Join AQ comp with station info
aq_comp <- merge(aq_comp, snap[!duplicated(snap$project_station_id), c("project_station_id", "station_name", "city", "use_hyderabad", "use_india")], by="project_station_id", all.x=TRUE)

# 27 — HYDERABAD PILOT SUMMARY
hyd_stations <- unique(aq_comp$project_station_id[aq_comp$use_hyderabad])
hyd_summary <- list()
for (pid in hyd_stations) {
    sub <- aq_comp[aq_comp$project_station_id == pid, ]
    w_sub <- w_comp[w_comp$project_station_id == pid, ]
    w_pct <- if(nrow(w_sub) > 0) w_sub$completeness_pct[1] else 0
    
    row <- data.frame(
        Station = sub$station_name[1],
        PM2_5 = if(any(sub$parameter=="pm2_5")) sub$hourly_completeness_pct[sub$parameter=="pm2_5"] else NA,
        PM10 = if(any(sub$parameter=="pm10")) sub$hourly_completeness_pct[sub$parameter=="pm10"] else NA,
        NO2 = if(any(sub$parameter=="no2")) sub$hourly_completeness_pct[sub$parameter=="no2"] else NA,
        SO2 = if(any(sub$parameter=="so2")) sub$hourly_completeness_pct[sub$parameter=="so2"] else NA,
        CO = if(any(sub$parameter=="co")) sub$hourly_completeness_pct[sub$parameter=="co"] else NA,
        O3 = if(any(sub$parameter=="o3")) sub$hourly_completeness_pct[sub$parameter=="o3"] else NA,
        Weather = w_pct,
        stringsAsFactors=F
    )
    # Overall status based on worst PM2.5 or PM10 if both bad?
    pm_vals <- c(row$PM2_5, row$PM10)
    pm_vals <- pm_vals[!is.na(pm_vals)]
    if (length(pm_vals) > 0 && max(pm_vals) >= 75) {
        row$Status <- "Pass"
    } else {
        row$Status <- "Review Required"
    }
    hyd_summary[[length(hyd_summary)+1]] <- row
}
hyd_df <- do.call(rbind, hyd_summary)
write.csv(hyd_df, "data/metadata/phase2_pilot_hyderabad_summary.csv", row.names=FALSE)

# 28 — INDIA PILOT SUMMARY
ind_stations <- unique(aq_comp$project_station_id[aq_comp$use_india])
ind_summary <- list()
for (pid in ind_stations) {
    sub <- aq_comp[aq_comp$project_station_id == pid, ]
    w_sub <- w_comp[w_comp$project_station_id == pid, ]
    w_pct <- if(nrow(w_sub) > 0) w_sub$completeness_pct[1] else 0
    
    row <- data.frame(
        City = sub$city[1],
        Station = sub$station_name[1],
        PM2_5 = if(any(sub$parameter=="pm2_5")) sub$hourly_completeness_pct[sub$parameter=="pm2_5"] else NA,
        PM10 = if(any(sub$parameter=="pm10")) sub$hourly_completeness_pct[sub$parameter=="pm10"] else NA,
        NO2 = if(any(sub$parameter=="no2")) sub$hourly_completeness_pct[sub$parameter=="no2"] else NA,
        SO2 = if(any(sub$parameter=="so2")) sub$hourly_completeness_pct[sub$parameter=="so2"] else NA,
        CO = if(any(sub$parameter=="co")) sub$hourly_completeness_pct[sub$parameter=="co"] else NA,
        O3 = if(any(sub$parameter=="o3")) sub$hourly_completeness_pct[sub$parameter=="o3"] else NA,
        Weather = w_pct,
        stringsAsFactors=F
    )
    pm_vals <- c(row$PM2_5, row$PM10)
    pm_vals <- pm_vals[!is.na(pm_vals)]
    if (length(pm_vals) > 0 && max(pm_vals) >= 75) {
        row$Status <- "Pass"
    } else {
        row$Status <- "Review Required"
    }
    if (sub$city[1] == "Mumbai") {
        # Explicit Mumbai check
        if (length(pm_vals) == 0 || max(pm_vals) < 50) {
            row$Status <- "MUMBAI_SELECTION_REVIEW_REQUIRED"
        }
    }
    ind_summary[[length(ind_summary)+1]] <- row
}
ind_df <- do.call(rbind, ind_summary)
write.csv(ind_df, "data/metadata/phase2_pilot_india_summary.csv", row.names=FALSE)

log_info("Pilot Summary Complete")
