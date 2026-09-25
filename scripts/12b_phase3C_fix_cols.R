library(dplyr)
library(readr)

master_res <- read_csv("data/analysis/phase3C/phase3C_current_drift_inference_results.csv", show_col_types = FALSE)
snap <- read_csv("data/analysis/phase3B/phase3B_current_drift_snapshot.csv", show_col_types = FALSE)

master_res <- master_res %>%
  left_join(snap %>% select(project_station_id, variable, city, drift_direction, drift_magnitude_class), by=c("project_station_id", "variable")) %>%
  mutate(median_difference = recent_median - baseline_median)

write_csv(master_res, "data/analysis/phase3C/phase3C_current_drift_inference_results.csv")

supported <- master_res %>% filter(statistical_support %in% c("SUPPORTED_UPWARD_SHIFT", "SUPPORTED_DOWNWARD_SHIFT")) %>%
  select(project_station_id, station_name, variable, drift_z, mean_difference, hedges_g, cliffs_delta, p_block7_bh_global, block7_ci_low, block7_ci_high)
write_csv(supported, "data/analysis/phase3C/phase3C_supported_shifts.csv")

small_sup <- supported %>% filter(abs(hedges_g) < 0.5 | abs(drift_z) < 0.5)
write_csv(small_sup, "data/analysis/phase3C/phase3C_small_but_supported_shifts.csv")

large_unc <- master_res %>% filter(abs(drift_z) >= 1, statistical_support == "NOT_STATISTICALLY_SUPPORTED")
write_csv(large_unc, "data/analysis/phase3C/phase3C_large_but_uncertain_drifts.csv")
