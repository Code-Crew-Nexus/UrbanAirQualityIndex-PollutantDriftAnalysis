# Website Scientific Truth Table

**Project:** `UrbanAirQualityIndex-PollutantDriftAnalysis`  
**Milestone:** `v0.6-svm-freeze`  
**Authority Level:** Level 2 Canonical Truth Reference for Website Presentation  
**Status:** Authoritative Frozen Scientific Baseline  

---

## 1. Study Design & Panel Definitions

| Parameter | Specification | Authority Source |
| :--- | :--- | :--- |
| **Study Window** | `2025-03-01` through `2026-09-21` (570 calendar days) | `data/processed/UAQI_Master_Daily.csv` |
| **Unique Physical Stations** | **21 physical stations** across India | `config/selected_stations.csv` |
| **Hyderabad Metropolitan Panel** | **7 stations** (Zoo Park, Bollaram, Central Univ, ECIL Kapra, Kompally, Somajiguda, New Malakpet) | `config/selected_stations.csv` (`use_hyderabad == TRUE`) |
| **India Representative Panel** | **15 stations** across diverse climatic and geographic zones | `config/selected_stations.csv` (`use_india == TRUE`) |
| **Panel Overlap** | **Zoo Park, Hyderabad (`PROJ_007`)** is intentionally present in **both** panels | `config/selected_stations.csv` |
| **Total Station-Days** | $21 \times 570 = 11,970$ scheduled station-days (missing observations preserved) | Level-1 Dataset Integrity Audit |

---

## 2. AQI Calculation Policy

| Parameter | Specification | Authority Source |
| :--- | :--- | :--- |
| **Calculation Policy** | `VERIFIED_SUBSET_PM25_PM10_O3` | `config/aqi_breakpoints_india.csv`, `config/final_aqi_input_policy.yml`, `scripts/09_phase2E_generate_final_aqi.R` |
| **Included Pollutants** | $\text{PM}_{2.5}$ (24-hr avg input), $\text{PM}_{10}$ (24-hr avg input), $\text{O}_3$ (`o3_8h_max`, verified project 8-hour ozone pathway) | `config/final_aqi_input_policy.yml`, CPCB 2014 Standardized Breakpoints |
| **Excluded Pollutants** | $\text{CO}$, $\text{NO}_2$, $\text{SO}_2$ are **excluded** from AQI due to unverified source units / lack of certified conversion | `config/final_aqi_input_policy.yml`, `scripts/09_phase2E_generate_final_aqi.R` |
| **Sub-Index Formula** | Piecewise linear segmented interpolation: $I_p = \frac{I_{hi} - I_{lo}}{B_{hi} - B_{lo}} (C_p - B_{lo}) + I_{lo}$ | `config/aqi_breakpoints_india.csv`, CPCB (2014) Technical Documentation |
| **Verified-Subset Validity Rule** | Under the frozen project implementation, a valid verified-subset AQI strictly requires valid subindices for **all three** included verified pollutants: $\mathcal{P}_{verified} = \{ \text{PM}_{2.5}, \text{PM}_{10}, \text{O}_3 \}$ ($|\mathcal{P}_{valid}| = 3$). Composite $\text{AQI} = \max(I_{\text{PM}_{2.5}}, I_{\text{PM}_{10}}, I_{\text{O}_3})$. Unverified gases ($\text{CO}, \text{NO}_2, \text{SO}_2$) cannot substitute. | `config/final_aqi_input_policy.yml`, `scripts/09_phase2E_generate_final_aqi.R` |

---

## 3. Pollutant Drift Design & Magnitude Classification

| Parameter | Specification | Authority Source |
| :--- | :--- | :--- |
| **Recent Window** | $t-29$ to $t$ (30 calendar days, rolling) | `scripts/11_phase3B_pollutant_drift.R` |
| **Baseline Window** | $t-119$ to $t-30$ (90 calendar days, preceding non-overlapping) | `scripts/11_phase3B_pollutant_drift.R` |
| **Recent Minimum Days** | $\ge 21 / 30$ valid daily observations ($70\%$ data completeness) | `scripts/11_phase3B_pollutant_drift.R` |
| **Baseline Minimum Days** | $\ge 63 / 90$ valid daily observations ($70\%$ data completeness) | `scripts/11_phase3B_pollutant_drift.R` |
| **Drift Metric ($D_z$)** | $D_z = \frac{\bar{x}_{\text{recent}} - \bar{x}_{\text{baseline}}}{s_{\text{baseline}}}$ ($s_{baseline}$; uses **baseline standard deviation**, rather than pooled dispersion; requires $s_{\text{baseline}} > 0$) | `scripts/11_phase3B_pollutant_drift.R` |
| **Minimal Drift** | $\|D_z\| < 0.5$ | Canonical Classification Rule |
| **Mild Drift** | $0.5 \le \|D_z\| < 1.0$ | Canonical Classification Rule |
| **Moderate Drift** | $1.0 \le \|D_z\| < 2.0$ | Canonical Classification Rule |
| **Strong Drift** | $\|D_z\| \ge 2.0$ | Canonical Classification Rule |
| **Temporal Interpretation** | Rolling temporal shift between recent 30 days and preceding 90 days. Seasons are used solely as descriptive context. | Accepted Phase 3B Closure (`scripts/11_phase3B_pollutant_drift.R`) |
| **Empirical Finding** | Station-level drift tests show a mixture of supported increase, supported decrease, unsupported, and not tested. No universal single-direction claim is valid. | Phase 3B/3C Frozen Output (`scripts/11_phase3B_pollutant_drift.R`, `scripts/12_phase3C_statistical_inference.R`) |

