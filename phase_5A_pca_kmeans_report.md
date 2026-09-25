# Phase 5A — Principal Component Analysis & K-Means Pollution-Regime Discovery
**Author**: SML PBL Team (Mangali Sai Krishna, Md. Abdul Rayain, Rishit Ghosh, Yaram Karthik)  
**Academic Context**: Statistics for Machine Learning (SML) — Project-Based Learning (PBL)  
**Target Milestone**: Phase 5A / 5A.2 Final Unsupervised Freeze  
**Date**: September 25, 2026  
**Git Branch**: `feature/pca-kmeans`  
**Status**: `PHASE 5 UNSUPERVISED LEARNING FROZEN — READY FOR GIT INTEGRATION`

---

## EXECUTIVE SUMMARY

Phase 5A delivers the unsupervised learning layer of the Urban Air Quality Index & Multi-Pollutant Dynamics project. Operating downstream of the frozen Phase-4 supervised learning layer, this phase addresses two fundamental questions:
1. **Dimensionality Reduction**: Can multi-station urban air quality and meteorological dynamics be represented by a lower-dimensional latent coordinate system that preserves $\ge 80\%$ of total empirical variance?
2. **Pollution-Regime Discovery**: Do distinct, interpretable, multi-pollutant environmental regimes emerge naturally across monitoring stations without incorporating regulatory AQI definitions or predictive target labels?

Using strictly standardized complete cases over an 18-month historical window (March 1, 2025 to August 31, 2026), Principal Component Analysis (PCA) revealed that **exactly 4 Principal Components** capture $\approx 89\text{–}90\%$ of total variance across both urban and national scales. Subsequent K-Means clustering in this 4-dimensional latent space identified **$k = 3$ recurring environmental regimes** per scope, selected via a deterministic algorithm maximizing average silhouette width under feasibility constraints. Out-of-sample projection of September 1–21, 2026 observations confirmed that atmospheric conditions shifted dramatically into the humid/ventilated regime, consistent with the reduced adverse AQI prevalence observed during Phase-4 holdout testing.

---

## SECTION A — RESEARCH OBJECTIVE & ARCHITECTURE
Unlike supervised predictive modeling ($X_t \rightarrow Y_{t+1}$), Phase 5A performs unsupervised contemporaneous characterization:
- **Latent Space Modeling**: Mapping high-dimensional environmental sensor inputs onto orthogonal axes of variation.
- **Regime Discovery**: Clustering atmospheric states into discrete, recurring multi-pollutant profiles.
- **Strict Separation from AQI**: Composite AQI is excluded from PCA and clustering inputs to prevent circular collinearity. AQI is evaluated purely as passive descriptive metadata post-clustering.
- **Zero Leakage**: All scalers, PCA rotations, and cluster centroids are fitted exclusively on Modeling History data (`2025-03-01` to `2026-08-31`). Recent Evaluation data (`2026-09-01` to `2026-09-21`) is projected strictly onto frozen parameters.

---

## SECTION B — FEATURE CONTRACT & ELIGIBILITY

The feature contract is strictly restricted to six continuous physical measurements:
1. `pm2_5_aqi_input`: Fine inhalable particulate matter ($\mu\text{g/m}^3$)
2. `pm10_aqi_input`: Coarse inhalable particulate matter ($\mu\text{g/m}^3$)
3. `o3_8h_max`: Peak 8-hour photochemical ozone oxidant ($\mu\text{g/m}^3$)
4. `temperature`: Ambient temperature ($^\circ\text{C}$)
5. `humidity`: Relative humidity ($\%$)
6. `wind_speed`: Local atmospheric wind speed ($\text{m/s}$)

### Explicit Exclusions:
- **AQI Inputs & Subindices**: `aqi_verified`, subindices, and regulatory categories are excluded from PCA and K-Means.
- **Trace Gases**: `co_source_mean`, `no2_source_mean`, and `so2_source_mean` remain excluded due to unresolved unit semantics.
- **Target & Inference Fields**: `target_aqi_next_day`, `target_category_next_day`, `target_adverse_next_day`, `drift_z`, and bootstrap p-values are strictly excluded.

