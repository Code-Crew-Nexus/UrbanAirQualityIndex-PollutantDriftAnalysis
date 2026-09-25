# 12c_phase3C_subset_repair.R
library(dplyr)
library(readr)
library(ggplot2)

# Load Master Data
master_df <- read_csv("data/processed/UAQI_Master_Daily.csv", show_col_types = FALSE)
hyd_stations <- master_df %>% filter(use_hyderabad == TRUE) %>% distinct(project_station_id) %>% pull(project_station_id)
ind_stations <- master_df %>% filter(use_india == TRUE) %>% distinct(project_station_id) %>% pull(project_station_id)

stopifnot(length(hyd_stations) == 7)
stopifnot(length(ind_stations) == 15)

# Load Master Inference
inf_master <- read_csv("data/analysis/phase3C/phase3C_current_drift_inference_results.csv", show_col_types = FALSE)
stopifnot(nrow(inf_master) == 147)

# Update robustness_agreement field with directionality check
inf_master <- inf_master %>%
  mutate(
    dir_mean_diff = sign(mean_difference),
    dir_hedges = sign(hedges_g),
    dir_cliffs = sign(cliffs_delta),
    
    # Are directions completely consistent where they exist and aren't exact 0?
    # Actually, let's just check if they have the same sign (ignoring NA or zero if they aren't the primary measure)
    # The simplest is that if supported upward, both block and classical agree it's positive.
    # We define method significance:
    block_sig = p_block7_bh_global < 0.05,
    welch_sig = welch_p_bh_global < 0.05,
    wilcox_sig = wilcox_p_bh_global < 0.05,
    
    # Let's say all methods agree if all are sig AND effect sizes share the sign of mean_difference
    effect_signs_agree = (dir_mean_diff == dir_hedges | is.na(dir_hedges)) & (dir_mean_diff == dir_cliffs | is.na(dir_cliffs)),
    
    robustness_agreement = case_when(
      !test_performed ~ "NOT_TESTED_INSUFFICIENT_DATA",
      statistical_support != "NOT_STATISTICALLY_SUPPORTED" & welch_sig & wilcox_sig & effect_signs_agree ~ "ALL_METHODS_AGREE",
      statistical_support != "NOT_STATISTICALLY_SUPPORTED" & welch_sig & wilcox_sig & !effect_signs_agree ~ "MIXED_DIRECTION_OR_RESULT",
      statistical_support != "NOT_STATISTICALLY_SUPPORTED" & welch_sig & !wilcox_sig ~ "BLOCK_AND_WELCH",
      statistical_support != "NOT_STATISTICALLY_SUPPORTED" & !welch_sig & wilcox_sig ~ "BLOCK_AND_WILCOX",
      statistical_support != "NOT_STATISTICALLY_SUPPORTED" & !welch_sig & !wilcox_sig ~ "BLOCK_ONLY",
      statistical_support == "NOT_STATISTICALLY_SUPPORTED" & (welch_sig | wilcox_sig) ~ "CLASSICAL_ONLY",
      statistical_support == "NOT_STATISTICALLY_SUPPORTED" & !welch_sig & !wilcox_sig ~ "NO_METHOD_SUPPORT",
      TRUE ~ "MIXED_DIRECTION_OR_RESULT"
    )
  ) %>%
  select(-dir_mean_diff, -dir_hedges, -dir_cliffs, -block_sig, -welch_sig, -wilcox_sig, -effect_signs_agree)

# Rewrite master correctly
write_csv(inf_master, "data/analysis/phase3C/phase3C_current_drift_inference_results.csv")

# 5. Rebuild Hyderabad Inference
hyd_inf <- inf_master %>% filter(project_station_id %in% hyd_stations)
stopifnot(nrow(hyd_inf) == 49)
write_csv(hyd_inf, "data/analysis/phase3C/phase3C_hyderabad_inference.csv")

# 6. Rebuild India Inference
ind_inf <- inf_master %>% filter(project_station_id %in% ind_stations)
stopifnot(nrow(ind_inf) == 105)
write_csv(ind_inf, "data/analysis/phase3C/phase3C_india_inference.csv")