---

## 4. Statistical Inference & Resampling

| Parameter | Specification | Authority Source |
| :--- | :--- | :--- |
| **Resampling Method** | Moving-Block Bootstrap (MBB) preserving serial autocorrelation | `scripts/12_phase3C_statistical_inference.R` |
| **Primary Block Length** | $l = 7$ days | `scripts/12_phase3C_statistical_inference.R` |
| **Sensitivity Block Lengths** | $l = 3$ days and $l = 14$ days | Phase 3C Robustness Audit (`scripts/12_phase3C_statistical_inference.R`) |
| **Bootstrap Repetitions** | $B = 2000$ resamples | `scripts/12_phase3C_statistical_inference.R` |
| **Multiple Testing Correction**| Benjamini–Hochberg False Discovery Rate (BH-FDR, $\alpha = 0.05$) applied globally | `scripts/12_phase3C_statistical_inference.R` |
| **Scientific Scope** | Demonstrates robust temporal variation; does not alone establish atmospheric or chemical causation. | Phase 3C Accepted Report |

---

## 5. Machine Learning Partitions & Chronology

All models were evaluated on strict chronological partitions without lookahead bias:

| Split Name | Target Date Window | Role in Pipeline | Refit Status for Evaluation |
| :--- | :--- | :--- | :--- |
| **TRAIN** | `2025-03-02` through `2025-12-31` | Model parameter estimation (MLR, Logistic, SVM) | Initial model fit |
| **VALIDATION** | `2026-01-01` through `2026-04-30` | Hyperparameter selection ($C, \gamma$, thresholds, feature subsets) | Frozen during selection |
| **TEST** | `2026-05-01` through `2026-08-31` | Out-of-sample performance evaluation | Refit on Train + Validation (`2025-03-02` → `2026-04-30`) |
| **FINAL RECENT HOLDOUT**| `2026-09-01` through `2026-09-21` | Final locked prospective evaluation | Refit on Train + Validation + Test (`2025-03-02` → `2026-08-31`) |

---

## 6. Supervised Learning Specifications

### Target Definition
- **Binary Adverse Event Target:** $Y_{t+1} = \mathbb{I}(\text{AQI}_{t+1} > 100)$ (`target_adverse_next_day = 1` iff $\text{AQI}_{t+1} > 100$), taking value 1 if next-day verified AQI strictly exceeds 100 (classifying as Moderately Polluted, Poor, Very Poor, or Severe, where $\text{AQI} > 100$) versus non-adverse (Good or Satisfactory, where $\text{AQI} \le 100$). The boundary 100 is the upper limit of Satisfactory; AQI=100 is Satisfactory, and only strictly $\text{AQI}_{t+1} > 100$ is adverse.
- **Continuous AQI Target:** Next-day continuous verified AQI (`target_aqi_next_day`, $\text{AQI}_{t+1}$) for Multiple Linear Regression. Authority: `config/modeling_specification.yml`.

### Predictor Feature Contracts (Model A & Model B)
Authority: `config/modeling_specification.yml`
- **Model A (Environmental-Only):**
  - Pollutant inputs ($p=3$): `pm2_5_aqi_input`, `pm10_aqi_input`, `o3_8h_max`
  - Meteorology ($p=5$): `temperature`, `humidity`, `wind_speed`, `sin_wind_direction`, `cos_wind_direction`
  - Calendar harmonics ($p=3$): `day_of_week` (factor), `month_sin`, `month_cos`
  - Station effects: `project_station_id` (factor)
- **Model B (Persistence-Aware):**
  - $\text{Model B} = \text{Model A} + \text{aqi\_verified}$ (EXACT Model A predictors plus current day-$t$ verified AQI `aqi_verified`).
  - **Zero Rolling Statistics:** Model B contains **no extra rolling-statistic predictors** and no additional lag terms. Current day-$t$ verified AQI is the sole persistence-aware addition.

