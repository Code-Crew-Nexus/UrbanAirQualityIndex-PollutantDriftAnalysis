# Detailed Execution Guide & Phase-by-Phase Walkthrough

**Project:** `UrbanAirQualityIndex-PollutantDriftAnalysis`  
**Course:** Statistics for Machine Learning — Project Based Learning  
**Organization:** `Code-Crew-Nexus`  
**Baseline Status:** `v0.6-svm-freeze`

---

## Faculty Walkthrough Structure

This document outlines the structured execution history of the project from initial station discovery through statistical modeling, unsupervised regime discovery, support vector machines, and the static presentation layer. Each phase adheres to a standardized academic specification.

---

## Phase 1 — Data Authenticity & Station Selection

- **Objective:** Identify, audit, and select authentic Central and State Pollution Control Board (CPCB / SPCB) CAAQMS stations with sufficient historical sensor coverage.
- **Input:** OpenAQ v3 station discovery endpoints, CPCB portal station inventories, and `config/candidate_india_cities.csv`.
- **Method:** 90-day multi-pollutant completeness auditing, sensor lineage verification, and geographical representation balancing.
- **Key Script(s):**
  - `scripts/01_run_station_audit.R`
  - `scripts/01a_build_metadata_shortlist.R`
  - `scripts/01c_build_station_selection_summary.R`
- **Output Artifact(s):**
  - `config/selected_stations.csv`
  - `docs/phase1_station_selection_decision.md`
- **Key Result:** Established a frozen panel of **21 unique physical monitoring stations**: 7 Hyderabad metropolitan stations and 15 India representative national stations (with 1 overlapping station: `PROJ_007 Zoo Park, Hyderabad`).
- **Important Limitation:** Unequal distribution of continuous analyzers across Tier-2 Indian cities necessitated selecting primary state capitals.
- **Related Figure / Screenshot:** Station selection decision matrix documented in [`docs/phase1_station_selection_decision.md`](../phase1_station_selection_decision.md).

---

## Phase 2 — Acquisition, Harmonization & Verified AQI

- **Objective:** Harvest 19 months of hourly air quality and meteorological observations, harmonize units, calculate 24-hour aggregations, and compute regulatory Indian AQI.
- **Input:**
  - `config/selected_stations.csv`
  - OpenAQ v3 API hourly concentrations
  - Open-Meteo Historical Weather API hourly surface weather
  - `config/final_aqi_input_policy.yml`
- **Method:** Strict chronological chunked acquisition, SHA-256 raw data hashing, UTC to Indian Standard Time (`Asia/Kolkata`) conversion, daily maximum rolling 8-hour ozone (`o3_8h_max`) evaluation, and segmented linear interpolation based on verified CPCB breakpoint tables.
- **Key Script(s):**
  - `scripts/03_build_datasets.R`
  - `scripts/04b_phase2B_full_acquisition.R`
  - `scripts/05a_phase2C_preAQI_engineering.R`
  - `scripts/09_phase2E_generate_final_aqi.R`
- **Output Artifact(s):**
  - `data/processed/UAQI_Master_Daily.csv` (11,970 station-days across 570 study days)
  - `data/processed/UAQI_Hyderabad_Daily.csv` (3,990 station-days)
  - `data/processed/UAQI_India_Daily.csv` (8,550 station-days)
  - `docs/reports/phase2_data_aqi_summary.md`
- **Key Result:** Generated canonical daily panel datasets with missingness preserved and verified-subset AQI computed where sufficiency requirements were met from **2025-03-01 through 2026-09-21** applying the verified-subset policy (`VERIFIED_SUBSET_PM25_PM10_O3`).
- **Important Limitation:** OpenAQ dual-unit tracking ended in 2022; because modern mass concentrations for CO, NO2, and SO2 cannot be independently cross-verified against official CPCB portals without scraping, those three gases were excluded from the sub-index to preserve absolute scientific authenticity.
- **Related Figure / Screenshot:** CPCB breakpoint schedule and verified-subset policy detailed in [`docs/cpcb_aqi_methodology_verified.md`](../cpcb_aqi_methodology_verified.md).

---

## Phase 3 — Exploratory Analysis, Pollutant Drift & Statistical Inference

- **Objective:** Quantify distributional properties of pollutants, measure temporal distribution shifts (drift) across rolling windows, and compute formal confidence intervals under temporal autocorrelation.
- **Input:** `data/processed/UAQI_Master_Daily.csv`.
- **Method:** Parametric and non-parametric summary statistics, rolling standardized mean difference ($D_z = (\bar{x}_{recent} - \bar{x}_{baseline})/s_{baseline}$ over 30-day recent vs. preceding 90-day baseline), and moving-block bootstrap resampling ($B = 2{,}000$ iterations, primary block length = 7 days, sensitivity blocks = 3 and 14 days) with Benjamini-Hochberg FDR correction.
- **Key Script(s):**
  - `scripts/10_phase3A_exploratory_analysis.R`
  - `scripts/11_phase3B_pollutant_drift.R`
  - `scripts/12_phase3C_statistical_inference.R`
