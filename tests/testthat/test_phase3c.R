library(testthat)
library(dplyr)
library(readr)

test_that("Phase 3C.1 Inference Rules", {
  master_meta <- read_csv("../../data/processed/UAQI_Master_Daily.csv", show_col_types = FALSE)
  inf <- read_csv("../../data/analysis/phase3C/phase3C_current_drift_inference_results.csv", show_col_types = FALSE)
  
  # A. MASTER STRUCTURE
  expect_equal(nrow(inf), 147) # 1
  expect_equal(sum(inf$test_performed), 131) # 2
  expect_equal(sum(!inf$test_performed), 16) # 3
  
  st_table <- table(inf$statistical_support)
  expect_equal(sum(st_table), 147) # 4
  
  # B. HYDERABAD
  hyd <- read_csv("../../data/analysis/phase3C/phase3C_hyderabad_inference.csv", show_col_types = FALSE)
  meta_hyd_ids <- master_meta %>% filter(use_hyderabad == TRUE) %>% pull(project_station_id) %>% unique() %>% sort()
  
  expect_equal(nrow(hyd), 49) # 5
  expect_equal(length(unique(hyd$project_station_id)), 7) # 6
  expect_equal(sort(unique(hyd$project_station_id)), meta_hyd_ids) # 7
  
  if(!("PROJ_002" %in% meta_hyd_ids)) {
    expect_false("PROJ_002" %in% hyd$project_station_id) # 8
  }
  
  var_counts <- hyd %>% group_by(project_station_id) %>% summarize(n=n(), .groups="drop")
  expect_true(all(var_counts$n == 7)) # 9
  
  # C. INDIA
  ind <- read_csv("../../data/analysis/phase3C/phase3C_india_inference.csv", show_col_types = FALSE)
  meta_ind_ids <- master_meta %>% filter(use_india == TRUE) %>% pull(project_station_id) %>% unique() %>% sort()
  
  expect_equal(nrow(ind), 105) # 10
  expect_equal(length(unique(ind$project_station_id)), 15) # 11
  expect_equal(sort(unique(ind$project_station_id)), meta_ind_ids) # 12
  expect_true("PROJ_007" %in% ind$project_station_id) # 13
  
  # D. INELIGIBLE TESTS
  ineligible <- inf %>% filter(!test_performed)
  if(nrow(ineligible) > 0) {
    expect_true(all(is.na(ineligible$p_block7_raw))) # 14
    expect_true(all(is.na(ineligible$welch_p_raw))) # 15
    expect_true(all(is.na(ineligible$wilcox_p_raw))) # 16
    expect_true(all(ineligible$statistical_support == "NOT_TESTED_INSUFFICIENT_DATA")) # 17
  }
  
  # E. PRIMARY SUPPORT
  upward <- inf %>% filter(statistical_support == "SUPPORTED_UPWARD_SHIFT")
  if(nrow(upward) > 0) {
    expect_true(all(upward$p_block7_bh_global < 0.05)) # 18
    expect_true(all(upward$block7_ci_low > 0)) # 19
    expect_true(all(upward$mean_difference > 0)) # 20
  }
  
  downward <- inf %>% filter(statistical_support == "SUPPORTED_DOWNWARD_SHIFT")
  if(nrow(downward) > 0) {
    expect_true(all(downward$p_block7_bh_global < 0.05)) # 21
    expect_true(all(downward$block7_ci_high < 0)) # 22
    expect_true(all(downward$mean_difference < 0)) # 23
  }
  
  # F. EFFECT SIZE
  valid_es <- inf %>% filter(test_performed, !is.na(hedges_g), !is.na(mean_difference), hedges_g != 0, mean_difference != 0)
  if(nrow(valid_es) > 0) {
    expect_true(all(sign(valid_es$hedges_g) == sign(valid_es$mean_difference))) # 24
  }
  
  valid_cliffs <- inf %>% filter(test_performed, !is.na(cliffs_delta))
  if(nrow(valid_cliffs) > 0) {
    expect_true(all(valid_cliffs$cliffs_delta >= -1 & valid_cliffs$cliffs_delta <= 1)) # 25
  }
  
  # G. BH
  eligible <- inf %>% filter(test_performed)
  recalc_global <- p.adjust(eligible$p_block7_raw, method="BH")
  expect_equal(eligible$p_block7_bh_global, recalc_global, tolerance = 1e-5) # 26
  
  var_groups <- eligible %>% group_by(variable) %>% mutate(re_bh = p.adjust(p_block7_raw, method="BH")) %>% pull(re_bh)
  # Arrange matches the same so we can just compare properly by doing a join or group_by on original
  # Since it's group_by we can check exact match
  chk_var_bh <- eligible %>% group_by(variable) %>% mutate(re_bh = p.adjust(p_block7_raw, method="BH")) %>% ungroup()
  expect_equal(chk_var_bh$p_block7_bh_within_variable, chk_var_bh$re_bh, tolerance=1e-5) # 27
  
  # H. BOOTSTRAP
  expect_true(all(eligible$p_block7_raw >= 0 & eligible$p_block7_raw <= 1)) # 28
  expect_true(all(eligible$block7_ci_low <= eligible$block7_ci_high)) # 29
  expect_equal(eligible$block7_mean_diff, eligible$recent_mean - eligible$baseline_mean, tolerance=1e-5) # 30
  
  # I. SOURCE SEMANTICS
  gases <- inf %>% filter(variable_type == "SOURCE_SCALE_GAS")
  expect_true(all(gases$physical_unit_verified == FALSE)) # 31
  verified <- inf %>% filter(variable_type != "SOURCE_SCALE_GAS")
  expect_true(all(verified$physical_unit_verified == TRUE)) # 32
  
  # J. SPECIAL TABLES
  sup_tb <- read_csv("../../data/analysis/phase3C/phase3C_supported_shifts.csv", show_col_types = FALSE)
  if(nrow(sup_tb) > 0) {
    master_sup <- inf %>% filter(statistical_support %in% c("SUPPORTED_UPWARD_SHIFT", "SUPPORTED_DOWNWARD_SHIFT"))
    expect_true(all(sup_tb$project_station_id %in% master_sup$project_station_id)) # 33
  }
  
  unc_tb <- read_csv("../../data/analysis/phase3C/phase3C_large_but_uncertain_drifts.csv", show_col_types = FALSE)
  if(nrow(unc_tb) > 0) {
    expect_true(all(unc_tb$statistical_support == "NOT_STATISTICALLY_SUPPORTED" & abs(unc_tb$drift_z) >= 1)) # 34
  }
  
  small_tb <- read_csv("../../data/analysis/phase3C/phase3C_small_but_supported_shifts.csv", show_col_types = FALSE)
  if(nrow(small_tb) > 0) {
    expect_true(all(abs(small_tb$hedges_g) < 0.5 | abs(small_tb$drift_z) < 0.5)) # 35
  } else {
    expect_equal(nrow(small_tb), 0) # Fallback pass replaced
  }
  
  # K. ROBUSTNESS
  all_agree <- inf %>% filter(robustness_agreement == "ALL_METHODS_AGREE", !is.na(hedges_g), !is.na(cliffs_delta))
  if(nrow(all_agree) > 0) {
    expect_true(all(sign(all_agree$mean_difference) == sign(all_agree$hedges_g) & sign(all_agree$mean_difference) == sign(all_agree$cliffs_delta))) # 36
  }
  
  valid_labels <- c("ALL_METHODS_AGREE", "BLOCK_AND_WELCH", "BLOCK_AND_WILCOX", "BLOCK_ONLY", "CLASSICAL_ONLY", "NO_METHOD_SUPPORT", "MIXED_DIRECTION_OR_RESULT", "NOT_TESTED_INSUFFICIENT_DATA")
  expect_true(all(inf$robustness_agreement %in% valid_labels)) # 37
  
  # L. FREEZE
  expect_equal(nrow(master_meta), 11970) # 38
  p3b_win <- read_csv("../../data/analysis/phase3B/phase3B_current_window_summary_for_inference.csv", show_col_types = FALSE)
  expect_equal(nrow(p3b_win), 147) # 39
})
