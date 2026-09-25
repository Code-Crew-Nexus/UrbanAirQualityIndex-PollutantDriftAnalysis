source("R/00_setup.R")
source("R/01_utils.R")
source("R/22_harmonize_data.R")
source("R/23_daily_aggregation.R")
source("R/25_data_quality.R")

log_info("Starting Phase 2C: Pre-AQI Daily Dataset Engineering")

# 1. Load inputs
stations <- read.csv("config/selected_stations.csv", stringsAsFactors=FALSE)
stations <- stations[stations$selected == TRUE, ]

# Load all frozen hourly files
aq_files <- list.files("data/interim/hourly/historical", pattern="^air_quality_.*\\.csv$", full.names=TRUE)
log_info(sprintf("Loading %d hourly air quality files...", length(aq_files)))
aq_list <- lapply(aq_files, read.csv, stringsAsFactors=FALSE)
air_df <- do.call(rbind, aq_list)
rm(aq_list)

w_files <- list.files("data/interim/hourly/historical_weather", pattern="^weather_.*\\.csv$", full.names=TRUE)
log_info(sprintf("Loading %d hourly weather files...", length(w_files)))
w_list <- lapply(w_files, read.csv, stringsAsFactors=FALSE)
weather_df <- do.call(rbind, w_list)
rm(w_list)

# 2. Build Date Spine
spine <- build_station_day_spine(stations, "2025-03-01", "2026-09-21")
spine <- add_temporal_features(spine)

log_info(sprintf("Spine created with %d rows", nrow(spine)))
write.csv(spine, "data/interim/daily/phase2C_master_station_day_spine.csv", row.names=FALSE)

# 3. Aggregate Pollution
agg_air <- aggregate_pollutant_source_daily(air_df, "2025-03-01", "2026-09-21")
wide_air <- pivot_daily_pollution(agg_air)

# 4. Aggregate Weather
agg_weather <- aggregate_weather_daily(weather_df)

# 5. Build Pre-AQI Master
pre_aqi <- build_daily_preaqi_master(spine, wide_air, agg_weather)

# Validate rows haven't duplicated/dropped
if (nrow(pre_aqi) != nrow(spine)) {
    stop(sprintf("Row count mismatch! Spine: %d, Pre-AQI: %d", nrow(spine), nrow(pre_aqi)))
}

write.csv(pre_aqi, "data/interim/daily/phase2C_master_daily_preAQI.csv", row.names=FALSE)
log_info(sprintf("Master Pre-AQI created with %d rows.", nrow(pre_aqi)))

# 6. Split into Hyderabad and India Sets
hyd_df <- pre_aqi[pre_aqi$use_hyderabad == TRUE, ]
ind_df <- pre_aqi[pre_aqi$use_india == TRUE, ]

# Validate
if (ncol(hyd_df) != ncol(ind_df) || any(colnames(hyd_df) != colnames(ind_df))) {
    stop("Schema mismatch between Hyderabad and India datasets!")
}

write.csv(hyd_df, "data/interim/daily/UAQI_Hyderabad_Daily_PreAQI.csv", row.names=FALSE)
write.csv(ind_df, "data/interim/daily/UAQI_India_Daily_PreAQI.csv", row.names=FALSE)
log_info(sprintf("Hyderabad Pre-AQI: %d rows", nrow(hyd_df)))
log_info(sprintf("India Pre-AQI: %d rows", nrow(ind_df)))

# 7. Metadata / Quality Profiling
missing_prof <- profile_station_day_missingness(pre_aqi)
write.csv(missing_prof, "data/metadata/phase2C_station_day_missingness.csv", row.names=FALSE)

qual_prof <- profile_daily_quality(pre_aqi)
write.csv(qual_prof, "data/metadata/phase2C_daily_quality_profile.csv", row.names=FALSE)

val_audit <- audit_value_integrity(pre_aqi)
write.csv(val_audit, "data/metadata/phase2C_value_integrity_audit.csv", row.names=FALSE)

# Dataset Scoped Summaries
hyd_summ <- data.frame(
    dataset = "Hyderabad",
    rows = nrow(hyd_df),
    stations = length(unique(hyd_df$project_station_id)),
    start_date = min(hyd_df$date),
    end_date = max(hyd_df$date),
    days_all_6 = sum(hyd_df$daily_air_availability_status == "all_6_observed"),
    days_none = sum(hyd_df$daily_air_availability_status == "no_air_observations"),
    weather_complete = sum(hyd_df$weather_completeness_pct >= 100),
    stringsAsFactors = FALSE
)
ind_summ <- data.frame(
    dataset = "India",
    rows = nrow(ind_df),
    stations = length(unique(ind_df$project_station_id)),
    start_date = min(ind_df$date),
    end_date = max(ind_df$date),
    days_all_6 = sum(ind_df$daily_air_availability_status == "all_6_observed"),
    days_none = sum(ind_df$daily_air_availability_status == "no_air_observations"),
    weather_complete = sum(ind_df$weather_completeness_pct >= 100),
    stringsAsFactors = FALSE
)
write.csv(hyd_summ, "data/metadata/phase2C_hyderabad_daily_summary.csv", row.names=FALSE)
write.csv(ind_summ, "data/metadata/phase2C_india_daily_summary.csv", row.names=FALSE)

log_info("Phase 2C Data Engineering Complete.")
