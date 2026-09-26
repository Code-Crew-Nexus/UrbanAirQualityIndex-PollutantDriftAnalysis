# Statistical Machine Learning Modeling Freeze Summary

**Project:** `UrbanAirQualityIndex-PollutantDriftAnalysis`  
**Organization:** `Code-Crew-Nexus`  
**Academic Context:** Statistics for Machine Learning (SML) Project Based Learning (PBL)  
**Status:** Frozen Modeling Baseline (v0.6-svm-freeze)

---

## Executive Overview

This document summarizes the final accepted modeling artifacts developed across Phases 4, 5A, and 5B. All predictive models, dimensionality reductions, cluster regimes, hyperparameter selections, and out-of-sample evaluations are permanently frozen and audited for reproducibility.

---

## 1. Phase 4 — Supervised Baseline Models

### Multiple Linear Regression (MLR)
- **Purpose:** Continuous next-day verified AQI forecasting ($\widehat{\text{AQI}}_{t+1}$) using linear combinations of day-$t$ pollutant concentrations, meteorology, temporal harmonics, and station effects.
- **Frozen Tag:** `v0.4-supervised-freeze`
- **Main Finding:** Model B (persistence-aware: $\text{Model B} = \text{Model A} + \text{aqi\_verified}$) was selected by VALIDATION MAE in both scopes. Single-day persistence retained lower primary MAE on the frozen TEST and holdout evaluations. India TEST Model B nevertheless achieved lower RMSE than persistence.
- **Important Limitation:** Linear regression represents additive linear predictor effects and showed heavy-tailed / heteroscedastic residual behavior in the frozen evaluation.

### Logistic Regression Classification
- **Purpose:** Probabilistic classification of next-day adverse air quality episodes ($\text{AQI}_{t+1} > 100$).
- **Frozen Tag:** `v0.4-supervised-freeze`
- **Main Finding:** Logistic Model B provided well-behaved out-of-sample probability ranking (PR-AUC $\approx 0.8255$ on India TEST) and direct interpretability via odds ratios ($\exp(\beta)$).
- **Important Limitation:** Operating decision thresholds were tuned on VALIDATION by balanced accuracy (Hyderabad $p^* \approx 0.311268$, India $p^* \approx 0.713448$). However, performance on TEST reflected sharp temporal prevalence shifts (e.g. low-prevalence evaluation period in Hyderabad with 2.3% adverse events).

---

## 2. Phase 5A — Unsupervised Dimensionality & Regime Discovery

### Principal Component Analysis (PCA)
- **Purpose:** Orthogonal feature compression of 6 core environmental variables (PM2.5, PM10, O3, temperature, humidity, wind speed) to assess underlying atmospheric dimensionality.
- **Frozen Tag:** `v0.5-unsupervised-freeze`
- **Main Finding:** The first four PCs retained 90.21% of Hyderabad variance and 88.65% of India variance. Loading interpretations differ by panel and are reported descriptively.
- **Important Limitation:** Linear projections do not represent nonlinear manifold structures or temporal lag dynamics.

### $K$-Means Clustering
- **Purpose:** Unsupervised identification of discrete urban air pollution regimes across multi-station monitoring networks.
- **Frozen Tag:** `v0.5-unsupervised-freeze`
- **Main Finding:** Selected a useful but overlapping three-regime partition ($K=3$ in both panels) with modest silhouette separation and high initialization stability across tested seeds, represented by table-derived descriptive profiles.
- **Important Limitation:** Partitional centroid-based clustering forces spherical cluster geometries in normalized feature space; cluster labels summarize descriptive contrasts without asserting causal emissions sources.

---

## 3. Phase 5B — Nonlinear Support Vector Machine (RBF SVM)

### Radial Basis Function (RBF) Kernel SVM
- **Purpose:** Evaluate whether a flexible nonlinear margin classifier improves next-day adverse air quality discrimination relative to frozen Logistic Model B and simple persistence.
- **Frozen Tag:** `v0.6-svm-freeze`
- **Main Finding:** On the heterogeneous 15-station India Representative Panel, RBF SVM ($C=4.0, \gamma=0.007576$) achieved superior out-of-sample ranking on the locked TEST split (PR-AUC $0.8335$ vs. Logistic $0.8255$) and elevated native hard-classification $F_1$ from $0.5794$ to $0.7218$ (matching single-day persistence at $0.7267$).
- **Important Limitation:** In low-prevalence settings (Hyderabad TEST with $2.3\%$ adverse events), the unweighted SVM decision hyperplane ($s(\mathbf{x}) \ge 0$) captured 0 true positives ($F_1 = \text{NA}$ under project convention), demonstrating that nonlinear margin separation does not replace operating threshold calibration under extreme class imbalance.

---

## Conclusion & Milestone Transition

The statistical / machine-learning model-development stage is frozen. Phase 6 integrates these accepted artifacts into a static project website (HTML5/CSS3/Vanilla JS hosted on GitHub Pages) that consumes frozen results produced by R, without retraining models.
