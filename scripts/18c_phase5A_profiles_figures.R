# ==============================================================================
# scripts/18c_phase5A_profiles_figures.R
# Phase 5A: Cluster Profiling, Labeling, Regime Shifts & Publication Figures
# ==============================================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(tibble)
  library(ggplot2)
})

cat(">>> Running Phase 5A Profiling & Figures Pipeline...\n")

# 1. Load Data
hyd_hist <- read_csv("data/analysis/phase5A/Hyderabad_PCA_History.csv", show_col_types = FALSE)
ind_hist <- read_csv("data/analysis/phase5A/India_PCA_History.csv", show_col_types = FALSE)
hyd_rec  <- read_csv("data/analysis/phase5A/Hyderabad_Recent_Cluster_Assignments.csv", show_col_types = FALSE)
ind_rec  <- read_csv("data/analysis/phase5A/India_Recent_Cluster_Assignments.csv", show_col_types = FALSE)

pca_var  <- read_csv("analysis/phase5A/tables/phase5A_pca_variance_explained.csv", show_col_types = FALSE)
pca_load <- read_csv("analysis/phase5A/tables/phase5A_pca_loadings.csv", show_col_types = FALSE)
pca_sel  <- read_csv("analysis/phase5A/tables/phase5A_pca_selection.csv", show_col_types = FALSE)
k_diag   <- read_csv("analysis/phase5A/tables/phase5A_k_selection_diagnostics.csv", show_col_types = FALSE)
cents_df <- read_csv("analysis/phase5A/tables/phase5A_cluster_centroids_pca.csv", show_col_types = FALSE)

pca_features <- c(
  "pm2_5_aqi_input",
  "pm10_aqi_input",
  "o3_8h_max",
  "temperature",
  "humidity",
  "wind_speed"
)

# 2. Raw-Scale Cluster Profiles (phase5A_cluster_profiles.csv)
scopes_data <- list(
  HYDERABAD = list(hist = hyd_hist, rec = hyd_rec),
  INDIA     = list(hist = ind_hist, rec = ind_rec)
)

profiles_list <- list()
for (scope_name in names(scopes_data)) {
  hdf <- scopes_data[[scope_name]]$hist
  clusters <- sort(unique(hdf$initial_cluster))
  
  for (cl in clusters) {
    cl_df <- hdf %>% filter(initial_cluster == cl)
    n_cl <- nrow(cl_df)
    
    # Quantitative stats for 6 features + aqi_verified
    all_numeric_vars <- c(pca_features, "aqi_verified")
    
    for (v in all_numeric_vars) {
      vals <- cl_df[[v]]
      vals_clean <- vals[!is.na(vals)]
      
      profiles_list[[paste(scope_name, cl, v, sep = "_")]] <- tibble(
        scope = scope_name,
        cluster = cl,
        variable = v,
        n = length(vals_clean),
        mean = mean(vals_clean),
        sd = sd(vals_clean),
        median = median(vals_clean),
        q1 = quantile(vals_clean, 0.25),
        q3 = quantile(vals_clean, 0.75)
      )
    }
  }
}
cluster_profiles_df <- bind_rows(profiles_list)
write_csv(cluster_profiles_df, "analysis/phase5A/tables/phase5A_cluster_profiles.csv")
cat("Saved: phase5A_cluster_profiles.csv\n")

