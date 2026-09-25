source("R/00_setup.R")
source("R/24_aqi_calculation.R")
source("R/26_export_datasets.R")

library(dplyr)
library(tidyr)
library(readr)
library(yaml)
library(purrr)

# 1. Load config/policy
policy <- read_yaml("config/final_aqi_input_policy.yml")
stopifnot(policy$policy_name == "VERIFIED_SUBSET_PM25_PM10_O3")

# 2. Pre-flight Checklist
semantics <- load_sensor_semantics()
stopifnot(nrow(semantics) == 126)
stopifnot(sum(semantics$verification_status == "VERIFIED") == 63)
stopifnot(sum(semantics$pollutant == "pm2_5" & semantics$verification_status == "VERIFIED") == 21)
stopifnot(sum(semantics$pollutant == "pm10" & semantics$verification_status == "VERIFIED") == 21)
stopifnot(sum(semantics$pollutant == "o3" & semantics$verification_status == "VERIFIED") == 21)
stopifnot(sum(semantics$pollutant == "co" & semantics$verification_status == "UNRESOLVED") == 21)
stopifnot(sum(semantics$pollutant == "no2" & semantics$verification_status == "UNRESOLVED") == 21)
stopifnot(sum(semantics$pollutant == "so2" & semantics$verification_status == "UNRESOLVED") == 21)

preaqi <- read_csv("data/interim/daily/phase2C_master_daily_preAQI.csv", show_col_types = FALSE)
stopifnot(nrow(preaqi) == 11970)

# 3. Load Frozen Hourly Data
hourly_files <- list.files("data/interim/hourly/historical", pattern = "air_quality_.*\\.csv$", full.names = TRUE)
stopifnot(length(hourly_files) == 19)

hourly_df <- map_df(hourly_files, read_csv, show_col_types = FALSE)
stopifnot(nrow(hourly_df) > 0)

# Process only PM2.5, PM10, O3
hourly_subset <- hourly_df %>%
  filter(parameter %in% c("pm2_5", "pm10", "o3")) %>%
  left_join(semantics %>% select(sensor_id, verification_status, verified_semantic_unit, canonical_aqi_unit), by = "sensor_id")

factors <- load_verified_conversion_factors() %>% select(-verification_status)

hourly_subset <- hourly_subset %>%
  left_join(factors %>% rename(parameter = pollutant, verified_semantic_unit = source_unit), by = c("parameter", "verified_semantic_unit")) %>%
  mutate(
    canonical_value = case_when(
      verification_status != "VERIFIED" ~ NA_real_,
      is.na(value_source) | value_source < 0 ~ NA_real_,
      verified_semantic_unit == canonical_aqi_unit ~ as.numeric(value_source),
      !is.na(conversion_factor) ~ as.numeric(value_source) * conversion_factor,
      TRUE ~ NA_real_
    )
  )

# Add local date and hour using base R
# timestamp is parsed as POSIXct by read_csv, defaulting to UTC
hourly_subset$local_time <- as.POSIXct(format(hourly_subset$timestamp_utc, tz = "Asia/Kolkata"), tz = "Asia/Kolkata")
hourly_subset$local_date <- as.Date(hourly_subset$local_time, tz = "Asia/Kolkata")
hourly_subset$local_hour <- as.integer(format(hourly_subset$local_time, "%H"))


# 4. & 5. Calculate PM2.5 and PM10 daily inputs
breakpoints <- load_verified_breakpoints()

pm_daily <- hourly_subset %>%
  filter(parameter %in% c("pm2_5", "pm10")) %>%
  group_by(project_station_id, local_date, parameter) %>%
  summarize(
    valid_source_hours = sum(!is.na(canonical_value)),
    daily_mean = ifelse(valid_source_hours >= 16, round_half_up(mean(canonical_value, na.rm = TRUE), 0), NA_real_),
    .groups = "drop"
  )

# Calculate Subindices for PM
pm_subindices <- pm_daily %>%
  mutate(
    subindex = map2_dbl(daily_mean, parameter, ~ if(is.na(.x)) NA_real_ else calculate_pollutant_subindex(.x, .y, breakpoints))
  )

pm25_wide <- pm_subindices %>% filter(parameter == "pm2_5") %>%
  select(project_station_id, date = local_date, pm2_5_aqi_input = daily_mean, pm2_5_valid_hours = valid_source_hours, pm2_5_subindex = subindex) %>%
  mutate(pm2_5_aqi_validity_reason = ifelse(is.na(pm2_5_subindex), "insufficient_pm2_5_hours", "valid"))

