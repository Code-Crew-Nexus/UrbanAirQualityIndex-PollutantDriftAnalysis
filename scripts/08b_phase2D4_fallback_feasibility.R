source("R/00_setup.R")
library(dplyr)
library(readr)

# Load daily pre-AQI dataset
pre_aqi <- read_csv("data/interim/daily/phase2C_master_daily_preAQI.csv", show_col_types = FALSE)

# Check validity: >= 16 valid hours
df <- pre_aqi %>%
  mutate(
    valid_pm2_5 = pm2_5_valid_hours >= 16,
    valid_pm10 = pm10_valid_hours >= 16,
    valid_o3 = o3_valid_hours >= 16,
    valid_all_three = valid_pm2_5 & valid_pm10 & valid_o3,
    scope = case_when(
      use_hyderabad & use_india ~ "Both",
      use_hyderabad ~ "Hyderabad",
      use_india ~ "India",
      TRUE ~ "None"
    )
  )

# Summarize by station
station_summary <- df %>%
  group_by(project_station_id, station_name, city, scope) %>%
  summarize(
    total_days = n(),
    days_valid_pm2_5 = sum(valid_pm2_5, na.rm = TRUE),
    days_valid_pm10 = sum(valid_pm10, na.rm = TRUE),
    days_valid_o3 = sum(valid_o3, na.rm = TRUE),
    days_valid_all_three = sum(valid_all_three, na.rm = TRUE),
    .groups = "drop"
  )

# Overall summary
overall_summary <- df %>%
  summarize(
    project_station_id = "OVERALL",
    station_name = "ALL",
    city = "ALL",
    scope = "ALL",
    total_days = n(),
    days_valid_pm2_5 = sum(valid_pm2_5, na.rm = TRUE),
    days_valid_pm10 = sum(valid_pm10, na.rm = TRUE),
    days_valid_o3 = sum(valid_o3, na.rm = TRUE),
    days_valid_all_three = sum(valid_all_three, na.rm = TRUE)
  )

# Combine
feasibility <- bind_rows(station_summary, overall_summary)

dir.create("data/metadata", showWarnings = FALSE, recursive = TRUE)
write_csv(feasibility, "data/metadata/phase2D4_verified_subset_feasibility.csv")
