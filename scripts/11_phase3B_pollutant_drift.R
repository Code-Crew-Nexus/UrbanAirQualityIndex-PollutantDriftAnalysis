# 11_phase3B_pollutant_drift.R

library(dplyr)
library(readr)
library(zoo)
library(tidyr)
library(purrr)
library(ggplot2)

dir.create("analysis/phase3B/figures", recursive=TRUE, showWarnings=FALSE)
dir.create("analysis/phase3B/tables", recursive=TRUE, showWarnings=FALSE)
dir.create("data/analysis/phase3B", recursive=TRUE, showWarnings=FALSE)

master <- read_csv("data/processed/UAQI_Master_Daily.csv", show_col_types = FALSE)
master <- master %>% arrange(project_station_id, date)

calc_slope <- function(y) {
  valid <- !is.na(y)
  if (sum(valid) < 2) return(NA_real_)
  x <- seq_along(y)
  cov(x[valid], y[valid]) / var(x[valid])
}

calc_q25 <- function(x) { if(sum(!is.na(x)) == 0) NA_real_ else quantile(x, 0.25, na.rm=TRUE) }
calc_q75 <- function(x) { if(sum(!is.na(x)) == 0) NA_real_ else quantile(x, 0.75, na.rm=TRUE) }

vars_to_drift <- c(
  aqi_verified = "VERIFIED_AQI",
  pm2_5_aqi_input = "VERIFIED_POLLUTANT",
  pm10_aqi_input = "VERIFIED_POLLUTANT",
  o3_8h_max = "VERIFIED_POLLUTANT",
  co_source_mean = "SOURCE_SCALE_GAS",
  no2_source_mean = "SOURCE_SCALE_GAS",
  so2_source_mean = "SOURCE_SCALE_GAS"
)

message("Calculating rolling metrics. This will take a moment...")
drift_results <- list()