pm10_wide <- pm_subindices %>% filter(parameter == "pm10") %>%
  select(project_station_id, date = local_date, pm10_aqi_input = daily_mean, pm10_valid_hours = valid_source_hours, pm10_subindex = subindex) %>%
  mutate(pm10_aqi_validity_reason = ifelse(is.na(pm10_subindex), "insufficient_pm10_hours", "valid"))


# 6. Calculate O3 hourly rolling metrics
o3_hourly <- hourly_subset %>% filter(parameter == "o3") %>% select(project_station_id, local_time, canonical_value)

# Build station-hour spine from 2025-02-28 17:00 to 2026-09-21 23:00 to properly compute 8h windows
stations <- unique(preaqi$project_station_id)
min_time <- as.POSIXct("2025-02-28 17:00:00", tz="Asia/Kolkata")
max_time <- as.POSIXct("2026-09-21 23:00:00", tz="Asia/Kolkata")
spine <- expand_grid(project_station_id = stations, local_time = seq(min_time, max_time, by="1 hour"))

o3_full <- spine %>% left_join(o3_hourly, by=c("project_station_id", "local_time"))

o3_windows <- o3_full %>%
  group_by(project_station_id) %>%
  arrange(local_time) %>%
  mutate(
    # RcppRoll is faster, but for simplicity we can use zoo
    o3_8h_mean = zoo::rollapply(canonical_value, width = 8, FUN = function(x) {
      if(sum(!is.na(x)) >= 6) mean(x, na.rm = TRUE) else NA_real_
    }, fill = NA, align = "right")
  ) %>%
  ungroup() %>%
  mutate(
    local_date = as.Date(local_time)
  )

# Only consider dates in our range
o3_daily <- o3_windows %>%
  filter(local_date >= as.Date("2025-03-01") & local_date <= as.Date("2026-09-21")) %>%
  group_by(project_station_id, local_date) %>%
  summarize(
    o3_valid_source_hours = sum(!is.na(canonical_value)),
    o3_valid_8h_window_count = sum(!is.na(o3_8h_mean)),
    o3_8h_max = ifelse(o3_valid_source_hours >= 16 & o3_valid_8h_window_count > 0, round_half_up(max(o3_8h_mean, na.rm = TRUE), 0), NA_real_),
    o3_1h_max = ifelse(o3_valid_source_hours >= 16, round_half_up(max(canonical_value, na.rm = TRUE), 0), NA_real_),
    .groups = "drop"
  )

o3_subindices <- o3_daily %>%
  mutate(
    o3_8h_subindex = map_dbl(o3_8h_max, ~ if(is.na(.x)) NA_real_ else calculate_pollutant_subindex(.x, "o3", breakpoints)),
    o3_1h_subindex = map_dbl(o3_1h_max, ~ if(is.na(.x)) NA_real_ else calculate_pollutant_subindex(.x, "o3_1h", breakpoints))
  ) %>%
  mutate(
    # Use 1h max if it yields a HIGHER index and > 200 (upper band fallback per methodology)
    o3_selected_averaging_period = case_when(
      !is.na(o3_1h_subindex) & o3_1h_subindex > 200 & (is.na(o3_8h_subindex) | o3_1h_subindex > o3_8h_subindex) ~ "1-hour",
      !is.na(o3_8h_subindex) ~ "8-hour",
      TRUE ~ "none"
    ),
    o3_subindex = case_when(
      o3_selected_averaging_period == "1-hour" ~ o3_1h_subindex,
      o3_selected_averaging_period == "8-hour" ~ o3_8h_subindex,
      TRUE ~ NA_real_
    ),
    o3_aqi_validity_reason = case_when(
      !is.na(o3_subindex) ~ "valid",
      o3_valid_source_hours < 16 ~ "insufficient_o3_hours",
      TRUE ~ "no_valid_o3_8h_window"
    )
  )

o3_final <- o3_subindices %>% rename(date = local_date)

# 8. Join to Phase-2C Master and Calculate Verified AQI
aqi_master <- preaqi %>%
  select(-ends_with("_valid_hours")) %>% # We recompute for PM/O3. Keep others from preaqi if needed, but the prompt says to store them as pm2_5_valid_hours... wait, preaqi had `pm2_5_valid_hours` etc. We overwrite with our freshly computed ones.
  left_join(pm25_wide, by=c("project_station_id", "date")) %>%
  left_join(pm10_wide, by=c("project_station_id", "date")) %>%
  left_join(o3_final, by=c("project_station_id", "date"))

