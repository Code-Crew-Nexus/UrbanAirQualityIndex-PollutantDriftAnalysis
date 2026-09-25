library(dplyr)
library(readr)

library(ggplot2)
library(tidyr)

# 1. Load Data
master_df <- read_csv("data/processed/UAQI_Master_Daily.csv", show_col_types = FALSE)

# 2. Derive Predictors and Target
design_df <- master_df %>%
  arrange(project_station_id, date) %>%
  mutate(
    target_date = date + 1,
    sin_wind_direction = sin(wind_direction * pi / 180),
    cos_wind_direction = cos(wind_direction * pi / 180),
    month_number = as.numeric(format(date, "%m")),
    month_sin = sin(2 * pi * month_number / 12),
    month_cos = cos(2 * pi * month_number / 12)
  )

# Get next day AQI strictly from the same station
target_lookup <- master_df %>%
  select(project_station_id, target_date = date, target_aqi_next_day = aqi_verified, target_category_next_day = aqi_category)

design_df <- design_df %>%
  left_join(target_lookup, by = c("project_station_id", "target_date"))

# Study end edge case: September 21 target is Sep 22, which is out of range.
# Left join automatically assigns NA since Sep 22 is not in the original data.
design_df <- design_df %>%
  mutate(
    target_aqi_next_day = if_else(target_date > as.Date("2026-09-21"), NA_real_, target_aqi_next_day),
    target_category_next_day = if_else(target_date > as.Date("2026-09-21"), NA_character_, target_category_next_day),
    target_adverse_next_day = if_else(!is.na(target_aqi_next_day), if_else(target_aqi_next_day > 100, 1, 0), NA_real_)
  )

# 3. Chronological Splits based on target_date
design_df <- design_df %>%
  mutate(
    split = case_when(
      target_date >= as.Date("2025-03-02") & target_date <= as.Date("2025-12-31") ~ "TRAIN",
      target_date >= as.Date("2026-01-01") & target_date <= as.Date("2026-04-30") ~ "VALIDATION",
      target_date >= as.Date("2026-05-01") & target_date <= as.Date("2026-08-31") ~ "TEST",
      target_date >= as.Date("2026-09-01") & target_date <= as.Date("2026-09-21") ~ "FINAL_RECENT_HOLDOUT",
      TRUE ~ "OUT_OF_RANGE"
    )
  )

# 4. Eligibility rules
design_df <- design_df %>%
  mutate(
    eligible_model_A = !is.na(target_aqi_next_day) & 
                       !is.na(pm2_5_aqi_input) & !is.na(pm10_aqi_input) & !is.na(o3_8h_max) & 
                       !is.na(temperature) & !is.na(humidity) & !is.na(wind_speed) & 
                       !is.na(sin_wind_direction) & !is.na(cos_wind_direction) & 
                       !is.na(day_of_week) & !is.na(month_sin) & !is.na(month_cos) & !is.na(project_station_id),
    eligible_model_B = eligible_model_A & !is.na(aqi_verified),
    common_comparison_eligible = eligible_model_B & !is.na(aqi_verified) # Persistence is just aqi_verified
  ) %>%
  mutate(
    model_A_ineligibility_reason = case_when(
      eligible_model_A ~ "ELIGIBLE",
      is.na(target_aqi_next_day) ~ "MISSING_TARGET",
      is.na(pm2_5_aqi_input) | is.na(pm10_aqi_input) | is.na(o3_8h_max) ~ "MISSING_POLLUTANT",
      is.na(temperature) | is.na(humidity) | is.na(wind_speed) | is.na(sin_wind_direction) | is.na(cos_wind_direction) ~ "MISSING_WEATHER",
      TRUE ~ "MISSING_OTHER"
    ),
    model_B_ineligibility_reason = case_when(
      eligible_model_B ~ "ELIGIBLE",
      !eligible_model_A ~ model_A_ineligibility_reason,
      is.na(aqi_verified) ~ "MISSING_PERSISTENCE",
      TRUE ~ "UNKNOWN"
    )
  )