for (v in names(vars_to_drift)) {
  message(paste("Processing", v))
  v_type <- vars_to_drift[[v]]
  
  res <- master %>%
    group_by(project_station_id) %>%
    mutate(
      value = !!sym(v),
      
      # Recent window (30 days)
      recent_valid_days = rollapplyr(!is.na(value), width=30, FUN=sum, fill=NA),
      recent_mean = rollapplyr(value, width=30, FUN=mean, na.rm=TRUE, fill=NA),
      recent_median = rollapplyr(value, width=30, FUN=median, na.rm=TRUE, fill=NA),
      recent_sd = rollapplyr(value, width=30, FUN=sd, na.rm=TRUE, fill=NA),
      recent_q25 = rollapplyr(value, width=30, FUN=calc_q25, fill=NA),
      recent_q75 = rollapplyr(value, width=30, FUN=calc_q75, fill=NA),
      recent_slope_per_day_raw = rollapplyr(value, width=30, FUN=calc_slope, fill=NA),
      
      # Baseline window (90 days, lagged by 30 days)
      baseline_valid_days = lag(rollapplyr(!is.na(value), width=90, FUN=sum, fill=NA), 30),
      baseline_mean = lag(rollapplyr(value, width=90, FUN=mean, na.rm=TRUE, fill=NA), 30),
      baseline_median = lag(rollapplyr(value, width=90, FUN=median, na.rm=TRUE, fill=NA), 30),
      baseline_sd = lag(rollapplyr(value, width=90, FUN=sd, na.rm=TRUE, fill=NA), 30),
      baseline_q25 = lag(rollapplyr(value, width=90, FUN=calc_q25, fill=NA), 30),
      baseline_q75 = lag(rollapplyr(value, width=90, FUN=calc_q75, fill=NA), 30),
      
      day_idx = row_number()
    ) %>%
    ungroup() %>%
    mutate(
      variable = v,
      variable_type = v_type,
      baseline_start = date - 119,
      baseline_end = date - 30,
      recent_start = date - 29,
      recent_end = date,
      baseline_coverage_pct = baseline_valid_days / 90 * 100,
      recent_coverage_pct = recent_valid_days / 30 * 100,
      
      # 4. DETERMINE ELIGIBILITY BEFORE FINAL DRIFT METRICS
      drift_eligible = (day_idx >= 120) & (recent_valid_days >= 21) & (baseline_valid_days >= 63) & (!is.na(baseline_sd) & baseline_sd > 0),
      
      drift_ineligibility_reason = case_when(
        day_idx < 120 ~ "insufficient_history",
        recent_valid_days < 21 & baseline_valid_days < 63 ~ "insufficient_recent_and_baseline_data",
        recent_valid_days < 21 ~ "insufficient_recent_data",
        baseline_valid_days < 63 ~ "insufficient_baseline_data",
        is.na(baseline_sd) | baseline_sd == 0 ~ "zero_or_undefined_baseline_sd",
        TRUE ~ "eligible"
      ),
      
      # 5 & 6. MASK INTERPRETIVE DRIFT METRICS
      baseline_iqr = baseline_q75 - baseline_q25,
      recent_iqr = recent_q75 - recent_q25,
      
      mean_difference = if_else(drift_eligible, recent_mean - baseline_mean, NA_real_),
      median_difference = if_else(drift_eligible, recent_median - baseline_median, NA_real_),
      volatility_ratio = if_else(drift_eligible, recent_sd / baseline_sd, NA_real_),
      recent_slope_per_day = if_else(drift_eligible, recent_slope_per_day_raw, NA_real_),
      
      percent_change = if_else(drift_eligible & !is.na(baseline_mean) & abs(baseline_mean) > 1e-4, 100 * mean_difference / abs(baseline_mean), NA_real_),
      drift_z = if_else(drift_eligible, (recent_mean - baseline_mean) / baseline_sd, NA_real_),
      
      drift_direction = case_when(
        !drift_eligible ~ NA_character_,
        drift_z > 1e-6 ~ "upward",
        drift_z < -1e-6 ~ "downward",
        TRUE ~ "stable"
      ),
      
      drift_magnitude_class = case_when(
        !drift_eligible ~ NA_character_,
        abs(drift_z) < 0.5 ~ "MINIMAL",
        abs(drift_z) >= 0.5 & abs(drift_z) < 1.0 ~ "MILD",
        abs(drift_z) >= 1.0 & abs(drift_z) < 2.0 ~ "MODERATE",
        abs(drift_z) >= 2.0 ~ "STRONG"
      )
    ) %>%
    select(
      project_station_id, station_name, city, state, date, variable, variable_type,
      baseline_start, baseline_end, recent_start, recent_end,
      baseline_valid_days, recent_valid_days, baseline_coverage_pct, recent_coverage_pct,
      baseline_mean, recent_mean, mean_difference, percent_change,
      baseline_median, recent_median, median_difference,
      baseline_sd, recent_sd, volatility_ratio,
      baseline_q25, baseline_q75, recent_q25, recent_q75,
      baseline_iqr, recent_iqr, recent_slope_per_day,
      drift_z, drift_direction, drift_magnitude_class, drift_eligible, drift_ineligibility_reason
    )
  drift_results[[v]] <- res
}

long_drift <- bind_rows(drift_results)
write_csv(long_drift, "data/analysis/phase3B/phase3B_daily_drift_metrics.csv")

# 7. CURRENT SNAPSHOT
snapshot <- long_drift %>% filter(date == as.Date("2026-09-21"))
write_csv(snapshot, "data/analysis/phase3B/phase3B_current_drift_snapshot.csv")

# DRIFT VIEWS
master_scope <- master %>% select(project_station_id, date, use_hyderabad, use_india) %>% distinct()
long_drift_scope <- long_drift %>% left_join(master_scope, by = c("project_station_id", "date"))
write_csv(long_drift_scope %>% filter(use_hyderabad) %>% select(-use_hyderabad, -use_india), "data/analysis/phase3B/phase3B_hyderabad_drift.csv")
write_csv(long_drift_scope %>% filter(use_india) %>% select(-use_hyderabad, -use_india), "data/analysis/phase3B/phase3B_india_drift.csv")