### Complete-Case Eligibility (`phase5A_eligibility_profile.csv`):
- **Hyderabad Urban Panel (7 Stations)**:
  - Modeling History: 3,843 structural rows; **2,749 complete cases (71.53%)**; 1,094 incomplete.
  - Recent Evaluation: 147 structural rows; **121 complete cases (82.31%)**; 26 incomplete.
- **India Representative Panel (15 Stations)**:
  - Modeling History: 8,235 structural rows; **6,796 complete cases (82.53%)**; 1,439 incomplete.
  - Recent Evaluation: 315 structural rows; **262 complete cases (83.17%)**; 53 incomplete.

---

## SECTION C — HISTORICAL STANDARDIZATION

Standardization parameters (`training_mean`, `training_sd`) were derived exclusively from historical complete cases (`phase5A_scaling_parameters.csv`):

| Scope | Feature | Historical Mean | Historical SD | Standardized Mean | Standardized SD |
|---|---|---|---|---|---|
| **HYDERABAD** | `pm2_5_aqi_input` | 42.043652 | 23.899661 | 0.000000 | 1.000000 |
| HYDERABAD | `pm10_aqi_input` | 90.871590 | 46.064560 | 0.000000 | 1.000000 |
| HYDERABAD | `o3_8h_max` | 29.337577 | 17.060195 | 0.000000 | 1.000000 |
| HYDERABAD | `temperature` | 27.291779 | 4.257579 | 0.000000 | 1.000000 |
| HYDERABAD | `humidity` | 63.264278 | 17.839218 | 0.000000 | 1.000000 |
| HYDERABAD | `wind_speed` | 1.541470 | 0.758364 | 0.000000 | 1.000000 |
| **INDIA** | `pm2_5_aqi_input` | 51.583873 | 45.694697 | 0.000000 | 1.000000 |
| INDIA | `pm10_aqi_input` | 106.449529 | 76.602705 | 0.000000 | 1.000000 |
| INDIA | `o3_8h_max` | 29.645527 | 18.663189 | 0.000000 | 1.000000 |
| INDIA | `temperature` | 26.720232 | 6.060773 | 0.000000 | 1.000000 |
| INDIA | `humidity` | 70.301354 | 18.552994 | 0.000000 | 1.000000 |
| INDIA | `wind_speed` | 1.782813 | 0.931758 | 0.000000 | 1.000000 |

Recent September observations were standardized strictly using these historical parameters.

---

## SECTION D — HYDERABAD URBAN PANEL PCA
Fitted independently on standardized historical observations ($N=2,749$):
- **PC1 (Particulate / Ventilation Contrast)**: Strong negative loadings on `pm10_aqi_input` (-0.569) and `pm2_5_aqi_input` (-0.540) opposing positive loadings on `humidity` (+0.395) and `wind_speed` (+0.354). Captures dominant air quality degradation versus atmospheric dispersion.
- **PC2 (Thermal-Moisture Contrast)**: Strong positive loading on `temperature` (+0.672) opposing `humidity` (-0.570). Captures seasonal thermodynamic transition between hot/dry summer and cool/humid monsoon.
- **PC3 (Ozone-Dominated Axis)**: Dominated by `o3_8h_max` (+0.835) opposing `temperature` (-0.380). Captures independent secondary photochemical dynamics.
- **PC4 (Local Dispersion Axis)**: Strong loading on `wind_speed` (+0.830) and `pm2_5_aqi_input` (+0.370).

---

## SECTION E — INDIA REPRESENTATIVE-STATION PANEL PCA
Fitted independently across 15 national monitoring stations ($N=6,796$):
- **PC1 (Particulate / Ventilation Contrast)**: Negative loadings on `pm10_aqi_input` (-0.583) and `pm2_5_aqi_input` (-0.539) opposing `humidity` (+0.357). Reflects national particulate loading versus moist/ventilated conditions.
- **PC2 (Thermal-Moisture Contrast)**: `temperature` (+0.652) opposing `humidity` (-0.573).
- **PC3 (Wind-Dominated Axis)**: Dominated by `wind_speed` (-0.888).
- **PC4 (Ozone-Dominated Axis)**: `o3_8h_max` (-0.775) and `temperature` (+0.494).

