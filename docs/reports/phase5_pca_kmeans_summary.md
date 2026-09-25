# Phase 5A: PCA Dimensionality Analysis & K-Means Pollution-Regime Discovery

## 1. Unsupervised Research Objective
Following the formal freeze of the supervised prediction layer (Phase 4), Phase 5A investigated whether multi-station urban air quality and localized meteorological dynamics can be represented by a reduced latent coordinate system, and whether recurring, interpretable **environmental pollution regimes** emerge without relying on target labels or composite AQI definitions.

## 2. Feature Contract & Exclusion Policy
The unsupervised feature space was strictly restricted to six standardized physical and meteorological measurements:
- **Particulates**: `pm2_5_aqi_input` ($\mu\text{g/m}^3$), `pm10_aqi_input` ($\mu\text{g/m}^3$)
- **Photochemical Oxidant**: `o3_8h_max` ($\mu\text{g/m}^3$)
- **Meteorology**: `temperature` ($^\circ\text{C}$), `humidity` ($\%$), `wind_speed` ($\text{m/s}$)

**Exclusions**:
- `aqi_verified`, subindices, and regulatory categories were excluded from PCA and clustering inputs because composite AQI is mathematically derived from PM2.5, PM10, and O3. Including it would create artificial collinearity and overweight particulate signals. AQI was evaluated solely as passive descriptive metadata post-clustering.
- Unresolved gases (`co_source_mean`, `no2_source_mean`, `so2_source_mean`) were excluded due to unverified source physical units.
- Future targets, supervised predictions, and Phase-3 inference labels were strictly excluded.

## 3. Scope & Temporal Partitioning
Analyses were fitted completely independently for two geographic panels:
- **Hyderabad Urban Panel**: 7 physical monitoring stations.
- **India Representative Panel**: 15 national monitoring stations (representative locations, not citywide aggregates).
- **Zoo Park Overlap**: `PROJ_007` appears intentionally in both panels.

**Temporal Boundary**:
- **Modeling History (`2025-03-01` to `2026-08-31`)**: Used exclusively to learn standardization parameters (`training_mean`, `training_sd`), PCA eigenvectors, retained PC dimensions, and K-Means centroids.
- **Recent Evaluation (`2026-09-01` to `2026-09-21`)**: September data was projected strictly into the frozen history latent space; it did not alter any scaling, rotation, or cluster parameters.

## 4. Principal Component Analysis (PCA) Findings
Standardized on history complete cases (Hyderabad $N=2,749$; India $N=6,796$):
- **Retained Dimensions**: Using the deterministic $\ge 80\%$ cumulative variance threshold, exactly **4 Principal Components** were retained for both panels:
  - **Hyderabad**: PC1 (38.66%), PC2 (23.45%), PC3 (16.59%, cumulative 78.70%), PC4 (11.51%, cumulative **90.21%**). Because PC3 does not reach 80%, 4 PCs are legitimately required.
  - **India**: PC1 (37.53%), PC2 (24.47%), PC3 (13.92%, cumulative 75.92%), PC4 (12.73%, cumulative **88.65%**). Because PC3 does not reach 80%, 4 PCs are legitimately required.
- **Dominant Latent Axes**:
  - **PC1 (Particulate / Ventilation Contrast)**: Negative loadings on PM10 and PM2.5 opposing positive loadings on wind speed and humidity.
  - **PC2 (Thermal-Moisture Contrast)**: Strong opposition between high temperature and low relative humidity.
  - **PC3 (Ozone / Secondary Dynamics)**: Heavily loaded by O3 variance (Hyderabad) and wind ventilation (India).
  - **PC4 (Local Atmospheric Dispersion)**: Wind speed and temperature variations.

## 5. K-Means Pollution-Regime Discovery (`K_MEANS_K_SELECTION_PROJECT_RULE`)
K-Means clustering was executed in the 4-dimensional retained PCA space across candidate $k \in \{2, \dots, 8\}$ ($nstart=50$, seed `20260925`).
- **Deterministic Selection Rule**: Disqualifying candidate $k$ with small clusters ($< 2\%$ of history or $< 30$ observations) and maximizing average silhouette width, **$k = 3$** was deterministically selected for both panels.
  - **Hyderabad ($k=3$)**: Average Silhouette $= 0.3022$; Between/Total SS $= 45.63\%$.
  - **India ($k=3$)**: Average Silhouette $= 0.3152$; Between/Total SS $= 44.23\%$.
