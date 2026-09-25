# 12_phase3C_statistical_inference.R

library(dplyr)
library(readr)
library(tidyr)
library(purrr)
library(ggplot2)

dir.create("analysis/phase3C/figures", recursive=TRUE, showWarnings=FALSE)
dir.create("analysis/phase3C/tables", recursive=TRUE, showWarnings=FALSE)
dir.create("data/analysis/phase3C", recursive=TRUE, showWarnings=FALSE)

# Stage 0
summary_df <- read_csv("data/analysis/phase3B/phase3B_current_window_summary_for_inference.csv", show_col_types = FALSE)
obs_df <- read_csv("data/analysis/phase3B/phase3B_current_window_observations_for_inference.csv", show_col_types = FALSE)

if(nrow(summary_df) != 147) stop("Summary rows != 147")
if(sum(summary_df$test_eligible) != 131) stop("Eligible != 131")
if(sum(!summary_df$test_eligible) != 16) stop("Ineligible != 16")
if(nrow(obs_df) != 17640) stop("Obs rows != 17640")

# Helpers
calc_hedges_g <- function(x_recent, x_baseline) {
  n1 <- sum(!is.na(x_recent))
  n2 <- sum(!is.na(x_baseline))
  if (n1 < 2 | n2 < 2) return(list(g=NA, g_adj=NA))
  
  m1 <- mean(x_recent, na.rm=TRUE)
  m2 <- mean(x_baseline, na.rm=TRUE)
  
  v1 <- var(x_recent, na.rm=TRUE)
  v2 <- var(x_baseline, na.rm=TRUE)
  
  s_pool <- sqrt(((n1 - 1)*v1 + (n2 - 1)*v2) / (n1 + n2 - 2))
  if(s_pool == 0) return(list(g=NA, g_adj=NA))
  
  g <- (m1 - m2) / s_pool
  
  df <- n1 + n2 - 2
  J <- 1 - (3 / (4*df - 1))
  g_adj <- g * J
  
  return(list(g=g, g_adj=g_adj))
}

calc_cliffs_delta <- function(x_recent, x_baseline) {
  # O(n1*n2) exact Cliff's delta
  v1 <- x_recent[!is.na(x_recent)]
  v2 <- x_baseline[!is.na(x_baseline)]
  if(length(v1) == 0 | length(v2) == 0) return(NA_real_)
  
  # Outer subtraction: recent - baseline
  mat <- outer(v1, v2, FUN = function(a, b) sign(a - b))
  mean(mat)
}

get_boot_indices <- function(N, L) {
  k <- ceiling(N / L)
  starts <- sample(1:N, k, replace = TRUE)
  idx <- unlist(lapply(starts, function(s) seq(s, s + L - 1)))
  idx <- ifelse(idx > N, idx - N, idx)
  idx[1:N]
}

run_block_bootstrap <- function(vec_baseline, vec_recent, L, B=5000) {
  # Common mean
  X_bar <- mean(c(vec_baseline, vec_recent), na.rm=TRUE)
  
  B_mean <- mean(vec_baseline, na.rm=TRUE)
  R_mean <- mean(vec_recent, na.rm=TRUE)
  
  if(is.na(B_mean) | is.na(R_mean)) return(list(p_val=NA, diff=NA, ci_low=NA, ci_high=NA))
  
  obs_diff <- R_mean - B_mean
  
  B_cent <- vec_baseline - B_mean + X_bar
  R_cent <- vec_recent - R_mean + X_bar
  
  N_B <- length(vec_baseline) # 90
  N_R <- length(vec_recent) # 30
  
  null_diffs <- numeric(B)
  unc_diffs <- numeric(B)
  
  valid_b <- 0
  while(valid_b < B) {
    idx_B <- get_boot_indices(N_B, L)
    idx_R <- get_boot_indices(N_R, L)
    
    b_cent_star <- B_cent[idx_B]
    r_cent_star <- R_cent[idx_R]
    
    b_unc_star <- vec_baseline[idx_B]
    r_unc_star <- vec_recent[idx_R]
    
    m_b_cent <- mean(b_cent_star, na.rm=TRUE)
    m_r_cent <- mean(r_cent_star, na.rm=TRUE)
    
    m_b_unc <- mean(b_unc_star, na.rm=TRUE)
    m_r_unc <- mean(r_unc_star, na.rm=TRUE)
    
    if(!is.na(m_b_cent) & !is.na(m_r_cent) & !is.na(m_b_unc) & !is.na(m_r_unc)) {
      valid_b <- valid_b + 1
      null_diffs[valid_b] <- m_r_cent - m_b_cent
      unc_diffs[valid_b] <- m_r_unc - m_b_unc
    }
  }
  
  p_val <- (1 + sum(abs(null_diffs) >= abs(obs_diff))) / (B + 1)
  ci <- quantile(unc_diffs, probs = c(0.025, 0.975), na.rm=TRUE)
  
  list(
    p_val = p_val,
    diff = obs_diff,
    ci_low = as.numeric(ci[1]),
    ci_high = as.numeric(ci[2])
  )
}