- **Output Artifact(s):**
  - `analysis/phase3A/`, `analysis/phase3B/`, `analysis/phase3C/`
  - `docs/reports/phase3_statistical_analysis_summary.md`
- **Key Result:** Empirical tests revealed a heterogeneous mixture of supported increases, supported decreases, unsupported shifts, and non-eligible series across stations. Block-resampling demonstrated that fewer descriptive mean shifts achieved formal statistical significance under autocorrelation than naïve tests suggest; no universal single-direction conclusion (such as uniform scavenging) is supported.
- **Important Limitation:** Standardized drift scores ($D_z$) are descriptive effect sizes and do not prove causal emission abatement mechanisms.
- **Related Figure / Screenshot:** Summary statistics and bootstrap distributions detailed in [`docs/reports/phase3_statistical_analysis_summary.md`](../reports/phase3_statistical_analysis_summary.md).

---

## Phase 4 — Supervised Learning (MLR & Logistic Regression)

- **Objective:** Design leakage-free temporal splits, train Multiple Linear Regression (MLR) models for continuous next-day AQI prediction ($\widehat{\text{AQI}}_{t+1}$), and train Logistic Regression models for adverse-event classification ($\text{AQI}_{t+1} > 100$).
- **Input:**
  - `data/processed/UAQI_Master_Daily.csv`
  - Temporal splits: TRAIN (`2025-03-02` to `2025-12-31`), VALIDATION (`2026-01-01` to `2026-04-30`), locked TEST (`2026-05-01` to `2026-08-31`), final HOLDOUT (`2026-09-01` to `2026-09-21`)
- **Method:** Ordinary least squares (OLS) regression and generalized linear models (GLM binomial family). Comparison of persistence-free (Model A) vs. persistence-aware (Model B) specifications. Model selection on VALIDATION split via PR-AUC and MAE.
- **Key Script(s):**
  - `scripts/13_phase4A_prediction_design.R`
  - `scripts/14a_phase4B_train_validate_select.R`
  - `scripts/14b_phase4B_locked_test_holdout.R`
  - `scripts/15a_phase4C_train_validate_select.R`
  - `scripts/15b_phase4C_locked_test_holdout.R`
- **Output Artifact(s):**
  - `config/phase4B_selected_models.yml`
  - `config/phase4C_selected_models.yml`
  - `docs/reports/phase4_supervised_learning_summary.md`
  - `docs/figures/07_test_mae_comparison.png`
  - `docs/figures/05_validation_prauc_comparison.png`
  - `docs/figures/20_logistic_benchmark_comparison.png`
- **Key Result:** Persistence-aware Model B was selected across both MLR and Logistic families. However, naive single-day persistence ($\text{AQI}_t$) retained lower primary MAE on frozen TEST and holdout evaluations. For Logistic regression, operating decision thresholds selected on validation ($p^* \approx 0.311268$ for Hyderabad, $p^* \approx 0.713448$ for India) yielded strong PR-AUC ranking ($0.8255$ on India TEST).
- **Important Limitation:** Fixed classification thresholds are sensitive to temporal prevalence shifts (e.g. adverse event frequency drops between seasonal windows).
- **Related Figure / Screenshot:** [`docs/figures/05_validation_prauc_comparison.png`](../figures/05_validation_prauc_comparison.png) and [`docs/figures/07_test_mae_comparison.png`](../figures/07_test_mae_comparison.png).

---

## Phase 5A — Unsupervised Discovery (PCA & $K$-Means Regimes)

- **Objective:** Evaluate multi-sensor dimensionality via Principal Component Analysis (PCA) and discover discrete urban air quality regimes across stations via $K$-Means clustering.
- **Input:** Standardized continuous environmental features from `data/processed/UAQI_Master_Daily.csv` ($\text{PM}_{2.5}, \text{PM}_{10}, \text{O}_3$, temperature, humidity, wind speed; composite AQI and unresolved gases excluded).
- **Method:** Correlation-matrix eigen-decomposition (`prcomp` with unit variance scaling) and seed-locked Hartigan-Wong $K$-Means evaluated across candidate $k \in \{2, \dots, 8\}$ with silhouette-width and cluster size feasibility rules.
- **Key Script(s):**
  - `scripts/18a_phase5A_pca.R`
  - `scripts/18b_phase5A_kmeans.R`
  - `scripts/18c_phase5A_profiles_figures.R`
- **Output Artifact(s):**
  - `models/phase5A/`
  - `docs/reports/phase5_pca_kmeans_summary.md`
  - `docs/figures/03_cumulative_variance_comparison.png`
  - `docs/figures/06_hyderabad_pca_pc1_pc2_by_cluster.png`
  - `docs/figures/07_india_pca_pc1_pc2_by_cluster.png`
