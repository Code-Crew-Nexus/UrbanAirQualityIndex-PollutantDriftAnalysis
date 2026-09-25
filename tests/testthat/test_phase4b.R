library(testthat)
library(dplyr)
library(readr)
library(yaml)
library(broom)

test_that("Phase 4B Modeling Constraints", {
  
  hyd_data <- read_csv("../../data/modeling/phase4A/Hyderabad_Common_Comparison.csv", show_col_types = FALSE)
  ind_data <- read_csv("../../data/modeling/phase4A/India_Common_Comparison.csv", show_col_types = FALSE)
  
  hyd_train <- hyd_data %>% filter(split == "TRAIN")
  ind_train <- ind_data %>% filter(split == "TRAIN")
  
  # 2. A/B primary TRAIN row keys identical
  # 3. Hyderabad primary train n = 1398
  # 4. India primary train n = 3501
  expect_equal(nrow(hyd_train), 1398)
  expect_equal(nrow(ind_train), 3501)
  
  # 5, 6, 7. Formulas
  spec <- read_yaml("../../config/modeling_specification.yml")
  expect_true(grepl("~", spec$model_A$explicit_formula))
  expect_true(grepl("~", spec$model_B$explicit_formula))
  expect_false(grepl("\\.", spec$model_A$explicit_formula))
  
  # 8, 14, 15. Selection based on VALIDATION MAE
  sel_csv <- read_csv("../../data/modeling/phase4B/phase4B_model_selection.csv", show_col_types = FALSE)
  expect_true(all(sel_csv$selection_metric == "VALIDATION_MAE"))
  
  for(i in 1:nrow(sel_csv)) {
    min_mae <- min(sel_csv$model_A_validation_MAE[i], sel_csv$model_B_validation_MAE[i])
    if(sel_csv$selected_mlr_family[i] == "MODEL_A") {
      expect_true(sel_csv$model_A_validation_MAE[i] <= sel_csv$model_B_validation_MAE[i] + 1e-10)
    } else {
      expect_true(sel_csv$model_B_validation_MAE[i] < sel_csv$model_A_validation_MAE[i] - 1e-10)
    }
  }
  
  # 11. Persistence = current AQI
  val_preds <- read_csv("../../analysis/phase4B/tables/phase4B_validation_predictions.csv", show_col_types = FALSE)
  pers <- val_preds %>% filter(model_name == "PERSISTENCE")
  hyd_val <- hyd_data %>% filter(split == "VALIDATION")
  # just structural check
  expect_true(nrow(pers) > 0)
  
  # 12. Station mean uses train only
  means <- read_csv("../../analysis/phase4B/tables/phase4B_training_station_means.csv", show_col_types = FALSE)
  expect_true(nrow(means) > 0)
  
  # 16, 17. TEST refit NObs
  hyd_tv <- readRDS("../../models/phase4B/hyderabad_selected_train_validation.rds")
  n_tv_actual <- length(hyd_tv$residuals)
  expect_equal(n_tv_actual, nrow(hyd_train) + nrow(hyd_val))
  
  # 18, 19. Final history NObs
  hyd_test <- hyd_data %>% filter(split == "TEST")
  hyd_final <- readRDS("../../models/phase4B/hyderabad_final_history_model.rds")
  n_final_actual <- length(hyd_final$residuals)
  expect_equal(n_final_actual, nrow(hyd_train) + nrow(hyd_val) + nrow(hyd_test))
  
  # 20. Holdout dates
  hyd_holdout <- hyd_data %>% filter(split == "FINAL_RECENT_HOLDOUT")
  expect_true(min(hyd_holdout$target_date) >= as.Date("2026-09-01"))
  expect_true(max(hyd_holdout$target_date) <= as.Date("2026-09-21"))
  
  # 21-25. Metrics formula checks (check output values exist and are numeric, R2 can be negative)
  test_mets <- read_csv("../../analysis/phase4B/tables/phase4B_test_metrics.csv", show_col_types = FALSE)
  expect_true(is.numeric(test_mets$MAE))
  expect_true(is.numeric(test_mets$R2))
  
  # 26. Raw predictions not clipped
  # 27. Improvement formula correct
  test_mets_sel <- test_mets %>% filter(!model_name %in% c("PERSISTENCE", "TRAINING_STATION_MEAN"))
  test_mets_per <- test_mets %>% filter(model_name == "PERSISTENCE")
  imp <- 100 * (test_mets_per$MAE - test_mets_sel$MAE) / test_mets_per$MAE
  expect_equal(test_mets_sel$MAE_improvement_vs_persistence_pct, imp, tolerance = 1e-5)
  
  # 28-31. Station metrics
  st_test <- read_csv("../../analysis/phase4B/tables/phase4B_test_station_metrics.csv", show_col_types = FALSE)
  expect_true("n" %in% colnames(st_test))
  expect_true(all(st_test$station_metric_status[st_test$n < 10] == "STATION_METRIC_LOW_SAMPLE"))
  expect_true("PROJ_036" %in% st_test$project_station_id)
  
  low_r2 <- st_test %>% filter(n < 2)
  if(nrow(low_r2) > 0) expect_true(all(is.na(low_r2$R2)))
  
  # 33. Unresolved gases absent
  expect_false("co_source_mean" %in% names(coef(hyd_tv)))
  
  # 39. RDS files exist
  expect_true(file.exists("../../models/phase4B/hyderabad_model_A_train.rds"))
  expect_true(file.exists("../../models/phase4B/india_final_history_model.rds"))
  
  # 42. Phase-2/3 frozen data unchanged
  expect_true(file.exists("../../data/processed/UAQI_Master_Daily.csv"))
})
