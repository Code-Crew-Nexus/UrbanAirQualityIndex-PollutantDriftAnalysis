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
  - **Hyderabad**: PC1 ($\lambda=2.319848$, $38.66\%$), PC2 ($\lambda=1.406734$, $23.45\%$), PC3 ($\lambda=0.995306$, $16.59\%$, cumulative $78.70\%$), PC4 ($\lambda=0.690885$, $11.51\%$, cumulative **$90.21\%$**), PC5 ($\lambda=0.378604$, $6.31\%$), PC6 ($\lambda=0.208622$, $3.48\%$). Because PC3 does not reach $80\%$, exactly 4 PCs are legitimately required.
  - **India**: PC1 ($\lambda=2.251743$, $37.53\%$), PC2 ($\lambda=1.468250$, $24.47\%$), PC3 ($\lambda=0.834971$, $13.92\%$, cumulative $75.92\%$), PC4 ($\lambda=0.763821$, $12.73\%$, cumulative **$88.65\%$**), PC5 ($\lambda=0.425391$, $7.09\%$), PC6 ($\lambda=0.255825$, $4.26\%$). Because PC3 does not reach $80\%$, exactly 4 PCs are legitimately required.
- **Dominant Latent Axes**:
  - **PC1 (Particulate / Ventilation Contrast)**: Negative loadings on PM10 and PM2.5 opposing positive loadings on wind speed and humidity.
  - **PC2 (Thermal-Moisture Contrast)**: Strong opposition between high temperature and low relative humidity.
  - **PC3 (Ozone-Dominated Axis)**: Heavily loaded by O3 variance opposing localized particulate/wind dynamics.
  - **PC4 (Local Atmospheric Dispersion)**: Wind speed and temperature variations.

## 5. K-Means Pollution-Regime Discovery (`K_MEANS_K_SELECTION_PROJECT_RULE`)
K-Means clustering was executed in the 4-dimensional retained PCA space across candidate $k \in \{2, \dots, 8\}$ ($nstart=50$, seed `20260925`).
- **Deterministic Selection Rule**: Disqualifying candidate $k$ with small clusters ($< 2\%$ of history or $< 30$ observations) and maximizing average silhouette width, subject to the within-0.01 tie rule favoring parsimonious $k$. Within-cluster sum of squares (WSS) was evaluated as supportive diagnostic context only. Under this rule, **$k = 3$** was deterministically selected for both panels.
  - **Hyderabad ($k=3$)**: Average Silhouette $= 0.3022$; Between/Total SS $= 45.63\%$.
  - **India ($k=3$)**: Average Silhouette $= 0.3152$; Between/Total SS $= 44.23\%$.
- **Partition Quality**: Both panels exhibit **modest separation with non-degenerate cluster sizes**, representing a useful but overlapping three-regime partition.
- **Cluster Stability**: Evaluated across 10 deterministic multi-start seeds; Adjusted Rand Index (ARI) was **1.000** for both panels, showing high initialization stability across tested seeds.

## 6. Discovered Environmental Regimes
### Hyderabad Urban Panel (7 Stations, $N=2,749$)
1. **Cluster 1 (`warm-dry-moderate-pollution`)** [866 days, 31.50% history]: Warm ($30.33^\circ\text{C}$), dry ($42.78\%$ humidity), moderate particulates (PM2.5: $32.83$, PM10: $78.61\ \mu\text{g/m}^3$), passive AQI mean $= 80.52 \pm 23.59$ ($N=866$). Observed predominantly in Summer / Pre-monsoon ($759/901 = 84.24\%$).
2. **Cluster 2 (`humid-windy-lower-pollution`)** [962 days, 34.99% history]: Humid ($75.58\%$), elevated wind ($3.87\text{ m/s}$), low particulates (PM2.5: $22.90$, PM10: $54.70\ \mu\text{g/m}^3$), passive AQI mean $= 56.54 \pm 19.38$ ($N=962$). Observed predominantly in Monsoon ($805/1,057 = 76.16\%$).
3. **Cluster 3 (`cool-low-wind-particulate-elevated`)** [921 days, 33.50% history]: Cooler ($23.92^\circ\text{C}$), low wind ($2.02\text{ m/s}$), elevated particulates (PM2.5: $45.66$, PM10: $96.52\ \mu\text{g/m}^3$), passive AQI mean $= 99.79 \pm 31.45$ ($N=921$). Observed predominantly in Winter ($423/436 = 97.02\%$) and Post-monsoon ($253/355 = 71.27\%$).