- **Key Result:** Identified that **4 principal components retain $90.21\%$ cumulative variance in Hyderabad and $88.65\%$ in India**. Evaluated $k \in \{2, \dots, 8\}$ and deterministically selected **$k=3$ clusters for both panels**, identifying table-derived descriptive regimes: `warm-dry-moderate-pollution`, `humid-windy-lower-pollution`, and `cool-low-wind-particulate-elevated` for Hyderabad; `cool-low-wind-particulate-elevated`, `hot-dry-ozone-pm10-elevated`, and `humid-windy-lower-pollution` for India.
- **Important Limitation:** PCA was fitted independently by scope; cluster labels are descriptive regime summaries and do not identify atmospheric chemical mechanisms or specific emission sources.
- **Related Figure / Screenshot:** [`docs/figures/03_cumulative_variance_comparison.png`](../figures/03_cumulative_variance_comparison.png) and [`docs/figures/07_india_pca_pc1_pc2_by_cluster.png`](../figures/07_india_pca_pc1_pc2_by_cluster.png).

---

## Phase 5B — Nonlinear Support Vector Machine (RBF Kernel SVM)

- **Objective:** Benchmark flexible nonlinear margin separation against frozen Logistic Model B and simple persistence for next-day adverse AQI classification.
- **Input:** 25 features for Hyderabad, 33 features for India (continuous meteorology/pollutants + one-hot station and day-of-week indicators).
- **Method:** 20-candidate hyperparameter grid search over Cost ($C \in \{0.25, 1, 4, 16\}$) and Gamma ($\gamma \in \{0.25, 0.5, 1, 2, 4\} \times 1/p$), optimized on VALIDATION PR-AUC, followed by evaluation on the locked TEST set and September holdout.
- **Key Script(s):**
  - `scripts/20a_phase5B_prepare_design.R`
  - `scripts/20b_phase5B_train_validate_select.R`
  - `scripts/20c_phase5B_test_holdout_evaluation.R`
  - `scripts/20d_phase5B_figures.R`
- **Output Artifact(s):**
  - `config/phase5B_selected_svm.yml`
  - `docs/reports/phase5b_svm_summary.md`
  - `docs/figures/phase5b_10_test_prauc_comparison.png`
  - `docs/figures/phase5b_11_test_f1_comparison.png`
  - `docs/figures/phase5b_20_overall_svm_comparison_summary.png`
- **Key Result:** On the India Representative Panel, RBF SVM ($C=4.0, \gamma=0.007576$) achieved **superior PR-AUC ranking on the locked TEST set ($0.8335$)** compared to Logistic Model B ($0.8255$) and elevated native hard-classification $F_1$ from $0.5794$ to $0.7218$.
- **Important Limitation:** Raw SVM decision scores $s(\mathbf{x})$ are uncalibrated event rankings rather than probabilities. In low-prevalence regimes (Hyderabad TEST with $2.3\%$ adverse events), the native uncalibrated zero boundary produced zero true positives ($F_1 = \text{NA}$). Alternative operating thresholds or calibration could be evaluated as future extensions.
- **Related Figure / Screenshot:** [`docs/figures/phase5b_20_overall_svm_comparison_summary.png`](../figures/phase5b_20_overall_svm_comparison_summary.png) and [`docs/figures/phase5b_10_test_prauc_comparison.png`](../figures/phase5b_10_test_prauc_comparison.png).

---

## Phase 6 — Static Project Website (Presentation Layer)

- **Objective:** Deploy a professional, zero-dependency static presentation website on GitHub Pages that dynamically consumes frozen R analytical assets and renders single-source Markdown documentation and mathematical formulas.
- **Input:**
  - Frozen project metadata (`config/`)
  - Canonical documentation (`docs/*.md`, `docs/reports/*.md`)
  - Web foundation JSON (`docs/web-data/*.json`)
- **Method:** HTML5 semantic layout, custom CSS3 adhering to the Graphite $\times$ Jade $\times$ Champagne palette, Vanilla JavaScript documentation engine with local vendored Marked.js and KaTeX.
- **Key Script(s):**
  - `scripts/30_export_web_assets.R`
  - `docs/assets/js/markdown-renderer.js`
  - `docs/assets/js/documentation-manifest.js`
  - `tests/testthat/test_phase6a_website.R`
- **Output Artifact(s):**
  - `docs/index.html`
  - `docs/explore.html`
  - `docs/statistics.html`
  - `docs/machine-learning.html`
  - `docs/documentation.html`
  - `docs/about.html`
  - `docs/assets/css/styles.css`
  - `docs/web-data/project_summary.json`
- **Key Result:** Accessible, fully responsive academic project website rendering math formulas with KaTeX, displaying workflow pipelines, and providing single-source documentation for faculty review without any server runtime or npm build pipeline.
- **Important Limitation:** Read-only presentation layer that visualizes precomputed R results; does not perform real-time model retraining in the browser.