# 9. FIX MONTHLY DRIFT SUMMARIES
monthly_drift <- long_drift %>%
  mutate(year_month = format(date, "%Y-%m")) %>%
  group_by(project_station_id, year_month, variable) %>%
  summarize(
    eligible_days = sum(drift_eligible),
    median_drift_z = median(drift_z[drift_eligible], na.rm=TRUE),
    mean_drift_z = mean(drift_z[drift_eligible], na.rm=TRUE),
    minimum_drift_z = min(drift_z[drift_eligible], na.rm=TRUE),
    maximum_drift_z = max(drift_z[drift_eligible], na.rm=TRUE),
    days_MINIMAL = sum(drift_magnitude_class == "MINIMAL", na.rm=TRUE),
    days_MILD = sum(drift_magnitude_class == "MILD", na.rm=TRUE),
    days_MODERATE = sum(drift_magnitude_class == "MODERATE", na.rm=TRUE),
    days_STRONG = sum(drift_magnitude_class == "STRONG", na.rm=TRUE),
    days_upward = sum(drift_direction == "upward", na.rm=TRUE),
    days_downward = sum(drift_direction == "downward", na.rm=TRUE),
    days_stable = sum(drift_direction == "stable", na.rm=TRUE),
    .groups = "drop"
  ) %>%
  mutate(across(c(median_drift_z, mean_drift_z, minimum_drift_z, maximum_drift_z), ~ ifelse(is.infinite(.), NA, .)))
write_csv(monthly_drift, "data/analysis/phase3B/phase3B_station_month_drift_summary.csv")

# 18. COVERAGE SUMMARY IMPROVEMENT
first_possible <- as.Date("2025-06-28")
coverage_sum <- long_drift %>%
  group_by(project_station_id, variable) %>%
  summarize(
    total_evaluation_days = n(),
    eligible_drift_days = sum(drift_eligible),
    ineligible_drift_days = total_evaluation_days - eligible_drift_days,
    eligible_pct = eligible_drift_days / total_evaluation_days * 100,
    
    post_history_possible_days = sum(date >= first_possible),
    post_history_eligible_days = sum(drift_eligible & date >= first_possible),
    post_history_eligible_pct = sum(drift_eligible & date >= first_possible) / sum(date >= first_possible) * 100,
    
    insufficient_recent_count = sum(drift_ineligibility_reason %in% c("insufficient_recent_data", "insufficient_recent_and_baseline_data")),
    insufficient_baseline_count = sum(drift_ineligibility_reason %in% c("insufficient_baseline_data", "insufficient_recent_and_baseline_data")),
    zero_sd_count = sum(drift_ineligibility_reason == "zero_or_undefined_baseline_sd"),
    .groups = "drop"
  )
write_csv(coverage_sum, "analysis/phase3B/tables/phase3B_drift_coverage_summary.csv")

# 14. CURRENT DRIFT RANKING TABLES
write_ranking <- function(var_name, file_name) {
  ranked <- snapshot %>%
    filter(variable == var_name, drift_eligible == TRUE) %>%
    arrange(desc(drift_z)) %>%
    mutate(rank = row_number()) %>%
    select(rank, station = station_name, city, baseline_mean, recent_mean, drift_z, direction = drift_direction, magnitude_class = drift_magnitude_class, percent_change)
  write_csv(ranked, file_name)
}
write_ranking("pm2_5_aqi_input", "data/analysis/phase3B/phase3B_current_pm25_drift_ranking.csv")
write_ranking("pm10_aqi_input", "data/analysis/phase3B/phase3B_current_pm10_drift_ranking.csv")
write_ranking("o3_8h_max", "data/analysis/phase3B/phase3B_current_o3_drift_ranking.csv")
write_ranking("aqi_verified", "data/analysis/phase3B/phase3B_current_aqi_drift_ranking.csv")

# 15. FIX PHASE-3C INFERENCE INPUT
phase3C_windows <- snapshot %>%
  mutate(test_eligible = drift_eligible) %>%
  select(
    project_station_id, station_name, variable,
    baseline_start, baseline_end, recent_start, recent_end,
    baseline_n = baseline_valid_days, recent_n = recent_valid_days,
    baseline_mean, recent_mean, baseline_sd, recent_sd,
    baseline_median, recent_median, drift_z, test_eligible
  )