results_list <- list()

# Sort obs_df just to be safe
obs_df <- obs_df %>% arrange(project_station_id, variable, observation_date)

set.seed(20260925)

for(i in 1:nrow(summary_df)) {
  row_info <- summary_df[i, ]
  sid <- row_info$project_station_id
  v <- row_info$variable
  
  cat(sprintf("Testing %s %s...\n", sid, v))
  
  sub_obs <- obs_df %>% filter(project_station_id == sid, variable == v)
  vec_baseline <- sub_obs %>% filter(window_type == "BASELINE") %>% pull(value)
  vec_recent <- sub_obs %>% filter(window_type == "RECENT") %>% pull(value)
  
  # Initialize result row with safe defaults
  res <- as.list(row_info)
  res$test_performed <- FALSE
  res$inference_status <- "NOT_TESTED_INSUFFICIENT_DATA"
  
  res$baseline_min <- min(vec_baseline, na.rm=TRUE)
  res$baseline_max <- max(vec_baseline, na.rm=TRUE)
  res$recent_min <- min(vec_recent, na.rm=TRUE)
  res$recent_max <- max(vec_recent, na.rm=TRUE)
  
  # Fix Inf
  if(is.infinite(res$baseline_min)) {
    res$baseline_min <- NA
    res$baseline_max <- NA
  }
  if(is.infinite(res$recent_min)) {
    res$recent_min <- NA
    res$recent_max <- NA
  }
  
  # ACFs
  if(sum(!is.na(vec_baseline)) > 10) {
    ac_b <- acf(vec_baseline, plot=FALSE, na.action=na.pass)
    res$baseline_acf1 <- ac_b$acf[2]
    res$baseline_acf7 <- if(length(ac_b$acf) >= 8) ac_b$acf[8] else NA
  } else {
    res$baseline_acf1 <- NA; res$baseline_acf7 <- NA
  }
  
  if(sum(!is.na(vec_recent)) > 10) {
    ac_r <- acf(vec_recent, plot=FALSE, na.action=na.pass)
    res$recent_acf1 <- ac_r$acf[2]
    res$recent_acf7 <- if(length(ac_r$acf) >= 8) ac_r$acf[8] else NA
  } else {
    res$recent_acf1 <- NA; res$recent_acf7 <- NA
  }
  
  if(!row_info$test_eligible) {
    results_list[[i]] <- as_tibble(res)
    next
  }
  
  res$test_performed <- TRUE
  res$inference_status <- "TESTED"
  
  # Shapiro
  if(sum(!is.na(vec_baseline)) >= 3) {
    sh_b <- tryCatch(shapiro.test(vec_baseline[!is.na(vec_baseline)]), error=function(e) list(statistic=NA, p.value=NA))
    res$shapiro_baseline_w <- sh_b$statistic
    res$shapiro_baseline_p <- sh_b$p.value
  } else {
    res$shapiro_baseline_w <- NA; res$shapiro_baseline_p <- NA
  }
  
  if(sum(!is.na(vec_recent)) >= 3) {
    sh_r <- tryCatch(shapiro.test(vec_recent[!is.na(vec_recent)]), error=function(e) list(statistic=NA, p.value=NA))
    res$shapiro_recent_w <- sh_r$statistic
    res$shapiro_recent_p <- sh_r$p.value
  } else {
    res$shapiro_recent_w <- NA; res$shapiro_recent_p <- NA
  }
  
  # Welch
  wt <- tryCatch(t.test(vec_recent, vec_baseline, var.equal=FALSE), error=function(e) list(statistic=NA, parameter=NA, p.value=NA))
  res$welch_t <- wt$statistic
  res$welch_df <- wt$parameter
  res$welch_p_raw <- wt$p.value
  
  # Wilcoxon
  wx <- tryCatch(wilcox.test(vec_recent, vec_baseline, exact=FALSE), error=function(e) list(statistic=NA, p.value=NA))
  res$wilcox_statistic <- wx$statistic
  res$wilcox_p_raw <- wx$p.value
  
  # Effect sizes
  he <- calc_hedges_g(vec_recent, vec_baseline)
  res$hedges_g <- he$g_adj
  res$hedges_g_magnitude <- case_when(
    is.na(res$hedges_g) ~ NA_character_,
    abs(res$hedges_g) < 0.2 ~ "very small",
    abs(res$hedges_g) < 0.5 ~ "small",
    abs(res$hedges_g) < 0.8 ~ "moderate",
    TRUE ~ "large"
  )
  
  cd <- calc_cliffs_delta(vec_recent, vec_baseline)
  res$cliffs_delta <- cd
  res$cliffs_delta_magnitude <- case_when(
    is.na(cd) ~ NA_character_,
    abs(cd) < 0.147 ~ "negligible",
    abs(cd) < 0.33 ~ "small",
    abs(cd) < 0.474 ~ "medium",
    TRUE ~ "large"
  )
  
  # Block Bootstrap
  bb7 <- run_block_bootstrap(vec_baseline, vec_recent, 7, 2000)
  res$block7_mean_diff <- bb7$diff
  res$block7_ci_low <- bb7$ci_low
  res$block7_ci_high <- bb7$ci_high
  res$p_block7_raw <- bb7$p_val
  res$block7_ci_excludes_zero <- (bb7$ci_low > 0) | (bb7$ci_high < 0)
  
  bb3 <- run_block_bootstrap(vec_baseline, vec_recent, 3, 2000)
  res$p_block3_raw <- bb3$p_val
  
  bb14 <- run_block_bootstrap(vec_baseline, vec_recent, 14, 2000)
  res$p_block14_raw <- bb14$p_val
  
  results_list[[i]] <- as_tibble(res)
}
master_res <- bind_rows(results_list)