# 3. Descriptive Cluster Labels (phase5A_cluster_labels.csv)
# Based directly on data profiles:
cluster_labels_df <- tribble(
  ~scope, ~cluster, ~descriptive_label, ~profile_basis, ~caution,
  "HYDERABAD", "Cluster 1", "warm-dry-moderate-pollution", "High temperature (30.3C), low humidity (42.8%), moderate particulate and ozone (AQI ~80.5); dominant in Summer/Pre-monsoon", "Unsupervised cluster; does not represent a causal source allocation",
  "HYDERABAD", "Cluster 2", "humid-monsoon-lower-pollution", "High humidity (75.6%), elevated wind (3.87 m/s), low PM2.5/PM10 (AQI ~56.5); dominant in Monsoon", "Meteorological dilution does not imply total absence of local emissions",
  "HYDERABAD", "Cluster 3", "cool-calm-particulate-elevated", "Lower temperature (23.9C), calm wind (2.02 m/s), elevated PM2.5 and PM10 (AQI ~99.8); dominant in Winter", "Inversion-driven accumulation across urban panel; not a single point source",
  "INDIA", "Cluster 1", "cool-stagnant-particulate-elevated", "Low temperature (21.5C), low wind (1.80 m/s), severe PM2.5 (100.4 ug/m3) and PM10 (186.2 ug/m3, AQI ~211.4); dominant in Winter", "Multi-station representative subset; cannot be generalized as an entire citywide mean",
  "INDIA", "Cluster 2", "hot-dry-ozone-dust-elevated", "High temperature (30.7C), low humidity (40.9%), elevated O3 (68.3 ug/m3) and PM10 (115.8 ug/m3, AQI ~120.9); dominant in Summer/Pre-monsoon", "High photochemical and crustal aerosol activity; unverified gases excluded",
  "INDIA", "Cluster 3", "humid-monsoon-lower-pollution", "High humidity (77.2%), higher wind (2.77 m/s), lowest PM2.5/PM10/O3 (AQI ~66.5); dominant in Monsoon (55.5% of history observations)", "Regional wet scavenging across national monitoring stations"
)
write_csv(cluster_labels_df, "analysis/phase5A/tables/phase5A_cluster_labels.csv")
cat("Saved: phase5A_cluster_labels.csv\n")

# 4. Regime Frequency Comparison: History vs Recent (phase5A_regime_frequency_comparison.csv)
freq_list <- list()
for (scope_name in names(scopes_data)) {
  hdf <- scopes_data[[scope_name]]$hist
  rdf <- scopes_data[[scope_name]]$rec
  
  h_counts <- hdf %>%
    count(initial_cluster, name = "n") %>%
    rename(cluster = initial_cluster) %>%
    mutate(
      scope = scope_name,
      period = "MODELING_HISTORY",
      percentage = round(100 * n / sum(n), 2)
    )
  
  r_counts <- rdf %>%
    count(assigned_cluster, name = "n") %>%
    rename(cluster = assigned_cluster) %>%
    mutate(
      scope = scope_name,
      period = "RECENT_EVALUATION",
      percentage = round(100 * n / sum(n), 2)
    )
  
  # Ensure all clusters are present in both periods
  all_cls <- unique(c(h_counts$cluster, r_counts$cluster))
  h_full <- tibble(cluster = all_cls) %>%
    left_join(h_counts, by = "cluster") %>%
    mutate(scope = scope_name, period = "MODELING_HISTORY", n = coalesce(n, 0L), percentage = coalesce(percentage, 0.0))
  
  r_full <- tibble(cluster = all_cls) %>%
    left_join(r_counts, by = "cluster") %>%
    mutate(scope = scope_name, period = "RECENT_EVALUATION", n = coalesce(n, 0L), percentage = coalesce(percentage, 0.0))
  
  freq_list[[scope_name]] <- bind_rows(h_full, r_full) %>%
    left_join(cluster_labels_df %>% select(scope, cluster, descriptive_label), by = c("scope", "cluster")) %>%
    select(scope, period, cluster, descriptive_label, n, percentage)
}
regime_freq_df <- bind_rows(freq_list)
write_csv(regime_freq_df, "analysis/phase5A/tables/phase5A_regime_frequency_comparison.csv")
cat("Saved: phase5A_regime_frequency_comparison.csv\n")

