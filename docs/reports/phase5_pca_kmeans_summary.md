# Phase 5A: PCA Dimensionality Analysis & K-Means Pollution-Regime Discovery

## 1. Unsupervised Research Objective
Following the completion and freezing of the supervised prediction layer (Phase 4), Phase 5A investigated whether multi-station urban air quality and localized meteorological dynamics can be represented by a reduced latent coordinate system, and whether recurring, interpretable **environmental pollution regimes** emerge without relying on target labels or composite AQI definitions.

## 2. Feature Contract & Exclusion Policy
The unsupervised feature space was strictly restricted to six standardized physical and meteorological measurements:
- **Particulates**: `pm2_5_aqi_input`, `pm10_aqi_input`
- **Photochemical Oxidant**: `o3_8h_max`
- **Meteorology**: `temperature`, `humidity`, `wind_speed`

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
  - **Hyderabad**: 4 PCs capture **90.21%** of total environmental variance.
  - **India**: 4 PCs capture **88.65%** of total environmental variance.
- **Dominant Latent Axes**:
  - **PC1 (Particulate Loading vs Ventilation)**: Heavily loaded by PM10 and PM2.5 (negative) opposing wind speed and humidity.
  - **PC2 (Thermal-Moisture Contrast)**: Strong opposition between high temperature and low relative humidity.
  - **PC3 (Photochemical / Ventilation Dynamics)**: Dominated by O3 variance (Hyderabad) and wind ventilation (India).
  - **PC4 (Localized Atmospheric Dispersion)**: Atmospheric mixing, thermal boundaries, and secondary oxidant interactions.

## 5. K-Means Pollution-Regime Discovery
K-Means clustering was executed in the 4-dimensional retained PCA space across candidate $k \in \{2, \dots, 8\}$ ($nstart=50$, seed `20260925`).
- **Deterministic Selection Rule**: Disqualifying candidate $k$ with small clusters ($< 2\%$ of history or $< 30$ observations) and maximizing average silhouette width, **$k = 3$** was deterministically selected for both panels.
  - **Hyderabad ($k=3$)**: Average Silhouette $= 0.3022$; Between/Total SS $= 45.63\%$.
  - **India ($k=3$)**: Average Silhouette $= 0.3152$; Between/Total SS $= 44.23\%$.
- **Cluster Stability**: Evaluated across 10 random seeds; median Adjusted Rand Index (ARI) was **1.000** for both panels, confirming that the 3-cluster partition is globally robust.

## 6. Discovered Environmental Regimes
### Hyderabad Urban Panel (7 Stations)
1. **Cluster 1 (`warm-dry-moderate-pollution`)** [31.5% history]: Warm ($30.3^\circ\text{C}$), dry ($42.8\%$ humidity), moderate particulates (PM2.5: 32.8, PM10: 78.6 $\mu\text{g/m}^3$), passive AQI $\approx 80.5$. Dominant in Summer / Pre-monsoon.
2. **Cluster 2 (`humid-monsoon-lower-pollution`)** [35.0% history]: Humid ($75.6\%$), elevated wind ($3.87\text{ m/s}$), low particulates (PM2.5: 22.9, PM10: 54.7 $\mu\text{g/m}^3$), passive AQI $\approx 56.5$. Dominant in Monsoon season.
3. **Cluster 3 (`cool-calm-particulate-elevated`)** [33.5% history]: Cooler ($23.9^\circ\text{C}$), low wind ($2.02\text{ m/s}$), elevated particulates (PM2.5: 45.7, PM10: 96.5 $\mu\text{g/m}^3$), passive AQI $\approx 99.8$. Dominant in Winter.

### India Representative Panel (15 Stations)
1. **Cluster 1 (`cool-stagnant-particulate-elevated`)** [18.6% history]: Cool ($21.5^\circ\text{C}$), stagnant wind ($1.80\text{ m/s}$), severe particulates (PM2.5: 100.4, PM10: 186.2 $\mu\text{g/m}^3$), passive AQI $\approx 211.4$ ("Poor/Very Poor"). Dominant in Winter.
2. **Cluster 2 (`hot-dry-ozone-dust-elevated`)** [26.0% history]: High temperature ($30.7^\circ\text{C}$), low humidity ($40.9\%$), elevated O3 ($68.3\text{ ppb}$) and PM10 ($115.8 \mu\text{g/m}^3$), passive AQI $\approx 120.9$. Dominant in Summer.
3. **Cluster 3 (`humid-monsoon-lower-pollution`)** [55.5% history]: Humid ($77.2\%$), active air movement ($2.77\text{ m/s}$), clean air baseline (PM2.5: 29.2, PM10: 62.9 $\mu\text{g/m}^3$), passive AQI $\approx 66.5$. Dominant in Monsoon.

## 7. September Regime Projection & Distribution Shift
Projecting September 2026 ($N=121$ Hyderabad, $N=262$ India) into the frozen centroids revealed massive seasonal regime convergence:
- **Hyderabad Shift**: September observations concentrated **73.6%** into Cluster 2 (`humid-monsoon-lower-pollution`) and **26.4%** into Cluster 1, with **0.0%** in Cluster 3.
- **India Shift**: September observations concentrated **94.7%** into Cluster 3 (`humid-monsoon-lower-pollution`), **5.3%** in Cluster 2, and **0.0%** in Cluster 1.
- This empirical shift explains the 0-positive adverse AQI holdout behavior documented during Phase 4: the atmosphere physically transitioned almost entirely into the wet-scavenging, low-particulate regime.

## 8. Summary Status
The unsupervised PCA and K-Means analysis is complete, verified by 75 automated regression tests, and fully reproducible offline.
