source("R/00_setup.R")
source("R/01_utils.R")
library(dplyr)
library(readr)

# Load hourly data
files <- list.files("data/interim/hourly/historical", full.names = TRUE, pattern = "\\.csv$")
all_air <- do.call(rbind, lapply(files, read_csv, show_col_types = FALSE))

# We need to compute simple daily aggregations just to check the impact
# This is NOT the final AQI generator, just a quick audit.
all_air$date <- as.Date(all_air$timestamp_local)

daily_summary <- all_air %>%
  group_by(project_station_id, parameter, date) %>%
  summarize(
    # Note: we are just roughly aggregating the raw values for impact estimation.
    max_val = max(value_source, na.rm=TRUE),
    mean_val = mean(value_source, na.rm=TRUE),
    .groups = "drop"
  )

impact <- data.frame(
  pollutant = character(),
  severe_lower_bound = numeric(),
  candidate_days_exceeding = numeric(),
  maximum_observed_regulatory_input = numeric(),
  policy_impact = character(),
  stringsAsFactors = FALSE
)

# Severe lower bounds (canonical units)
severe_bounds <- list(
  "pm10" = 431,
  "pm2_5" = 251,
  "no2" = 401,
  "so2" = 1601,
  "co" = 34.1,
  "o3" = 749 # 1 hour
)

for (pol in names(severe_bounds)) {
  pol_data <- daily_summary %>% filter(parameter == pol)
  if (nrow(pol_data) == 0) next
  
  # Rough conversion just for impact estimation (ignoring rolling 8-hour complexities)
  if (pol == "co") {
    # If CO was reported as mg/m3 but OpenAQ says ppb, value_source is already mg/m3 scale.
    val <- pol_data$max_val
  } else if (pol == "no2") {
    val <- pol_data$mean_val * 1.88
  } else if (pol == "so2") {
    val <- pol_data$mean_val * 2.62
  } else if (pol == "o3") {
    val <- pol_data$max_val # o3 is already ug/m3
  } else {
    val <- pol_data$mean_val
  }
  
  bound <- severe_bounds[[pol]]
  exceed <- sum(val >= bound, na.rm=TRUE)
  max_obs <- max(val, na.rm=TRUE)
  
  impact_str <- if(exceed > 0) "Extrapolation Policy triggers frequently" else "Policy rarely/never triggers"
  
  impact <- rbind(impact, data.frame(
    pollutant = pol,
    severe_lower_bound = bound,
    candidate_days_exceeding = exceed,
    maximum_observed_regulatory_input = max_obs,
    policy_impact = impact_str,
    stringsAsFactors = FALSE
  ))
}

write_csv(impact, "data/metadata/phase2D2_severe_policy_impact.csv")