# 5. Master Design Table
master_out <- design_df %>%
  select(
    project_station_id, station_name, city, date, target_date, split,
    use_hyderabad, use_india,
    pm2_5_aqi_input, pm10_aqi_input, o3_8h_max,
    temperature, humidity, wind_speed, sin_wind_direction, cos_wind_direction,
    day_of_week, month_sin, month_cos,
    aqi_verified, target_aqi_next_day, target_category_next_day, target_adverse_next_day,
    eligible_model_A, eligible_model_B, common_comparison_eligible,
    model_A_ineligibility_reason, model_B_ineligibility_reason
  )
write_csv(master_out, "data/modeling/phase4A/NextDay_AQI_Modeling_Design_Master.csv")

# 6. Eligible Modeling Matrices
write_eligible_matrix <- function(df, scope_flag, eligible_flag, filename) {
  filtered <- df %>% filter(!!sym(scope_flag) == TRUE, !!sym(eligible_flag) == TRUE, split != "OUT_OF_RANGE")
  write_csv(filtered, filename)
}

write_eligible_matrix(master_out, "use_hyderabad", "eligible_model_A", "data/modeling/phase4A/Hyderabad_Model_A.csv")
write_eligible_matrix(master_out, "use_hyderabad", "eligible_model_B", "data/modeling/phase4A/Hyderabad_Model_B.csv")
write_eligible_matrix(master_out, "use_india", "eligible_model_A", "data/modeling/phase4A/India_Model_A.csv")
write_eligible_matrix(master_out, "use_india", "eligible_model_B", "data/modeling/phase4A/India_Model_B.csv")
write_eligible_matrix(master_out, "use_hyderabad", "common_comparison_eligible", "data/modeling/phase4A/Hyderabad_Common_Comparison.csv")
write_eligible_matrix(master_out, "use_india", "common_comparison_eligible", "data/modeling/phase4A/India_Common_Comparison.csv")

# 7. Split Audit Tables
split_audit <- master_out %>%
  filter(split != "OUT_OF_RANGE") %>%
  mutate(scope = if_else(use_hyderabad & use_india, "BOTH", if_else(use_hyderabad, "HYDERABAD", if_else(use_india, "INDIA", "NONE")))) %>%
  filter(scope != "NONE") %>%
  # We should aggregate by Hyderabad vs India specifically since stations can overlap
  # We will just do it twice and bind rows
  bind_rows(
    master_out %>% filter(split != "OUT_OF_RANGE", use_hyderabad) %>% mutate(scope = "HYDERABAD"),
    master_out %>% filter(split != "OUT_OF_RANGE", use_india) %>% mutate(scope = "INDIA")
  ) %>%
  group_by(scope, split) %>%
  summarize(
    structural_rows = n(),
    valid_targets = sum(!is.na(target_aqi_next_day)),
    model_A_eligible = sum(eligible_model_A),
    model_B_eligible = sum(eligible_model_B),
    common_comparison_eligible = sum(common_comparison_eligible),
    pct_A_eligible = round(model_A_eligible / structural_rows * 100, 1),
    .groups = "drop"
  )
write_csv(split_audit, "analysis/phase4A/tables/phase4A_split_sample_counts.csv")

station_audit <- master_out %>%
  filter(split != "OUT_OF_RANGE") %>%
  bind_rows(
    master_out %>% filter(split != "OUT_OF_RANGE", use_hyderabad) %>% mutate(scope = "HYDERABAD"),
    master_out %>% filter(split != "OUT_OF_RANGE", use_india) %>% mutate(scope = "INDIA")
  ) %>%
  filter(!is.na(scope)) %>%
  group_by(scope, project_station_id, split) %>%
  summarize(eligible_samples = sum(common_comparison_eligible), .groups = "drop") %>%
  pivot_wider(names_from = split, values_from = eligible_samples, values_fill = 0) %>%
  mutate(
    flag_low_train = if_else(TRAIN < 50, TRUE, FALSE),
    flag_zero_val = if_else(VALIDATION == 0, TRUE, FALSE),
    flag_zero_test = if_else(TEST == 0, TRUE, FALSE),
    flag_zero_holdout = if_else(FINAL_RECENT_HOLDOUT == 0, TRUE, FALSE)
  )
write_csv(station_audit, "analysis/phase4A/tables/phase4A_station_split_counts.csv")