# 5. Station x Regime Table (phase5A_station_cluster_distribution.csv)
station_dist_list <- list()
for (scope_name in names(scopes_data)) {
  hdf <- scopes_data[[scope_name]]$hist
  rdf <- scopes_data[[scope_name]]$rec
  
  stations <- sort(unique(c(hdf$station_name, rdf$station_name)))
  clusters <- sort(unique(hdf$initial_cluster))
  
  grid <- expand.grid(station_name = stations, cluster = clusters, stringsAsFactors = FALSE)
  
  h_st <- hdf %>%
    count(station_name, initial_cluster, name = "history_n") %>%
    rename(cluster = initial_cluster) %>%
    group_by(station_name) %>%
    mutate(history_pct = round(100 * history_n / sum(history_n), 2)) %>%
    ungroup()
  
  r_st <- rdf %>%
    count(station_name, assigned_cluster, name = "recent_n") %>%
    rename(cluster = assigned_cluster) %>%
    group_by(station_name) %>%
    mutate(recent_pct = round(100 * recent_n / sum(recent_n), 2)) %>%
    ungroup()
  
  st_full <- grid %>%
    left_join(h_st, by = c("station_name", "cluster")) %>%
    left_join(r_st, by = c("station_name", "cluster")) %>%
    mutate(
      scope = scope_name,
      history_n = coalesce(history_n, 0L),
      history_pct = coalesce(history_pct, 0.0),
      recent_n = coalesce(recent_n, 0L),
      recent_pct = coalesce(recent_pct, 0.0)
    ) %>%
    select(scope, station_name, cluster, history_n, history_pct, recent_n, recent_pct)
  
  station_dist_list[[scope_name]] <- st_full
}
station_dist_df <- bind_rows(station_dist_list)
write_csv(station_dist_df, "analysis/phase5A/tables/phase5A_station_cluster_distribution.csv")
cat("Saved: phase5A_station_cluster_distribution.csv\n")

# 6. Season x Regime Table for HISTORY (phase5A_season_cluster_distribution.csv)
season_dist_list <- list()
for (scope_name in names(scopes_data)) {
  hdf <- scopes_data[[scope_name]]$hist
  
  s_df <- hdf %>%
    count(season, initial_cluster, name = "n") %>%
    rename(cluster = initial_cluster) %>%
    group_by(season) %>%
    mutate(
      scope = scope_name,
      pct = round(100 * n / sum(n), 2)
    ) %>%
    ungroup() %>%
    select(scope, season, cluster, n, pct)
  
  season_dist_list[[scope_name]] <- s_df
}
season_dist_df <- bind_rows(season_dist_list)
write_csv(season_dist_df, "analysis/phase5A/tables/phase5A_season_cluster_distribution.csv")
cat("Saved: phase5A_season_cluster_distribution.csv\n")

# ==============================================================================
# 7. GENERATE ALL 20 FIGURES
# ==============================================================================
theme_clean <- theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(size = 9, color = "grey30"),
    panel.grid.minor = element_blank()
  )

# Figure 01: Hyderabad Scree Plot
p01 <- ggplot(pca_var %>% filter(scope == "HYDERABAD"), aes(x = factor(PC, levels = paste0("PC", 1:6)), y = eigenvalue)) +
  geom_col(fill = "#2c3e50", width = 0.6) +
  geom_point(color = "#e74c3c", size = 3) +
  geom_line(aes(group = 1), color = "#e74c3c", linewidth = 1) +
  geom_hline(yintercept = 1, linetype = "dashed", color = "grey50") +
  labs(title = "Figure 01: Hyderabad PCA Scree Plot", subtitle = "Eigenvalues by Principal Component (Kaiser criterion line at 1.0)", x = "Principal Component", y = "Eigenvalue (Variance)") +
  theme_clean
ggsave("analysis/phase5A/figures/01_hyderabad_scree_plot.png", p01, width = 7, height = 4.5, dpi = 300)

# Figure 02: India Scree Plot
p02 <- ggplot(pca_var %>% filter(scope == "INDIA"), aes(x = factor(PC, levels = paste0("PC", 1:6)), y = eigenvalue)) +
  geom_col(fill = "#2980b9", width = 0.6) +
  geom_point(color = "#e74c3c", size = 3) +
  geom_line(aes(group = 1), color = "#e74c3c", linewidth = 1) +
  geom_hline(yintercept = 1, linetype = "dashed", color = "grey50") +
  labs(title = "Figure 02: India Representative Panel PCA Scree Plot", subtitle = "Eigenvalues across national monitoring stations (Kaiser line at 1.0)", x = "Principal Component", y = "Eigenvalue (Variance)") +
  theme_clean
ggsave("analysis/phase5A/figures/02_india_scree_plot.png", p02, width = 7, height = 4.5, dpi = 300)

# Figure 03: Cumulative Variance Comparison
p03 <- ggplot(pca_var, aes(x = factor(PC, levels = paste0("PC", 1:6)), y = cumulative_variance, color = scope, group = scope)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 3) +
  geom_hline(yintercept = 0.80, linetype = "dashed", color = "#c0392b") +
  annotate("text", x = 1.5, y = 0.82, label = "80% Threshold", color = "#c0392b", size = 3.5) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1), limits = c(0.3, 1.0)) +
  scale_color_manual(values = c("HYDERABAD" = "#2c3e50", "INDIA" = "#2980b9")) +
  labs(title = "Figure 03: Cumulative Variance Explained Comparison", subtitle = "Both scopes satisfy the >=80% threshold at exactly 4 Principal Components", x = "Principal Component", y = "Cumulative Variance Explained", color = "Scope") +
  theme_clean
