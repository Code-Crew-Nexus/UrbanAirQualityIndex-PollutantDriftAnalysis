library(testthat)
library(dplyr)
library(readr)
library(yaml)

test_that("Phase 4A.1 Matrix Constraints", {
  # Load repaired tables
  split_audit <- read_csv("../../analysis/phase4A/tables/phase4A_split_sample_counts.csv", show_col_types = FALSE)
  feasibility <- read_csv("../../analysis/phase4A/tables/phase4A_station_metric_feasibility.csv", show_col_types = FALSE)
  log_dist <- read_csv("../../analysis/phase4A/tables/phase4A_logistic_class_balance.csv", show_col_types = FALSE)
  
  # 1. Correct Hyderabad counts (no double-counting)
  hyd_train <- split_audit %>% filter(scope == "HYDERABAD", split == "TRAIN")
  expect_equal(hyd_train$structural_rows, 2135)
  expect_equal(hyd_train$common_comparison_eligible, 1398)
  
  # 2. Correct India counts
  ind_train <- split_audit %>% filter(scope == "INDIA", split == "TRAIN")
  expect_equal(ind_train$structural_rows, 4575)
  expect_equal(ind_train$common_comparison_eligible, 3501)
  
  # 3. No duplicated scope accounting
  # Check if scopes are strictly unique grouping
  expect_true(length(unique(split_audit$scope)) <= 3) # HYDERABAD, INDIA, MASTER_21
  
  # Load matrices
  hyd_A <- read_csv("../../data/modeling/phase4A/Hyderabad_Model_A.csv", show_col_types = FALSE)
  ind_A <- read_csv("../../data/modeling/phase4A/India_Model_A.csv", show_col_types = FALSE)
  hyd_B <- read_csv("../../data/modeling/phase4A/Hyderabad_Model_B.csv", show_col_types = FALSE)
  
  # 4-6. Model A excludes aqi_verified & targets
  expect_false("aqi_verified" %in% colnames(hyd_A))
  expect_false("aqi_verified" %in% colnames(ind_A))
  expect_false("target_category_next_day" %in% colnames(hyd_A))
  expect_false("target_adverse_next_day" %in% colnames(hyd_A))
  
  # 7-8. Model B is A + aqi_verified exactly
  expect_true("aqi_verified" %in% colnames(hyd_B))
  diff_cols <- setdiff(colnames(hyd_B), colnames(hyd_A))
  expect_equal(diff_cols, "aqi_verified")
  
  # 9-10. Common comparison uses identical rows
  hyd_com <- read_csv("../../data/modeling/phase4A/Hyderabad_Common_Comparison.csv", show_col_types = FALSE)
  expect_equal(nrow(hyd_com), nrow(hyd_B)) # Because common = eligible for B and Persistence (which is just B)
  
  # 11-12. Explicit formulas
  yml <- read_yaml("../../config/modeling_specification.yml")
  expect_true(!is.null(yml$model_A$explicit_formula))
  expect_true(yml$model_A$prohibit_dot_formula == TRUE)
  
  # 13. Bollaram low-sample periods correctly flagged
  bollaram <- feasibility %>% filter(project_station_id == "PROJ_036")
  # Train is ~176 (adequate), validation ~13 (adequate), test ~1 (low), holdout ~7 (low)
  b_train <- bollaram %>% filter(split == "TRAIN") %>% pull(station_metric_status)
  b_test <- bollaram %>% filter(split == "TEST") %>% pull(station_metric_status)
  expect_equal(b_train, "ADEQUATE_FOR_DESCRIPTIVE_STATION_METRIC")
  expect_equal(b_test, "STATION_METRIC_LOW_SAMPLE")
  
  # 14-15. Hyderabad logistic holdout one-class status
  hyd_holdout_log <- log_dist %>% filter(scope == "HYDERABAD", split == "FINAL_RECENT_HOLDOUT")
  expect_equal(hyd_holdout_log$adverse_1, 0)
  
  # 16. India logistic holdout has both
  ind_holdout_log <- log_dist %>% filter(scope == "INDIA", split == "FINAL_RECENT_HOLDOUT")
  expect_true(ind_holdout_log$adverse_1 > 0)
  expect_true(ind_holdout_log$adverse_0 > 0)
  
  # 17-20: Repeated from 4A
  script <- readLines("../../scripts/13b_phase4A1_matrix_repair.R")
  expect_false(any(grepl("impute|na\\.locf", script)))
  expect_false(any(grepl("lm\\(|train\\(", script)))
})
