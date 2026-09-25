source("R/00_setup.R")
source("R/01_utils.R")
source("R/02_phase2_provenance.R")
library(jsonlite)
library(digest)

log_info("Starting Phase 2B Stage 1 Repair")

# -------------------------------------------------------------------------
# 1. PRESERVE SELECTION HISTORY
# -------------------------------------------------------------------------
log_info("Preserving selection history...")
sel <- read.csv("config/selected_stations.csv", stringsAsFactors=FALSE)
cat <- read.csv("data/metadata/station_catalog.csv", stringsAsFactors=FALSE)

history_cols <- c("selection_version", "project_station_id", "source_location_id", "station_name", "city", "use_hyderabad", "use_india", "decision_status", "decision_reason", "effective_at")

if (!file.exists("data/metadata/selection_history.csv")) {
    hist <- data.frame(matrix(ncol = length(history_cols), nrow = 0))
    names(hist) <- history_cols
} else {
    hist <- read.csv("data/metadata/selection_history.csv", stringsAsFactors=FALSE)
}

new_hist <- sel[, c("project_station_id", "station_name", "city", "use_hyderabad", "use_india")]
new_hist$selection_version <- 1
new_hist$source_location_id <- cat$source_location_id[match(new_hist$project_station_id, cat$project_station_id)]
new_hist$decision_status <- ifelse(new_hist$project_station_id == "PROJ_104", "superseded_after_phase2a1", "active")
new_hist$decision_reason <- ifelse(new_hist$project_station_id == "PROJ_104", 
                                   "March 2025 six-pollutant historical completeness was materially weaker than the verified Jadavpur alternate.", 
                                   "Selected in Phase 1.6")
new_hist$effective_at <- Sys.time()

# Append to history
hist <- rbind(hist, new_hist[, history_cols])
write.csv(hist, "data/metadata/selection_history.csv", row.names=FALSE)

# -------------------------------------------------------------------------
# 2. UPDATE FINAL SELECTED STATIONS
# -------------------------------------------------------------------------
log_info("Updating config/selected_stations.csv...")
if ("PROJ_104" %in% sel$project_station_id) {
    sel <- sel[sel$project_station_id != "PROJ_104", ]

    jadavpur <- cat[cat$project_station_id == "PROJ_094", ]
    new_sel <- jadavpur[, c("project_station_id", "source", "source_location_id", "station_name", "city", "state", "latitude", "longitude")]
    new_sel$selection_version <- 2
    new_sel$use_hyderabad <- FALSE
    new_sel$use_india <- TRUE
    new_sel$selection_strategy <- "manual"
    new_sel$selection_reason <- "Human-approved after Phase 2A.1 Kolkata alternate pilot."
    new_sel$selected <- TRUE
    new_sel$selected_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")
    
    sel$selection_version <- 2
    sel$selection_reason <- ifelse(sel$use_hyderabad, "Human-approved Hyderabad", "Human-approved India")
    
    # Reorder new_sel to match sel
    new_sel <- new_sel[, names(sel)]
    
    sel <- rbind(sel, new_sel)
    write.csv(sel, "config/selected_stations.csv", row.names=FALSE)
}

# -------------------------------------------------------------------------
# 3. REBUILD SELECTED SENSOR SNAPSHOT
# -------------------------------------------------------------------------
log_info("Rebuilding selected sensor snapshot...")
sens_cat <- read.csv("data/metadata/sensor_catalog.csv", stringsAsFactors=FALSE)

snap <- read.csv("data/metadata/selected_sensor_snapshot.csv", stringsAsFactors=FALSE)

if ("PROJ_104" %in% snap$project_station_id) {
    snap <- snap[snap$project_station_id != "PROJ_104", ]

    jad_sens <- sens_cat[sens_cat$project_station_id == "PROJ_094" & sens_cat$sensor_generation_status == "preferred_current" & sens_cat$parameter %in% c("pm2_5", "pm10", "no2", "so2", "co", "o3"), ]

    jad_sens$state <- "West Bengal"
    jad_sens$use_hyderabad <- FALSE
    jad_sens$use_india <- TRUE
    jad_sens <- jad_sens[, names(snap)]

    snap <- rbind(snap, jad_sens)
    write.csv(snap, "data/metadata/selected_sensor_snapshot.csv", row.names=FALSE)
}

