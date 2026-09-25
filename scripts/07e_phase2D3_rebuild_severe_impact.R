source("R/00_setup.R")
library(dplyr)
library(readr)
source("R/24_aqi_calculation.R")

# Re-run severe policy impact using the locked sensor semantics
files <- list.files("data/interim/hourly/historical", full.names=TRUE, pattern="\\.csv$")
all_air <- do.call(rbind, lapply(files, read_csv, show_col_types=FALSE))

# Load semantic table
sem <- read_csv("data/metadata/phase2D3_sensor_semantic_units.csv", show_col_types = FALSE)

# Convert all values to canonical units
# mapply will be slow for 1.4M rows.
# Let's vectorize it safely.

semantics <- read_csv("data/metadata/phase2D3_sensor_semantic_units.csv", show_col_types = FALSE)
factors <- read.csv("config/gas_conversion_factors_india.csv", stringsAsFactors = FALSE)

# create a lookup table
lookup <- semantics %>% 
  left_join(factors, by=c("pollutant", "verified_semantic_unit" = "source_unit")) %>%
  mutate(conv_factor = ifelse(verified_semantic_unit == canonical_target_unit, 1, conversion_factor)) %>%
  select(sensor_id, conv_factor, verification_status = verification_status.x)

all_air <- all_air %>%
  left_join(lookup, by="sensor_id") %>%
  mutate(
    canonical_value = ifelse(
      verification_status == "VERIFIED" & value_source >= 0,
      value_source * conv_factor,
      NA
    )
  )

severe_bounds <- data.frame(
  pollutant = c("pm10", "pm2_5", "no2", "so2", "co", "o3"),
  severe_lower_bound = c(431, 251, 401, 1601, 34.1, 749)
)

impact <- all_air %>%
  rename(pollutant = parameter) %>%
  left_join(severe_bounds, by="pollutant") %>%
  group_by(pollutant) %>%
  summarize(
    candidate_days_exceeding = sum(canonical_value > severe_lower_bound, na.rm=TRUE),
    maximum_observed_regulatory_input = suppressWarnings(max(canonical_value, na.rm=TRUE))
  ) %>%
  mutate(
    maximum_observed_regulatory_input = ifelse(is.infinite(maximum_observed_regulatory_input), NA, maximum_observed_regulatory_input),
    policy_impact = ifelse(candidate_days_exceeding > 0, "Extrapolation Policy triggers frequently", "Policy rarely/never triggers")
  )

write_csv(impact, "data/metadata/phase2D3_severe_policy_impact.csv")