# BH Corrections
# Global across all eligible tests
master_res <- master_res %>%
  mutate(
    p_block7_bh_global = if_else(test_performed, p.adjust(p_block7_raw, method="BH"), NA_real_),
    welch_p_bh_global = if_else(test_performed, p.adjust(welch_p_raw, method="BH"), NA_real_),
    wilcox_p_bh_global = if_else(test_performed, p.adjust(wilcox_p_raw, method="BH"), NA_real_)
  )

# Within-variable BH correction
master_res <- master_res %>%
  group_by(variable) %>%
  mutate(
    p_block7_bh_within_variable = if_else(test_performed, p.adjust(p_block7_raw, method="BH"), NA_real_)
  ) %>%
  ungroup()

# Statistical Support
master_res <- master_res %>%
  mutate(
    mean_difference = recent_mean - baseline_mean,
    statistical_support = case_when(
      !test_performed ~ "NOT_TESTED_INSUFFICIENT_DATA",
      (p_block7_bh_global < 0.05) & (block7_ci_low > 0) & (mean_difference > 0) ~ "SUPPORTED_UPWARD_SHIFT",
      (p_block7_bh_global < 0.05) & (block7_ci_high < 0) & (mean_difference < 0) ~ "SUPPORTED_DOWNWARD_SHIFT",
      TRUE ~ "NOT_STATISTICALLY_SUPPORTED"
    ),
    
    robustness_agreement = case_when(
      !test_performed ~ "NOT_TESTED_INSUFFICIENT_DATA",
      statistical_support != "NOT_STATISTICALLY_SUPPORTED" & welch_p_bh_global < 0.05 & wilcox_p_bh_global < 0.05 ~ "ALL_METHODS_AGREE",
      statistical_support != "NOT_STATISTICALLY_SUPPORTED" & welch_p_bh_global < 0.05 & wilcox_p_bh_global >= 0.05 ~ "BLOCK_AND_WELCH",
      statistical_support != "NOT_STATISTICALLY_SUPPORTED" & welch_p_bh_global >= 0.05 & wilcox_p_bh_global < 0.05 ~ "BLOCK_AND_WILCOX",
      statistical_support != "NOT_STATISTICALLY_SUPPORTED" & welch_p_bh_global >= 0.05 & wilcox_p_bh_global >= 0.05 ~ "BLOCK_ONLY",
      statistical_support == "NOT_STATISTICALLY_SUPPORTED" & (welch_p_bh_global < 0.05 | wilcox_p_bh_global < 0.05) ~ "CLASSICAL_ONLY",
      statistical_support == "NOT_STATISTICALLY_SUPPORTED" & welch_p_bh_global >= 0.05 & wilcox_p_bh_global >= 0.05 ~ "NO_METHOD_SUPPORT",
      TRUE ~ "MIXED_DIRECTION_OR_RESULT"
    ),
    
    variable_type = case_when(
      variable == "aqi_verified" ~ "VERIFIED_SUBSET_AQI_INFERENCE",
      variable %in% c("pm2_5_aqi_input", "pm10_aqi_input", "o3_8h_max") ~ "VERIFIED_POLLUTANT_INFERENCE",
      TRUE ~ "SOURCE_SCALE_GAS"
    ),
    
    physical_unit_verified = if_else(variable_type == "SOURCE_SCALE_GAS", FALSE, TRUE),
    inference_notes = ""
  )

