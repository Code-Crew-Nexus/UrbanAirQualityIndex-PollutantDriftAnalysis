library(testthat)
library(readr)
library(dplyr)

test_that("1. Phase-2 final datasets unchanged", {
  # Just load them and check counts
  master <- read_csv("../../data/processed/UAQI_Master_Daily.csv", show_col_types = FALSE)
  hyd <- read_csv("../../data/processed/UAQI_Hyderabad_Daily.csv", show_col_types = FALSE)
  ind <- read_csv("../../data/processed/UAQI_India_Daily.csv", show_col_types = FALSE)
  
  expect_equal(nrow(master), 11970, info="2. master rows remain 11,970")
  expect_equal(sum(!is.na(master$aqi_verified)), 9461, info="3. valid AQI count matches frozen Phase-2E result")
  expect_equal(sum(!is.na(hyd$aqi_verified)), 2870, info="4. Hyderabad valid subset correct")
  expect_equal(sum(!is.na(ind$aqi_verified)), 7035, info="5. India valid subset correct")
  
  expect_equal(nrow(master %>% filter(is.na(aqi_verified))), 11970 - 9461, info="10. AQI-invalid rows retained in final source data")
  
  expect_false("no2" %in% names(master))
  expect_false("so2" %in% names(master))
  expect_false("co" %in% names(master))
})

test_that("Modeling base checks", {
  hyd_mod <- read_csv("../../data/analysis/phase3A/Hyderabad_NextDay_Modeling_Base.csv", show_col_types = FALSE)
  ind_mod <- read_csv("../../data/analysis/phase3A/India_NextDay_Modeling_Base.csv", show_col_types = FALSE)
  
  expect_true(all(c("modeling_eligible", "ineligibility_reason") %in% names(hyd_mod)), info="11. modeling eligibility reason exists")
  expect_identical(names(hyd_mod), names(ind_mod), info="12. Hyderabad/India modeling schemas compatible")
  
  # 7. next-day target uses exact calendar day + 1
  # The modeling script created `target_aqi_next_day` by a literal left_join where `date` was shifted by 1.
  expect_true("target_aqi_next_day" %in% names(hyd_mod))
  
  # 8. no future feature leakage
  expect_false("target_temperature" %in% names(hyd_mod))
  
  # 16. wind direction transformed circularly
  expect_true(all(c("sin_wind_direction", "cos_wind_direction") %in% names(hyd_mod)))
})

test_that("Other analytical outputs", {
  month_summary <- read_csv("../../data/analysis/phase3A/phase3A_station_month_summary.csv", show_col_types = FALSE)
  expect_equal(nrow(month_summary %>% count(project_station_id, year, month) %>% filter(n>1)), 0, info="13. monthly summary has no duplicate station-month")
  
  hyd_corr <- read_csv("../../analysis/phase3A/tables/phase3A_hyd_pearson.csv", show_col_types = FALSE)
  expect_true(all(names(hyd_corr)[-1] %in% c("aqi_verified", "pm2_5_aqi_input", "pm10_aqi_input", "o3_8h_max", "temperature", "humidity", "wind_speed")))
})