---

## SECTION F — PCA VARIANCE EXPLAINED & SELECTION

Using the project deterministic selection rule (retain smallest number of PCs whose cumulative variance explained $\ge 80\%$):

| Scope | PC | Eigenvalue | Variance Explained | Cumulative Variance | Retained? |
|---|---|---|---|---|---|
| **HYDERABAD** | PC1 | 2.319848 | 38.66% | 38.66% | Yes |
| HYDERABAD | PC2 | 1.406734 | 23.45% | 62.11% | Yes |
| HYDERABAD | PC3 | 0.995306 | 16.59% | **78.70%** | Yes (Does NOT reach 80%) |
| HYDERABAD | PC4 | 0.690885 | 11.51% | **90.21%** | **Yes (Selected)** |
| HYDERABAD | PC5 | 0.378604 | 6.31% | 96.52% | No |
| HYDERABAD | PC6 | 0.208622 | 3.48% | 100.00% | No |
| **INDIA** | PC1 | 2.251743 | 37.53% | 37.53% | Yes |
| INDIA | PC2 | 1.468250 | 24.47% | 62.00% | Yes |
| INDIA | PC3 | 0.834971 | 13.92% | **75.92%** | Yes (Does NOT reach 80%) |
| INDIA | PC4 | 0.763821 | 12.73% | **88.65%** | **Yes (Selected)** |
| INDIA | PC5 | 0.425391 | 7.09% | 95.74% | No |
| INDIA | PC6 | 0.255825 | 4.26% | 100.00% | No |

**Critical Reconciliation**: Because PC3 cumulative variance is $78.70\%$ in Hyderabad and $75.92\%$ in India, neither scope satisfies the $80\%$ threshold with 3 PCs. Exactly **4 Principal Components** are legitimately required for both scopes.

---

## SECTION G — PCA LOADING INTERPRETATION
The loadings confirm that environmental air quality is governed by three primary, distinct empirical contrasts:
1. **Particulate vs Ventilation Contrast (PC1)**: Fine and coarse particulates co-vary strongly and represent the dominant source of variation across monitoring stations.
2. **Thermal-Moisture Contrast (PC2)**: Inherent thermodynamics where warm conditions coincide with depressed relative humidity.
3. **Secondary Oxidant / Wind Dynamics (PC3 & PC4)**: Ozone acts orthogonally to primary particulates, alongside localized wind ventilation differences.

---

## SECTION H — K-MEANS SELECTION METHOD (`K_MEANS_K_SELECTION_PROJECT_RULE`)
K-Means was executed on the 4 retained PC scores across candidate $k \in \{2, \dots, 8\}$ with `nstart = 50` and seed `20260925`.
- **Constraint A**: Disqualify candidate $k$ where any cluster contains $< 2.0\%$ of history cases or $< 30$ observations.
- **Constraint B**: Maximize average silhouette width $\bar{s}$.
- **Constraint C**: If silhouette widths tie within $\Delta \le 0.01$, select the smaller $k$ for parsimony. WSS was evaluated as supportive context only.

### Diagnostic Comparison (`phase5A_k_selection_diagnostics.csv`):
- **Hyderabad**:
  - $k=2$: Sil = 0.2734, BSS/TSS = 29.02%
  - **$k=3$**: **Sil = 0.3022, BSS/TSS = 45.63% (Selected: Global Maximum $\bar{s}$)**
  - $k=4$: Sil = 0.2999, BSS/TSS = 54.75%
  - $k=5$: Sil = 0.2990, BSS/TSS = 60.29%
  - $k=6$: Sil = 0.2891, BSS/TSS = 64.44%
  - $k=7$: Sil = 0.2745, BSS/TSS = 67.60%
  - $k=8$: Sil = 0.2834, BSS/TSS = 70.25%
