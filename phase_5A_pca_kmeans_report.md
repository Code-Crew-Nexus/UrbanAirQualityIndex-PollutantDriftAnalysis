# Phase 5A: PCA Dimensionality Analysis & K-Means Pollution-Regime Discovery

## SECTION A — UNSUPERVISED ANALYSIS QUESTION
Following the formal freeze of Phase 4 supervised predictive modeling (where next-day quantitative AQI and binary adverse risks were evaluated against persistence benchmarks), Phase 5A addresses the foundational unsupervised statistical learning question:
> **Can multi-station daily air quality and localized meteorological conditions be embedded into a lower-dimensional latent space via Principal Component Analysis (PCA), and does K-Means clustering on those retained latent dimensions reveal recurring, interpretable, and meteorologically coherent environmental pollution regimes across time and space?**

Crucially, this phase is completely unsupervised: composite AQI, future targets, supervised model predictions, and Phase-3 significance labels are strictly prevented from influencing feature scaling, coordinate rotations, or cluster centroids.

---

## SECTION B — FEATURE CONTRACT
The unsupervised feature space is rigidly restricted to six continuous physical and meteorological variables measured daily:
1. `pm2_5_aqi_input`: 24-hour truncated mean fine particulate concentration ($\mu\text{g/m}^3$)
2. `pm10_aqi_input`: 24-hour truncated mean respirable particulate concentration ($\mu\text{g/m}^3$)
3. `o3_8h_max`: Daily maximum 8-hour rolling ozone concentration ($\mu\text{g/m}^3$)
4. `temperature`: Daily mean ambient 2-meter air temperature ($^\circ\text{C}$)
5. `humidity`: Daily mean relative humidity ($\%$)
6. `wind_speed`: Daily mean 10-meter wind speed ($\text{m/s}$)

### Explicit Exclusion Rationale:
- **Composite AQI (`aqi_verified`, `aqi_category`, subindices)**: Excluded because AQI is a piecewise linear deterministic transformation of PM2.5, PM10, and O3. Including AQI alongside its components would overweight repeated pollution information and induce collinearity. AQI is evaluated solely as **passive descriptive metadata** post-clustering.
- **Unresolved Source-Scale Gases (`co_source_mean`, `no2_source_mean`, `so2_source_mean`)**: Excluded because OpenAQ reporting units (ppm/ppb) could not be authoritatively converted to CPCB standard mass concentration units ($\mu\text{g/m}^3$) for the historical study period. Including arbitrary units would distort Euclidean distances.
- **Target Fields & Significance Labels**: `target_aqi_next_day`, `target_adverse_next_day`, and Phase-3 `drift_z` or p-values are excluded to ensure complete functional isolation.

---

## SECTION C — STANDARDIZATION & ZERO-VARIANCE SAFETY
Because environmental parameters operate across vastly different physical scales ($\mu\text{g/m}^3$, $^\circ\text{C}$, $\%$, $\text{m/s}$), unweighted Euclidean clustering or covariance-based PCA would be completely dominated by PM10 variance.

Standardization was conducted strictly on **complete cases from `MODELING_HISTORY` (2025-03-01 to 2026-08-31)**:
$$z_{ij} = \frac{x_{ij} - \bar{x}_{j,\text{hist}}}{s_{j,\text{hist}}}$$

### Authoritative Scaling Statistics (`phase5A_scaling_parameters.csv`):
- **Hyderabad Urban Panel ($N=2,749$ complete historical station-days)**:
  - `pm2_5_aqi_input`: Mean = $33.652601\ \mu\text{g/m}^3$, $\text{SD} = 16.834597\ \mu\text{g/m}^3$
  - `pm10_aqi_input`: Mean = $76.243725\ \mu\text{g/m}^3$, $\text{SD} = 28.677641\ \mu\text{g/m}^3$
  - `o3_8h_max`: Mean = $32.166242\ \mu\text{g/m}^3$, $\text{SD} = 15.352162\ \mu\text{g/m}^3$
  - `temperature`: Mean = $26.612507^\circ\text{C}$, $\text{SD} = 3.285930^\circ\text{C}$
  - `humidity`: Mean = $59.989947\%$, $\text{SD} = 17.390665\%$
  - `wind_speed`: Mean = $2.725712\text{ m/s}$, $\text{SD} = 1.160512\text{ m/s}$
