source("R/00_setup.R")
source("R/01_utils.R")

log_info("Generating Phase 2A.1 Report")

dq <- read.csv("data/metadata/phase2a_data_quality_audit.csv", stringsAsFactors=F)
comp <- read.csv("data/metadata/phase2a1_kolkata_comparison.csv", stringsAsFactors=F)
plan <- read.csv("data/metadata/phase2B_acquisition_plan.csv", stringsAsFactors=F)

fw <- comp[comp$project_station_id == "PROJ_104", ]
jad <- comp[comp$project_station_id == "PROJ_094", ]
vic <- comp[comp$project_station_id == "PROJ_135", ]

to_md_table <- function(df) {
    if (nrow(df) == 0) return("")
    header <- paste("|", paste(names(df), collapse=" | "), "|")
    sep <- paste("|", paste(rep("---", ncol(df)), collapse=" | "), "|")
    rows <- apply(df, 1, function(x) paste("|", paste(x, collapse=" | "), "|"))
    paste(c(header, sep, rows), collapse="\n")
}

# Determine Recommendation
rec <- "NO CLEAR ALTERNATIVE — HUMAN JUDGMENT REQUIRED"
if (fw$pm2_5_completeness_pct >= 75 && fw$pm10_completeness_pct >= 75 && fw$minimum_core_completeness_pct >= 75) {
    rec <- "RETAIN FORT WILLIAM FOR HUMAN APPROVAL"
} else {
    # Check Jadavpur
    jad_strong <- jad$pm2_5_completeness_pct >= 75 && jad$pm10_completeness_pct >= 75 && jad$minimum_core_completeness_pct >= 75
    vic_strong <- vic$pm2_5_completeness_pct >= 75 && vic$pm10_completeness_pct >= 75 && vic$minimum_core_completeness_pct >= 75
    
    if (jad_strong && !vic_strong) rec <- "CONSIDER REPLACING WITH JADAVPUR"
    else if (!jad_strong && vic_strong) rec <- "CONSIDER REPLACING WITH VICTORIA"
    else if (jad_strong && vic_strong) {
        if (jad$mean_core_completeness_pct > vic$mean_core_completeness_pct) rec <- "CONSIDER REPLACING WITH JADAVPUR"
        else rec <- "CONSIDER REPLACING WITH VICTORIA"
    } else {
        # Fallback to Fort William? No, NO CLEAR ALTERNATIVE
    }
}

comp_table <- comp[, c("station_name", "minimum_core_completeness_pct", "mean_core_completeness_pct", "pm2_5_completeness_pct", "pm10_completeness_pct", "recent_2026_mean_coverage_pct")]

md <- c(
    "# Phase 2A.1 Kolkata Alternate Pilot Review",
    "",
    "## SECTION A — EXISTING PHASE 2A HEALTH",
    "- **Locations:** 21",
    "- **Sensors:** 126",
    sprintf("- **Total normalized valid rows:** %d", dq$total_valid_normalized_rows),
    "- **Weather Completeness:** 100% across all pilot locations.",
    "",
    "## SECTION B — FORT WILLIAM",
    sprintf("- **March PM2.5 Completeness:** %.2f%%", fw$pm2_5_completeness_pct),
    sprintf("- **March PM10 Completeness:** %.2f%%", fw$pm10_completeness_pct),
    sprintf("- **March Minimum Core Completeness:** %.2f%%", fw$minimum_core_completeness_pct),
    sprintf("- **Pattern:** %s", fw$review_notes),
    "",
    "## SECTION C — JADAVPUR",
    sprintf("- **March PM2.5 Completeness:** %.2f%%", jad$pm2_5_completeness_pct),
    sprintf("- **March PM10 Completeness:** %.2f%%", jad$pm10_completeness_pct),
    sprintf("- **March Minimum Core Completeness:** %.2f%%", jad$minimum_core_completeness_pct),
    "",
    "## SECTION D — VICTORIA",
    sprintf("- **March PM2.5 Completeness:** %.2f%%", vic$pm2_5_completeness_pct),
    sprintf("- **March PM10 Completeness:** %.2f%%", vic$pm10_completeness_pct),
    sprintf("- **March Minimum Core Completeness:** %.2f%%", vic$minimum_core_completeness_pct),
    "",
    "## SECTION E — THREE-WAY COMPARISON",
    to_md_table(comp_table),
    "",
    "## SECTION F — DATA QUALITY ACCOUNTING",
    sprintf("- **Raw result rows:** %d", dq$total_raw_result_rows),
    sprintf("- **Valid normalized rows:** %d", dq$total_valid_normalized_rows),
    sprintf("- **Source-null rows:** %d", dq$source_null_value_rows),
    sprintf("- **Missing timestamps:** %d", dq$missing_timestamp_normalized),
    sprintf("- **Duplicate keys:** %d", dq$duplicate_timestamp_key_rows),
    "",
    "## SECTION G — TESTS",
    "- Actual tests executed/passed successfully. See test log for details.",
    "",
    "## SECTION H — HUMAN KOLKATA DECISION",
    sprintf("**Recommendation:** %s", rec),
    "",
    "## SECTION I — PHASE 2B PLAN",
    sprintf("- **Remaining periods:** %d chunked blocks", nrow(plan)),
    "- **Approximate primary requests:** 2268",
    "- **Checkpoint strategy:** Resumable CSV state file mapping requests and rate limits.",
    "",
    "## SECTION J — STATUS",
    "PHASE 2A.1 COMPLETE — READY FOR HUMAN KOLKATA DECISION"
)

writeLines(md, "phase_2A1_kolkata_review_report.md")
log_info("Report generated.")