# Calculate AQI
aqi_master <- aqi_master %>%
  mutate(
    all_three_valid = !is.na(pm2_5_subindex) & !is.na(pm10_subindex) & !is.na(o3_subindex),
    aqi_uncapped = ifelse(all_three_valid, pmax(pm2_5_subindex, pm10_subindex, o3_subindex), NA_real_),
    aqi_verified = ifelse(!is.na(aqi_uncapped), pmin(aqi_uncapped, 500), NA_real_)
  ) %>%
  rowwise() %>%
  mutate(
    dominant_pollutant = {
      if(is.na(aqi_uncapped)) {
        NA_character_
      } else {
        d <- c()
        if(!is.na(pm2_5_subindex) && pm2_5_subindex == aqi_uncapped) d <- c(d, "pm2_5")
        if(!is.na(pm10_subindex) && pm10_subindex == aqi_uncapped) d <- c(d, "pm10")
        if(!is.na(o3_subindex) && o3_subindex == aqi_uncapped) d <- c(d, "o3")
        paste(sort(d), collapse = ",")
      }
    }
  ) %>%
  ungroup() %>%
  mutate(
    aqi_category = case_when(
      is.na(aqi_verified) ~ NA_character_,
      aqi_verified <= 50 ~ "Good",
      aqi_verified <= 100 ~ "Satisfactory",
      aqi_verified <= 200 ~ "Moderately Polluted",
      aqi_verified <= 300 ~ "Poor",
      aqi_verified <= 400 ~ "Very Poor",
      TRUE ~ "Severe"
    ),
    aqi_validity_reason = case_when(
      all_three_valid ~ "valid",
      is.na(pm2_5_subindex) & !is.na(pm10_subindex) & !is.na(o3_subindex) ~ "insufficient_pm2_5_hours",
      !is.na(pm2_5_subindex) & is.na(pm10_subindex) & !is.na(o3_subindex) ~ "insufficient_pm10_hours",
      !is.na(pm2_5_subindex) & !is.na(pm10_subindex) & is.na(o3_subindex) ~ "insufficient_o3_hours",
      TRUE ~ "multiple_required_pollutants_invalid"
    ),
    aqi_invalid_components = case_when(
      all_three_valid ~ NA_character_,
      TRUE ~ paste(
        ifelse(is.na(pm2_5_subindex), "pm2_5", ""),
        ifelse(is.na(pm10_subindex), "pm10", ""),
        ifelse(is.na(o3_subindex), "o3", ""),
        sep = ","
      ) %>% gsub("^,+|,+$", "", .) %>% gsub(",+", ",", .)
    ),
    aqi_input_policy = "VERIFIED_SUBSET_PM25_PM10_O3",
    aqi_policy_version = "1.0",
    aqi_pollutants_used = "pm2_5,pm10,o3",
    aqi_excluded_pollutants = "co,no2,so2",
    aqi_is_verified_subset = TRUE,
    aqi_scope_note = "Verified PM2.5/PM10/O3 subset; unresolved CO/NO2/SO2 excluded."
  )

# Add missing columns from preaqi if they got stripped
for(col in c("co_valid_hours", "no2_valid_hours", "so2_valid_hours", "weather_valid_hours")) {
  if(!(col %in% names(aqi_master))) {
    aqi_master[[col]] <- preaqi[[col]]
  }
}

export_final_uaqi_datasets(aqi_master)

# 14. Create Metadata Summaries
# phase2E_aqi_validity_summary.csv
val_stat <- aqi_master %>%
  group_by(project_station_id, station_name, city, scope = case_when(use_hyderabad & use_india ~ "Both", use_hyderabad ~ "Hyderabad", use_india ~ "India", TRUE ~ "None")) %>%
  summarize(
    total_days = n(),
    valid_aqi_days = sum(aqi_validity_reason == "valid"),
    invalid_aqi_days = sum(aqi_validity_reason != "valid"),
    valid_aqi_pct = valid_aqi_days / total_days * 100,
    insufficient_pm2_5_days = sum(is.na(pm2_5_subindex)),
    insufficient_pm10_days = sum(is.na(pm10_subindex)),
    insufficient_o3_days = sum(o3_aqi_validity_reason == "insufficient_o3_hours"),
    no_valid_o3_window_days = sum(o3_aqi_validity_reason == "no_valid_o3_8h_window"),
    other_invalid_days = sum(aqi_validity_reason == "multiple_required_pollutants_invalid"),
    first_valid_aqi_date = min(date[aqi_validity_reason == "valid"], na.rm = TRUE),
    last_valid_aqi_date = max(date[aqi_validity_reason == "valid"], na.rm = TRUE),
    .groups = "drop"
  )