- **India**:
  - $k=2$: Sil = 0.2972, BSS/TSS = 27.83%
  - **$k=3$**: **Sil = 0.3152, BSS/TSS = 44.23% (Selected: Global Maximum $\bar{s}$)**
  - $k=4$: Sil = 0.2690, BSS/TSS = 53.36%
  - $k=5$: Sil = 0.2711, BSS/TSS = 58.92%
  - $k \ge 6$: Disqualified (smallest cluster size $< 2.0\%$; $k=6$: 1.69%, $k=7$: 1.65%, $k=8$: 1.18%).

---

## SECTION I — HYDERABAD REGIMES (K=3)
Populated directly from `phase5A_cluster_profiles.csv`:
- **Cluster 1 (`warm-dry-moderate-pollution`)** [$N=866$, 31.50% history]:
  - PM2.5: Mean = $32.83\ \mu\text{g/m}^3$ (SD 12.53), Median = 32, IQR = [26, 38]
  - PM10: Mean = $78.61\ \mu\text{g/m}^3$ (SD 20.65), Median = 80, IQR = [70, 87]
  - O3: Mean = $35.09\ \mu\text{g/m}^3$ (SD 18.25), Median = 32, IQR = [24, 41]
  - Temperature: Mean = $30.33^\circ\text{C}$ (SD 1.99), Median = 30.39, IQR = [28.88, 31.88]
  - Humidity: Mean = $42.78\%$ (SD 9.88), Median = 41.98, IQR = [35.73, 49.50]
  - Wind speed: Mean = $2.21\text{ m/s}$ (SD 0.60), Median = 2.10, IQR = [1.80, 2.51]
  - Passive AQI: Mean = 80.52 (SD 23.59, valid $N=866/866$).
  - Observed predominantly in Summer / Pre-monsoon (84.24%).
- **Cluster 2 (`humid-windy-lower-pollution`)** [$N=962$, 34.99% history]:
  - PM2.5: Mean = $22.90\ \mu\text{g/m}^3$ (SD 10.81), Median = 23, IQR = [14, 30]
  - PM10: Mean = $54.70\ \mu\text{g/m}^3$ (SD 21.03), Median = 57, IQR = [41, 69]
  - O3: Mean = $29.20\ \mu\text{g/m}^3$ (SD 14.44), Median = 26, IQR = [21, 36]
  - Temperature: Mean = $25.84^\circ\text{C}$ (SD 1.55), Median = 25.78, IQR = [24.83, 26.71]
  - Humidity: Mean = $75.58\%$ (SD 9.20), Median = 75.83, IQR = [70.46, 82.54]
  - Wind speed: Mean = $3.87\text{ m/s}$ (SD 1.08), Median = 3.88, IQR = [3.19, 4.58]
  - Passive AQI: Mean = 56.54 (SD 19.38, valid $N=962/962$).
  - Observed predominantly in Monsoon (76.16%).
- **Cluster 3 (`cool-low-wind-particulate-elevated`)** [$N=921$, 33.50% history]:
  - PM2.5: Mean = $45.66\ \mu\text{g/m}^3$ (SD 17.63), Median = 39, IQR = [32, 58]
  - PM10: Mean = $96.52\ \mu\text{g/m}^3$ (SD 26.30), Median = 90, IQR = [80, 106]
  - O3: Mean = $32.51\ \mu\text{g/m}^3$ (SD 12.47), Median = 30, IQR = [24, 39]
  - Temperature: Mean = $23.92^\circ\text{C}$ (SD 2.27), Median = 23.81, IQR = [22.16, 25.62]
  - Humidity: Mean = $59.89\%$ (SD 13.80), Median = 57.67, IQR = [50.58, 69.50]
  - Wind speed: Mean = $2.02\text{ m/s}$ (SD 0.57), Median = 1.95, IQR = [1.65, 2.31]
  - Passive AQI: Mean = 99.79 (SD 31.45, valid $N=921/921$).
  - Observed predominantly in Winter (97.02%) and Post-monsoon (71.27%).

---

