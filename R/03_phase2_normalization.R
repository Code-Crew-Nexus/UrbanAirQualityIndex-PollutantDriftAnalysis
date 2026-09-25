library(jsonlite)

# Canonical OpenAQ Hourly Normalization
normalize_openaq_hour_response <- function(raw_file, project_station_id, sensor_id, snap, sel) {
    parsed <- fromJSON(raw_file, simplifyVector=FALSE)
    if (is.null(parsed$results) || length(parsed$results) == 0) return(NULL)
    
    # Authoritative metadata from snapshot
    snap_row <- snap[snap$sensor_id == sensor_id & snap$project_station_id == project_station_id, ]
    if (nrow(snap_row) == 0) return(NULL)
    
    canonical_param <- snap_row$parameter[1]
    
    rows <- list()
    for (res in parsed$results) {
        val <- res$value
        if (is.null(val)) val <- NA
        
        t_from_utc <- res$period$datetimeFrom$utc
        t_from_loc <- res$period$datetimeFrom$local
        t_to_utc <- res$period$datetimeTo$utc
        t_to_loc <- res$period$datetimeTo$local
        
        d_loc <- substr(t_from_loc, 1, 10)
        
        c_pct <- if (!is.null(res$coverage$percentComplete)) res$coverage$percentComplete else NA
        c_cov <- if (!is.null(res$coverage$percentCoverage)) res$coverage$percentCoverage else NA
        
        rows[[length(rows)+1]] <- data.frame(
            project_station_id = project_station_id,
            source_location_id = sel[sel$project_station_id == project_station_id, "source_location_id"][1],
            station_name = sel[sel$project_station_id == project_station_id, "station_name"][1],
            city = sel[sel$project_station_id == project_station_id, "city"][1],
            state = sel[sel$project_station_id == project_station_id, "state"][1],
            sensor_id = sensor_id,
            parameter = canonical_param,
            value_source = as.numeric(val),
            source_unit = res$parameter$units,
            timestamp_utc = t_from_utc,
            timestamp_local = t_from_loc,
            period_end_utc = t_to_utc,
            period_end_local = t_to_loc,
            date_local = d_loc,
            api_percent_complete = as.numeric(c_pct),
            api_percent_coverage = as.numeric(c_cov),
            raw_source_file = raw_file,
            stringsAsFactors = FALSE
        )
    }
    do.call(rbind, rows)
}