ggsave("analysis/phase5A/figures/03_cumulative_variance_comparison.png", p03, width = 8, height = 4.5, dpi = 300)

# Figure 04: Hyderabad Loadings Heatmap
p04 <- ggplot(pca_load %>% filter(scope == "HYDERABAD"), aes(x = factor(PC, levels = paste0("PC", 1:6)), y = feature, fill = loading)) +
  geom_tile(color = "white") +
  geom_text(aes(label = round(loading, 2)), size = 3.5) +
  scale_fill_gradient2(low = "#c0392b", mid = "#ecf0f1", high = "#27ae60", midpoint = 0, limits = c(-1, 1)) +
  labs(title = "Figure 04: Hyderabad PCA Feature Loadings Heatmap", subtitle = "Eigenvector coefficients for the 6 standardized environmental features", x = "Principal Component", y = "Environmental Feature", fill = "Loading") +
  theme_clean
ggsave("analysis/phase5A/figures/04_hyderabad_loading_heatmap.png", p04, width = 8, height = 5, dpi = 300)

# Figure 05: India Loadings Heatmap
p05 <- ggplot(pca_load %>% filter(scope == "INDIA"), aes(x = factor(PC, levels = paste0("PC", 1:6)), y = feature, fill = loading)) +
  geom_tile(color = "white") +
  geom_text(aes(label = round(loading, 2)), size = 3.5) +
  scale_fill_gradient2(low = "#c0392b", mid = "#ecf0f1", high = "#2980b9", midpoint = 0, limits = c(-1, 1)) +
  labs(title = "Figure 05: India Representative Panel PCA Feature Loadings Heatmap", subtitle = "Eigenvector coefficients across the 15 national monitoring stations", x = "Principal Component", y = "Environmental Feature", fill = "Loading") +
  theme_clean
ggsave("analysis/phase5A/figures/05_india_loading_heatmap.png", p05, width = 8, height = 5, dpi = 300)

# Figure 06: Hyderabad PC1-PC2 Scores by Cluster
p06 <- ggplot(hyd_hist, aes(x = PC1, y = PC2, color = initial_cluster)) +
  geom_point(alpha = 0.5, size = 1.8) +
  stat_ellipse(level = 0.85, linewidth = 1) +
  scale_color_brewer(palette = "Set1") +
  labs(title = "Figure 06: Hyderabad History PCA Projection (PC1 vs PC2)", subtitle = "Observations in latent space colored by selected K=3 K-Means clusters", x = "PC1 (Particulate Intensity / Dispersion)", y = "PC2 (Thermal / Humidity Contrast)", color = "Regime") +
  theme_clean
ggsave("analysis/phase5A/figures/06_hyderabad_pca_pc1_pc2_by_cluster.png", p06, width = 8, height = 5.5, dpi = 300)

# Figure 07: India PC1-PC2 Scores by Cluster
p07 <- ggplot(ind_hist, aes(x = PC1, y = PC2, color = initial_cluster)) +
  geom_point(alpha = 0.4, size = 1.5) +
  stat_ellipse(level = 0.85, linewidth = 1) +
  scale_color_brewer(palette = "Set1") +
  labs(title = "Figure 07: India Representative Panel PCA Projection (PC1 vs PC2)", subtitle = "National monitoring observations colored by selected K=3 K-Means clusters", x = "PC1 (Particulate Loading vs Scavenging)", y = "PC2 (Thermal / Humidity Contrast)", color = "Regime") +
  theme_clean
ggsave("analysis/phase5A/figures/07_india_pca_pc1_pc2_by_cluster.png", p07, width = 8, height = 5.5, dpi = 300)