- **India Representative Panel ($N=6,796$ complete historical station-days)**:
  - `pm2_5_aqi_input`: Mean = $47.248234\ \mu\text{g/m}^3$, $\text{SD} = 41.728098\ \mu\text{g/m}^3$
  - `pm10_aqi_input`: Mean = $99.471160\ \mu\text{g/m}^3$, $\text{SD} = 67.072512\ \mu\text{g/m}^3$
  - `o3_8h_max`: Mean = $43.336374\ \mu\text{g/m}^3$, $\text{SD} = 34.558008\ \mu\text{g/m}^3$
  - `temperature`: Mean = $27.104998^\circ\text{C}$, $\text{SD} = 4.374290^\circ\text{C}$
  - `humidity`: Mean = $64.789128\%$, $\text{SD} = 19.705652\%$
  - `wind_speed`: Mean = $2.495111\text{ m/s}$, $\text{SD} = 1.024621\text{ m/s}$

**Safety Audit**: All training standard deviations were confirmed strictly positive ($s > 0$). Standardized history features exhibited mean $< 10^{-10}$ and $\text{SD} = 1.0000000000 \pm 10^{-10}$.

---

## SECTION D — HYDERABAD PCA
PCA was fitted using `stats::prcomp` with `center = FALSE, scale. = FALSE` on the pre-standardized history matrix (with scale attributes cleanly stripped to ensure unbiased eigenvectors):
- **PC1 (Particulate / Ventilation Contrast)**: Negative loadings on `pm10_aqi_input` (-0.554) and `pm2_5_aqi_input` (-0.508) opposing positive loadings on `wind_speed` (+0.469) and `humidity` (+0.435). Captures the contrast between elevated particulate levels and active meteorological dispersion.
- **PC2 (Thermal-Moisture Contrast)**: Positive loading on `temperature` (+0.731) opposing negative loading on `humidity` (-0.505). Reflects warm-dry versus cool-humid thermodynamic variation.
- **PC3 (Ozone-Dominated Axis)**: Dominated by `o3_8h_max` (-0.975), orthogonal to primary particulate loading.
- **PC4 (Wind-Dominated Axis)**: Dominated by `wind_speed` (-0.766) and `temperature` (-0.431).

---

## SECTION E — INDIA REPRESENTATIVE-STATION PCA
Fitted independently across 15 national monitoring stations:
- **PC1 (Particulate / Ventilation Contrast)**: Negative loadings on `pm10_aqi_input` (-0.583) and `pm2_5_aqi_input` (-0.539) opposing `humidity` (+0.357). Reflects national particulate loading versus moist/ventilated conditions.
- **PC2 (Thermal-Moisture Contrast)**: `temperature` (+0.652) opposing `humidity` (-0.573).
- **PC3 (Wind-Dominated Axis)**: Dominated by `wind_speed` (-0.888).
- **PC4 (Ozone / Temperature Axis)**: `o3_8h_max` (-0.775) and `temperature` (+0.494).

---

## SECTION F — PCA VARIANCE EXPLAINED & SELECTION
Using the project deterministic selection rule (retain smallest number of PCs whose cumulative variance explained $\ge 80\%$):