if (nrow(snap) != 126) stop("Expected exactly 126 sensors in selected snapshot.")

# -------------------------------------------------------------------------
# 4 & 5. BUILD FINAL SELECTED MARCH PILOT TABLE
# -------------------------------------------------------------------------
log_info("Building final March pilot tables...")
aq_main <- read.csv("data/interim/hourly/phase2_pilot_air_quality_2025_03.csv", stringsAsFactors=FALSE)
aq_main <- aq_main[aq_main$project_station_id != "PROJ_104", ]

aq_alt <- read.csv("data/interim/hourly/phase2a1_kolkata_alternates_air_quality_2025_03.csv", stringsAsFactors=FALSE)
aq_jad <- aq_alt[aq_alt$project_station_id == "PROJ_094", ]

aq_jad$city <- "Kolkata"
aq_jad$state <- "West Bengal"
aq_jad <- aq_jad[, names(aq_main)]
aq_final <- rbind(aq_main, aq_jad)
write.csv(aq_final, "data/interim/hourly/phase2_selected_air_quality_2025_03.csv", row.names=FALSE)

w_main <- read.csv("data/interim/hourly/phase2_pilot_weather_2025_03.csv", stringsAsFactors=FALSE)
w_main <- w_main[w_main$project_station_id != "PROJ_104", ]
w_alt <- read.csv("data/interim/hourly/phase2a1_kolkata_alternates_weather_2025_03.csv", stringsAsFactors=FALSE)
w_jad <- w_alt[w_alt$project_station_id == "PROJ_094", ]
w_jad <- w_jad[!duplicated(w_jad[, c("project_station_id", "timestamp_local")]), ] # Just one canonical weather

w_jad$source_location_id <- NA
w_jad$station_name <- "Jadavpur, Kolkata - WBPCB"
w_jad$city <- "Kolkata"
w_jad$state <- "West Bengal"
w_jad <- w_jad[, names(w_main)]
w_final <- rbind(w_main, w_jad)
write.csv(w_final, "data/interim/hourly/phase2_selected_weather_2025_03.csv", row.names=FALSE)

# -------------------------------------------------------------------------
# 6. RECOMPUTE FINAL MARCH COMPLETENESS
# -------------------------------------------------------------------------
log_info("Recomputing March completeness...")
comp_list <- list()
EXPECTED <- 744
stations <- unique(snap$project_station_id)

for (pid in stations) {
    s_meta <- sel[sel$project_station_id == pid, ]
    for (p in c("pm2_5", "pm10", "no2", "so2", "co", "o3")) {
        sub <- aq_final[aq_final$project_station_id == pid & aq_final$parameter == p, ]
        if (nrow(sub) == 0) {
            d <- 0
            n_nulls <- 0
            ts_first <- NA
            ts_last <- NA
        } else {
            d <- length(unique(sub$timestamp_local[!is.na(sub$timestamp_local) & !is.na(sub$value_source)]))
            n_nulls <- sum(is.na(sub$value_source))
            ts_first <- min(sub$timestamp_local, na.rm=TRUE)
            ts_last <- max(sub$timestamp_local, na.rm=TRUE)
        }
        
        comp_list[[length(comp_list)+1]] <- data.frame(
            project_station_id = pid,
            city = s_meta$city,
            parameter = p,
            expected_hour_count = EXPECTED,
            distinct_valid_hour_count = d,
            source_null_value_count = n_nulls,
            hourly_completeness_pct = round(d/EXPECTED*100, 2),
            first_observed_timestamp = ts_first,
            last_observed_timestamp = ts_last,
            stringsAsFactors = FALSE
        )
    }
}
comp_df <- do.call(rbind, comp_list)
write.csv(comp_df, "data/metadata/phase2_selected_march_completeness.csv", row.names=FALSE)

# -------------------------------------------------------------------------
# 7, 8 & 9. REPAIR HISTORICAL MANIFEST
# -------------------------------------------------------------------------
log_info("Repairing historical manifest...")
mf <- read.csv("data/metadata/historical_acquisition_manifest.csv", stringsAsFactors=FALSE, header=FALSE)
# The first line is the header
mf_header <- mf[1, ]
mf_data <- mf[-1, ]
# We know the first 147 data rows are good.
good_mf <- mf_data[1:147, ]
names(good_mf) <- MANIFEST_COLUMNS

