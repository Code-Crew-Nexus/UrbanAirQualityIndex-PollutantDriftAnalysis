# ==============================================================================
# scripts/30_export_web_assets.R
# UrbanAirQualityIndex-PollutantDriftAnalysis
# B.Tech CSE (AI & ML) III Year / I Sem - Statistics for Machine Learning PBL
# Phase 6A: Web Data Export Foundation
# ==============================================================================

suppressPackageStartupMessages({
  library(yaml)
  library(jsonlite)
  library(readr)
})

message("--> Phase 6A: Exporting web data foundation assets...")

# Ensure destination directory exists
web_data_dir <- file.path("docs", "web-data")
if (!dir.exists(web_data_dir)) {
  dir.create(web_data_dir, recursive = TRUE, showWarnings = FALSE)
}

# 1. Read Project Configuration & Policies
config <- yaml::read_yaml("config/project_config.yml")
aqi_policy <- yaml::read_yaml("config/final_aqi_input_policy.yml")
selected_stations <- read.csv("config/selected_stations.csv", stringsAsFactors = FALSE)

# 2. Inspect Processed Dataset for Canonical Statistics
master_data_path <- file.path("data", "processed", "UAQI_Master_Daily.csv")
if (!file.exists(master_data_path)) {
  stop("Canonical dataset missing: ", master_data_path)
}

master_dates <- read_csv(
  master_data_path,
  col_types = cols_only(
    project_station_id = col_character(),
    date = col_date()
  )
)

start_date <- as.character(min(master_dates$date))
end_date <- as.character(max(master_dates$date))
total_days <- as.integer(length(unique(master_dates$date)))
total_station_days <- as.integer(nrow(master_dates))
unique_stations_data <- as.integer(length(unique(master_dates$project_station_id)))

# 3. Process Station Metadata
stations_clean <- lapply(seq_len(nrow(selected_stations)), function(i) {
  row <- selected_stations[i, ]
  is_hyd <- isTRUE(as.logical(row$use_hyderabad))
  is_ind <- isTRUE(as.logical(row$use_india))
  role_label <- if (is_hyd && is_ind) {
    "Both Panels (Hyderabad & India Overlap)"
  } else if (is_hyd) {
    "Hyderabad Panel"
  } else {
    "India Representative Panel"
  }
  
  list(
    project_station_id = as.character(row$project_station_id),
    station_name = as.character(row$station_name),
    city = as.character(row$city),
    state = as.character(row$state),
    latitude = as.numeric(row$latitude),
    longitude = as.numeric(row$longitude),
    use_hyderabad = is_hyd,
    use_india = is_ind,
    panel_role = role_label
  )
})

hyderabad_count <- sum(selected_stations$use_hyderabad == TRUE | selected_stations$use_hyderabad == "TRUE")
india_count <- sum(selected_stations$use_india == TRUE | selected_stations$use_india == "TRUE")
unique_stations_count <- nrow(selected_stations)

# 4. Construct project_summary.json
project_summary <- list(
  project_name = config$project$name,
  course = "Statistics for Machine Learning (SML)",
  framework = "Project Based Learning (PBL)",
  organization = "Code-Crew-Nexus",
  study_scope = list(
    geographic_coverage = "Hyderabad Metropolitan & India Representative National Network",
    total_physical_stations = unique_stations_count,
    hyderabad_stations = hyderabad_count,
    india_representative_stations = india_count,
    overlap_stations = (hyderabad_count + india_count) - unique_stations_count
  ),
  study_period = list(
    start_date = start_date,
    end_date = end_date,
    total_study_days = total_days,
    total_station_days = total_station_days
  ),
  modeling_baseline = list(
    latest_tag = "v0.6-svm-freeze",
    previous_tags = list("v0.4-supervised-freeze", "v0.5-unsupervised-freeze"),
    status = "FROZEN",
    description = "Nonlinear RBF SVM classification, PCA/K-Means unsupervised regimes, and MLR/Logistic regression baselines permanently locked."
  ),
  aqi_policy = list(
    policy_name = aqi_policy$policy_name,
    label = "CPCB-Methodology-Aligned Verified-Subset AQI",
    included_pollutants = list("PM2.5", "PM10", "O3"),
    excluded_pollutants = list("CO", "NO2", "SO2"),
    adverse_threshold = "AQI_(t+1) > 100",
    description = "Applies official CPCB linear sub-index interpolation using verified PM2.5, PM10, and daily maximum rolling 8-hour ozone (o3_8h_max). CO, NO2, and SO2 remain excluded due to unresolved unit semantics in modern OpenAQ streams."
  ),
  team = list(
    list(name = "Mangali Sai Krishna", roll_number = "24R11A6669", github = "@Saikrishna-dev-oss"),
    list(name = "Md. Abdul Rayain", roll_number = "24R11A6673", github = "@rayainwarrior-dev"),
    list(name = "RISHIT GHOSH", roll_number = "24R11A6685", github = "@rajghosh06-dev"),
    list(name = "Yaram Karthik", roll_number = "24R11A66A1", github = "@karthik10-dev")
  ),
  generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
)

# 5. Construct web_manifest.json
web_manifest <- list(
  manifest_version = "1.0.0",
  phase = "6A",
  phase_description = "Static Project Website Foundation",
  exported_files = list(
    list(
      file = "project_summary.json",
      purpose = "Site-wide project metadata, cards, and frozen milestone status",
      records = 1
    ),
    list(
      file = "stations.json",
      purpose = "Clean physical station directory with geographic coordinates and panel assignments",
      records = length(stations_clean)
    )
  ),
  frozen_data_sources = list(
    master_dataset = "data/processed/UAQI_Master_Daily.csv",
    station_config = "config/selected_stations.csv",
    policy_config = "config/final_aqi_input_policy.yml"
  ),
  generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
)

# 6. Write JSON files
write_json(project_summary, file.path(web_data_dir, "project_summary.json"), pretty = TRUE, auto_unbox = TRUE)
write_json(stations_clean, file.path(web_data_dir, "stations.json"), pretty = TRUE, auto_unbox = TRUE)
write_json(web_manifest, file.path(web_data_dir, "web_manifest.json"), pretty = TRUE, auto_unbox = TRUE)

message("[OK] Exported project_summary.json (", file.info(file.path(web_data_dir, "project_summary.json"))$size, " bytes)")
message("[OK] Exported stations.json (", file.info(file.path(web_data_dir, "stations.json"))$size, " bytes)")
message("[OK] Exported web_manifest.json (", file.info(file.path(web_data_dir, "web_manifest.json"))$size, " bytes)")
message("--> Web data foundation export complete.")
