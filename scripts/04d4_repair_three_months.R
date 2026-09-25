source("R/00_setup.R")
source("R/01_utils.R")
source("R/03_phase2_normalization.R")

log_info("Repairing three chunks with canonical normalization (2025-07, 2026-03, 2026-06)")

snap <- read.csv("data/metadata/selected_sensor_snapshot.csv", stringsAsFactors=FALSE)
sel <- read.csv("config/selected_stations.csv", stringsAsFactors=FALSE)
state <- read.csv("data/metadata/phase2B_acquisition_state.csv", stringsAsFactors=FALSE)

aq_dir <- "data/interim/hourly/historical"

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
    
    files <- c()
    for (rf in c_s$raw_files) {
        fs <- unlist(strsplit(rf, ";"))
        files <- c(files, fs[fs != "" & !is.na(fs)])
    }
    
    chunk_dfs <- list()
    for (f in unique(files)) {
        if (!file.exists(f)) next
        fname <- basename(f)
        parts <- strsplit(fname, "_")[[1]]
        pid <- paste(parts[1], parts[2], sep="_")
        sid <- parts[3]
        
        df <- normalize_openaq_hour_response(f, pid, sid, snap, sel)
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
