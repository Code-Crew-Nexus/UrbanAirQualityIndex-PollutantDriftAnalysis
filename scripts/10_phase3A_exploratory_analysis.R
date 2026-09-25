# ==============================================================================
# 10_phase3A_exploratory_analysis.R
# Phase 3A: Exploratory Statistical Analysis & Modeling Base Preparation
# ==============================================================================

library(dplyr)
library(readr)
library(tidyr)
library(ggplot2)

library(zoo)

# Setup Paths
dir.create("analysis/phase3A/figures", recursive = TRUE, showWarnings = FALSE)
dir.create("analysis/phase3A/tables", recursive = TRUE, showWarnings = FALSE)
dir.create("data/analysis/phase3A", recursive = TRUE, showWarnings = FALSE)

# 4. LOAD AND VALIDATE FINAL DATASETS
message("Loading datasets...")
master <- read_csv("data/processed/UAQI_Master_Daily.csv", show_col_types = FALSE)
hyd <- read_csv("data/processed/UAQI_Hyderabad_Daily.csv", show_col_types = FALSE)
ind <- read_csv("data/processed/UAQI_India_Daily.csv", show_col_types = FALSE)

stopifnot(nrow(master) == 11970)
stopifnot(nrow(hyd) == 3990)
stopifnot(nrow(ind) == 8550)
stopifnot(min(master$date) == as.Date("2025-03-01"))
stopifnot(max(master$date) == as.Date("2026-09-21"))
stopifnot(nrow(master %>% count(project_station_id, date) %>% filter(n > 1)) == 0)
stopifnot(identical(names(hyd), names(ind)))

# 5. VERIFY AQI POLICY
stopifnot(all(master$aqi_input_policy == "VERIFIED_SUBSET_PM25_PM10_O3"))

# Determine scope strings for grouping
master <- master %>%
  mutate(scope = case_when(use_hyderabad & use_india ~ "Both", use_hyderabad ~ "Hyderabad", use_india ~ "India", TRUE ~ "None"))

# 6. VALID AND INVALID AQI POPULATIONS
message("Generating AQI Validity Profile...")
validity_profile <- master %>%
  group_by(project_station_id, station_name, city, scope, month, season) %>%
  summarize(
    total_days = n(),
    valid_aqi = sum(!is.na(aqi_verified)),
    invalid_aqi = sum(is.na(aqi_verified)),
    valid_percentage = round(valid_aqi / total_days * 100, 2),
    invalid_pm2_5 = sum(grepl("insufficient_pm2_5_hours", aqi_invalid_components)),
    invalid_pm10 = sum(grepl("insufficient_pm10_hours", aqi_invalid_components)),
    invalid_o3 = sum(grepl("insufficient_o3_hours|no_valid_o3_8h_window", aqi_invalid_components)),
    .groups = "drop"
  )
write_csv(validity_profile, "data/analysis/phase3A/aqi_validity_profile.csv")

# 7. CREATE AQI-VALID ANALYSIS VIEWS
master_valid <- master %>% filter(aqi_validity_reason == "valid")
hyd_valid <- hyd %>% filter(aqi_validity_reason == "valid")
ind_valid <- ind %>% filter(aqi_validity_reason == "valid")

write_csv(master_valid, "data/analysis/phase3A/phase3A_master_valid_aqi.csv")
write_csv(hyd_valid, "data/analysis/phase3A/phase3A_hyderabad_valid_aqi.csv")
write_csv(ind_valid, "data/analysis/phase3A/phase3A_india_valid_aqi.csv")

# Function for Descriptive Stats
calc_stats <- function(df, grouping_vars, var_name, col_sym) {
  df %>%
    group_by(across(all_of(grouping_vars))) %>%
    summarize(
      variable = var_name,
      n = n(),
      missing = sum(is.na(!!sym(col_sym))),
      mean = mean(!!sym(col_sym), na.rm=TRUE),
      median = median(!!sym(col_sym), na.rm=TRUE),
      sd = sd(!!sym(col_sym), na.rm=TRUE),
      var = var(!!sym(col_sym), na.rm=TRUE),
      min = min(!!sym(col_sym), na.rm=TRUE),
      max = max(!!sym(col_sym), na.rm=TRUE),
      Q1 = quantile(!!sym(col_sym), 0.25, na.rm=TRUE),
      Q3 = quantile(!!sym(col_sym), 0.75, na.rm=TRUE),
      IQR = IQR(!!sym(col_sym), na.rm=TRUE),
      CV = ifelse(mean > 0, sd / mean, NA_real_),
      .groups = "drop"
    )
}