### India Representative Panel (15 Stations, $N=6,796$)
1. **Cluster 1 (`cool-low-wind-particulate-elevated`)** [1,261 days, 18.56% history]: Cool ($21.52^\circ\text{C}$), low wind ($1.80\text{ m/s}$), elevated particulates (PM2.5: $100.41$, PM10: $186.17\ \mu\text{g/m}^3$), passive AQI mean $= 211.38 \pm 92.70$ (valid $N=1,260$). Observed predominantly in Winter ($740/1,013 = 73.05\%$).
2. **Cluster 2 (`hot-dry-ozone-pm10-elevated`)** [1,764 days, 25.96% history]: High temperature ($30.65^\circ\text{C}$), low humidity ($40.89\%$), elevated O3 ($68.33\ \mu\text{g/m}^3$) and PM10 ($115.76\ \mu\text{g/m}^3$), passive AQI mean $= 120.87 \pm 41.09$ (valid $N=1,742$). Observed predominantly in Summer / Pre-monsoon ($1,266/2,327 = 54.40\%$).
3. **Cluster 3 (`humid-windy-lower-pollution`)** [3,771 days, 55.49% history]: Humid ($77.23\%$), active wind ($2.77\text{ m/s}$), lower particulate and ozone concentrations (PM2.5: $29.24$, PM10: $62.86\ \mu\text{g/m}^3$), passive AQI mean $= 66.48 \pm 30.56$ (valid $N=3,771$). Observed predominantly in Monsoon ($2,314/2,664 = 86.86\%$).

*Note on Passive AQI Missingness*: While clustering operates on six-feature complete cases, passive `aqi_verified` metadata can occasionally be missing due to subindex completeness constraints (1 missing in India Cluster 1, 22 missing in India Cluster 2).

### Station Distribution Context
Station profiles reflect clear geographic variation:
- **Coastal/High-Ventilation Sites**: Manali, Chennai (`PROJ_019`) spends $92.45\%$ of historical observations in Cluster 3 (`humid-windy-lower-pollution`). Jadavpur, Kolkata (`PROJ_094`) spends $69.31\%$ in Cluster 3.
- **Arid/Inland Summer Sites**: Maninagar, Ahmedabad (`PROJ_024`) spends $58.19\%$ of historical observations in Cluster 2 (`hot-dry-ozone-pm10-elevated`).
- **Balanced Multi-Regime Sites**: R K Puram, Delhi (`PROJ_002`) experiences a balanced distribution across all three regimes (Cluster 1: $36.12\%$, Cluster 2: $36.78\%$, Cluster 3: $27.09\%$). Zoo Park in the India panel (`PROJ_007`) spends $55.87\%$ in Cluster 3, $26.29\%$ in Cluster 2, and $17.84\%$ in Cluster 1.

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
- **Centroid-Distance Context**: Evaluated via within-cluster historical distance percentiles:
  - **Hyderabad Recent**: Mean percentile $= 0.576864$, median $= 0.629750$, 90th percentile $= 0.866944$, 95th percentile $= 0.905312$. Exactly 3 observations ($2.48\%$) had percentile $\ge 0.95$.
  - **India Recent**: Mean percentile $= 0.393887$, median $= 0.342880$, 90th percentile $= 0.782551$, 95th percentile $= 0.846513$. Exactly 2 observations ($0.76\%$) had percentile $\ge 0.95$.
  - *Interpretation*: Most recent observations lie within the historical within-cluster distance distribution. Only a small fraction of September observations occupied the upper 5% tail of their assigned historical cluster-distance distribution.
- **Relationship to Phase-4 Supervised Findings**: September observations were strongly concentrated in the humid/lower-pollution historical regime. This pattern is consistent with the lower AQI distribution and reduced adverse-event prevalence observed in the Phase-4 holdout, but the unsupervised analysis does not establish a causal explanation for the supervised-model performance. Furthermore, Phase-4 and Phase-5 eligibility populations are not identical.

## 8. Summary Status
The unsupervised PCA and K-Means analysis is frozen, verified by 115 automated runtime test assertions (79 literal expect calls across 6 modular test blocks), and fully reproducible offline.
