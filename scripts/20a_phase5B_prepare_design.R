# scripts/20a_phase5B_prepare_design.R
# Phase 5B: Prepare Clean-Clone Next-Day Adverse-AQI Design Master and Prevalence Table

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})

cat(">>> Running scripts/20a_phase5B_prepare_design.R...\n")

# 1. Load frozen Master Daily dataset
master_path <- "data/processed/UAQI_Master_Daily.csv"
if (!file.exists(master_path)) {
  stop("FATAL: Required source data missing: ", master_path)
}
master_df <- read_csv(master_path, show_col_types = FALSE)
cat("Loaded master daily observations:", nrow(master_df), "rows\n")

# 2. Derive Predictors and Target
design_df <- master_df %>%
  arrange(project_station_id, date) %>%
  mutate(
    date = as.Date(date),
    target_date = date + 1,
    sin_wind_direction = sin(wind_direction * pi / 180),
    cos_wind_direction = cos(wind_direction * pi / 180),
    month_number = as.numeric(format(date, "%m")),
    month_sin = sin(2 * pi * month_number / 12),
    month_cos = cos(2 * pi * month_number / 12)
  )

# Next-day AQI strictly from the same station
target_lookup <- master_df %>%
  mutate(target_date = as.Date(date)) %>%
  select(project_station_id, target_date, target_aqi_next_day = aqi_verified)

design_df <- design_df %>%
  left_join(target_lookup, by = c("project_station_id", "target_date")) %>%
  mutate(
    target_aqi_next_day = if_else(target_date > as.Date("2026-09-21"), NA_real_, target_aqi_next_day),
    target_adverse_next_day = if_else(!is.na(target_aqi_next_day), if_else(target_aqi_next_day > 100, 1, 0), NA_real_),
    split = case_when(
      target_date >= as.Date("2025-03-02") & target_date <= as.Date("2025-12-31") ~ "TRAIN",
      target_date >= as.Date("2026-01-01") & target_date <= as.Date("2026-04-30") ~ "VALIDATION",
      target_date >= as.Date("2026-05-01") & target_date <= as.Date("2026-08-31") ~ "TEST",
      target_date >= as.Date("2026-09-01") & target_date <= as.Date("2026-09-21") ~ "FINAL_RECENT_HOLDOUT",
      TRUE ~ "OUT_OF_RANGE"
    ),
    eligible_svm = !is.na(target_adverse_next_day) &
      !is.na(pm2_5_aqi_input) & !is.na(pm10_aqi_input) & !is.na(o3_8h_max) &
      !is.na(temperature) & !is.na(humidity) & !is.na(wind_speed) &
      !is.na(sin_wind_direction) & !is.na(cos_wind_direction) &
      !is.na(day_of_week) & !is.na(month_sin) & !is.na(month_cos) &
      !is.na(project_station_id) & !is.na(aqi_verified)
  )

# 3. Sanity verification of expected sample counts
expected_counts <- list(
  HYDERABAD = list(
    TRAIN = c(n = 1398, pos = 269),
    VALIDATION = c(n = 498, pos = 66),
    TEST = c(n = 477, pos = 11),
    FINAL_RECENT_HOLDOUT = c(n = 111, pos = 0)
  ),
  INDIA = list(
    TRAIN = c(n = 3501, pos = 1553),
    VALIDATION = c(n = 1302, pos = 828),
    TEST = c(n = 1389, pos = 294),
    FINAL_RECENT_HOLDOUT = c(n = 238, pos = 22)
  )
)

for (sc in c("HYDERABAD", "INDIA")) {
  use_col <- if (sc == "HYDERABAD") "use_hyderabad" else "use_india"
  sc_df <- design_df %>% filter(.data[[use_col]] == TRUE, eligible_svm, split != "OUT_OF_RANGE")
  for (sp in names(expected_counts[[sc]])) {
    sub_df <- sc_df %>% filter(split == sp)
    actual_n <- nrow(sub_df)
    actual_pos <- sum(sub_df$target_adverse_next_day == 1)
    exp_n <- expected_counts[[sc]][[sp]]["n"]
    exp_pos <- expected_counts[[sc]][[sp]]["pos"]
    
    if (actual_n != exp_n || actual_pos != exp_pos) {
      stop(sprintf("FATAL: Sample count mismatch in %s %s: got n=%d (exp %d), pos=%d (exp %d)",
                   sc, sp, actual_n, exp_n, actual_pos, exp_pos))
    }
  }
}
cat("[OK] Sample counts verified exactly against Section 12 requirements.\n")

# 4. Save design master dataset
dir.create("data/analysis/phase5B", recursive = TRUE, showWarnings = FALSE)
design_out_path <- "data/analysis/phase5B/phase5B_design_master.csv"
write_csv(design_df, design_out_path)
cat("Saved design master to:", design_out_path, "(", nrow(design_df), "rows )\n")

# 5. Build and save prevalence summary table
dir.create("analysis/phase5B/tables", recursive = TRUE, showWarnings = FALSE)
prevalence_records <- list()

for (sc in c("HYDERABAD", "INDIA")) {
  use_col <- if (sc == "HYDERABAD") "use_hyderabad" else "use_india"
  sc_df <- design_df %>% filter(.data[[use_col]] == TRUE, eligible_svm, split != "OUT_OF_RANGE")
  
  splits_ordered <- c("TRAIN", "VALIDATION", "TEST", "FINAL_RECENT_HOLDOUT")
  for (sp in splits_ordered) {
    sub_df <- sc_df %>% filter(split == sp)
    n_total <- nrow(sub_df)
    pos_n <- sum(sub_df$target_adverse_next_day == 1)
    neg_n <- n_total - pos_n
    pos_rate <- if (n_total > 0) pos_n / n_total else NA_real_
    
    prevalence_records[[length(prevalence_records) + 1]] <- data.frame(
      scope = sc,
      split = sp,
      n = n_total,
      positive_n = pos_n,
      negative_n = neg_n,
      positive_rate = pos_rate,
      stringsAsFactors = FALSE
    )
  }
}

prevalence_df <- bind_rows(prevalence_records)
prev_path <- "analysis/phase5B/tables/phase5B_prevalence_by_split.csv"
write_csv(prevalence_df, prev_path)
cat("Saved prevalence summary table to:", prev_path, "\n")
print(prevalence_df)

cat(">>> scripts/20a_phase5B_prepare_design.R completed successfully.\n")