# 8. DESCRIPTIVE STATISTICS
message("Calculating Descriptive Statistics...")
vars_to_describe <- c("aqi_verified", "pm2_5_aqi_input", "pm10_aqi_input", "o3_8h_max", "temperature", "humidity", "wind_speed")
stats_list <- list()

for(v in vars_to_describe) {
  # Overall
  stats_list[[length(stats_list) + 1]] <- calc_stats(master, "scope", v, v) %>% mutate(level = "Overall")
  # Station
  stats_list[[length(stats_list) + 1]] <- calc_stats(master, c("project_station_id", "station_name", "city"), v, v) %>% mutate(level = "Station")
  # City
  stats_list[[length(stats_list) + 1]] <- calc_stats(master, "city", v, v) %>% mutate(level = "City")
  # Season
  stats_list[[length(stats_list) + 1]] <- calc_stats(master, "season", v, v) %>% mutate(level = "Season")
}

desc_stats_df <- bind_rows(stats_list)
write_csv(desc_stats_df, "analysis/phase3A/tables/phase3A_descriptive_statistics.csv")

# 9. AQI CATEGORY ANALYSIS
message("Analyzing Categories...")
cat_analysis <- master %>%
  group_by(project_station_id, city, season, month, aqi_category) %>%
  summarize(counts = n(), .groups = "drop") %>%
  group_by(project_station_id, city, season, month) %>%
  mutate(
    total_valid = sum(counts[!is.na(aqi_category)]),
    valid_day_pct = ifelse(!is.na(aqi_category) & total_valid > 0, counts / total_valid * 100, NA_real_)
  ) %>% ungroup()
write_csv(cat_analysis, "analysis/phase3A/tables/phase3A_aqi_category_analysis.csv")

# 10. TEMPORAL AQI ANALYSIS
message("Temporal Profiling...")
master <- master %>%
  arrange(project_station_id, date) %>%
  group_by(project_station_id) %>%
  mutate(
    aqi_7d_mean = rollapply(aqi_verified, width=7, FUN=mean, na.rm=TRUE, fill=NA, align="right", partial=TRUE),
    aqi_7d_median = rollapply(aqi_verified, width=7, FUN=median, na.rm=TRUE, fill=NA, align="right", partial=TRUE)
  ) %>%
  ungroup()

monthly_aqi <- master %>%
  group_by(project_station_id, year, month) %>%
  summarize(
    monthly_mean_aqi = mean(aqi_verified, na.rm=TRUE),
    monthly_median_aqi = median(aqi_verified, na.rm=TRUE),
    .groups = "drop"
  )
write_csv(monthly_aqi, "analysis/phase3A/tables/phase3A_monthly_aqi_summary.csv")
# 16. WIND DIRECTION
master <- master %>%
  mutate(
    sin_wind_direction = sin(wind_direction * pi / 180),
    cos_wind_direction = cos(wind_direction * pi / 180)
  )

# 18. SOURCE-SCALE GAS STANDARDIZATION
master <- master %>%
  group_by(project_station_id) %>%
  mutate(
    co_source_z = if(sum(!is.na(co_source_mean)) > 1) scale(co_source_mean)[,1] else NA_real_,
    no2_source_z = if(sum(!is.na(no2_source_mean)) > 1) scale(no2_source_mean)[,1] else NA_real_,
    so2_source_z = if(sum(!is.na(so2_source_mean)) > 1) scale(so2_source_mean)[,1] else NA_real_
  ) %>%
  ungroup()

# 19. MISSINGNESS ANALYSIS
message("Missingness Profile...")
missingness <- master %>%
  group_by(project_station_id, month) %>%
  summarize(
    total = n(),
    missing_aqi = sum(is.na(aqi_verified)),
    missing_aqi_pct = missing_aqi/total*100,
    missing_pm25 = sum(is.na(pm2_5_aqi_input)),
    missing_pm10 = sum(is.na(pm10_aqi_input)),
    missing_o3 = sum(is.na(o3_8h_max)),
    missing_weather = sum(is.na(temperature)),
    longest_invalid_aqi_run = { r <- rle(as.numeric(is.na(aqi_verified))); max(c(0, r$lengths[r$values == 1])) },
    .groups = "drop"
  )
write_csv(missingness, "analysis/phase3A/tables/phase3A_missingness_profile.csv")