## SECTION J — INDIA REGIMES (K=3)
Populated directly from `phase5A_cluster_profiles.csv`:
- **Cluster 1 (`cool-low-wind-particulate-elevated`)** [$N=1,261$, 18.56% history]:
  - PM2.5: Mean = $100.41\ \mu\text{g/m}^3$ (SD 66.41), Median = 83, IQR = [64, 112]
  - PM10: Mean = $186.17\ \mu\text{g/m}^3$ (SD 81.39), Median = 166, IQR = [133, 221]
  - O3: Mean = $54.77\ \mu\text{g/m}^3$ (SD 38.98), Median = 46, IQR = [26, 75]
  - Temperature: Mean = $21.52^\circ\text{C}$ (SD 3.90), Median = 21.61, IQR = [19.00, 23.93]
  - Humidity: Mean = $61.02\%$ (SD 13.50), Median = 60.42, IQR = [50.96, 70.62]
  - Wind speed: Mean = $1.80\text{ m/s}$ (SD 0.62), Median = 1.71, IQR = [1.36, 2.15]
  - Passive AQI: Mean = 211.38 (SD 92.70, valid $N=1,260$ / cluster $N=1,261$).
  - Observed predominantly in Winter (73.05%).
- **Cluster 2 (`hot-dry-ozone-pm10-elevated`)** [$N=1,764$, 25.96% history]:
  - PM2.5: Mean = $47.74\ \mu\text{g/m}^3$ (SD 19.60), Median = 46, IQR = [34, 59]
  - PM10: Mean = $115.76\ \mu\text{g/m}^3$ (SD 45.98), Median = 109, IQR = [87, 138]
  - O3: Mean = $68.33\ \mu\text{g/m}^3$ (SD 40.13), Median = 61, IQR = [40, 86]
  - Temperature: Mean = $30.65^\circ\text{C}$ (SD 3.44), Median = 30.78, IQR = [28.20, 33.19]
  - Humidity: Mean = $40.89\%$ (SD 15.21), Median = 40.35, IQR = [28.58, 50.54]
  - Wind speed: Mean = $2.40\text{ m/s}$ (SD 0.69), Median = 2.33, IQR = [1.88, 2.81]
  - Passive AQI: Mean = 120.87 (SD 41.09, valid $N=1,742$ / cluster $N=1,764$).
  - Observed predominantly in Summer / Pre-monsoon (54.40%).
- **Cluster 3 (`humid-windy-lower-pollution`)** [$N=3,771$, 55.49% history]:
  - PM2.5: Mean = $29.24\ \mu\text{g/m}^3$ (SD 14.66), Median = 27, IQR = [19, 37]
  - PM10: Mean = $62.86\ \mu\text{g/m}^3$ (SD 30.45), Median = 59, IQR = [41, 81]
  - O3: Mean = $27.82\ \mu\text{g/m}^3$ (SD 17.75), Median = 26, IQR = [16, 35]
  - Temperature: Mean = $27.31^\circ\text{C}$ (SD 2.75), Median = 27.64, IQR = [25.73, 29.20]
  - Humidity: Mean = $77.23\%$ (SD 10.20), Median = 79.08, IQR = [71.54, 85.12]
  - Wind speed: Mean = $2.77\text{ m/s}$ (SD 1.14), Median = 2.62, IQR = [1.89, 3.49]
  - Passive AQI: Mean = 66.48 (SD 30.56, valid $N=3,771$ / cluster $N=3,771$).
  - Observed predominantly in Monsoon (86.86%).

*Note on Passive AQI Missingness*: In India history, 23 complete observations lack verified CPCB AQI (1 in Cluster 1, 22 in Cluster 2) due to subindex validity requirements. Clustered observations reflect complete 6-feature physical sensor data.

---

## SECTION K — CLUSTER QUALITY METRICS
Both 3-cluster solutions demonstrate **modest separation with non-degenerate cluster sizes**, representing a useful but overlapping three-regime partition:
- **Between-to-Total SS Ratio**: $45.63\%$ in Hyderabad, $44.23\%$ in India.
- **Average Silhouette Width**: $0.3022$ in Hyderabad, $0.3152$ in India.
- **Cluster Balance**: The smallest cluster comprises $31.50\%$ in Hyderabad and $18.56\%$ in India, completely avoiding singletons or unstable micro-clusters.