### Logistic Regression
- **Functional Form:** $\log \left( \frac{\pi_{t+1}}{1 - \pi_{t+1}} \right) = \beta_0 + \sum_{j=1}^p \beta_j X_{tj}$ where $\pi_{t+1}$ represents the **estimated conditional probability of the adverse class** ($P(Y_{t+1}=1 \mid \mathbf{x}_t)$).
- **Model Family:** Selected **Model B** (persistence-aware: $\text{Model B} = \text{Model A} + \text{aqi\_verified}$; zero rolling statistics).
- **Decision Threshold Selection:** Thresholds selected on **VALIDATION** to maximize balanced accuracy, frozen prior to out-of-sample testing.
  - **Hyderabad Selected Threshold:** $p^* \approx \mathbf{0.311268}$ (exact: `0.3112681`)
  - **India Selected Threshold:** $p^* \approx \mathbf{0.713448}$ (exact: `0.713448`)
- **Authority:** `config/phase4C_selected_models.yml`.
- **Policy:** Never describe Logistic classification as using a universal default $p^* = 0.50$.

### Multiple Linear Regression (OLS)
- **Model Selection:** Model B ($\text{Model B} = \text{Model A} + \text{aqi\_verified}$) selected on validation MAE in both scopes (`config/phase4B_selected_models.yml`).
- **Empirical Reality:** While Model B was selected by validation MAE in both scopes, the baseline **Single-Day Persistence** retained lower primary MAE on the frozen TEST and holdout evaluations. Persistence benchmark remained strong; India TEST Model B nevertheless achieved lower RMSE than persistence. No speculative atmospheric stagnation mechanisms are asserted.
- **Model Limitation:** Linear regression represents additive linear predictor effects and showed heavy-tailed / heteroscedastic residual behavior in the frozen evaluation.

### Support Vector Machine (RBF SVM)
- **Engine & Kernel:** `e1071::svm` C-classification with Radial Basis Function kernel $K(\mathbf{x}_i, \mathbf{x}_j) = \exp(-\gamma \|\mathbf{x}_i - \mathbf{x}_j\|^2)$.
- **Hyderabad Selected Hyperparameters:** Cost $C = 16.0$, Gamma $\gamma = 0.0100$
- **India Selected Hyperparameters:** Cost $C = 4.0$, Gamma $\gamma \approx 0.007575758$ (`0.0075758`)
- **Authority:** `config/phase5B_selected_svm.yml`.
- **Decision Boundary:** Hard classification uses native decision score boundary $s(\mathbf{x}) = 0$. Raw decision scores represent uncalibrated event/classification rankings (PR-AUC ranking), NOT posterior probabilities. Alternative operating thresholds or calibration could be evaluated as future extensions.

---

## 7. Unsupervised Learning Specifications

### Principal Component Analysis (PCA)
- **Features ($p = 6$):** $\text{PM}_{2.5}$, $\text{PM}_{10}$, $\text{O}_3$, temperature, relative humidity, wind speed (standardized $z$-scores).
- **Explicit Exclusions:** AQI is excluded from input (avoids circularity); other gaseous pollutants ($\text{CO}, \text{NO}_2, \text{SO}_2$) are excluded.
- **Scope Independence:** PCA was fitted independently by scope; loadings differ between panels and must not be conflated into a single universal physical interpretation.
- **Retained Components:**
  - **Hyderabad Panel:** **4 Principal Components** retaining **90.21%** ($90.21\%$) cumulative variance.
  - **India Panel:** **4 Principal Components** retaining **88.65%** ($88.65\%$) cumulative variance.
- **Interpreted Axes:** Described using table-derived contrasts: particulate / ventilation contrast, thermal-moisture contrast, ozone-dominated axis, wind / environmental contrast. Unsupported terms such as "Photochemical Smog Axis" are forbidden.

### K-Means Clustering
- **Candidate Regimes:** $K \in \{2, 3, 4, 5, 6, 7, 8\}$ evaluated on PCA projection scores.
- **Selection Decision:** **$K = 3$ selected for Hyderabad**; **$K = 3$ selected for India** based on cluster size feasibility, highest silhouette score, and smaller-$K$ tie-breaking within 0.01. WSS is supportive only.
- **Authoritative Table-Derived Cluster Labels:**
  - **Hyderabad Regimes ($K=3$):**
    1. `warm-dry-moderate-pollution`
    2. `humid-windy-lower-pollution`
    3. `cool-low-wind-particulate-elevated`
  - **India Regimes ($K=3$):**
    1. `cool-low-wind-particulate-elevated`
    2. `hot-dry-ozone-pm10-elevated`
    3. `humid-windy-lower-pollution`
- **Methodological Caution:** Cluster labels are descriptive regime summaries. They do not identify atmospheric mechanism or pollutant source.
- **Superseded Labels:** Early 4-cluster exploratory draft labels are completely superseded and retired in favor of table-derived empirical profiles.
