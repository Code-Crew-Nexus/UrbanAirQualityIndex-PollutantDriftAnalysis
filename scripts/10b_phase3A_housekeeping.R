library(dplyr)
library(readr)
library(ggplot2)
library(tidyr)


# Load data
master <- read_csv("data/processed/UAQI_Master_Daily.csv", show_col_types = FALSE)

# STAGE 0A: Correct missingness
missingness_corrected <- master %>%
  group_by(project_station_id, year, month) %>%
  summarize(
    total = n(),
    missing_aqi = sum(is.na(aqi_verified)),
    missing_aqi_pct = missing_aqi/total*100,
    missing_pm25 = sum(is.na(pm2_5_aqi_input)),
    missing_pm10 = sum(is.na(pm10_aqi_input)),
    missing_o3 = sum(is.na(o3_8h_max)),
    missing_weather = sum(is.na(temperature)),
    .groups = "drop"
  )
write_csv(missingness_corrected, "analysis/phase3B/tables/phase3B_corrected_missingness_profile.csv")

station_outage <- master %>%
  arrange(project_station_id, date) %>%
  group_by(project_station_id) %>%
  summarize(
    total_days = n(),
    missing_days = sum(is.na(aqi_verified)),
    longest_invalid_aqi_run = { r <- rle(as.numeric(is.na(aqi_verified))); max(c(0, r$lengths[r$values == 1])) },
    .groups = "drop"
  )
write_csv(station_outage, "analysis/phase3B/tables/phase3B_station_outage_summary.csv")

# STAGE 0B: Missing Correlation Heatmaps
# We use the correlation tables from Phase 3A to generate heatmaps
hyd_pearson <- read_csv("analysis/phase3A/tables/phase3A_hyd_pearson.csv", show_col_types = FALSE)
ind_spearman <- read_csv("analysis/phase3A/tables/phase3A_ind_spearman.csv", show_col_types = FALSE) # just plotting one for each as example

plot_heatmap <- function(df, filename, title) {
  df_long <- df %>% pivot_longer(cols = -variable, names_to = "variable.1", values_to = "value")
  p <- ggplot(df_long, aes(x=variable, y=variable.1, fill=value)) +
    geom_tile() +
    scale_fill_gradient2(low="blue", high="red", mid="white", midpoint=0, limit=c(-1,1)) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle=45, hjust=1)) +
    labs(title=title, x="", y="")
  ggsave(filename, p, width=8, height=6)
}

plot_heatmap(hyd_pearson, "analysis/phase3A/figures/11_pearson_correlation_heatmap.png", "Pearson Correlation Heatmap (Hyderabad)")
plot_heatmap(ind_spearman, "analysis/phase3A/figures/12_spearman_correlation_heatmap.png", "Spearman Correlation Heatmap (India)")