# 8. Target Distribution Audit
target_dist <- master_out %>%
  filter(split != "OUT_OF_RANGE", common_comparison_eligible == TRUE) %>%
  bind_rows(
    master_out %>% filter(split != "OUT_OF_RANGE", use_hyderabad, common_comparison_eligible) %>% mutate(scope = "HYDERABAD"),
    master_out %>% filter(split != "OUT_OF_RANGE", use_india, common_comparison_eligible) %>% mutate(scope = "INDIA")
  ) %>%
  filter(!is.na(scope)) %>%
  group_by(scope, split) %>%
  summarize(
    n = n(),
    mean = mean(target_aqi_next_day, na.rm=TRUE),
    median = median(target_aqi_next_day, na.rm=TRUE),
    SD = sd(target_aqi_next_day, na.rm=TRUE),
    Q1 = quantile(target_aqi_next_day, 0.25, na.rm=TRUE),
    Q3 = quantile(target_aqi_next_day, 0.75, na.rm=TRUE),
    minimum = min(target_aqi_next_day, na.rm=TRUE),
    maximum = max(target_aqi_next_day, na.rm=TRUE),
    pct_good = sum(target_category_next_day == "Good", na.rm=TRUE) / n * 100,
    pct_satisfactory = sum(target_category_next_day == "Satisfactory", na.rm=TRUE) / n * 100,
    pct_mod_polluted = sum(target_category_next_day == "Moderately Polluted", na.rm=TRUE) / n * 100,
    pct_poor = sum(target_category_next_day == "Poor", na.rm=TRUE) / n * 100,
    pct_very_poor = sum(target_category_next_day == "Very Poor", na.rm=TRUE) / n * 100,
    pct_severe = sum(target_category_next_day == "Severe", na.rm=TRUE) / n * 100,
    .groups = "drop"
  )
write_csv(target_dist, "analysis/phase4A/tables/phase4A_target_distribution_by_split.csv")

# 9. Logistic Class Balance Audit
logistic_dist <- master_out %>%
  filter(split != "OUT_OF_RANGE", common_comparison_eligible == TRUE) %>%
  bind_rows(
    master_out %>% filter(split != "OUT_OF_RANGE", use_hyderabad, common_comparison_eligible) %>% mutate(scope = "HYDERABAD"),
    master_out %>% filter(split != "OUT_OF_RANGE", use_india, common_comparison_eligible) %>% mutate(scope = "INDIA")
  ) %>%
  filter(!is.na(scope)) %>%
  group_by(scope, split) %>%
  summarize(
    n_total = n(),
    adverse_1 = sum(target_adverse_next_day == 1, na.rm=TRUE),
    adverse_0 = sum(target_adverse_next_day == 0, na.rm=TRUE),
    pct_adverse_1 = adverse_1 / n_total * 100,
    pct_adverse_0 = adverse_0 / n_total * 100,
    .groups = "drop"
  )
write_csv(logistic_dist, "analysis/phase4A/tables/phase4A_logistic_class_balance.csv")

# 10. Figures
# Split Timeline
# Create a dummy data frame for the timeline bounds
splits_timeline <- data.frame(
  Split = factor(c("TRAIN", "VALIDATION", "TEST", "FINAL_RECENT_HOLDOUT"), levels = c("FINAL_RECENT_HOLDOUT", "TEST", "VALIDATION", "TRAIN")),
  Start = as.Date(c("2025-03-02", "2026-01-01", "2026-05-01", "2026-09-01")),
  End = as.Date(c("2025-12-31", "2026-04-30", "2026-08-31", "2026-09-21"))
)

p1 <- ggplot(splits_timeline, aes(xmin = Start, xmax = End, y = Split, fill = Split)) +
  geom_errorbarh(aes(xmax = End, xmin = Start, height = 0.5), color = "black", linewidth=2) +
  theme_minimal() + labs(title = "Chronological Target Date Splits", x = "Target Date", y = "") +
  theme(legend.position = "none")
ggsave("analysis/phase4A/figures/01_chronological_split_timeline.png", p1, width=8, height=4)

# Eligible samples by split - Hyderabad
hyd_split_audit <- split_audit %>% filter(scope == "HYDERABAD") %>%
  mutate(split = factor(split, levels = c("TRAIN", "VALIDATION", "TEST", "FINAL_RECENT_HOLDOUT")))
