library(testthat)
library(dplyr)
library(readr)
library(yaml)

test_that("Phase 4A Design Constraints", {
  # 1. Phase 2 unchanged
  expect_true(file.exists("../../data/processed/UAQI_Master_Daily.csv"))
  p2 <- read_csv("../../data/processed/UAQI_Master_Daily.csv", show_col_types = FALSE)
  expect_equal(nrow(p2), 11970)
  
  # 2. Phase 3 unchanged
  expect_true(file.exists("../../data/analysis/phase3C/phase3C_current_drift_inference_results.csv"))
  p3 <- read_csv("../../data/analysis/phase3C/phase3C_current_drift_inference_results.csv", show_col_types = FALSE)
  expect_equal(nrow(p3), 147)
  
  master <- read_csv("../../data/modeling/phase4A/NextDay_AQI_Modeling_Design_Master.csv", show_col_types = FALSE)
  
  # 3. target_date = date + 1
  expect_true(all(master$target_date == master$date + 1))
  
  # 4. Exact next-day station target alignment
  check_target <- master %>% filter(!is.na(target_aqi_next_day))
  p2_lookup <- p2 %>% select(project_station_id, date, aqi_verified)
  joined <- check_target %>% inner_join(p2_lookup, by=c("project_station_id"="project_station_id", "target_date"="date"))
  expect_true(all(joined$target_aqi_next_day == joined$aqi_verified.y))
  
  # 5. Sept 21 rows have no target
  sep21 <- master %>% filter(date == as.Date("2026-09-21"))
  expect_true(all(is.na(sep21$target_aqi_next_day)))
  
  # 6-10. exact split dates
  train <- master %>% filter(split == "TRAIN")
  expect_true(min(train$target_date) >= as.Date("2025-03-02") && max(train$target_date) <= as.Date("2025-12-31"))
  val <- master %>% filter(split == "VALIDATION")
  expect_true(min(val$target_date) >= as.Date("2026-01-01") && max(val$target_date) <= as.Date("2026-04-30"))
  test <- master %>% filter(split == "TEST")
  expect_true(min(test$target_date) >= as.Date("2026-05-01") && max(test$target_date) <= as.Date("2026-08-31"))
  holdout <- master %>% filter(split == "FINAL_RECENT_HOLDOUT")
  expect_true(min(holdout$target_date) >= as.Date("2026-09-01") && max(holdout$target_date) <= as.Date("2026-09-21"))
  
  # 11. no target-date overlap
  expect_true(max(train$target_date) < min(val$target_date))
  expect_true(max(val$target_date) < min(test$target_date))
  expect_true(max(test$target_date) < min(holdout$target_date))
  
  # 12. no random split
  script <- readLines("../../scripts/13_phase4A_prediction_design.R")
  expect_false(any(grepl("sample\\(|createDataPartition|randomSplit|initial_split", script)))
  
  # 13-18. Predictor contracts
  model_a <- read_csv("../../data/modeling/phase4A/Hyderabad_Model_A.csv", show_col_types = FALSE)
  model_b <- read_csv("../../data/modeling/phase4A/Hyderabad_Model_B.csv", show_col_types = FALSE)
  req_a_cols <- c("pm2_5_aqi_input", "pm10_aqi_input", "o3_8h_max", "temperature", "humidity", "wind_speed", "sin_wind_direction", "cos_wind_direction", "day_of_week", "month_sin", "month_cos", "project_station_id")
  expect_true(all(req_a_cols %in% colnames(model_a)))
  
  expect_true("aqi_verified" %in% colnames(model_b))
  expect_false("co_source_mean" %in% colnames(master))
  expect_false("pm2_5_subindex" %in% colnames(master))
  expect_false("aqi_verified" %in% req_a_cols)
  expect_false(any(grepl("p_block7", colnames(master))))
  
  # 19. wind direction sin/cos
  expect_true("sin_wind_direction" %in% colnames(master))
  expect_true("cos_wind_direction" %in% colnames(master))
  
  # 20. eligible A satisfy all via master row key membership
  keys_a <- model_a %>% select(project_station_id, target_date)
  joined_a <- keys_a %>% inner_join(master, by=c("project_station_id", "target_date"))
  expect_true(all(joined_a$eligible_model_A == TRUE))
  expect_true(all(joined_a$use_hyderabad == TRUE))
  
  # 21. eligible B satisfy all via master row key membership
  keys_b <- model_b %>% select(project_station_id, target_date)
  joined_b <- keys_b %>% inner_join(master, by=c("project_station_id", "target_date"))
  expect_true(all(joined_b$eligible_model_B == TRUE))
  expect_true(all(joined_b$use_hyderabad == TRUE))
  
  # 22-23. common comparison via master row key membership
  common <- read_csv("../../data/modeling/phase4A/Hyderabad_Common_Comparison.csv", show_col_types = FALSE)
  keys_c <- common %>% select(project_station_id, target_date)
  joined_c <- keys_c %>% inner_join(master, by=c("project_station_id", "target_date"))
  expect_true(all(joined_c$common_comparison_eligible == TRUE))
  expect_true(all(joined_c$eligible_model_A & joined_c$eligible_model_B & !is.na(joined_c$aqi_verified)))
  
  # 24-25. Scope station counts
  hyd <- read_csv("../../data/modeling/phase4A/Hyderabad_Model_A.csv", show_col_types = FALSE)
  ind <- read_csv("../../data/modeling/phase4A/India_Model_A.csv", show_col_types = FALSE)
  expect_equal(length(unique(hyd$project_station_id)), 7)
  expect_equal(length(unique(ind$project_station_id)), 15)
  
  # 26. Evaluate stations in training
  h_train <- hyd %>% filter(split == "TRAIN") %>% pull(project_station_id) %>% unique()
  expect_equal(sort(h_train), sort(unique(hyd$project_station_id)))
  
  i_train <- ind %>% filter(split == "TRAIN") %>% pull(project_station_id) %>% unique()
  expect_equal(sort(i_train), sort(unique(ind$project_station_id)))
  
  # 27. no future data
  expect_true(all(master$target_date > master$date))
  
  # 28. no imputation 
  expect_false(any(grepl("na\\.aggregate|impute|na\\.locf", script)))
  
  # 29. holdout not used for fitting
  expect_false(any(grepl("lm\\(|train\\(", script)))
  
  # 30. Adverse
  valid_adv <- master %>% filter(!is.na(target_aqi_next_day))
  expect_true(all(valid_adv$target_adverse_next_day == (valid_adv$target_aqi_next_day > 100)))
  
  # 31. YAML parses
  yml <- read_yaml("../../config/modeling_specification.yml")
  expect_true(yml$random_split_allowed == FALSE)
  
  # 32. no duplicate station-date
  counts <- master %>% count(project_station_id, date)
  expect_true(all(counts$n == 1))
})