write_csv(master_res, "data/analysis/phase3C/phase3C_current_drift_inference_results.csv")

# Sub-tables
supported <- master_res %>% filter(statistical_support %in% c("SUPPORTED_UPWARD_SHIFT", "SUPPORTED_DOWNWARD_SHIFT")) %>%
  select(project_station_id, station_name, variable, drift_z, mean_difference, hedges_g, cliffs_delta, p_block7_bh_global, block7_ci_low, block7_ci_high)
write_csv(supported, "data/analysis/phase3C/phase3C_supported_shifts.csv")

large_unc <- master_res %>% filter(abs(drift_z) >= 1, statistical_support == "NOT_STATISTICALLY_SUPPORTED")
write_csv(large_unc, "data/analysis/phase3C/phase3C_large_but_uncertain_drifts.csv")

small_sup <- supported %>% filter(abs(hedges_g) < 0.5 | abs(drift_z) < 0.5)
write_csv(small_sup, "data/analysis/phase3C/phase3C_small_but_supported_shifts.csv")

hyd_inf <- master_res %>% filter(project_station_id %in% c("PROJ_001", "PROJ_002", "PROJ_003", "PROJ_004", "PROJ_005", "PROJ_006", "PROJ_007"))
write_csv(hyd_inf, "data/analysis/phase3C/phase3C_hyderabad_inference.csv")

# India representative stations (which include Zoo Park)
ind_stations <- obs_df %>% filter(grepl("PROJ", project_station_id)) %>% distinct(project_station_id) %>% pull(project_station_id)
# Wait, let's just get the 15 from master
master_all <- read_csv("data/processed/UAQI_Master_Daily.csv", show_col_types = FALSE)
ind_stations <- master_all %>% filter(use_india == TRUE) %>% distinct(project_station_id) %>% pull(project_station_id)
ind_inf <- master_res %>% filter(project_station_id %in% ind_stations)
write_csv(ind_inf, "data/analysis/phase3C/phase3C_india_inference.csv")

