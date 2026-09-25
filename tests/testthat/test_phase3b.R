library(testthat)
library(dplyr)
library(readr)

test_that("Phase 3B.1 Drift Rules", {
  master <- read_csv("../../data/processed/UAQI_Master_Daily.csv", show_col_types = FALSE)
  expect_equal(nrow(master), 11970) # 21
  
  long_drift <- read_csv("../../data/analysis/phase3B/phase3B_daily_drift_metrics.csv", show_col_types = FALSE)
  
  ineligible <- long_drift %>% filter(drift_eligible == FALSE)
  eligible <- long_drift %>% filter(drift_eligible == TRUE)
  
  expect_true(all(is.na(ineligible$drift_z))) # 1
  expect_true(all(is.na(ineligible$drift_direction))) # 2
  expect_true(all(is.na(ineligible$drift_magnitude_class))) # 3
  
  expect_true(all(is.finite(eligible$drift_z))) # 4
  
  calc <- eligible %>% mutate(calc_z = (recent_mean - baseline_mean) / baseline_sd)
  expect_equal(calc$drift_z, calc$calc_z) # 5
  
  snap <- read_csv("../../data/analysis/phase3B/phase3B_current_drift_snapshot.csv", show_col_types = FALSE)
  expect_equal(nrow(snap), 147) # 6
  
  snap_ineligible <- snap %>% filter(drift_eligible == FALSE)
  if(nrow(snap_ineligible) > 0) {
    expect_true(all(is.na(snap_ineligible$drift_z))) # 7
  }
  
  mon_drift <- read_csv("../../data/analysis/phase3B/phase3B_station_month_drift_summary.csv", show_col_types = FALSE)
  
  # 8, 9, 10, 11
  expect_true(all(mon_drift$days_MINIMAL <= mon_drift$eligible_days))
  expect_true(all(mon_drift$days_MILD <= mon_drift$eligible_days))
  expect_true(all(mon_drift$days_MODERATE <= mon_drift$eligible_days))
  expect_true(all(mon_drift$days_STRONG <= mon_drift$eligible_days))
  
  # The sums should equal eligible days
  expect_equal(mon_drift$days_MINIMAL + mon_drift$days_MILD + mon_drift$days_MODERATE + mon_drift$days_STRONG, mon_drift$eligible_days)
  
  expect_true(all(mon_drift$days_upward <= mon_drift$eligible_days))
  expect_true(all(mon_drift$days_downward <= mon_drift$eligible_days))
  expect_true(all(mon_drift$days_stable <= mon_drift$eligible_days))
  expect_equal(mon_drift$days_upward + mon_drift$days_downward + mon_drift$days_stable, mon_drift$eligible_days)
  
  inf <- read_csv("../../data/analysis/phase3B/phase3B_current_window_summary_for_inference.csv", show_col_types = FALSE)
  expect_equal(nrow(inf), 147) # 13
  expect_true("test_eligible" %in% names(inf)) # 14
  
  inf_ineligible <- inf %>% filter(test_eligible == FALSE)
  if(nrow(inf_ineligible) > 0) {
    expect_true(all(is.na(inf_ineligible$drift_z))) # 15
  }
  
  # 16, 17
  raw_inf <- read_csv("../../data/analysis/phase3B/phase3B_current_window_observations_for_inference.csv", show_col_types = FALSE)
  baseline_dates <- raw_inf %>% filter(window_type == "BASELINE") %>% pull(observation_date)
  recent_dates <- raw_inf %>% filter(window_type == "RECENT") %>% pull(observation_date)
  
  expect_true(min(baseline_dates) == as.Date("2026-05-25") && max(baseline_dates) == as.Date("2026-08-22"))
  expect_true(min(recent_dates) == as.Date("2026-08-23") && max(recent_dates) == as.Date("2026-09-21"))
  
  # For eligible windows, check if numeric observation count meets 63/21
  valid_counts <- raw_inf %>% filter(test_eligible == TRUE, !is.na(value)) %>%
    group_by(project_station_id, variable, window_type) %>% summarize(n = n(), .groups="drop")
  
  expect_true(all(valid_counts %>% filter(window_type == "BASELINE") %>% pull(n) >= 63))
  expect_true(all(valid_counts %>% filter(window_type == "RECENT") %>% pull(n) >= 21))
  
  # 18
  expect_true(all(long_drift %>% filter(grepl("co_|no2_|so2_", variable)) %>% pull(variable_type) == "SOURCE_SCALE_GAS"))
  
  # 19
  expect_false(any(grepl("p_value|pvalue|sig", names(long_drift))))
  
  # 22. post-history coverage
  cov_sum <- read_csv("../../analysis/phase3B/tables/phase3B_drift_coverage_summary.csv", show_col_types=FALSE)
  expect_true("post_history_possible_days" %in% names(cov_sum))
})
