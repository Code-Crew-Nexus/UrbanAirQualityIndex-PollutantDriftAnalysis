source("R/00_setup.R")
source("R/01_utils.R")

log_info("Updating Acquisition Plan Status")
plan <- read.csv("data/metadata/phase2B_acquisition_plan.csv", stringsAsFactors=FALSE)
state <- read.csv("data/metadata/phase2B_acquisition_state.csv", stringsAsFactors=FALSE)
# March 2025 isn't in state but is in plan (chunk_id = 0)

for (i in 1:nrow(plan)) {
    cid <- plan$chunk_id[i]
    if (cid == 0) {
        plan$completed_sensor_requests[i] <- plan$planned_primary_requests[i]
        plan$empty_valid_responses[i] <- 0
        plan$failed_requests[i] <- 0
        plan$chunk_status[i] <- "COMPLETE"
    } else {
        c_s <- state[state$chunk_id == cid, ]
        c_r <- sum(c_s$status == "completed")
        e_r <- sum(c_s$status == "empty_valid_response")
        f_r <- sum(c_s$status %in% c("failed_retryable", "failed_terminal"))
        
        plan$completed_sensor_requests[i] <- c_r
        plan$empty_valid_responses[i] <- e_r
        plan$failed_requests[i] <- f_r
        
        if (f_r > 0) {
            plan$chunk_status[i] <- "INCOMPLETE"
        } else if (e_r > 0) {
            plan$chunk_status[i] <- "COMPLETE_WITH_EMPTY_DATA"
        } else {
            plan$chunk_status[i] <- "COMPLETE"
        }
    }
}

write.csv(plan, "data/metadata/phase2B_acquisition_plan.csv", row.names=FALSE)
log_info("Plan update complete.")
