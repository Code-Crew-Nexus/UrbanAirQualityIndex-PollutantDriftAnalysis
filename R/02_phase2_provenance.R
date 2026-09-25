source("R/00_setup.R")
library(digest)

# Canonical 25 columns
MANIFEST_COLUMNS <- c(
    "retrieval_id", "local_file", "source", "source_type", "source_endpoint",
    "retrieved_at", "http_status", "request_start_datetime", "request_end_datetime",
    "project_station_id", "source_location_id", "sensor_id", "parameter",
    "page", "api_found", "response_row_count", "source_unit", "data_origin",
    "file_sha256", "x_ratelimit_used", "x_ratelimit_limit", "x_ratelimit_remaining",
    "x_ratelimit_reset", "request_status", "notes"
)

# Initialize if doesn't exist
init_historical_manifest <- function() {
    path <- "data/metadata/historical_acquisition_manifest.csv"
    if (!file.exists(path)) {
        dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
        df <- data.frame(matrix(ncol = length(MANIFEST_COLUMNS), nrow = 0))
        names(df) <- MANIFEST_COLUMNS
        write.csv(df, path, row.names = FALSE)
    }
}

# Strict append function
append_historical_manifest <- function(record_list) {
    path <- "data/metadata/historical_acquisition_manifest.csv"
    init_historical_manifest()
    
    # Check for required fields
    missing_cols <- setdiff(names(record_list), MANIFEST_COLUMNS)
    if (length(missing_cols) > 0) {
        stop(paste("Unknown columns supplied to manifest append:", paste(missing_cols, collapse=", ")))
    }
    
    # Create empty canonical row
    row <- data.frame(matrix(ncol = length(MANIFEST_COLUMNS), nrow = 1))
    names(row) <- MANIFEST_COLUMNS
    
    # Fill in provided values
    for (col in names(record_list)) {
        val <- record_list[[col]]
        if (is.null(val)) val <- NA
        row[[col]] <- val
    }
    
    # Fill remaining with NA
    for (col in MANIFEST_COLUMNS) {
        if (!col %in% names(record_list)) {
            row[[col]] <- NA
        }
    }
    
    # Validate local_file and file_sha256
    if (!is.na(row$local_file)) {
        if (!startsWith(row$local_file, "data/raw/")) {
            stop("local_file must start with data/raw/")
        }
        if (file.exists(row$local_file)) {
            if (is.na(row$file_sha256) || row$file_sha256 == "") {
                row$file_sha256 <- digest::digest(row$local_file, algo="sha256", file=TRUE)
            } else {
                # Confirm it's sha256 (length 64)
                if (nchar(row$file_sha256) != 64) {
                    stop("file_sha256 must be a 64-character SHA-256 hash")
                }
            }
        }
    }
    
    # Write by strictly ordering columns
    row <- row[, MANIFEST_COLUMNS, drop = FALSE]
    write.table(row, path, sep = ",", append = TRUE, row.names = FALSE, col.names = FALSE)
}