| Scope | PC | Eigenvalue | Variance Explained | Cumulative Variance | Retained? |
|---|---|---|---|---|---|
| **HYDERABAD** | PC1 | 2.319848 | 38.66% | 38.66% | Yes |
| HYDERABAD | PC2 | 1.406734 | 23.45% | 62.11% | Yes |
| HYDERABAD | PC3 | 0.995306 | 16.59% | **78.70%** | Yes (Does NOT reach 80%) |
| HYDERABAD | PC4 | 0.690885 | 11.51% | **90.21%** | **Yes (Selected)** |
| HYDERABAD | PC5 | 0.378566 | 6.31% | 96.52% | No |
| HYDERABAD | PC6 | 0.208660 | 3.48% | 100.00% | No |
| **INDIA** | PC1 | 2.251743 | 37.53% | 37.53% | Yes |
| INDIA | PC2 | 1.468250 | 24.47% | 62.00% | Yes |
| INDIA | PC3 | 0.834971 | 13.92% | **75.92%** | Yes (Does NOT reach 80%) |
| INDIA | PC4 | 0.763821 | 12.73% | **88.65%** | **Yes (Selected)** |
| INDIA | PC5 | 0.425330 | 7.09% | 95.74% | No |
| INDIA | PC6 | 0.255885 | 4.26% | 100.00% | No |

**Critical Reconciliation**: Because PC3 cumulative variance is $78.70\%$ in Hyderabad and $75.92\%$ in India, neither scope satisfies the $80\%$ threshold with 3 PCs. Exactly **4 Principal Components** are legitimately required for both scopes.

---

## SECTION G — PCA LOADING INTERPRETATION
The loadings confirm that environmental air quality is governed by three primary, distinct empirical contrasts:
1. **Particulate vs Ventilation Contrast (PC1)**: Fine and coarse particulates co-vary strongly and represent the dominant source of variation across monitoring stations.
2. **Thermal-Moisture Contrast (PC2)**: Inherent thermodynamics where warm conditions coincide with depressed relative humidity.
3. **Secondary Oxidant / Wind Dynamics (PC3 & PC4)**: Ozone acts orthogonally to primary particulates, alongside localized wind ventilation differences.

---

## SECTION H — K-MEANS SELECTION METHOD (`K_MEANS_K_SELECTION_PROJECT_RULE`)
K-Means was executed on the 4 retained PC scores across $k \in \{2, \dots, 8\}$ with `nstart = 50` and seed `20260925`.
- **Constraint A**: Disqualify candidate $k$ where any cluster contains $< 2.0\%$ of history cases or $< 30$ observations.
- **Constraint B**: Maximize average silhouette width $\bar{s}$.
- **Constraint C**: If silhouette widths tie within $\Delta \le 0.01$, select the smaller $k$ for parsimony.

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
From `phase5A_cluster_profiles.csv`:
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
  - Observed predominantly in Winter (97.02%).

---

## SECTION J — INDIA REGIMES (K=3)
From `phase5A_cluster_profiles.csv`:
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
- **Hyderabad**:
  - Monsoon days fall predominantly into Cluster 2 ($76.16\%$).
  - Summer / Pre-monsoon days fall predominantly into Cluster 1 ($84.24\%$).
  - Winter days fall predominantly into Cluster 3 ($97.02\%$).
  - Post-monsoon days fall predominantly into Cluster 3 ($71.27\%$).
- **India Panel**:
  - Monsoon days fall predominantly into Cluster 3 ($86.86\%$).
  - Summer / Pre-monsoon days fall predominantly into Cluster 2 ($54.40\%$).
  - Winter days fall predominantly into Cluster 1 ($73.05\%$).
  - Post-monsoon days are split between Cluster 3 ($46.97\%$) and Cluster 1 ($43.06\%$).

---

## SECTION N — STATION-LEVEL REGIME DISTRIBUTION
Using verified master station metadata:
- **Hyderabad Panel (7 stations)**: Stations like Central University (`PROJ_044`) and Zoo Park (`PROJ_007`) experience exposure across all three regimes, whereas Somajiguda (`PROJ_181`) records higher particulate-regime frequency during winter.
- **India Panel (15 stations)**: Continental northern stations (e.g. R K Puram, Delhi `PROJ_002`) spend $>60\%$ of their history in the elevated-particulate Cluster 1, whereas southern and coastal stations (e.g. Zoo Park, Hyderabad `PROJ_007`, Manali, Chennai `PROJ_019`, and Jadavpur, Kolkata `PROJ_094`) spend $>60\%$ of their history in the cleaner Cluster 3.