# Figure 08: Hyderabad K Selection Silhouette
p08 <- ggplot(k_diag %>% filter(scope == "HYDERABAD"), aes(x = k, y = average_silhouette_width)) +
  geom_line(color = "#2c3e50", linewidth = 1) +
  geom_point(color = "#e74c3c", size = 3) +
  geom_vline(xintercept = 3, linetype = "dashed", color = "#27ae60", linewidth = 1) +
  annotate("text", x = 3.3, y = 0.301, label = "Selected k=3 (Max Sil: 0.302)", color = "#27ae60", hjust = 0, size = 3.5) +
  scale_x_continuous(breaks = 2:8) +
  labs(title = "Figure 08: Hyderabad K-Means Cluster Diagnostic: Average Silhouette", subtitle = "Average silhouette width across candidate k in Euclidean retained PCA space", x = "Number of Clusters (k)", y = "Average Silhouette Width") +
  theme_clean
ggsave("analysis/phase5A/figures/08_hyderabad_k_selection_silhouette.png", p08, width = 7.5, height = 4.5, dpi = 300)

# Figure 09: India K Selection Silhouette
p09 <- ggplot(k_diag %>% filter(scope == "INDIA"), aes(x = k, y = average_silhouette_width, color = is_feasible)) +
  geom_line(aes(group = 1), color = "#2980b9", linewidth = 1) +
  geom_point(size = 3.5) +
  geom_vline(xintercept = 3, linetype = "dashed", color = "#27ae60", linewidth = 1) +
  annotate("text", x = 3.3, y = 0.314, label = "Selected k=3 (Max Feasible Sil: 0.315)", color = "#27ae60", hjust = 0, size = 3.5) +
  scale_x_continuous(breaks = 2:8) +
  scale_color_manual(values = c("TRUE" = "#27ae60", "FALSE" = "#e74c3c")) +
  labs(title = "Figure 09: India K-Means Cluster Diagnostic: Average Silhouette", subtitle = "Candidate k evaluated; k >= 6 disqualified by < 2% cluster size constraint", x = "Number of Clusters (k)", y = "Average Silhouette Width", color = "Size Feasible") +
  theme_clean
ggsave("analysis/phase5A/figures/09_india_k_selection_silhouette.png", p09, width = 8, height = 4.5, dpi = 300)

# Figure 10: WSS / Elbow Comparison
p10 <- ggplot(k_diag, aes(x = k, y = total_withinss, color = scope, group = scope)) +
  geom_line(linewidth = 1) +
  geom_point(size = 3) +
  scale_x_continuous(breaks = 2:8) +
  scale_color_manual(values = c("HYDERABAD" = "#2c3e50", "INDIA" = "#2980b9")) +
  labs(title = "Figure 10: K-Means Elbow Curve (Total Within-Cluster Sum of Squares)", subtitle = "Diminishing marginal within-cluster variance reduction beyond k=3", x = "Number of Clusters (k)", y = "Total Within-Cluster SS", color = "Scope") +
  theme_clean
ggsave("analysis/phase5A/figures/10_wss_elbow_comparison.png", p10, width = 8, height = 4.5, dpi = 300)

# Figure 11: Hyderabad Cluster Profile Heatmap
hyd_prof_z <- hyd_hist %>%
  group_by(initial_cluster) %>%
  summarise(across(all_of(pca_features), mean)) %>%
  pivot_longer(cols = -initial_cluster, names_to = "feature", values_to = "raw_mean") %>%
  group_by(feature) %>%
  mutate(std_mean = (raw_mean - mean(raw_mean)) / sd(raw_mean)) %>%
  ungroup()

p11 <- ggplot(hyd_prof_z, aes(x = initial_cluster, y = feature, fill = std_mean)) +
  geom_tile(color = "white") +
  geom_text(aes(label = round(raw_mean, 1)), size = 3.5) +
  scale_fill_gradient2(low = "#2980b9", mid = "#f5f6fa", high = "#c0392b", midpoint = 0) +
  labs(title = "Figure 11: Hyderabad Cluster Mean Profiles (Raw Units with Z-Shading)", subtitle = "Numbers display raw unstandardized means; cell color indicates relative cross-cluster elevation", x = "Cluster Regime", y = "Environmental Variable", fill = "Z-Score Relative") +
  theme_clean
ggsave("analysis/phase5A/figures/11_hyderabad_cluster_profile_heatmap.png", p11, width = 8, height = 5, dpi = 300)

