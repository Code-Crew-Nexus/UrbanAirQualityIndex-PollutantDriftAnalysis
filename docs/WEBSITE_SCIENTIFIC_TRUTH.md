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
| **Calculation Policy** | `VERIFIED_SUBSET_PM25_PM10_O3` | `config/cpcb_breakpoints.csv`, `scripts/06_calculate_aqi.R` |
| **Included Pollutants** | $\text{PM}_{2.5}$ (24-hr avg), $\text{PM}_{10}$ (24-hr avg), $\text{O}_3$ (8-hr max / daily avg) | CPCB 2014 Standardized Breakpoints |
| **Excluded Pollutants** | $\text{CO}$, $\text{NO}_2$, $\text{SO}_2$ are **excluded** from AQI due to unverified source units / lack of certified conversion | Level-1 Data Engineering Policy |
| **Sub-Index Formula** | Piecewise linear: $I_p = \frac{I_{hi} - I_{lo}}{B_{hi} - B_{lo}} (C_p - B_{lo}) + I_{lo}$ | CPCB (2014) Technical Documentation |
| **Overall AQI Rule** | $\text{AQI} = \max_{p \in \mathcal{P}_{valid}} \{ I_p \}$ where $|\mathcal{P}_{valid}| \ge 3$ and ($\text{PM}_{10} \in \mathcal{P}_{valid} \lor \text{PM}_{2.5} \in \mathcal{P}_{valid}$) | Verified CPCB Subset Standard |

---

## 3. Pollutant Drift Design & Magnitude Classification

| Parameter | Specification | Authority Source |
| :--- | :--- | :--- |
| **Recent Window** | $t-29$ to $t$ (30 calendar days, rolling) | `scripts/08_drift_analysis.R` |
| **Baseline Window** | $t-119$ to $t-30$ (90 calendar days, preceding non-overlapping) | `scripts/08_drift_analysis.R` |
| **Recent Minimum Days** | $\ge 21 / 30$ valid daily observations ($70\%$ data completeness) | `scripts/08_drift_analysis.R` |
| **Baseline Minimum Days** | $\ge 63 / 90$ valid daily observations ($70\%$ data completeness) | `scripts/08_drift_analysis.R` |
| **Drift Metric ($D_z$)** | $D_z = \frac{\bar{x}_{\text{recent}} - \bar{x}_{\text{baseline}}}{s_{\text{baseline}}}$ ($s_{baseline}$; uses **baseline standard deviation**, rather than pooled dispersion) | Phase 3B Analysis Pipeline |
| **Minimal Drift** | $\|D_z\| < 0.5$ | Canonical Classification Rule |
| **Mild Drift** | $0.5 \le \|D_z\| < 1.0$ | Canonical Classification Rule |
| **Moderate Drift** | $1.0 \le \|D_z\| < 2.0$ | Canonical Classification Rule |
| **Strong Drift** | $\|D_z\| \ge 2.0$ | Canonical Classification Rule |
| **Temporal Interpretation** | Rolling temporal shift between recent 30 days and preceding 90 days. Seasons are used solely as descriptive context. | Accepted Phase 3B Closure |
| **Empirical Finding** | Station-level drift tests show a mixture of supported increase, supported decrease, unsupported, and not tested. No universal single-direction claim is valid. | Phase 3B/3C Frozen Output |

---

## 4. Statistical Inference & Resampling

| Parameter | Specification | Authority Source |
| :--- | :--- | :--- |
| **Resampling Method** | Moving-Block Bootstrap (MBB) preserving serial autocorrelation | `scripts/09_statistical_inference.R` |
| **Primary Block Length** | $l = 7$ days | Phase 3C Specification |
| **Sensitivity Block Lengths** | $l = 3$ days and $l = 14$ days | Phase 3C Robustness Audit |
| **Bootstrap Repetitions** | $B = 2000$ resamples | Phase 3C Specification |
| **Multiple Testing Correction**| Benjamini–Hochberg False Discovery Rate (BH-FDR, $\alpha = 0.05$) applied globally | Phase 3C Inference Standards |
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
- **Binary Adverse Event Target:** $Y_{t+1} = \mathbb{I}(\text{AQI}_{t+1} > 100)$ (1 if next-day AQI exceeds Moderate threshold of 100, else 0).
- **Continuous AQI Target:** Next-day continuous AQI ($\text{AQI}_{t+1}$) for Multiple Linear Regression.

### Logistic Regression
- **Functional Form:** $\log \left( \frac{\pi_{t+1}}{1 - \pi_{t+1}} \right) = \beta_0 + \sum_{j=1}^p \beta_j X_{tj}$ where $\pi_{t+1}$ represents the **estimated conditional probability of the adverse class**.
- **Model Family:** Selected **Model B** (persistence-aware, including lag-1 AQI and rolling statistics).
- **Decision Threshold Selection:** Thresholds selected on **VALIDATION** to maximize balanced accuracy, frozen prior to out-of-sample testing.
  - **Hyderabad Selected Threshold:** $p^* \approx \mathbf{0.311268}$ (exact: `0.3112681`)
  - **India Selected Threshold:** $p^* \approx \mathbf{0.713448}$ (exact: `0.713448`)
- **Policy:** Never describe Logistic classification as using a universal default $p^* = 0.50$.

### Multiple Linear Regression (OLS)
- **Model Selection:** Model B selected on validation MAE in both scopes.
- **Empirical Reality:** While Model B was optimal among linear specifications, the baseline **Single-Day Persistence** retained lower primary MAE on frozen TEST and holdout evaluations. Persistence benchmark was strong; no speculative atmospheric stagnation mechanisms are asserted.

### Support Vector Machine (RBF SVM)
- **Engine & Kernel:** `e1071::svm` C-classification with Radial Basis Function kernel $K(\mathbf{x}_i, \mathbf{x}_j) = \exp(-\gamma \|\mathbf{x}_i - \mathbf{x}_j\|^2)$.
- **Hyderabad Selected Hyperparameters:** Cost $C = 16.0$, Gamma $\gamma = 0.0100$
- **India Selected Hyperparameters:** Cost $C = 4.0$, Gamma $\gamma \approx 0.007575758$ (`0.0075758`)
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