p2 <- ggplot(hyd_split_audit, aes(x = split, y = common_comparison_eligible, fill = split)) +
  geom_bar(stat = "identity") +
  theme_minimal() + labs(title = "Hyderabad Eligible Samples by Split", x = "Split", y = "Count") +
  theme(legend.position = "none") + geom_text(aes(label=common_comparison_eligible), vjust=-0.5)
ggsave("analysis/phase4A/figures/02_hyderabad_samples_by_split.png", p2, width=8, height=5)

# Eligible samples by split - India
ind_split_audit <- split_audit %>% filter(scope == "INDIA") %>%
  mutate(split = factor(split, levels = c("TRAIN", "VALIDATION", "TEST", "FINAL_RECENT_HOLDOUT")))
p3 <- ggplot(ind_split_audit, aes(x = split, y = common_comparison_eligible, fill = split)) +
  geom_bar(stat = "identity") +
  theme_minimal() + labs(title = "India Eligible Samples by Split", x = "Split", y = "Count") +
  theme(legend.position = "none") + geom_text(aes(label=common_comparison_eligible), vjust=-0.5)
ggsave("analysis/phase4A/figures/03_india_samples_by_split.png", p3, width=8, height=5)

# Target AQI distribution by split - Hyderabad
p4 <- ggplot(master_out %>% filter(split != "OUT_OF_RANGE", use_hyderabad, common_comparison_eligible) %>% mutate(split=factor(split, levels=c("TRAIN","VALIDATION","TEST","FINAL_RECENT_HOLDOUT"))), 
             aes(x = split, y = target_aqi_next_day, fill = split)) +
  geom_boxplot() +
  theme_minimal() + labs(title = "Hyderabad Target AQI Distribution by Split", x = "Split", y = "Next-Day AQI") +
  theme(legend.position = "none")
ggsave("analysis/phase4A/figures/04_hyderabad_target_distribution.png", p4, width=8, height=5)

# Target AQI distribution by split - India
p5 <- ggplot(master_out %>% filter(split != "OUT_OF_RANGE", use_india, common_comparison_eligible) %>% mutate(split=factor(split, levels=c("TRAIN","VALIDATION","TEST","FINAL_RECENT_HOLDOUT"))), 
             aes(x = split, y = target_aqi_next_day, fill = split)) +
  geom_boxplot() +
  theme_minimal() + labs(title = "India Target AQI Distribution by Split", x = "Split", y = "Next-Day AQI") +
  theme(legend.position = "none")
ggsave("analysis/phase4A/figures/05_india_target_distribution.png", p5, width=8, height=5)

# Adverse class prevalence by split
p6 <- ggplot(logistic_dist, aes(x = factor(split, levels=c("TRAIN","VALIDATION","TEST","FINAL_RECENT_HOLDOUT")), y = pct_adverse_1, fill = scope)) +
  geom_bar(stat = "identity", position = "dodge") +
  theme_minimal() + labs(title = "Adverse Class Prevalence by Split", x = "Split", y = "% Adverse (AQI > 100)")
ggsave("analysis/phase4A/figures/06_adverse_class_prevalence.png", p6, width=8, height=5)

# Station level training coverage
p7 <- ggplot(station_audit, aes(x = project_station_id, y = TRAIN, fill = scope)) +
  geom_bar(stat = "identity") + coord_flip() +
  theme_minimal() + labs(title = "Station-level Training Coverage", x = "Station", y = "Eligible Samples in TRAIN") +
  theme(legend.position = "none") + facet_wrap(~scope, scales="free_y")
ggsave("analysis/phase4A/figures/07_station_training_coverage.png", p7, width=10, height=8)

# Station level holdout coverage
p8 <- ggplot(station_audit, aes(x = project_station_id, y = FINAL_RECENT_HOLDOUT, fill = scope)) +
  geom_bar(stat = "identity") + coord_flip() +
  theme_minimal() + labs(title = "Station-level Holdout Coverage", x = "Station", y = "Eligible Samples in HOLDOUT") +
  theme(legend.position = "none") + facet_wrap(~scope, scales="free_y")
ggsave("analysis/phase4A/figures/08_station_holdout_coverage.png", p8, width=10, height=8)

cat("Phase 4A completed successfully.\n")