write_csv(phase3C_windows, "data/analysis/phase3B/phase3B_current_window_summary_for_inference.csv")

# 16. CREATE RAW WINDOW INDEX TABLE FOR PHASE 3C
# For evaluation date 2026-09-21, baseline: 2026-05-25 through 2026-08-22, recent: 2026-08-23 through 2026-09-21
eval_date <- as.Date("2026-09-21")
base_s <- eval_date - 119
base_e <- eval_date - 30
rec_s <- eval_date - 29
rec_e <- eval_date

raw_windows <- master %>%
  filter(date >= base_s & date <= rec_e) %>%
  select(project_station_id, station_name, city, date, all_of(names(vars_to_drift))) %>%
  pivot_longer(cols = names(vars_to_drift), names_to = "variable", values_to = "value") %>%
  mutate(
    variable_type = vars_to_drift[variable],
    window_type = if_else(date <= base_e, "BASELINE", "RECENT"),
    evaluation_date = eval_date
  ) %>%
  rename(observation_date = date) %>%
  left_join(
    snapshot %>% select(project_station_id, variable, test_eligible = drift_eligible),
    by = c("project_station_id", "variable")
  ) %>%
  select(project_station_id, station_name, city, variable, variable_type, observation_date, window_type, value, evaluation_date, test_eligible)

write_csv(raw_windows, "data/analysis/phase3B/phase3B_current_window_observations_for_inference.csv")

# METEOROLOGICAL CONTEXT
weather_results <- list()
for(v in c("temperature", "humidity", "wind_speed")) {
  weather_results[[v]] <- master %>%
    group_by(project_station_id) %>%
    mutate(
      value = !!sym(v),
      recent_mean = rollapplyr(value, width=30, FUN=mean, na.rm=TRUE, fill=NA),
      baseline_mean = lag(rollapplyr(value, width=90, FUN=mean, na.rm=TRUE, fill=NA), 30),
      baseline_sd = lag(rollapplyr(value, width=90, FUN=sd, na.rm=TRUE, fill=NA), 30)
    ) %>%
    ungroup() %>%
    mutate(
      variable = v,
      variable_type = "METEOROLOGICAL_CONTEXT",
      drift_z = if_else(!is.na(baseline_sd) & baseline_sd > 0, (recent_mean - baseline_mean) / baseline_sd, NA_real_)
    ) %>%
    select(project_station_id, date, variable, variable_type, recent_mean, baseline_mean, baseline_sd, drift_z)
}
write_csv(bind_rows(weather_results), "data/analysis/phase3B/phase3B_weather_context.csv")

# 11 & 12. VISUALIZATIONS
message("Creating visualizations...")
plot_drift_ts <- function(df, var_name, title, filename) {
  sub_df <- df %>% filter(variable == var_name)
  p <- ggplot(sub_df, aes(x=date, y=drift_z, color=station_name)) +
    geom_line(alpha=0.6) +
    geom_hline(yintercept=c(-2,-1,-0.5,0,0.5,1,2), linetype="dashed", color="gray50") +
    theme_minimal() +
    labs(title=title, y="Drift Z Score", x="Date", subtitle="Dashed lines: PROJECT DRIFT MAGNITUDE HEURISTICS")
  ggsave(filename, p, width=10, height=5)
}

plot_drift_ts(long_drift_scope %>% filter(use_hyderabad), "pm2_5_aqi_input", "Hyderabad PM2.5 Rolling Drift Z", "analysis/phase3B/figures/01_hyd_pm25_drift_ts.png")
plot_drift_ts(long_drift_scope %>% filter(use_hyderabad), "pm10_aqi_input", "Hyderabad PM10 Rolling Drift Z", "analysis/phase3B/figures/02_hyd_pm10_drift_ts.png")
plot_drift_ts(long_drift_scope %>% filter(use_hyderabad), "o3_8h_max", "Hyderabad O3 Rolling Drift Z", "analysis/phase3B/figures/03_hyd_o3_drift_ts.png")
plot_drift_ts(long_drift_scope %>% filter(use_hyderabad), "aqi_verified", "Hyderabad Verified AQI Rolling Drift Z", "analysis/phase3B/figures/04_hyd_aqi_drift_ts.png")