# Figure 12: India Cluster Profile Heatmap
ind_prof_z <- ind_hist %>%
  group_by(initial_cluster) %>%
  summarise(across(all_of(pca_features), mean)) %>%
  pivot_longer(cols = -initial_cluster, names_to = "feature", values_to = "raw_mean") %>%
  group_by(feature) %>%
  mutate(std_mean = (raw_mean - mean(raw_mean)) / sd(raw_mean)) %>%
  ungroup()

p12 <- ggplot(ind_prof_z, aes(x = initial_cluster, y = feature, fill = std_mean)) +
  geom_tile(color = "white") +
  geom_text(aes(label = round(raw_mean, 1)), size = 3.5) +
  scale_fill_gradient2(low = "#2980b9", mid = "#f5f6fa", high = "#c0392b", midpoint = 0) +
  labs(title = "Figure 12: India Panel Cluster Mean Profiles (Raw Units with Z-Shading)", subtitle = "Raw unstandardized averages across the 3 national clusters", x = "Cluster Regime", y = "Environmental Variable", fill = "Z-Score Relative") +
  theme_clean
ggsave("analysis/phase5A/figures/12_india_cluster_profile_heatmap.png", p12, width = 8, height = 5, dpi = 300)

# Figure 13: Hyderabad Regime Frequency History vs Recent
p13 <- ggplot(regime_freq_df %>% filter(scope == "HYDERABAD"), aes(x = cluster, y = percentage, fill = period)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  scale_fill_manual(values = c("MODELING_HISTORY" = "#34495e", "RECENT_EVALUATION" = "#e67e22")) +
  scale_y_continuous(labels = scales::percent_format(scale = 1)) +
  labs(title = "Figure 13: Hyderabad Regime Frequency Shift (History vs September)", subtitle = "Substantial September expansion of Cluster 2 (humid-monsoon-lower-pollution)", x = "Cluster Regime", y = "Percentage of Complete Days", fill = "Period") +
  theme_clean
ggsave("analysis/phase5A/figures/13_hyderabad_regime_frequency_history_vs_recent.png", p13, width = 8, height = 4.5, dpi = 300)

# Figure 14: India Regime Frequency History vs Recent
p14 <- ggplot(regime_freq_df %>% filter(scope == "INDIA"), aes(x = cluster, y = percentage, fill = period)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  scale_fill_manual(values = c("MODELING_HISTORY" = "#2980b9", "RECENT_EVALUATION" = "#e67e22")) +
  scale_y_continuous(labels = scales::percent_format(scale = 1)) +
  labs(title = "Figure 14: India Panel Regime Frequency Shift (History vs September)", subtitle = "September shifts predominantly into Cluster 3 (humid-monsoon-lower-pollution)", x = "Cluster Regime", y = "Percentage of Complete Days", fill = "Period") +
  theme_clean
ggsave("analysis/phase5A/figures/14_india_regime_frequency_history_vs_recent.png", p14, width = 8, height = 4.5, dpi = 300)

# Figure 15: Station-Regime Heatmap Hyderabad (History)
p15 <- ggplot(station_dist_df %>% filter(scope == "HYDERABAD"), aes(x = cluster, y = station_name, fill = history_pct)) +
  geom_tile(color = "white") +
  geom_text(aes(label = paste0(round(history_pct, 1), "%")), size = 3) +
  scale_fill_gradient(low = "#ecf0f1", high = "#2c3e50") +
  labs(title = "Figure 15: Hyderabad Station-Level Regime Distribution (History)", subtitle = "Proportion of complete historical monitoring days spent in each cluster", x = "Cluster Regime", y = "Monitoring Station", fill = "History %") +
  theme_clean
ggsave("analysis/phase5A/figures/15_station_regime_heatmap_hyderabad.png", p15, width = 8.5, height = 5.5, dpi = 300)

# Figure 16: Station-Regime Heatmap India (History)
p16 <- ggplot(station_dist_df %>% filter(scope == "INDIA"), aes(x = cluster, y = station_name, fill = history_pct)) +
  geom_tile(color = "white") +
  geom_text(aes(label = paste0(round(history_pct, 1), "%")), size = 2.8) +
  scale_fill_gradient(low = "#ecf0f1", high = "#2980b9") +
  labs(title = "Figure 16: India Panel Station-Level Regime Distribution (History)", subtitle = "Distribution of historical days across the 15 national monitoring stations", x = "Cluster Regime", y = "Representative Station", fill = "History %") +
  theme_clean
ggsave("analysis/phase5A/figures/16_station_regime_heatmap_india.png", p16, width = 9.5, height = 7, dpi = 300)

# Figure 17: Season-Regime Distribution
p17 <- ggplot(season_dist_df, aes(x = season, y = pct, fill = cluster)) +
  geom_col(position = "fill", width = 0.7) +
  facet_wrap(~scope) +
  scale_y_continuous(labels = scales::percent_format()) +
  scale_fill_brewer(palette = "Set2") +
  labs(title = "Figure 17: Historical Season-Regime Breakdown", subtitle = "Proportion of seasonal observations assigned to each discovered regime", x = "Season", y = "Proportion of Season Days", fill = "Cluster") +
  theme_clean +
  theme(axis.text.x = element_text(angle = 25, hjust = 1))
ggsave("analysis/phase5A/figures/17_season_regime_distribution.png", p17, width = 9, height = 5, dpi = 300)

# Figure 18: Recent Centroid-Distance Percentile Distribution
dist_df <- bind_rows(
  hyd_rec %>% mutate(scope = "HYDERABAD"),
  ind_rec %>% mutate(scope = "INDIA")
)
p18 <- ggplot(dist_df, aes(x = centroid_distance_percentile, fill = scope)) +
  geom_histogram(bins = 20, color = "white", position = "dodge", alpha = 0.8) +
  geom_vline(xintercept = 0.5, linetype = "dashed", color = "grey40") +
  scale_fill_manual(values = c("HYDERABAD" = "#2c3e50", "INDIA" = "#2980b9")) +
  labs(title = "Figure 18: September Centroid-Distance Percentile Distribution", subtitle = "Distance of recent observations to frozen history centroids relative to history empirical distribution", x = "Centroid Distance Percentile [0, 1]", y = "Count of Observations", fill = "Scope") +
  theme_clean
ggsave("analysis/phase5A/figures/18_recent_centroid_distance_distribution.png", p18, width = 8, height = 4.5, dpi = 300)

# Figure 19: Selected Cluster Sizes
cl_sizes_df <- bind_rows(
  hyd_hist %>% count(initial_cluster, name = "size") %>% mutate(scope = "HYDERABAD", total = nrow(hyd_hist)),
  ind_hist %>% count(initial_cluster, name = "size") %>% mutate(scope = "INDIA", total = nrow(ind_hist))
) %>%
  mutate(pct = round(100 * size / total, 1))

p19 <- ggplot(cl_sizes_df, aes(x = initial_cluster, y = size, fill = scope)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  geom_text(aes(label = paste0(size, "\n(", pct, "%)")), position = position_dodge(width = 0.8), vjust = -0.3, size = 3.2) +
  scale_fill_manual(values = c("HYDERABAD" = "#2c3e50", "INDIA" = "#2980b9")) +
  labs(title = "Figure 19: Selected K-Means Cluster Sizes (History Complete Cases)", subtitle = "All clusters satisfy >= 2% and >= 30 observations constraints", x = "Cluster Regime", y = "Number of Station-Days", fill = "Scope") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  theme_clean
ggsave("analysis/phase5A/figures/19_selected_cluster_sizes.png", p19, width = 8, height = 4.5, dpi = 300)

# Figure 20: PCA Contribution Summary (Squared Loadings / Cos2)
load_contrib <- pca_load %>%
  mutate(contrib = loading^2) %>%
  filter(PC %in% paste0("PC", 1:4))

p20 <- ggplot(load_contrib, aes(x = PC, y = contrib, fill = feature)) +
  geom_col(position = "fill", width = 0.7) +
  facet_wrap(~scope) +
  scale_y_continuous(labels = scales::percent_format()) +
  scale_fill_brewer(palette = "Spectral") +
  labs(title = "Figure 20: PCA Feature Relative Variance Contribution (Loadings^2)", subtitle = "Proportional contribution of environmental features to the 4 retained PCs", x = "Principal Component", y = "Relative Variance Contribution", fill = "Feature") +
  theme_clean
ggsave("analysis/phase5A/figures/20_pca_contribution_summary.png", p20, width = 9, height = 5, dpi = 300)

cat("\n>>> All 20 Figures and Profiles Generated Successfully.\n")