---

## SECTION L — CLUSTER STABILITY (ARI SENSITIVITY)
To verify that the $k=3$ partition was not an artifact of random initialization, K-Means was re-run with 10 independent deterministic seeds (`20260926` to `20260935`).
- **Hyderabad**: Median $\text{ARI} = 1.000$, Minimum $\text{ARI} = 1.000$.
- **India**: Median $\text{ARI} = 1.000$, Minimum $\text{ARI} = 1.000$.
This establishes **high initialization stability across the tested deterministic seeds** under `nstart = 50`.

---

## SECTION M — SEASONAL CONTEXT
From `phase5A_season_cluster_distribution.csv`:
- **Hyderabad Panel ($N=2,749$)**:
  - Monsoon days fall predominantly into Cluster 2 ($805/1,057 = 76.16\%$).
  - Summer / Pre-monsoon days fall predominantly into Cluster 1 ($759/901 = 84.24\%$).
  - Winter days fall predominantly into Cluster 3 ($423/436 = 97.02\%$).
  - Post-monsoon days fall predominantly into Cluster 3 ($253/355 = 71.27\%$).
- **India Panel ($N=6,796$)**:
  - Monsoon days fall predominantly into Cluster 3 ($2,314/2,664 = 86.86\%$).
  - Summer / Pre-monsoon days fall predominantly into Cluster 2 ($1,266/2,327 = 54.40\%$).
  - Winter days fall predominantly into Cluster 1 ($740/1,013 = 73.05\%$).
  - Post-monsoon days are split between Cluster 3 ($372/792 = 46.97\%$) and Cluster 1 ($341/792 = 43.06\%$).

---

## SECTION N — STATION-LEVEL REGIME DISTRIBUTION
Using tracked master station metadata (`data/metadata/station_catalog.csv`):
- **Hyderabad Panel (7 stations)**: Stations like Central University (`PROJ_044`) spend 50.29% in Cluster 2 and 30.41% in Cluster 1, while Somajiguda (`PROJ_181`) records 44.27% in Cluster 3 (cool-low-wind-particulate-elevated) and 33.94% in Cluster 1.
- **India Panel (15 stations)**:
  - Coastal / high-ventilation stations: Manali, Chennai (`PROJ_019`) spends 92.45% of historical days in Cluster 3 (`humid-windy-lower-pollution`). Jadavpur, Kolkata (`PROJ_094`) spends 69.31% in Cluster 3.
  - Arid / inland summer stations: Maninagar, Ahmedabad (`PROJ_024`) spends 58.19% of historical days in Cluster 2 (`hot-dry-ozone-pm10-elevated`).
  - Balanced multi-regime stations: R K Puram, Delhi (`PROJ_002`) exhibits balanced exposure across all three regimes (Cluster 1: 36.12%, Cluster 2: 36.78%, Cluster 3: 27.09%). Zoo Park in the India panel (`PROJ_007`) spends 55.87% in Cluster 3, 26.29% in Cluster 2, and 17.84% in Cluster 1.

---

## SECTION O — SEPTEMBER PROJECTION (OUT-OF-SAMPLE)
The recent 21-day evaluation window (September 1–21, 2026) was projected onto frozen history centroids:
- Complete recent cases: $N=121$ for Hyderabad, $N=262$ for India.
- **Centroid-Distance Distribution (`phase5A_recent_centroid_distance_summary.csv`)**:
  - **Hyderabad Recent ($N=121$)**: Mean percentile = 0.576864, Median = 0.629750, 90th percentile = 0.866944, 95th percentile = 0.905312; exactly 3 observations ($\ge 0.95$, $2.48\%$) occupy high-distance tails.
  - **India Recent ($N=262$)**: Mean percentile = 0.393887, Median = 0.342880, 90th percentile = 0.782551, 95th percentile = 0.846513; exactly 2 observations ($\ge 0.95$, $0.76\%$) occupy high-distance tails.
- **Interpretation**: Most recent observations lie within the historical within-cluster distance distribution. Only a small fraction of September observations occupied the upper 5% tail of their assigned historical cluster-distance distribution.