plot_snapshot <- function(var_name, title, filename) {
  sub_df <- snapshot %>% left_join(master_scope %>% filter(date == as.Date("2026-09-21")), by="project_station_id") %>% filter(variable == var_name, drift_eligible == TRUE, use_india == TRUE)
  if(nrow(sub_df) == 0) return(NULL)
  p <- ggplot(sub_df, aes(x=reorder(project_station_id, drift_z), y=drift_z, fill=drift_magnitude_class)) +
    geom_col() + coord_flip() +
    geom_hline(yintercept=c(-2,-1,-0.5,0,0.5,1,2), linetype="dashed", color="gray50") +
    theme_minimal() +
    labs(title=title, x="Station", y="Current Drift Z", subtitle="Dashed lines: PROJECT DRIFT MAGNITUDE HEURISTICS")
  ggsave(filename, p, width=8, height=6)
}
plot_snapshot("pm2_5_aqi_input", "India Current PM2.5 Drift Snapshot", "analysis/phase3B/figures/05_ind_pm25_snapshot.png")
plot_snapshot("pm10_aqi_input", "India Current PM10 Drift Snapshot", "analysis/phase3B/figures/06_ind_pm10_snapshot.png")
plot_snapshot("o3_8h_max", "India Current O3 Drift Snapshot", "analysis/phase3B/figures/07_ind_o3_snapshot.png")
plot_snapshot("aqi_verified", "Current Verified AQI Drift Snapshot", "analysis/phase3B/figures/08_current_aqi_snapshot.png")

p9 <- ggplot(monthly_drift %>% filter(variable=="aqi_verified"), aes(x=year_month, y=project_station_id, fill=mean_drift_z)) +
  geom_tile() + scale_fill_gradient2(low="blue", high="red", mid="white", midpoint=0) +
  theme_minimal() + theme(axis.text.x = element_text(angle=45, hjust=1)) +
  labs(title="Station-Month Verified AQI Drift Heatmap")
ggsave("analysis/phase3B/figures/09_station_month_drift_heatmap.png", p9, width=10, height=6)

p10 <- ggplot(coverage_sum, aes(x=variable, y=project_station_id, fill=eligible_pct)) +
  geom_tile() + scale_fill_viridis_c() +
  theme_minimal() + theme(axis.text.x = element_text(angle=45, hjust=1)) +
  labs(title="Drift Eligibility Coverage (%)")
ggsave("analysis/phase3B/figures/10_drift_eligibility_heatmap.png", p10, width=10, height=6)

p11 <- ggplot(long_drift %>% filter(drift_eligible), aes(x=baseline_mean, y=recent_mean, color=variable)) +
  geom_point(alpha=0.3) + geom_abline(slope=1, intercept=0, linetype="dashed") +
  theme_minimal() + labs(title="Recent Mean vs Baseline Mean")
ggsave("analysis/phase3B/figures/11_recent_vs_baseline_mean.png", p11, width=8, height=6)

plot_gas_heatmap <- function(var_name, title, filename) {
  p <- ggplot(monthly_drift %>% filter(variable==var_name), aes(x=year_month, y=project_station_id, fill=mean_drift_z)) +
    geom_tile() + scale_fill_gradient2(low="blue", high="red", mid="white", midpoint=0) +
    theme_minimal() + theme(axis.text.x = element_text(angle=45, hjust=1)) +
    labs(title=title)
  ggsave(filename, p, width=10, height=6)
}
plot_gas_heatmap("co_source_mean", "Source-scale CO Drift Heatmap", "analysis/phase3B/figures/12_co_drift_heatmap.png")
plot_gas_heatmap("no2_source_mean", "Source-scale NO2 Drift Heatmap", "analysis/phase3B/figures/13_no2_drift_heatmap.png")
plot_gas_heatmap("so2_source_mean", "Source-scale SO2 Drift Heatmap", "analysis/phase3B/figures/14_so2_drift_heatmap.png")

message("Phase 3B.1 drift quantification complete.")