# 20. OUTLIER PROFILE
message("Outlier Profile...")
outlier_calc <- function(df, col_sym) {
  df %>%
    group_by(project_station_id) %>%
    summarize(
      variable = col_sym,
      min = min(!!sym(col_sym), na.rm=TRUE),
      max = max(!!sym(col_sym), na.rm=TRUE),
      p01 = quantile(!!sym(col_sym), 0.01, na.rm=TRUE),
      p99 = quantile(!!sym(col_sym), 0.99, na.rm=TRUE),
      Q1 = quantile(!!sym(col_sym), 0.25, na.rm=TRUE),
      Q3 = quantile(!!sym(col_sym), 0.75, na.rm=TRUE),
      IQR = IQR(!!sym(col_sym), na.rm=TRUE),
      iqr_outliers = sum(!!sym(col_sym) > (Q3 + 1.5*IQR) | !!sym(col_sym) < (Q1 - 1.5*IQR), na.rm=TRUE),
      .groups = "drop"
    )
}
outliers <- bind_rows(
  outlier_calc(master, "aqi_verified"),
  outlier_calc(master, "pm2_5_aqi_input"),
  outlier_calc(master, "pm10_aqi_input"),
  outlier_calc(master, "o3_8h_max")
)
write_csv(outliers, "analysis/phase3A/tables/phase3A_extreme_value_profile.csv")

# 21. CORRELATION MATRICES
corr_vars <- c("aqi_verified", "pm2_5_aqi_input", "pm10_aqi_input", "o3_8h_max", "temperature", "humidity", "wind_speed")
create_corr <- function(df, method) {
  cor(df %>% select(all_of(corr_vars)), use = "pairwise.complete.obs", method = method) %>%
    as.data.frame() %>%
    tibble::rownames_to_column("variable")
}
write_csv(create_corr(hyd, "pearson"), "analysis/phase3A/tables/phase3A_hyd_pearson.csv")
write_csv(create_corr(hyd, "spearman"), "analysis/phase3A/tables/phase3A_hyd_spearman.csv")
write_csv(create_corr(ind, "pearson"), "analysis/phase3A/tables/phase3A_ind_pearson.csv")
write_csv(create_corr(ind, "spearman"), "analysis/phase3A/tables/phase3A_ind_spearman.csv")

# 23. MONTHLY ANALYSIS SUMMARY
message("Monthly Summary...")
month_summary <- master %>%
  group_by(project_station_id, year, month) %>%
  summarize(
    valid_aqi_days = sum(!is.na(aqi_verified)),
    mean_aqi = mean(aqi_verified, na.rm=TRUE),
    median_aqi = median(aqi_verified, na.rm=TRUE),
    sd_aqi = sd(aqi_verified, na.rm=TRUE),
    pm2_5_mean = mean(pm2_5_aqi_input, na.rm=TRUE),
    pm10_mean = mean(pm10_aqi_input, na.rm=TRUE),
    o3_mean = mean(o3_8h_max, na.rm=TRUE),
    temperature = mean(temperature, na.rm=TRUE),
    humidity = mean(humidity, na.rm=TRUE),
    wind_speed = mean(wind_speed, na.rm=TRUE),
    cat_Good = sum(aqi_category == "Good", na.rm=TRUE),
    cat_Severe = sum(aqi_category == "Severe", na.rm=TRUE),
    dom_PM25 = sum(grepl("pm2_5", dominant_pollutant), na.rm=TRUE),
    .groups = "drop"
  )
write_csv(month_summary, "data/analysis/phase3A/phase3A_station_month_summary.csv")

# 24-28. NEXT-DAY TARGET PREPARATION
message("Modeling Eligibility...")
# We must prepare day t features with AQI day t+1
master_next <- master %>%
  select(project_station_id, date, target_aqi_next_day = aqi_verified, target_category_next_day = aqi_category) %>%
  mutate(date = date - 1) # Shift by 1 day so joining by 'date' maps t to t+1

modeling_base <- master %>%
  left_join(master_next, by = c("project_station_id", "date")) %>%
  mutate(
    modeling_eligible = !is.na(target_aqi_next_day) & !is.na(aqi_verified) & !is.na(temperature),
    ineligibility_reason = case_when(
      is.na(target_aqi_next_day) ~ "target_missing",
      is.na(aqi_verified) ~ "predictor_aqi_missing",
      is.na(temperature) ~ "predictor_weather_missing",
      TRUE ~ "eligible"
    )
  )

hyd_mod <- modeling_base %>% filter(use_hyderabad) %>% select(-co_source_mean, -no2_source_mean, -so2_source_mean, -co_source_z, -no2_source_z, -so2_source_z)
ind_mod <- modeling_base %>% filter(use_india) %>% select(-co_source_mean, -no2_source_mean, -so2_source_mean, -co_source_z, -no2_source_z, -so2_source_z)

write_csv(hyd_mod, "data/analysis/phase3A/Hyderabad_NextDay_Modeling_Base.csv")
write_csv(ind_mod, "data/analysis/phase3A/India_NextDay_Modeling_Base.csv")