# 9. Rebuild Hyderabad Summary
hyd_summary <- hyd_inf %>%
  group_by(project_station_id) %>%
  summarize(
    eligible_tests = sum(test_performed),
    supported_upward = sum(statistical_support == "SUPPORTED_UPWARD_SHIFT"),
    supported_downward = sum(statistical_support == "SUPPORTED_DOWNWARD_SHIFT"),
    not_supported = sum(statistical_support == "NOT_STATISTICALLY_SUPPORTED"),
    not_tested = sum(statistical_support == "NOT_TESTED_INSUFFICIENT_DATA"),
    verified_pollutant_supported_upward = sum(statistical_support == "SUPPORTED_UPWARD_SHIFT" & variable_type == "VERIFIED_POLLUTANT_INFERENCE"),
    verified_pollutant_supported_downward = sum(statistical_support == "SUPPORTED_DOWNWARD_SHIFT" & variable_type == "VERIFIED_POLLUTANT_INFERENCE"),
    aqi_supported = sum(statistical_support %in% c("SUPPORTED_UPWARD_SHIFT", "SUPPORTED_DOWNWARD_SHIFT") & variable_type == "VERIFIED_SUBSET_AQI_INFERENCE"),
    source_scale_gas_supported = sum(statistical_support %in% c("SUPPORTED_UPWARD_SHIFT", "SUPPORTED_DOWNWARD_SHIFT") & variable_type == "SOURCE_SCALE_GAS"),
    .groups = "drop"
  )
write_csv(hyd_summary, "analysis/phase3C/tables/phase3C_hyderabad_inference_summary.csv")

# Visualizations: 7 and 8 Heatmaps with distinguished NA
plot_hm <- function(df, title, filename) {
  hm_df <- df %>%
    mutate(val = case_when(
      statistical_support == "SUPPORTED_UPWARD_SHIFT" ~ 1,
      statistical_support == "SUPPORTED_DOWNWARD_SHIFT" ~ -1,
      statistical_support == "NOT_STATISTICALLY_SUPPORTED" ~ 0,
      TRUE ~ NA_real_ # NA for NOT_TESTED
    ))
  
  p <- ggplot(hm_df, aes(x=variable, y=project_station_id, fill=val)) +
    geom_tile(color="white") +
    scale_fill_gradient2(low="blue", high="red", mid="white", midpoint=0, na.value="gray80", name="Support") +
    theme_minimal() + theme(axis.text.x = element_text(angle=45, hjust=1)) +
    labs(title=title, subtitle="Gray = Not Tested")
  ggsave(filename, p, width=8, height=6)
}

plot_hm(hyd_inf, "Hyderabad Supported Shifts", "analysis/phase3C/figures/05_hyd_support_heatmap.png")
plot_hm(ind_inf, "India Support Heatmap", "analysis/phase3C/figures/06_ind_support_heatmap.png")

# Case Study Update
# Deterministic rule: among VERIFIED_AQI / VERIFIED_POLLUTANT rows only, supported row with largest absolute drift_z
obs_df <- read_csv("data/analysis/phase3B/phase3B_current_window_observations_for_inference.csv", show_col_types = FALSE)

case_study <- inf_master %>%
  filter(
    test_performed == TRUE,
    statistical_support %in% c("SUPPORTED_UPWARD_SHIFT", "SUPPORTED_DOWNWARD_SHIFT"),
    variable_type %in% c("VERIFIED_AQI", "VERIFIED_SUBSET_AQI_INFERENCE", "VERIFIED_POLLUTANT_INFERENCE")
  ) %>%
  arrange(desc(abs(drift_z))) %>%
  head(1)

if(nrow(case_study) > 0) {
  c_obs <- obs_df %>% filter(project_station_id == case_study$project_station_id, variable == case_study$variable)
  p15 <- ggplot(c_obs, aes(x=value, fill=window_type)) + 
    geom_density(alpha=0.5) + 
    theme_minimal() + 
    labs(title=paste("Regulatory Case Study (Max Drift):", case_study$project_station_id, case_study$variable))
  ggsave("analysis/phase3C/figures/15_case_study_distributions.png", p15, width=8, height=6)
}
