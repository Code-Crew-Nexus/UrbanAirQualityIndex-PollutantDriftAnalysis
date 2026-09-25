source("R/00_setup.R")
source("R/01_utils.R")
library(jsonlite)

log_info("Repairing specific monthly chunks (March 2025, July 2025, March 2026, June 2026)")

snap <- read.csv("data/metadata/selected_sensor_snapshot.csv", stringsAsFactors=FALSE)
sel <- read.csv("config/selected_stations.csv", stringsAsFactors=FALSE)
state <- read.csv("data/metadata/phase2B_acquisition_state.csv", stringsAsFactors=FALSE)

aq_dir <- "data/interim/hourly/historical"
dir.create(aq_dir, recursive=TRUE, showWarnings=FALSE)

process_aq_file <- function(f, pid, sid, param) {
    parsed <- fromJSON(f, simplifyVector=FALSE)
    if (is.null(parsed$results) || length(parsed$results) == 0) return(NULL)
    
    rows <- list()
    for (res in parsed$results) {
        val <- res$value
        if (is.null(val)) val <- NA
        
        t_utc <- res$period$datetimeTo$utc
        t_loc <- res$period$datetimeTo$local
        d_loc <- substr(t_loc, 1, 10)
        
        c_pct <- if (!is.null(res$coverage$percentComplete)) res$coverage$percentComplete else NA
        c_cov <- if (!is.null(res$coverage$percentCoverage)) res$coverage$percentCoverage else NA
        
        rows[[length(rows)+1]] <- data.frame(
            project_station_id = pid,
            source_location_id = sel[sel$project_station_id == pid, "source_location_id"][1],
            station_name = sel[sel$project_station_id == pid, "station_name"][1],
            city = sel[sel$project_station_id == pid, "city"][1],
            state = sel[sel$project_station_id == pid, "state"][1],
            sensor_id = sid,
            parameter = param,
            value_source = as.numeric(val),
            source_unit = res$parameter$units,
            timestamp_utc = t_utc,
            timestamp_local = t_loc,
            period_end_utc = t_utc,
            period_end_local = t_loc,
            date_local = d_loc,
            api_percent_complete = as.numeric(c_pct),
            api_percent_coverage = as.numeric(c_cov),
            raw_source_file = f,
            stringsAsFactors = FALSE
        )
    }
    do.call(rbind, rows)
}

# 1. March 2025
log_info("Replacing March 2025 from canonical selected dataset...")
file.copy("data/interim/hourly/phase2_selected_air_quality_2025_03.csv", 
          file.path(aq_dir, "air_quality_2025_03.csv"), overwrite=TRUE)

# 2. Re-normalize the chunks that had retries
chunks_to_repair <- data.frame(
    cid = c(4, 12, 15),
    ym = c("2025-07", "2026-03", "2026-06"),
    stringsAsFactors=FALSE
)

for (i in 1:nrow(chunks_to_repair)) {
    cid <- chunks_to_repair$cid[i]
    ym <- chunks_to_repair$ym[i]
    
    log_info(sprintf("Reprocessing chunk %s...", ym))
    c_s <- state[state$chunk_id == cid & state$status %in% c("completed", "empty_valid_response"), ]
    files <- unlist(strsplit(c_s$raw_files, ";"))
    files <- files[files != "" & !is.na(files)]
    
    chunk_dfs <- list()
    for (f in unique(files)) {
        if (!file.exists(f)) next
        fname <- basename(f)
        parts <- strsplit(fname, "_")[[1]]
        pid <- paste(parts[1], parts[2], sep="_")
        sid <- parts[3]
        param <- parts[4]
        
        df <- process_aq_file(f, pid, sid, param)
        if (!is.null(df)) {
            chunk_dfs[[length(chunk_dfs)+1]] <- df
        }
    }
    
    if (length(chunk_dfs) > 0) {
        chunk_all <- do.call(rbind, chunk_dfs)
        chunk_all <- chunk_all[!duplicated(chunk_all[, c("project_station_id", "sensor_id", "parameter", "timestamp_local")]), ]
        write.csv(chunk_all, file.path(aq_dir, paste0("air_quality_", gsub("-", "_", ym), ".csv")), row.names=FALSE)
    }
}
log_info("Chunk repair complete.")
