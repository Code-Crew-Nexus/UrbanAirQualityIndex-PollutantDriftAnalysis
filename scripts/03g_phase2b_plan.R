source("R/00_setup.R")
source("R/01_utils.R")

log_info("Preparing Phase 2B Acquisition Plan")

periods <- c(
    "2025-04-01 to 2025-04-30",
    "2025-05-01 to 2025-05-31",
    "2025-06-01 to 2025-06-30",
    "2025-07-01 to 2025-07-31",
    "2025-08-01 to 2025-08-31",
    "2025-09-01 to 2025-09-30",
    "2025-10-01 to 2025-10-31",
    "2025-11-01 to 2025-11-30",
    "2025-12-01 to 2025-12-31",
    "2026-01-01 to 2026-01-31",
    "2026-02-01 to 2026-02-28",
    "2026-03-01 to 2026-03-31",
    "2026-04-01 to 2026-04-30",
    "2026-05-01 to 2026-05-31",
    "2026-06-01 to 2026-06-30",
    "2026-07-01 to 2026-07-31",
    "2026-08-01 to 2026-08-31",
    "2026-09-01 to 2026-09-21"
)

plan <- data.frame(
    chunk_id = 1:18,
    period = periods,
    sensors_per_chunk = 126,
    approximate_requests = 126,
    max_hours_in_chunk = 744,
    status = "PLANNED",
    stringsAsFactors=FALSE
)

write.csv(plan, "data/metadata/phase2B_acquisition_plan.csv", row.names=FALSE)
log_info("Phase 2B Acquisition Plan generated.")
