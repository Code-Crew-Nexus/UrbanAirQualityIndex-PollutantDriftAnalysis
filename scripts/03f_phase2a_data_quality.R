source("R/00_setup.R")
source("R/01_utils.R")
library(jsonlite)

log_info("Starting Phase 2A Data Quality Audit")

raw_files <- list.files("data/raw/air_quality/openaq/historical", pattern="\\.json$", recursive=TRUE, full.names=TRUE)

raw_count <- 0
null_count <- 0
missing_ts_count_raw <- 0

for (f in raw_files) {
    tryCatch({
        parsed <- fromJSON(f, simplifyVector=F)
        if (is.null(parsed$results)) next
        
        raw_count <- raw_count + length(parsed$results)
        
        for (res in parsed$results) {
            if (is.null(res$value)) null_count <- null_count + 1
            if (is.null(res$period$datetimeFrom$local)) missing_ts_count_raw <- missing_ts_count_raw + 1
        }
    }, error = function(e) {})
}

aq <- read.csv("data/interim/hourly/phase2_pilot_air_quality_2025_03.csv", stringsAsFactors=F)

valid_normalized_rows <- nrow(aq)
missing_ts_normalized <- sum(is.na(aq$timestamp_local))
duplicate_keys <- sum(duplicated(aq[, c("project_station_id", "sensor_id", "parameter", "timestamp_local")]))

out <- data.frame(
    audit_target = "Phase 2A OpenAQ",
    total_raw_result_rows = raw_count,
    source_null_value_rows = null_count,
    missing_timestamp_raw = missing_ts_count_raw,
    total_valid_normalized_rows = valid_normalized_rows,
    missing_timestamp_normalized = missing_ts_normalized,
    duplicate_timestamp_key_rows = duplicate_keys,
    stringsAsFactors=FALSE
)

write.csv(out, "data/metadata/phase2a_data_quality_audit.csv", row.names=FALSE)
log_info("Data Quality Audit complete.")