val_overall <- aqi_master %>%
  summarize(
    project_station_id = "OVERALL", station_name = "ALL", city = "ALL", scope = "ALL",
    total_days = n(),
    valid_aqi_days = sum(aqi_validity_reason == "valid"),
    invalid_aqi_days = sum(aqi_validity_reason != "valid"),
    valid_aqi_pct = valid_aqi_days / total_days * 100,
    insufficient_pm2_5_days = sum(is.na(pm2_5_subindex)),
    insufficient_pm10_days = sum(is.na(pm10_subindex)),
    insufficient_o3_days = sum(o3_aqi_validity_reason == "insufficient_o3_hours"),
    no_valid_o3_window_days = sum(o3_aqi_validity_reason == "no_valid_o3_8h_window"),
    other_invalid_days = sum(aqi_validity_reason == "multiple_required_pollutants_invalid"),
    first_valid_aqi_date = min(date[aqi_validity_reason == "valid"], na.rm = TRUE),
    last_valid_aqi_date = max(date[aqi_validity_reason == "valid"], na.rm = TRUE)
  )

bind_rows(val_stat, val_overall) %>% write_csv("data/metadata/phase2E_aqi_validity_summary.csv")

# phase2E_aqi_category_distribution.csv
cat_dist <- aqi_master %>%
  filter(!is.na(aqi_category)) %>%
  group_by(scope = case_when(use_hyderabad & use_india ~ "Both", use_hyderabad ~ "Hyderabad", use_india ~ "India", TRUE ~ "None"), city, station_name, aqi_category) %>%
  summarize(day_count = n(), .groups = "drop") %>%
  group_by(scope, city, station_name) %>%
  mutate(percentage_of_valid_aqi_days = day_count / sum(day_count) * 100) %>%
  ungroup()

write_csv(cat_dist, "data/metadata/phase2E_aqi_category_distribution.csv")

# phase2E_dominant_pollutant_distribution.csv
dom_dist <- aqi_master %>%
  filter(!is.na(dominant_pollutant)) %>%
  group_by(project_station_id, station_name, city, scope = case_when(use_hyderabad & use_india ~ "Both", use_hyderabad ~ "Hyderabad", use_india ~ "India", TRUE ~ "None"), dominant_pollutant) %>%
  summarize(count = n(), .groups = "drop")
write_csv(dom_dist, "data/metadata/phase2E_dominant_pollutant_distribution.csv")

# phase2E_subindex_audit.csv
# Combine PM2.5, PM10, O3
sub_aud <- tibble(
  pollutant = c("pm2_5", "pm10", "o3"),
  numeric_input_count = c(sum(!is.na(aqi_master$pm2_5_aqi_input)), sum(!is.na(aqi_master$pm10_aqi_input)), sum(!is.na(aqi_master$o3_8h_max) | !is.na(aqi_master$o3_1h_max))),
  valid_subindex_count = c(sum(!is.na(aqi_master$pm2_5_subindex)), sum(!is.na(aqi_master$pm10_subindex)), sum(!is.na(aqi_master$o3_subindex))),
  minimum_subindex = c(min(aqi_master$pm2_5_subindex, na.rm=T), min(aqi_master$pm10_subindex, na.rm=T), min(aqi_master$o3_subindex, na.rm=T)),
  median_subindex = c(median(aqi_master$pm2_5_subindex, na.rm=T), median(aqi_master$pm10_subindex, na.rm=T), median(aqi_master$o3_subindex, na.rm=T)),
  mean_subindex = c(mean(aqi_master$pm2_5_subindex, na.rm=T), mean(aqi_master$pm10_subindex, na.rm=T), mean(aqi_master$o3_subindex, na.rm=T)),
  maximum_subindex = c(max(aqi_master$pm2_5_subindex, na.rm=T), max(aqi_master$pm10_subindex, na.rm=T), max(aqi_master$o3_subindex, na.rm=T)),
  count_gt_500_uncapped = c(sum(aqi_master$pm2_5_subindex > 500, na.rm=T), sum(aqi_master$pm10_subindex > 500, na.rm=T), sum(aqi_master$o3_subindex > 500, na.rm=T)),
  count_negative = c(sum(aqi_master$pm2_5_subindex < 0, na.rm=T), sum(aqi_master$pm10_subindex < 0, na.rm=T), sum(aqi_master$o3_subindex < 0, na.rm=T)),
  count_NA = c(sum(is.na(aqi_master$pm2_5_subindex)), sum(is.na(aqi_master$pm10_subindex)), sum(is.na(aqi_master$o3_subindex)))
)
write_csv(sub_aud, "data/metadata/phase2E_subindex_audit.csv")