var_sum <- master_res %>%
  group_by(variable) %>%
  summarize(
    eligible_tests = sum(test_performed),
    supported_upward = sum(statistical_support == "SUPPORTED_UPWARD_SHIFT", na.rm=TRUE),
    supported_downward = sum(statistical_support == "SUPPORTED_DOWNWARD_SHIFT", na.rm=TRUE),
    not_supported = sum(statistical_support == "NOT_STATISTICALLY_SUPPORTED", na.rm=TRUE),
    median_abs_drift_z = median(abs(drift_z[test_performed]), na.rm=TRUE),
    median_abs_hedges_g = median(abs(hedges_g[test_performed]), na.rm=TRUE),
    median_abs_cliffs_delta = median(abs(cliffs_delta[test_performed]), na.rm=TRUE),
    median_baseline_acf1 = median(baseline_acf1[test_performed], na.rm=TRUE),
    median_recent_acf1 = median(recent_acf1[test_performed], na.rm=TRUE),
    source_semantic_status = first(variable_type),
    .groups="drop"
  )
write_csv(var_sum, "analysis/phase3C/tables/phase3C_variable_inference_summary.csv")

stat_sum <- master_res %>%
  group_by(project_station_id) %>%
  summarize(
    eligible_variables = sum(test_performed),
    supported_upward_shifts = sum(statistical_support == "SUPPORTED_UPWARD_SHIFT", na.rm=TRUE),
    supported_downward_shifts = sum(statistical_support == "SUPPORTED_DOWNWARD_SHIFT", na.rm=TRUE),
    non_supported_shifts = sum(statistical_support == "NOT_STATISTICALLY_SUPPORTED", na.rm=TRUE),
    verified_pollutant_support = sum(statistical_support %in% c("SUPPORTED_UPWARD_SHIFT", "SUPPORTED_DOWNWARD_SHIFT") & variable_type == "VERIFIED_POLLUTANT_INFERENCE", na.rm=TRUE),
    aqi_support = sum(statistical_support %in% c("SUPPORTED_UPWARD_SHIFT", "SUPPORTED_DOWNWARD_SHIFT") & variable_type == "VERIFIED_SUBSET_AQI_INFERENCE", na.rm=TRUE),
    source_scale_gas_support = sum(statistical_support %in% c("SUPPORTED_UPWARD_SHIFT", "SUPPORTED_DOWNWARD_SHIFT") & variable_type == "SOURCE_SCALE_GAS", na.rm=TRUE),
    .groups="drop"
  )
write_csv(stat_sum, "analysis/phase3C/tables/phase3C_station_inference_summary.csv")
# Visualizations
plot_inf <- function(var_name, title, filename) {
  df <- master_res %>% filter(variable == var_name, test_performed)
  if(nrow(df) == 0) return(NULL)
  p <- ggplot(df, aes(x=reorder(project_station_id, drift_z), y=drift_z, fill=statistical_support)) +
    geom_col() + coord_flip() +
    geom_errorbar(aes(ymin=block7_ci_low/baseline_sd, ymax=block7_ci_high/baseline_sd), width=0.2) +
    theme_minimal() + labs(title=title, x="Station", y="Drift Z with Bootstrap CI")
  ggsave(filename, p, width=8, height=6)
}

plot_inf("pm2_5_aqi_input", "Current PM2.5 drift_z vs CI", "analysis/phase3C/figures/01_pm25_inference.png")
plot_inf("pm10_aqi_input", "Current PM10 inference", "analysis/phase3C/figures/02_pm10_inference.png")
plot_inf("o3_8h_max", "Current O3 inference", "analysis/phase3C/figures/03_o3_inference.png")
plot_inf("aqi_verified", "Current Verified AQI inference", "analysis/phase3C/figures/04_aqi_inference.png")

# Heatmaps
hyd_hm <- hyd_inf %>% filter(test_performed) %>%
  mutate(val = case_when(statistical_support == "SUPPORTED_UPWARD_SHIFT" ~ 1, statistical_support == "SUPPORTED_DOWNWARD_SHIFT" ~ -1, TRUE ~ 0))
