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
- **Main Finding:** Model B (persistence-aware, including day-$t$ AQI) demonstrated significant explanatory power ($R^2 \approx 0.65$–$0.72$), but single-day persistence achieved lower primary Mean Absolute Error (MAE) during periods of high environmental inertia.
- **Important Limitation:** Linear specifications cannot capture nonlinear regime shifts or extreme acute pollution spikes without overfitting higher-order terms.

### Logistic Regression Classification
- **Purpose:** Probabilistic classification of next-day adverse air quality episodes ($\text{AQI}_{t+1} > 100$).
- **Frozen Tag:** `v0.4-supervised-freeze`
- **Main Finding:** Logistic Model B provided well-behaved out-of-sample probability ranking (PR-AUC $\approx 0.8255$ on India TEST) and direct interpretability via odds ratios ($\exp(\beta)$).
- **Important Limitation:** Fixed probability decision thresholds ($p^* = 0.50$) experienced severe sensitivity drop-offs during sharp seasonal prevalence collapses (e.g., monsoon clearing in Hyderabad).

---

## 2. Phase 5A — Unsupervised Dimensionality & Regime Discovery

### Principal Component Analysis (PCA)
- **Purpose:** Orthogonal feature compression of 6 core environmental variables (PM2.5, PM10, O3, temperature, humidity, wind speed) to assess underlying atmospheric dimensionality.
- **Frozen Tag:** `v0.5-unsupervised-freeze`
- **Main Finding:** The first 4 principal components captured $> 83\%$ of total multi-sensor variance, establishing clear separation between particulate-dominated, photochemical, and meteorological dispersion axes.
- **Important Limitation:** Linear projections do not represent nonlinear manifold structures or temporal lag dynamics.

### $K$-Means Clustering
- **Purpose:** Unsupervised identification of discrete urban air pollution regimes across multi-station monitoring networks.
- **Frozen Tag:** `v0.5-unsupervised-freeze`
- **Main Finding:** Robust identification of $k=4$ distinct environmental regimes (Clean/Scavenged, Photochemical Moderate, Particulate High, Severe Inversion/Stagnation) with high silhouette consistency across geographical scopes.
- **Important Limitation:** Partitional centroid-based clustering forces spherical cluster geometries in normalized feature space.

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
