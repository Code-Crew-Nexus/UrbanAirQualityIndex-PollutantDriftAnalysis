library(dplyr)
library(readr)
library(ggplot2)

# Load master audit table
master_out <- read_csv("data/modeling/phase4A/NextDay_AQI_Modeling_Design_Master.csv", show_col_types = FALSE)

# Issue 1: Fix Split-Audit Construction
# We will compute Hyderabad and India scopes entirely independently.
hyd_audit <- master_out %>% filter(use_hyderabad == TRUE, split != "OUT_OF_RANGE") %>% mutate(scope = "HYDERABAD")
ind_audit <- master_out %>% filter(use_india == TRUE, split != "OUT_OF_RANGE") %>% mutate(scope = "INDIA")
master_phys <- master_out %>% filter(split != "OUT_OF_RANGE") %>% mutate(scope = "MASTER_21")

split_audit <- bind_rows(hyd_audit, ind_audit, master_phys) %>%
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

# Regenerate Split Figures (no double counting)
hyd_split_audit <- split_audit %>% filter(scope == "HYDERABAD") %>%
  mutate(split = factor(split, levels = c("TRAIN", "VALIDATION", "TEST", "FINAL_RECENT_HOLDOUT")))
p2 <- ggplot(hyd_split_audit, aes(x = split, y = common_comparison_eligible, fill = split)) +
  geom_bar(stat = "identity") +
  theme_minimal() + labs(title = "Hyderabad Eligible Samples by Split", x = "Split", y = "Count") +
  theme(legend.position = "none") + geom_text(aes(label=common_comparison_eligible), vjust=-0.5)
ggsave("analysis/phase4A/figures/02_hyderabad_samples_by_split.png", p2, width=8, height=5)

ind_split_audit <- split_audit %>% filter(scope == "INDIA") %>%
  mutate(split = factor(split, levels = c("TRAIN", "VALIDATION", "TEST", "FINAL_RECENT_HOLDOUT")))
p3 <- ggplot(ind_split_audit, aes(x = split, y = common_comparison_eligible, fill = split)) +
  geom_bar(stat = "identity") +
  theme_minimal() + labs(title = "India Eligible Samples by Split", x = "Split", y = "Count") +
  theme(legend.position = "none") + geom_text(aes(label=common_comparison_eligible), vjust=-0.5)
ggsave("analysis/phase4A/figures/03_india_samples_by_split.png", p3, width=8, height=5)

# Issue 2: Leakage-Safe Model Matrices
base_cols <- c("project_station_id", "station_name", "city", "date", "target_date", "split")
pred_a_cols <- c("pm2_5_aqi_input", "pm10_aqi_input", "o3_8h_max", "temperature", "humidity", "wind_speed", "sin_wind_direction", "cos_wind_direction", "day_of_week", "month_sin", "month_cos")
target_col <- "target_aqi_next_day"

model_a_cols <- c(base_cols, pred_a_cols, target_col)
model_b_cols <- c(model_a_cols, "aqi_verified")

write_csv(master_out %>% filter(use_hyderabad == TRUE, eligible_model_A == TRUE, split != "OUT_OF_RANGE") %>% select(all_of(model_a_cols)), "data/modeling/phase4A/Hyderabad_Model_A.csv")
write_csv(master_out %>% filter(use_india == TRUE, eligible_model_A == TRUE, split != "OUT_OF_RANGE") %>% select(all_of(model_a_cols)), "data/modeling/phase4A/India_Model_A.csv")

write_csv(master_out %>% filter(use_hyderabad == TRUE, eligible_model_B == TRUE, split != "OUT_OF_RANGE") %>% select(all_of(model_b_cols)), "data/modeling/phase4A/Hyderabad_Model_B.csv")
write_csv(master_out %>% filter(use_india == TRUE, eligible_model_B == TRUE, split != "OUT_OF_RANGE") %>% select(all_of(model_b_cols)), "data/modeling/phase4A/India_Model_B.csv")

write_csv(master_out %>% filter(use_hyderabad == TRUE, common_comparison_eligible == TRUE, split != "OUT_OF_RANGE") %>% select(all_of(model_b_cols)), "data/modeling/phase4A/Hyderabad_Common_Comparison.csv")
write_csv(master_out %>% filter(use_india == TRUE, common_comparison_eligible == TRUE, split != "OUT_OF_RANGE") %>% select(all_of(model_b_cols)), "data/modeling/phase4A/India_Common_Comparison.csv")

# Logistic Design Separate Files
log_cols <- c(model_a_cols, "target_category_next_day", "target_adverse_next_day")
write_csv(master_out %>% filter(use_hyderabad == TRUE, common_comparison_eligible == TRUE, split != "OUT_OF_RANGE") %>% select(all_of(log_cols)), "data/modeling/phase4A/Hyderabad_Logistic_Design.csv")
write_csv(master_out %>% filter(use_india == TRUE, common_comparison_eligible == TRUE, split != "OUT_OF_RANGE") %>% select(all_of(log_cols)), "data/modeling/phase4A/India_Logistic_Design.csv")

# Test/Holdout Station Metric Feasibility
station_audit <- bind_rows(hyd_audit, ind_audit) %>%
  group_by(scope, project_station_id, station_name, split) %>%
  summarize(n_common = sum(common_comparison_eligible), .groups = "drop") %>%
  mutate(station_metric_status = if_else(n_common >= 10, "ADEQUATE_FOR_DESCRIPTIVE_STATION_METRIC", "STATION_METRIC_LOW_SAMPLE"))
write_csv(station_audit, "analysis/phase4A/tables/phase4A_station_metric_feasibility.csv")

cat("Matrix repair complete.\n")