p5 <- ggplot(hyd_hm, aes(x=variable, y=project_station_id, fill=val)) + geom_tile() + scale_fill_gradient2(low="blue", high="red", mid="white", midpoint=0) + theme_minimal() + labs(title="Hyderabad Supported Shifts")
ggsave("analysis/phase3C/figures/05_hyd_support_heatmap.png", p5, width=8, height=6)

ind_hm <- ind_inf %>% filter(test_performed) %>%
  mutate(val = case_when(statistical_support == "SUPPORTED_UPWARD_SHIFT" ~ 1, statistical_support == "SUPPORTED_DOWNWARD_SHIFT" ~ -1, TRUE ~ 0))
p6 <- ggplot(ind_hm, aes(x=variable, y=project_station_id, fill=val)) + geom_tile() + scale_fill_gradient2(low="blue", high="red", mid="white", midpoint=0) + theme_minimal() + labs(title="India Support Heatmap")
ggsave("analysis/phase3C/figures/06_ind_support_heatmap.png", p6, width=8, height=6)

p7 <- ggplot(master_res %>% filter(test_performed), aes(x=variable, y=project_station_id, fill=hedges_g)) + geom_tile() + scale_fill_gradient2(low="blue", high="red", mid="white", midpoint=0) + theme_minimal() + labs(title="Hedges g Heatmap")
ggsave("analysis/phase3C/figures/07_hedges_g_heatmap.png", p7, width=8, height=8)

p8 <- ggplot(master_res %>% filter(test_performed), aes(x=variable, y=project_station_id, fill=cliffs_delta)) + geom_tile() + scale_fill_gradient2(low="blue", high="red", mid="white", midpoint=0) + theme_minimal() + labs(title="Cliffs Delta Heatmap")
ggsave("analysis/phase3C/figures/08_cliffs_delta_heatmap.png", p8, width=8, height=8)

p9 <- ggplot(master_res %>% filter(test_performed), aes(x=p_block7_raw, y=p_block7_bh_global)) + geom_point() + geom_abline(slope=1, linetype="dashed") + theme_minimal() + labs(title="Raw vs BH Block P-Values")
ggsave("analysis/phase3C/figures/09_raw_vs_bh_pvals.png", p9, width=6, height=6)

p10 <- ggplot(master_res %>% filter(test_performed), aes(x=welch_p_bh_global, y=p_block7_bh_global)) + geom_point() + geom_abline(slope=1, linetype="dashed") + theme_minimal() + labs(title="Welch vs Block Bootstrap P-Values")
ggsave("analysis/phase3C/figures/10_welch_vs_block.png", p10, width=6, height=6)

p11 <- ggplot(master_res %>% filter(test_performed), aes(x=wilcox_p_bh_global, y=p_block7_bh_global)) + geom_point() + geom_abline(slope=1, linetype="dashed") + theme_minimal() + labs(title="Wilcoxon vs Block Bootstrap")
ggsave("analysis/phase3C/figures/11_wilcox_vs_block.png", p11, width=6, height=6)

p12 <- ggplot(master_res %>% filter(test_performed), aes(x=baseline_acf1, y=recent_acf1)) + geom_point() + geom_abline(slope=1, linetype="dashed") + theme_minimal() + labs(title="Lag-1 Autocorrelation Baseline vs Recent")
ggsave("analysis/phase3C/figures/12_acf1_comparison.png", p12, width=6, height=6)

if (nrow(large_unc) > 0) {
  p13 <- ggplot(large_unc, aes(x=drift_z, y=p_block7_bh_global)) + geom_point() + theme_minimal() + labs(title="Large but Uncertain Drifts")
  ggsave("analysis/phase3C/figures/13_large_uncertain_drifts.png", p13, width=6, height=6)
}