- **Partition Quality**: Both panels exhibit **modest separation with non-degenerate cluster sizes**, representing a useful but overlapping three-regime partition.
- **Cluster Stability**: Evaluated across 10 deterministic seeds; Adjusted Rand Index (ARI) was **1.000** for both panels, showing high initialization stability across tested seeds.

## 6. Discovered Environmental Regimes
### Hyderabad Urban Panel (7 Stations)
1. **Cluster 1 (`warm-dry-moderate-pollution`)** [866 days, 31.5% history]: Warm ($30.3^\circ\text{C}$), dry ($42.8\%$ humidity), moderate particulates (PM2.5: 32.8, PM10: 78.6 $\mu\text{g/m}^3$), passive AQI $\approx 80.5$ ($N=866$). Observed predominantly in Summer / Pre-monsoon (84.24%).
2. **Cluster 2 (`humid-windy-lower-pollution`)** [962 days, 35.0% history]: Humid ($75.6\%$), elevated wind ($3.87\text{ m/s}$), low particulates (PM2.5: 22.9, PM10: 54.7 $\mu\text{g/m}^3$), passive AQI $\approx 56.5$ ($N=962$). Observed predominantly in Monsoon (76.16%).
3. **Cluster 3 (`cool-low-wind-particulate-elevated`)** [921 days, 33.5% history]: Cooler ($23.9^\circ\text{C}$), low wind ($2.02\text{ m/s}$), elevated particulates (PM2.5: 45.7, PM10: 96.5 $\mu\text{g/m}^3$), passive AQI $\approx 99.8$ ($N=921$). Observed predominantly in Winter (97.02%).

### India Representative Panel (15 Stations)
1. **Cluster 1 (`cool-low-wind-particulate-elevated`)** [1,261 days, 18.6% history]: Cool ($21.5^\circ\text{C}$), low wind ($1.80\text{ m/s}$), elevated particulates (PM2.5: 100.4, PM10: 186.2 $\mu\text{g/m}^3$), passive AQI $\approx 211.4$ (valid $N=1,260$). Observed predominantly in Winter (73.05%).
2. **Cluster 2 (`hot-dry-ozone-pm10-elevated`)** [1,764 days, 26.0% history]: High temperature ($30.7^\circ\text{C}$), low humidity ($40.9\%$), elevated O3 ($68.3\ \mu\text{g/m}^3$) and PM10 ($115.8\ \mu\text{g/m}^3$), passive AQI $\approx 120.9$ (valid $N=1,742$). Observed predominantly in Summer / Pre-monsoon (54.40%).
3. **Cluster 3 (`humid-windy-lower-pollution`)** [3,771 days, 55.5% history]: Humid ($77.2\%$), active wind ($2.77\text{ m/s}$), lower particulate and ozone concentrations (PM2.5: 29.2, PM10: 62.9 $\mu\text{g/m}^3$), passive AQI $\approx 66.5$ (valid $N=3,771$). Observed predominantly in Monsoon (86.86%).

*Note on Passive AQI Missingness*: While clustering operates on six-feature complete cases, passive `aqi_verified` metadata can occasionally be missing due to subindex completeness constraints (e.g. 1 missing in India Cluster 1, 22 missing in India Cluster 2).

## 7. September Regime Projection & Distribution Shift
Projecting September 2026 complete observations ($N=121$ Hyderabad, $N=262$ India) onto frozen centroids:
- **Hyderabad Recent Frequencies**:
  - Cluster 1: 28 / 121 (23.14%)
  - Cluster 2: 82 / 121 (67.77%)
  - Cluster 3: 11 / 121 (9.09%)
- **India Recent Frequencies**:
  - Cluster 1: 3 / 262 (1.15%)
  - Cluster 2: 22 / 262 (8.40%)
  - Cluster 3: 237 / 262 (90.46%)
- **Centroid-Distance Context**: Mean distance percentiles were $0.5769$ in Hyderabad (median $0.6300$, $1.65\% \ge 0.95$) and $0.3939$ in India (median $0.3429$, $1.91\% \ge 0.95$). Most recent observations lie within the historical within-cluster distance distribution, while a small number occupy relatively high-distance tails.
- **Relationship to Phase-4 Supervised Findings**: September observations were strongly concentrated in the humid/lower-pollution historical regime. This pattern is consistent with the lower AQI distribution and reduced adverse-event prevalence observed in the Phase-4 holdout, but the unsupervised analysis does not establish a causal explanation for the supervised-model performance. Furthermore, Phase-4 and Phase-5 eligibility populations are not identical.

## 8. Summary Status
The unsupervised PCA and K-Means analysis is frozen, verified by 93 automated runtime test assertions (63 literal expect calls across 1 test block), and fully reproducible offline.