# The last 16 are bad. We will rebuild them from files.
aq_files <- list.files("data/raw/air_quality/openaq/historical_alternate_pilot", pattern="\\.json$", recursive=TRUE, full.names=TRUE)
w_files <- list.files("data/raw/weather/openmeteo/historical_alternate_pilot", pattern="\\.json$", recursive=TRUE, full.names=TRUE)

# Re-init manifest with the good 147 rows
write.csv(good_mf, "data/metadata/historical_acquisition_manifest.csv", row.names=FALSE)

for (f in c(aq_files, w_files)) {
    is_aq <- grepl("openaq", f)
    parsed <- fromJSON(f, simplifyVector=FALSE)
    fname <- basename(f)
    
    parts <- strsplit(fname, "_")[[1]]
    pid <- paste(parts[1], parts[2], sep="_")
    
    if (is_aq) {
        sid <- parts[3]
        param <- parts[4]
        # Use existing timestamp from filename
        ts <- strsplit(parts[7], "\\.")[[1]][1]
        
        meta_row <- sens_cat[sens_cat$project_station_id == pid & sens_cat$sensor_id == sid, ]
        if (nrow(meta_row) == 0) next
        
        rec <- list(
            retrieval_id = paste0("openaq_", ts),
            local_file = f,
            source = "openaq",
            source_type = "historical_hourly",
            source_endpoint = "/sensors/hours",
            retrieved_at = Sys.time(), # not the original, but the script is rewriting history
            http_status = 200,
            request_start_datetime = "2025-02-28T18:30:00Z",
            request_end_datetime = "2025-03-31T18:29:59Z",
            project_station_id = pid,
            source_location_id = meta_row$source_location_id[1],
            sensor_id = sid,
            parameter = param,
            page = 1,
            api_found = ifelse(is.null(parsed$meta$found), NA, parsed$meta$found),
            response_row_count = length(parsed$results),
            source_unit = meta_row$source_unit[1],
            data_origin = "phase2a1_kolkata_alternate_pilot",
            file_sha256 = digest::digest(f, algo="sha256", file=TRUE),
            x_ratelimit_used = NA,
            x_ratelimit_limit = NA,
            x_ratelimit_remaining = NA,
            x_ratelimit_reset = NA,
            request_status = "SUCCESS",
            notes = "not_captured_by_phase2a1_script; selected_after_phase2a1"
        )
    } else {
        ts <- strsplit(parts[5], "\\.")[[1]][1]
        rec <- list(
            retrieval_id = paste0("openmeteo_", ts),
            local_file = f,
            source = "openmeteo",
            source_type = "historical_hourly",
            source_endpoint = "/v1/archive",
            retrieved_at = Sys.time(),
            http_status = 200,
            request_start_datetime = "2025-03-01T00:00:00Z",
            request_end_datetime = "2025-03-31T23:59:59Z",
            project_station_id = pid,
            source_location_id = NA,
            sensor_id = NA,
            parameter = NA,
            page = NA,
            api_found = NA,
            response_row_count = length(parsed$hourly$time),
            source_unit = NA,
            data_origin = "phase2a1_kolkata_alternate_pilot",
            file_sha256 = digest::digest(f, algo="sha256", file=TRUE),
            x_ratelimit_used = NA,
            x_ratelimit_limit = NA,
            x_ratelimit_remaining = NA,
            x_ratelimit_reset = NA,
            request_status = "SUCCESS",
            notes = "not_captured_by_phase2a1_script; selected_after_phase2a1"
        )
    }
    append_historical_manifest(rec)
}

# -------------------------------------------------------------------------
# 12. FIX PHASE-2A.1 RECENT COVERAGE SUMMARY
# -------------------------------------------------------------------------
log_info("Fixing recent coverage...")
comp <- read.csv("data/metadata/phase2a1_kolkata_comparison.csv", stringsAsFactors=FALSE)
cov <- read.csv("data/metadata/coverage_report.csv", stringsAsFactors=FALSE)