sup_gas <- supported %>% filter(grepl("co_|no2_|so2_", variable))
if (nrow(sup_gas) > 0) {
  p14 <- ggplot(sup_gas, aes(x=reorder(project_station_id, drift_z), y=drift_z)) + geom_col() + coord_flip() + theme_minimal() + labs(title="Supported Source-Scale Gas Shifts")
  ggsave("analysis/phase3C/figures/14_supported_gas_shifts.png", p14, width=6, height=6)
}

# 15. Selected case study
case_study_id <- master_res %>% filter(test_performed, abs(drift_z) > 1, statistical_support != "NOT_STATISTICALLY_SUPPORTED") %>% arrange(desc(abs(drift_z))) %>% head(1)
if(nrow(case_study_id) > 0) {
  c_obs <- obs_df %>% filter(project_station_id == case_study_id$project_station_id, variable == case_study_id$variable)
  p15 <- ggplot(c_obs, aes(x=value, fill=window_type)) + geom_density(alpha=0.5) + theme_minimal() + labs(title=paste("Case Study:", case_study_id$project_station_id, case_study_id$variable))
  ggsave("analysis/phase3C/figures/15_case_study_distributions.png", p15, width=8, height=6)
}

message("Phase 3C complete")

# ADDING MISSING COLUMNS
snap <- read_csv("data/analysis/phase3B/phase3B_current_drift_snapshot.csv", show_col_types = FALSE)
master_res <- master_res %>%
  left_join(snap %>% select(project_station_id, variable, city, drift_direction, drift_magnitude_class), by=c("project_station_id", "variable"))

# Ensure median_difference exists
master_res <- master_res %>% mutate(median_difference = recent_median - baseline_median)

# Re-write the master
write_csv(master_res, "data/analysis/phase3C/phase3C_current_drift_inference_results.csv")

# Also re-write supported
supported <- master_res %>% filter(statistical_support %in% c("SUPPORTED_UPWARD_SHIFT", "SUPPORTED_DOWNWARD_SHIFT")) %>%
  select(project_station_id, station_name, variable, drift_z, mean_difference, hedges_g, cliffs_delta, p_block7_bh_global, block7_ci_low, block7_ci_high)
write_csv(supported, "data/analysis/phase3C/phase3C_supported_shifts.csv")

small_sup <- supported %>% filter(abs(hedges_g) < 0.5 | abs(drift_z) < 0.5)
write_csv(small_sup, "data/analysis/phase3C/phase3C_small_but_supported_shifts.csv")

large_unc <- master_res %>% filter(abs(drift_z) >= 1, statistical_support == "NOT_STATISTICALLY_SUPPORTED")
write_csv(large_unc, "data/analysis/phase3C/phase3C_large_but_uncertain_drifts.csv")
master_res <- read_csv("data/analysis/phase3C/phase3C_current_drift_inference_results.csv", show_col_types = FALSE)
snap <- read_csv("data/analysis/phase3B/phase3B_current_drift_snapshot.csv", show_col_types = FALSE)

master_res <- master_res %>%
  left_join(snap %>% select(project_station_id, variable, city, drift_direction, drift_magnitude_class), by=c("project_station_id", "variable")) %>%
  mutate(median_difference = recent_median - baseline_median)

write_csv(master_res, "data/analysis/phase3C/phase3C_current_drift_inference_results.csv")

supported <- master_res %>% filter(statistical_support %in% c("SUPPORTED_UPWARD_SHIFT", "SUPPORTED_DOWNWARD_SHIFT")) %>%
  select(project_station_id, station_name, variable, drift_z, mean_difference, hedges_g, cliffs_delta, p_block7_bh_global, block7_ci_low, block7_ci_high)
write_csv(supported, "data/analysis/phase3C/phase3C_supported_shifts.csv")

small_sup <- supported %>% filter(abs(hedges_g) < 0.5 | abs(drift_z) < 0.5)
write_csv(small_sup, "data/analysis/phase3C/phase3C_small_but_supported_shifts.csv")

large_unc <- master_res %>% filter(abs(drift_z) >= 1, statistical_support == "NOT_STATISTICALLY_SUPPORTED")
write_csv(large_unc, "data/analysis/phase3C/phase3C_large_but_uncertain_drifts.csv")