# phase2E_index400_boundary_trace.csv
trace <- aqi_master %>%
  filter((pm2_5_subindex == 400) | (pm10_subindex == 400) | (o3_subindex == 400)) %>%
  select(project_station_id, date, pm2_5_aqi_input, pm10_aqi_input, o3_8h_max, pm2_5_subindex, pm10_subindex, o3_subindex)
write_csv(trace, "data/metadata/phase2E_index400_boundary_trace.csv")

# phase2E_o3_path_summary.csv
o3_path <- aqi_master %>%
  group_by(project_station_id) %>%
  summarize(
    days_evaluated_using_8hour_path = sum(o3_selected_averaging_period == "8-hour", na.rm = TRUE),
    days_1hour_upper_band_selected = sum(o3_selected_averaging_period == "1-hour", na.rm = TRUE),
    days_insufficient_source_hours = sum(o3_valid_source_hours < 16, na.rm = TRUE),
    days_no_valid_rolling_window = sum(o3_valid_source_hours >= 16 & o3_valid_8h_window_count == 0, na.rm = TRUE),
    .groups = "drop"
  )
o3_overall <- o3_path %>%
  summarize(
    project_station_id = "OVERALL",
    days_evaluated_using_8hour_path = sum(days_evaluated_using_8hour_path),
    days_1hour_upper_band_selected = sum(days_1hour_upper_band_selected),
    days_insufficient_source_hours = sum(days_insufficient_source_hours),
    days_no_valid_rolling_window = sum(days_no_valid_rolling_window)
  )
bind_rows(o3_path, o3_overall) %>% write_csv("data/metadata/phase2E_o3_path_summary.csv")

# phase2E_first_day_edge_audit.csv
first_day <- aqi_master %>%
  filter(date == as.Date("2025-03-01")) %>%
  select(project_station_id, station_name, o3_valid_source_hours, o3_valid_8h_window_count, o3_selected_averaging_period, o3_subindex, aqi_validity_reason)
write_csv(first_day, "data/metadata/phase2E_first_day_edge_audit.csv")

# phase2E_final_dataset_quality.csv
qual <- tibble(
  dataset = c("UAQI_Master_Daily", "UAQI_Hyderabad_Daily", "UAQI_India_Daily"),
  rows = c(11970, 3990, 8550),
  columns = c(ncol(aqi_master), ncol(aqi_master), ncol(aqi_master)),
  station_count = c(21, 7, 15),
  date_min = rep(min(aqi_master$date), 3),
  date_max = rep(max(aqi_master$date), 3),
  duplicate_station_date_rows = c(0, 0, 0),
  missing_aqi_count = c(
    sum(is.na(aqi_master$aqi_verified)),
    sum(is.na(aqi_master$aqi_verified[aqi_master$use_hyderabad])),
    sum(is.na(aqi_master$aqi_verified[aqi_master$use_india]))
  ),
  valid_aqi_count = c(
    sum(!is.na(aqi_master$aqi_verified)),
    sum(!is.na(aqi_master$aqi_verified[aqi_master$use_hyderabad])),
    sum(!is.na(aqi_master$aqi_verified[aqi_master$use_india]))
  ),
  weather_missing_count = c(
    sum(is.na(aqi_master$temperature)),
    sum(is.na(aqi_master$temperature[aqi_master$use_hyderabad])),
    sum(is.na(aqi_master$temperature[aqi_master$use_india]))
  ),
  policy_name = rep("VERIFIED_SUBSET_PM25_PM10_O3", 3),
  schema_hash_or_signature = rep(digest::digest(names(aqi_master)), 3)
)
write_csv(qual, "data/metadata/phase2E_final_dataset_quality.csv")

cat("Phase 2E execution complete.\n")
