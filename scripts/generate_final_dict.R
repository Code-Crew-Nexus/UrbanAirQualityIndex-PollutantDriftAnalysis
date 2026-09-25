library(readr)
library(dplyr)

# Final Data Dictionary
dict <- tibble::tribble(
  ~column_name, ~data_type, ~unit, ~description, ~source, ~derived_or_observed, ~aqi_policy_relevance, ~limitations,
  "project_station_id", "character", "NA", "Unique project identifier for the station", "Project", "derived", "NA", "NA",
  "date", "date", "NA", "Local calendar date", "Project", "derived", "NA", "NA",
  "source_location_id", "numeric", "NA", "Original OpenAQ location ID", "OpenAQ", "observed", "NA", "NA",
  "station_name", "character", "NA", "Name of the monitoring station", "OpenAQ", "observed", "NA", "NA",
  "city", "character", "NA", "City where the station is located", "OpenAQ", "observed", "NA", "NA",
  "state", "character", "NA", "State where the station is located", "OpenAQ", "observed", "NA", "NA",
  "latitude", "numeric", "degrees", "Latitude of the station", "OpenAQ", "observed", "NA", "NA",
  "longitude", "numeric", "degrees", "Longitude of the station", "OpenAQ", "observed", "NA", "NA",
  "use_hyderabad", "logical", "NA", "Flag indicating inclusion in Hyderabad analysis scope", "Project", "derived", "NA", "NA",
  "use_india", "logical", "NA", "Flag indicating inclusion in India representative analysis scope", "Project", "derived", "NA", "NA",
  "day_of_week", "character", "NA", "Day of the week (e.g. Monday)", "Project", "derived", "NA", "NA",
  "month_name", "character", "NA", "Name of the month", "Project", "derived", "NA", "NA",
  "month", "character", "NA", "Month in YYYY-MM format", "Project", "derived", "NA", "NA",
  "month_number", "numeric", "NA", "Numeric month (1-12)", "Project", "derived", "NA", "NA",
  "year", "numeric", "NA", "Year", "Project", "derived", "NA", "NA",
  "season", "character", "NA", "Meteorological season", "Project", "derived", "NA", "NA",
  
  "pm2_5_source_mean", "numeric", "µg/m³", "24-hour mean of PM2.5", "OpenAQ", "derived", "NA", "NA",
  "pm2_5_source_null_hour_count", "numeric", "hours", "Number of missing PM2.5 hours", "OpenAQ", "derived", "NA", "NA",
  "pm2_5_hourly_coverage_pct", "numeric", "%", "Percentage of hours with valid PM2.5 data", "OpenAQ", "derived", "NA", "NA",
  "pm2_5_source_unit", "character", "NA", "Original unit of PM2.5", "OpenAQ", "observed", "NA", "NA",
  
  "pm10_source_mean", "numeric", "µg/m³", "24-hour mean of PM10", "OpenAQ", "derived", "NA", "NA",
  "pm10_source_null_hour_count", "numeric", "hours", "Number of missing PM10 hours", "OpenAQ", "derived", "NA", "NA",
  "pm10_hourly_coverage_pct", "numeric", "%", "Percentage of hours with valid PM10 data", "OpenAQ", "derived", "NA", "NA",
  "pm10_source_unit", "character", "NA", "Original unit of PM10", "OpenAQ", "observed", "NA", "NA",
  
  "no2_source_mean", "numeric", "ppb/µg/m³", "24-hour mean of NO2", "OpenAQ", "derived", "excluded", "UNRESOLVED_FOR_AQI",
  "no2_valid_hours", "numeric", "hours", "Number of valid NO2 hours", "OpenAQ", "derived", "excluded", "UNRESOLVED_FOR_AQI",
  "no2_source_null_hour_count", "numeric", "hours", "Number of missing NO2 hours", "OpenAQ", "derived", "excluded", "UNRESOLVED_FOR_AQI",
  "no2_hourly_coverage_pct", "numeric", "%", "Percentage of hours with valid NO2 data", "OpenAQ", "derived", "excluded", "UNRESOLVED_FOR_AQI",
  "no2_source_unit", "character", "NA", "Original unit of NO2", "OpenAQ", "observed", "excluded", "UNRESOLVED_FOR_AQI",
  
  "so2_source_mean", "numeric", "ppb/µg/m³", "24-hour mean of SO2", "OpenAQ", "derived", "excluded", "UNRESOLVED_FOR_AQI",
  "so2_valid_hours", "numeric", "hours", "Number of valid SO2 hours", "OpenAQ", "derived", "excluded", "UNRESOLVED_FOR_AQI",
  "so2_source_null_hour_count", "numeric", "hours", "Number of missing SO2 hours", "OpenAQ", "derived", "excluded", "UNRESOLVED_FOR_AQI",
  "so2_hourly_coverage_pct", "numeric", "%", "Percentage of hours with valid SO2 data", "OpenAQ", "derived", "excluded", "UNRESOLVED_FOR_AQI",
  "so2_source_unit", "character", "NA", "Original unit of SO2", "OpenAQ", "observed", "excluded", "UNRESOLVED_FOR_AQI",
  
  "co_source_mean", "numeric", "ppb/mg/m³", "24-hour mean of CO", "OpenAQ", "derived", "excluded", "UNRESOLVED_FOR_AQI",
  "co_valid_hours", "numeric", "hours", "Number of valid CO hours", "OpenAQ", "derived", "excluded", "UNRESOLVED_FOR_AQI",
  "co_source_null_hour_count", "numeric", "hours", "Number of missing CO hours", "OpenAQ", "derived", "excluded", "UNRESOLVED_FOR_AQI",
  "co_hourly_coverage_pct", "numeric", "%", "Percentage of hours with valid CO data", "OpenAQ", "derived", "excluded", "UNRESOLVED_FOR_AQI",
  "co_source_unit", "character", "NA", "Original unit of CO", "OpenAQ", "observed", "excluded", "UNRESOLVED_FOR_AQI",
  
  "o3_source_mean", "numeric", "µg/m³", "24-hour mean of O3 (descriptive)", "OpenAQ", "derived", "NA", "NA",
  "o3_source_null_hour_count", "numeric", "hours", "Number of missing O3 hours", "OpenAQ", "derived", "NA", "NA",
  "o3_hourly_coverage_pct", "numeric", "%", "Percentage of hours with valid O3 data", "OpenAQ", "derived", "NA", "NA",
  "o3_source_unit", "character", "NA", "Original unit of O3", "OpenAQ", "observed", "NA", "NA",
  
  "temperature", "numeric", "°C", "Average daily temperature", "Open-Meteo", "derived", "NA", "NA",
  "humidity", "numeric", "%", "Average daily relative humidity", "Open-Meteo", "derived", "NA", "NA",
  "wind_speed", "numeric", "m/s", "Average daily wind speed", "Open-Meteo", "derived", "NA", "NA",
  "wind_direction", "numeric", "degrees", "Average daily wind direction", "Open-Meteo", "derived", "NA", "NA",
  "wind_direction_resultant_strength", "numeric", "NA", "Strength of resultant wind vector", "Open-Meteo", "derived", "NA", "NA",
  "weather_valid_hours", "numeric", "hours", "Number of valid weather hours", "Open-Meteo", "derived", "NA", "NA",
  "weather_completeness_pct", "numeric", "%", "Percentage of hours with valid weather data", "Open-Meteo", "derived", "NA", "NA",
  
  "core_pollutants_with_any_data", "numeric", "count", "Number of core pollutants with any data on this day", "Project", "derived", "NA", "NA",
  "all_six_have_any_data", "logical", "NA", "TRUE if all 6 core pollutants have some data", "Project", "derived", "NA", "NA",
  "pm_pair_have_any_data", "logical", "NA", "TRUE if both PM2.5 and PM10 have some data", "Project", "derived", "NA", "NA",
  "daily_air_availability_status", "character", "NA", "Descriptive string of data availability", "Project", "derived", "NA", "NA",
  
  "pm2_5_aqi_input", "numeric", "µg/m³", "Regulatory 24-hour PM2.5 concentration", "Project", "derived", "included", "NA",
  "pm2_5_valid_hours", "numeric", "hours", "Number of valid PM2.5 source hours", "Project", "derived", "included", "NA",
  "pm2_5_subindex", "numeric", "AQI", "CPCB Subindex for PM2.5", "Project", "derived", "included", "NA",
  "pm2_5_aqi_validity_reason", "character", "NA", "Reason for PM2.5 subindex validity/invalidity", "Project", "derived", "included", "NA",
  
  "pm10_aqi_input", "numeric", "µg/m³", "Regulatory 24-hour PM10 concentration", "Project", "derived", "included", "NA",
  "pm10_valid_hours", "numeric", "hours", "Number of valid PM10 source hours", "Project", "derived", "included", "NA",
  "pm10_subindex", "numeric", "AQI", "CPCB Subindex for PM10", "Project", "derived", "included", "NA",
  "pm10_aqi_validity_reason", "character", "NA", "Reason for PM10 subindex validity/invalidity", "Project", "derived", "included", "NA",
  
  "o3_valid_source_hours", "numeric", "hours", "Number of valid O3 source hours", "Project", "derived", "included", "NA",
  "o3_valid_8h_window_count", "numeric", "count", "Number of valid 8-hour rolling windows within day", "Project", "derived", "included", "NA",
  "o3_8h_max", "numeric", "µg/m³", "Maximum of 8-hour rolling averages", "Project", "derived", "included", "NA",
  "o3_1h_max", "numeric", "µg/m³", "Maximum of 1-hour source values", "Project", "derived", "included", "NA",
  "o3_8h_subindex", "numeric", "AQI", "O3 subindex based on 8-hour max", "Project", "derived", "included", "NA",
  "o3_1h_subindex", "numeric", "AQI", "O3 subindex based on 1-hour max", "Project", "derived", "included", "NA",
  "o3_selected_averaging_period", "character", "NA", "Averaging period selected for final subindex (8-hour or 1-hour)", "Project", "derived", "included", "NA",
  "o3_subindex", "numeric", "AQI", "Final CPCB Subindex for O3", "Project", "derived", "included", "NA",
  "o3_aqi_validity_reason", "character", "NA", "Reason for O3 subindex validity/invalidity", "Project", "derived", "included", "NA",
  
  "all_three_valid", "logical", "NA", "TRUE if PM2.5, PM10, and O3 subindices are valid", "Project", "derived", "NA", "NA",
  "aqi_uncapped", "numeric", "AQI", "Raw calculated AQI without 500 cap", "Project", "derived", "included", "NA",
  "aqi_verified", "numeric", "AQI", "Final regulatory AQI (capped at 500)", "Project", "derived", "included", "NA",
  "aqi_category", "character", "NA", "Regulatory AQI classification category", "Project", "derived", "included", "NA",
  "dominant_pollutant", "character", "NA", "Pollutant(s) driving the maximum subindex", "Project", "derived", "included", "Limited to verified subset",
  "aqi_validity_reason", "character", "NA", "Reason for overall AQI validity/invalidity", "Project", "derived", "included", "NA",
  "aqi_invalid_components", "character", "NA", "List of invalid subindices contributing to NA AQI", "Project", "derived", "included", "NA",
  "aqi_input_policy", "character", "NA", "Name of the AQI policy applied", "Project", "derived", "included", "NA",
  "aqi_policy_version", "character", "NA", "Version of the AQI policy", "Project", "derived", "included", "NA",
  "aqi_pollutants_used", "character", "NA", "List of pollutants actively used in AQI", "Project", "derived", "included", "NA",
  "aqi_excluded_pollutants", "character", "NA", "List of pollutants excluded from AQI", "Project", "derived", "excluded", "NA",
  "aqi_is_verified_subset", "logical", "NA", "TRUE indicating conservative subset usage", "Project", "derived", "included", "NA",
  "aqi_scope_note", "character", "NA", "Note explaining subset limitations", "Project", "derived", "included", "NA"
)

write_csv(dict, "data/metadata/UAQI_Final_Data_Dictionary.csv")