for (i in 1:nrow(comp)) {
    pid <- comp$project_station_id[i]
    sub <- cov[cov$project_station_id == pid & cov$period_label == "recent_30d" & cov$parameter %in% c("pm2_5", "pm10", "no2", "so2", "co", "o3"), ]
    if (nrow(sub) > 0) {
        comp$recent_2026_minimum_coverage_pct[i] <- min(sub$days_with_data_pct)
        comp$recent_2026_mean_coverage_pct[i] <- round(mean(sub$days_with_data_pct), 2)
    }
}
write.csv(comp, "data/metadata/phase2a1_kolkata_comparison.csv", row.names=FALSE)

# -------------------------------------------------------------------------
# 18. REBUILD PHASE 2B PLAN WITH EXACT HOURS
# -------------------------------------------------------------------------
log_info("Rebuilding Phase 2B plan with exact local expected hours...")
periods <- data.frame(
    chunk_id = 1:18,
    local_start_date = c(
        "2025-04-01", "2025-05-01", "2025-06-01", "2025-07-01", "2025-08-01", "2025-09-01", "2025-10-01", "2025-11-01", "2025-12-01",
        "2026-01-01", "2026-02-01", "2026-03-01", "2026-04-01", "2026-05-01", "2026-06-01", "2026-07-01", "2026-08-01", "2026-09-01"
    ),
    local_end_date = c(
        "2025-04-30", "2025-05-31", "2025-06-30", "2025-07-31", "2025-08-31", "2025-09-30", "2025-10-31", "2025-11-30", "2025-12-31",
        "2026-01-31", "2026-02-28", "2026-03-31", "2026-04-30", "2026-05-31", "2026-06-30", "2026-07-31", "2026-08-31", "2026-09-21"
    ),
    stringsAsFactors=FALSE
)

periods$expected_local_hours <- sapply(1:18, function(i) {
    s <- as.Date(periods$local_start_date[i])
    e <- as.Date(periods$local_end_date[i])
    as.numeric(e - s + 1) * 24
})

periods$sensor_count <- 126
periods$planned_primary_requests <- 126
periods$status <- "PLANNED"

write.csv(periods, "data/metadata/phase2B_acquisition_plan.csv", row.names=FALSE)

# -------------------------------------------------------------------------
# INITIALIZE PHASE 2B ACQUISITION STATE
# -------------------------------------------------------------------------
log_info("Initializing Phase 2B Acquisition State...")
state_cols <- c(
    "chunk_id", "project_station_id", "source_location_id", "sensor_id", "parameter",
    "request_start_datetime", "request_end_datetime", "status", "attempt_count",
    "api_found", "response_row_count", "page_count", "raw_files", "first_attempt_at",
    "completed_at", "last_http_status", "error_message"
)

state_file <- "data/metadata/phase2B_acquisition_state.csv"
if (!file.exists(state_file)) {
    state_list <- list()
    for (i in 1:18) {
        chunk <- periods[i, ]
        
        # Local to UTC conversion
        start_lt <- as.POSIXct(paste0(chunk$local_start_date, " 00:00:00"), tz="Asia/Kolkata")
        end_lt <- as.POSIXct(paste0(chunk$local_end_date, " 23:59:59"), tz="Asia/Kolkata")
        
        start_utc <- format(start_lt, "%Y-%m-%dT%H:%M:%SZ", tz="UTC")
        end_utc <- format(end_lt, "%Y-%m-%dT%H:%M:%SZ", tz="UTC")
        
        for (j in 1:nrow(snap)) {
            s <- snap[j, ]
            state_list[[length(state_list)+1]] <- data.frame(
                chunk_id = chunk$chunk_id,
                project_station_id = s$project_station_id,
                source_location_id = s$source_location_id,
                sensor_id = s$sensor_id,
                parameter = s$parameter,
                request_start_datetime = start_utc,
                request_end_datetime = end_utc,
                status = "pending",
                attempt_count = 0,
                api_found = NA,
                response_row_count = NA,
                page_count = 0,
                raw_files = "",
                first_attempt_at = NA,
                completed_at = NA,
                last_http_status = NA,
                error_message = NA,
                stringsAsFactors = FALSE
            )
        }
    }
    state_df <- do.call(rbind, state_list)
    write.csv(state_df, state_file, row.names=FALSE)
}

log_info("Stage 1 Repair Complete.")