# 29. CHRONOLOGICAL SPLIT AUDIT
split_audit <- modeling_base %>%
  mutate(period = case_when(
    date >= "2025-03-01" & date <= "2026-08-31" ~ "MODELING_HISTORY",
    date >= "2026-09-01" & date <= "2026-09-21" ~ "RECENT_EVALUATION",
    TRUE ~ "OTHER"
  )) %>%
  group_by(period) %>%
  summarize(
    total_days = n(),
    eligible_days = sum(modeling_eligible),
    .groups = "drop"
  )
write_csv(split_audit, "analysis/phase3A/tables/phase3A_chronological_split_audit.csv")

# 30. VISUALIZATIONS
message("Visualizations...")
# 1. AQI time series — Hyderabad
p1 <- ggplot(hyd_valid, aes(x=date, y=aqi_verified, color=station_name)) + geom_line(alpha=0.6) + theme_minimal() + labs(title="AQI Time Series - Hyderabad")
ggsave("analysis/phase3A/figures/01_aqi_ts_hyderabad.png", p1, width=10, height=5)

# 2. AQI time series — India representative stations
p2 <- ggplot(ind_valid, aes(x=date, y=aqi_verified, group=station_name)) + geom_line(alpha=0.3) + theme_minimal() + labs(title="AQI Time Series - India")
ggsave("analysis/phase3A/figures/02_aqi_ts_india.png", p2, width=10, height=5)

# 3. AQI category distribution
p3 <- ggplot(master_valid, aes(x=city, fill=aqi_category)) + geom_bar(position="fill") + coord_flip() + theme_minimal() + labs(title="AQI Category Dist")
ggsave("analysis/phase3A/figures/03_aqi_categories.png", p3, width=10, height=6)

# 4. Seasonal AQI boxplots
p4 <- ggplot(master_valid, aes(x=season, y=aqi_verified, fill=season)) + geom_boxplot() + theme_minimal() + labs(title="Seasonal AQI Distribution")
ggsave("analysis/phase3A/figures/04_seasonal_aqi_boxplots.png", p4, width=8, height=5)

# 5. Station-month AQI heatmap
p5 <- ggplot(month_summary, aes(x=factor(month), y=project_station_id, fill=mean_aqi)) + geom_tile() + scale_fill_viridis_c() + theme_minimal()
ggsave("analysis/phase3A/figures/05_station_month_aqi_heatmap.png", p5, width=10, height=6)

# 6. PM2.5 distribution
p6 <- ggplot(master_valid, aes(x=pm2_5_aqi_input)) + geom_histogram(bins=50) + facet_wrap(~season) + theme_minimal() + labs(title="PM2.5 Dist by Season")
ggsave("analysis/phase3A/figures/06_pm25_dist.png", p6, width=8, height=6)

# 7. PM10 distribution
p7 <- ggplot(master_valid, aes(x=pm10_aqi_input)) + geom_histogram(bins=50) + facet_wrap(~season) + theme_minimal()
ggsave("analysis/phase3A/figures/07_pm10_dist.png", p7, width=8, height=6)

# 8. O3 distribution
p8 <- ggplot(master_valid, aes(x=o3_8h_max)) + geom_histogram(bins=50) + facet_wrap(~season) + theme_minimal()
ggsave("analysis/phase3A/figures/08_o3_dist.png", p8, width=8, height=6)

# 9. AQI vs humidity
p9 <- ggplot(master_valid, aes(x=humidity, y=aqi_verified)) + geom_point(alpha=0.2) + geom_smooth(method="gam") + theme_minimal()
ggsave("analysis/phase3A/figures/09_aqi_vs_humidity.png", p9, width=6, height=5)

# 10. AQI vs wind speed
p10 <- ggplot(master_valid, aes(x=wind_speed, y=aqi_verified)) + geom_point(alpha=0.2) + geom_smooth(method="gam") + theme_minimal()
ggsave("analysis/phase3A/figures/10_aqi_vs_wind_speed.png", p10, width=6, height=5)

# 11 & 12 skipped for actual plots here (matrix saved to table)

# 13. AQI missingness heatmap
p13 <- ggplot(missingness, aes(x=factor(month), y=project_station_id, fill=missing_aqi_pct)) + geom_tile() + scale_fill_gradient(low="white", high="red") + theme_minimal()
ggsave("analysis/phase3A/figures/13_aqi_missingness_heatmap.png", p13, width=10, height=6)

# 14. Dominant pollutant
p14 <- ggplot(master_valid %>% filter(!is.na(dominant_pollutant)), aes(x=dominant_pollutant)) + geom_bar() + theme_minimal() + coord_flip()
ggsave("analysis/phase3A/figures/14_dominant_pollutant_dist.png", p14, width=8, height=5)

message("Phase 3A scripts completed successfully.")