---

## SECTION P — RECENT REGIME SHIFT & RELATIONSHIP TO PHASE-4
Comparing cluster frequencies between History and September (`phase5A_regime_frequency_comparison.csv`):
- **Hyderabad**:
  - Cluster 1 (Warm/Dry): History 31.50% $\rightarrow$ Recent 23.14% (28 / 121)
  - Cluster 2 (Humid/Windy/Lower-Pollution): History 34.99% $\rightarrow$ **Recent 67.77%** (82 / 121)
  - Cluster 3 (Cool/Low-Wind/Particulate): History 33.50% $\rightarrow$ **Recent 9.09%** (11 / 121)
- **India**:
  - Cluster 1 (Cool/Low-Wind/Particulate): History 18.56% $\rightarrow$ **Recent 1.15%** (3 / 262)
  - Cluster 2 (Hot/Dry/Ozone): History 25.96% $\rightarrow$ Recent 8.40% (22 / 262)
  - Cluster 3 (Humid/Windy/Lower-Pollution): History 55.49% $\rightarrow$ **Recent 90.46%** (237 / 262)

### Non-Causal Synthesis:
September observations were strongly concentrated in the humid/lower-pollution historical regime. This pattern is consistent with the lower AQI distribution and reduced adverse-event prevalence observed in the Phase-4 holdout, but the unsupervised analysis does not establish a causal explanation for the supervised-model performance. Furthermore, Phase-4 and Phase-5 eligibility populations are not identical. Importantly, elevated-particulate regimes did not completely disappear: Hyderabad recent data still include 11 observations in Cluster 3, and India recent data include 3 observations in Cluster 1.

---

## SECTION Q — LIMITATIONS
1. **Unsupervised vs Causal**: Discovered clusters are descriptive empirical associations; they do not identify emission source types, chemical pathways, or boundary layer mechanisms.
2. **Exclusion of Trace Gases**: CO, NO2, and SO2 were excluded due to unresolved unit semantics; their inclusion could alter secondary regime structures.
3. **Panel Specificity**: Cluster 1 in Hyderabad is not the same entity as Cluster 1 in India; each panel reflects its own geographic scale and scaler normalization.
4. **Complete-Case Filtering**: Complete-case enforcement dropped incomplete sensor records, though the eligibility audit confirms missingness is distributed across seasons.

---

## SECTION R — TEST RESULTS
The hardened modular Phase 5A test suite (`tests/testthat/test_phase5a.R`) executed **115 automated runtime assertions** (79 literal expect calls across 6 modular test blocks) with **0 failures, 0 warnings, and 0 skips**:
- **Block A**: Verified exact 6-feature contract, scaling parameters, date boundaries, and 4-PC retention.
- **Block B**: Verified candidate $k \in \{2..8\}$, feasibility constraints, algorithmic K-selection rule ($k=3$), and ARI stability across seeds.
- **Block C**: Verified recent projection, frozen PCA transformation, nearest-centroid assignment, and within-cluster distance percentiles.
- **Block D**: Verified tracked station metadata (`station_catalog.csv`), hardened O3 unit declaration ($\mu\text{g/m}^3$), and complete absence of forbidden causal terms in labels.
- **Block E**: Verified 100% agreement on all 124 checks in `phase5A_numeric_consistency_audit.csv`, variance sums to 1.0, and exact sample sizes.
- **Block F**: Verified offline execution safety, zero external network calls, preservation of Phase-4 artifacts, and tracked report generation integrity (`phase5A_report_generation_integrity.csv`).

---

## SECTION S — NEXT PHASE
With unsupervised dimensionality reduction, pollution regime discovery, and result reconciliation fully completed and frozen, the project can proceed to:  
**PHASE 5B — SUPPORT VECTOR MACHINE (SVM) ADVERSE-AQI CLASSIFICATION COMPARISON** (Non-linear supervised benchmarking against Logistic Regression and Persistence).

---

## SECTION T — STATUS
```
================================================================================
PHASE 5 UNSUPERVISED LEARNING FROZEN — READY FOR GIT INTEGRATION
================================================================================
```
