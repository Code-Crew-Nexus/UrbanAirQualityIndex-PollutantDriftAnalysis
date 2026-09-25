source("R/00_setup.R")
source("R/01_utils.R")

log_info("Rebuilding Quality Summaries and Completeness")

snap <- read.csv("data/metadata/selected_sensor_snapshot.csv", stringsAsFactors=FALSE)
sel <- read.csv("config/selected_stations.csv", stringsAsFactors=FALSE)
plan <- read.csv("data/metadata/phase2B_acquisition_plan.csv", stringsAsFactors=FALSE)

aq_files <- list.files("data/interim/hourly/historical", pattern="^air_quality_.*\\.csv$", full.names=TRUE)
aq_files <- sort(aq_files)

# Expected hours logic
# Expected hours logic
get_exp_hours <- function(ym) {
    if (ym == "2026-09") return(504) # specifically 2026-09-01 through 2026-09-21
    
    parts <- strsplit(ym, "-")[[1]]
    yr <- as.integer(parts[1])
    mo <- as.integer(parts[2])
    
    days_map <- c(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
    if (yr %% 4 == 0 && (yr %% 100 != 0 || yr %% 400 == 0)) days_map[2] <- 29
    
    return(days_map[mo] * 24)
}

comp_rows <- list()

for (f in aq_files) {
    fname <- basename(f)
    ym <- gsub("_", "-", gsub("air_quality_", "", gsub("\\.csv", "", fname)))
    exp_hr <- get_exp_hours(ym)
    
    df <- read.csv(f, stringsAsFactors=FALSE)
    
    for (pid in unique(snap$project_station_id)) {
        s_city <- sel[sel$project_station_id == pid, "city"]
        for (p in c("pm2_5", "pm10", "no2", "so2", "co", "o3")) {
            sub <- df[df$project_station_id == pid & df$parameter == p, ]
            
            vh_sub <- sub[!is.na(sub$value_source), ]
            vh <- length(unique(vh_sub$timestamp_local))
            sh <- sum(is.na(sub$value_source))
            mh <- exp_hr - vh
            c_pct <- round((vh / exp_hr) * 100, 2)
            
            ft <- if(nrow(vh_sub) > 0) min(vh_sub$timestamp_local, na.rm=TRUE) else NA
            lt <- if(nrow(vh_sub) > 0) max(vh_sub$timestamp_local, na.rm=TRUE) else NA
            
            qc <- "No Data"
            if (c_pct >= 75) qc <- "Strong"
            else if (c_pct >= 50) qc <- "Usable"
            else if (c_pct > 0) qc <- "Weak"
            
            comp_rows[[length(comp_rows)+1]] <- data.frame(
                chunk_id = ym,
                project_station_id = pid,
                city = s_city,
                parameter = p,
                expected_hour_count = exp_hr,
                distinct_valid_hour_count = vh,
                source_null_value_count = sh,
                missing_hour_count = mh,
                hourly_completeness_pct = c_pct,
                first_observed_timestamp = ft,
                last_observed_timestamp = lt,
                quality_class = qc,
                stringsAsFactors = FALSE
            )
        }
    }
}

comp_all <- do.call(rbind, comp_rows)
write.csv(comp_all, "data/metadata/phase2B_monthly_completeness.csv", row.names=FALSE)

log_info("Generating Station History Summaries...")
hist_rows <- list()
for (pid in unique(snap$project_station_id)) {
    for (p in c("pm2_5", "pm10", "no2", "so2", "co", "o3")) {
        sub <- comp_all[comp_all$project_station_id == pid & comp_all$parameter == p, ]
        sub <- sub[order(sub$chunk_id), ]
        
        tot_exp <- sum(sub$expected_hour_count)
        tot_val <- sum(sub$distinct_valid_hour_count)
        ov_pct <- round((tot_val / tot_exp) * 100, 2)
        
        m_s <- sum(sub$quality_class == "Strong")
        m_u <- sum(sub$quality_class == "Usable")
        m_w <- sum(sub$quality_class == "Weak")
        m_n <- sum(sub$quality_class == "No Data")
        
        # Longest consecutive weak/no-data
        cw <- 0
        mcw <- 0
        for (qc in sub$quality_class) {
            if (qc %in% c("Weak", "No Data")) {
                cw <- cw + 1
                if (cw > mcw) mcw <- cw
            } else {
                cw <- 0
            }
        }
        
        ft <- min(sub$first_observed_timestamp, na.rm=TRUE)
        lt <- max(sub$last_observed_timestamp, na.rm=TRUE)
        if (is.infinite(ft)) ft <- NA
        if (is.infinite(lt)) lt <- NA
        
        rd <- "Review"
        if (ov_pct >= 75 && mcw < 3) rd <- "Ready"
        
        hist_rows[[length(hist_rows)+1]] <- data.frame(
            project_station_id = pid,
            parameter = p,
            total_expected_hours = tot_exp,
            total_valid_hours = tot_val,
            overall_completeness_pct = ov_pct,
            months_strong = m_s,
            months_usable = m_u,
            months_weak = m_w,
            months_no_data = m_n,
            longest_consecutive_weak_months = mcw,
            first_valid_timestamp = ft,
            last_valid_timestamp = lt,
            historical_readiness = rd,
            stringsAsFactors = FALSE
        )
    }
}
hist_all <- do.call(rbind, hist_rows)
write.csv(hist_all, "data/metadata/phase2B_station_history_summary.csv", row.names=FALSE)

log_info("Generating City Summaries...")
# Hyderabad
h_stat <- sel$project_station_id[sel$use_hyderabad == TRUE]
hyd_sub <- hist_all[hist_all$project_station_id %in% h_stat, ]
write.csv(hyd_sub, "data/metadata/phase2B_hyderabad_history_summary.csv", row.names=FALSE)

# India
i_stat <- sel$project_station_id[sel$use_india == TRUE]
ind_sub <- hist_all[hist_all$project_station_id %in% i_stat, ]
write.csv(ind_sub, "data/metadata/phase2B_india_history_summary.csv", row.names=FALSE)

log_info("Generating Quality Flags...")
q_rows <- list()

for (pid in unique(snap$project_station_id)) {
    for (p in c("pm2_5", "pm10", "no2", "so2", "co", "o3")) {
        sub <- comp_all[comp_all$project_station_id == pid & comp_all$parameter == p, ]
        sub <- sub[order(sub$chunk_id), ]
        
        in_run <- FALSE
        run_start <- NA
        run_end <- NA
        run_w <- 0
        run_n <- 0
        run_months <- 0
        
        for (i in 1:nrow(sub)) {
            qc <- sub$quality_class[i]
            is_bad <- qc %in% c("Weak", "No Data")
            
            if (is_bad) {
                if (!in_run) {
                    in_run <- TRUE
                    run_start <- sub$chunk_id[i]
                    run_w <- 0
                    run_n <- 0
                    run_months <- 0
                }
                run_end <- sub$chunk_id[i]
                run_months <- run_months + 1
                if (qc == "Weak") run_w <- run_w + 1
                if (qc == "No Data") run_n <- run_n + 1
            } else {
                if (in_run) {
                    # Close run
                    sev <- ifelse(run_months >= 3, "High", "Medium")
                    iss <- paste(p, "has weak/no-data months")
                    evid <- sprintf("%d months weak, %d months no-data", run_w, run_n)
                    
                    q_rows[[length(q_rows)+1]] <- data.frame(
                        project_station_id = pid,
                        city = sel$city[sel$project_station_id == pid][1],
                        station_name = sel$station_name[sel$project_station_id == pid][1],
                        parameter = p,
                        issue_type = iss,
                        start_month = run_start,
                        end_month = run_end,
                        months_affected = run_months,
                        weak_month_count = run_w,
                        no_data_month_count = run_n,
                        severity = sev,
                        evidence = evid,
                        stringsAsFactors = FALSE
                    )
                    in_run <- FALSE
                }
            }
        }
        
        # Check if ended in a run
        if (in_run) {
            sev <- ifelse(run_months >= 3, "High", "Medium")
            iss <- paste(p, "has weak/no-data months")
            evid <- sprintf("%d months weak, %d months no-data", run_w, run_n)
            
            q_rows[[length(q_rows)+1]] <- data.frame(
                project_station_id = pid,
                city = sel$city[sel$project_station_id == pid][1],
                station_name = sel$station_name[sel$project_station_id == pid][1],
                parameter = p,
                issue_type = iss,
                start_month = run_start,
                end_month = run_end,
                months_affected = run_months,
                weak_month_count = run_w,
                no_data_month_count = run_n,
                severity = sev,
                evidence = evid,
                stringsAsFactors = FALSE
            )
        }
    }
}

if (length(q_rows) > 0) {
    qf_all <- do.call(rbind, q_rows)
    write.csv(qf_all, "data/metadata/phase2B_quality_flags.csv", row.names=FALSE)
} else {
    write.csv(data.frame(project_station_id=character(), city=character(), station_name=character(), parameter=character(), issue_type=character(), start_month=character(), end_month=character(), months_affected=integer(), weak_month_count=integer(), no_data_month_count=integer(), severity=character(), evidence=character()), "data/metadata/phase2B_quality_flags.csv", row.names=FALSE)
}

log_info("Rebuilding summaries complete.")