---

## SECTION O — SEPTEMBER PROJECTION (OUT-OF-SAMPLE)
The recent 21-day evaluation window (September 1–21, 2026) was projected onto frozen history centroids:
- Complete recent cases: $N=121$ for Hyderabad, $N=262$ for India.
- **Centroid-Distance Distribution (`phase5A_recent_centroid_distance_summary.csv`)**:
  - **Hyderabad**: Mean percentile = 0.5769, Median = 0.6300, 90th percentile = 0.8671, 95th percentile = 0.9052; 2 observations ($\ge 0.95$, $1.65\%$) occupy high-distance tails.
  - **India**: Mean percentile = 0.3939, Median = 0.3429, 90th percentile = 0.7834, 95th percentile = 0.8466; 5 observations ($\ge 0.95$, $1.91\%$) occupy high-distance tails.
- **Interpretation**: Most recent observations lie within the historical within-cluster distance distribution, while a small number occupy relatively high-distance tails.

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

### Careful Non-Causal Synthesis:
September observations were strongly concentrated in the humid/lower-pollution historical regime. This pattern is consistent with the lower AQI distribution and reduced adverse-event prevalence observed in the Phase-4 holdout, but the unsupervised analysis does not establish a causal explanation for the supervised-model performance. Furthermore, Phase-4 and Phase-5 eligibility populations are not identical. Importantly, elevated-particulate regimes did not completely disappear: Hyderabad recent data still include 11 observations in Cluster 3, and India recent data include 3 observations in Cluster 1.

---

## SECTION Q — LIMITATIONS
1. **Unsupervised vs Causal**: Discovered clusters are descriptive empirical associations; they do not identify emission source types, chemical pathways, or boundary layer mechanisms.
2. **Exclusion of Trace Gases**: CO, NO2, and SO2 were excluded due to unresolved unit semantics; their inclusion could alter secondary regime structures.
3. **Panel Specificity**: Cluster 1 in Hyderabad is not the same entity as Cluster 1 in India; each panel reflects its own geographic scale and scaler normalization.
4. **Complete-Case Filtering**: Complete-case enforcement dropped incomplete sensor records, though the eligibility audit confirms missingness is distributed across seasons.

---

## SECTION R — TEST RESULTS
The hardened Phase 5A test suite (`tests/testthat/test_phase5a.R`) executed **93 automated runtime assertions** (63 literal expect calls across 1 test block) with **0 failures, 0 warnings, and 0 skips**:
- Verified exact 6-feature contract and complete exclusion of AQI, trace gases, targets, and inference fields.
- Verified chronological split and zero influence of September data on scalers, PCA rotation, or centroids.
- Verified mathematical equivalence between manual matrix projection and `predict.prcomp`.
- Verified deterministic K selection rule, cluster size feasibility constraints, and ARI stability across seeds.
- Verified 100% agreement on all 86 checks in `phase5A_numeric_consistency_audit.csv` and 42 checks in `phase5A_report_numeric_integrity_audit.csv`.

---

## SECTION S — NEXT PHASE
With unsupervised dimensionality reduction, pollution regime discovery, and result reconciliation fully completed and frozen, the project can proceed to:
**PHASE 5B — SUPPORT VECTOR MACHINE (SVM) ADVERSE-AQI CLASSIFICATION COMPARISON** (Non-linear supervised benchmarking against Logistic Regression and Persistence).

---

## SECTION T — STATUS
```
PHASE 5A UNSUPERVISED ANALYSIS FROZEN — READY FOR NEXT SML EXTENSION
```
