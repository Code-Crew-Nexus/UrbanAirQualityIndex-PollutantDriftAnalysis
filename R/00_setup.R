# ==============================================================================
# 00_setup.R: Project Initialization and Environment Setup
# UrbanAirQualityIndex-PollutantDriftAnalysis
# B.Tech CSE (AI & ML) III Year / I Sem - Statistics for Machine Learning PBL
# ==============================================================================

# Ensure standard timezone is Asia/Kolkata
Sys.setenv(TZ = "Asia/Kolkata")
.libPaths(c("C:/Users/rajghosh/Documents/R/win-library/4.6", .libPaths()))

# 1. Directory Structure Verification
project_dirs <- c(
  file.path("config"),
  file.path("data", "raw", "air_quality", "openaq"),
  file.path("data", "raw", "air_quality", "cpcb"),
  file.path("data", "raw", "weather", "openmeteo"),
  file.path("data", "raw", "reference", "kaggle"),
  file.path("data", "interim", "station_audit"),
  file.path("data", "interim", "hourly"),
  file.path("data", "interim", "daily"),
  file.path("data", "processed"),
  file.path("data", "metadata"),
  file.path("R", "sources"),
  file.path("scripts"),
  file.path("analysis"),
  file.path("models"),
  file.path("app"),
  file.path("docs"),
  file.path("tests", "testthat"),
  file.path("logs")
)

for (d in project_dirs) {
  if (!dir.exists(d)) {
    dir.create(d, recursive = TRUE, showWarnings = FALSE)
  }
}

# 2. Dependency Inspection (Production & Test)
required_pkgs <- c("httr2", "jsonlite", "yaml", "readr", "digest")
test_pkgs <- c("testthat")

missing_req <- required_pkgs[!vapply(required_pkgs, requireNamespace, quietly = TRUE, FUN.VALUE = logical(1))]
missing_test <- test_pkgs[!vapply(test_pkgs, requireNamespace, quietly = TRUE, FUN.VALUE = logical(1))]

if (length(missing_req) > 0) {
  stop(sprintf("[SETUP ERROR] Missing required production packages: %s. Cannot proceed with live authenticated ingestion.", paste(missing_req, collapse = ", ")))
} else {
  message("[SETUP OK] All required production packages are available.")
}

if (length(missing_test) > 0) {
  message(sprintf("[SETUP NOTE] Missing test packages: %s. Unit tests will not run.", paste(missing_test, collapse = ", ")))
}

message(sprintf("[SETUP OK] Project environment initialized. Timezone: %s", Sys.timezone()))
