# Phase 4: Supervised Machine Learning Summary

## 1. Next-Day AQI Prediction Design
The core predictive task was to leverage environmental data from exact calendar day $t$ to forecast the verified AQI status on day $t+1$. 
- **Chronological Split Design**: To prevent data leakage and properly evaluate non-stationary temporal drift, the dataset was split chronologically rather than randomly:
  - **TRAIN / VALIDATION**: Historical tuning windows.
  - **LOCKED TEST**: Aug 2026.
  - **FINAL RECENT HOLDOUT**: Sept 1 – Sept 21, 2026.

## 2. Model Feature Contracts
Two distinct model specifications were engineered and locked:
- **Model A (Environmental)**: Predicts next-day AQI utilizing only meteorological features and current-day raw pollutant concentrations, alongside fixed station factors.
- **Model B (Persistence-Aware)**: Mirrors Model A precisely but explicitly incorporates the current day's verified AQI as an anchor feature.

## 3. Multiple Linear Regression (MLR)
Standard MLR models were fit targeting the continuous next-day AQI.
- **Finding**: While Model B was statistically selected over Model A on validation metrics, simple **Persistence** (natively forecasting tomorrow's exact AQI as today's exact AQI) yielded a lower primary Mean Absolute Error (MAE) than the selected MLR on the frozen TEST and HOLDOUT arrays. This reinforced the severe baseline inertia dominating air quality series and triggered the shift toward probabilistic classification.

## 4. Logistic Adverse-AQI Classification
The target was rigidly binarized (Adverse AQI > 100 vs Non-Adverse AQI $\le$ 100) and evaluated via Logistic Regression (Models A and B).
- **Validation-Only Selection**: Model B was unequivocally selected across both the Hyderabad and India scopes using exclusively the Validation dataset.
- **Frozen Threshold Selection**: Operating probability thresholds (Hyderabad: ~0.311, India: ~0.713) were selected on Validation to maximize Balanced Accuracy and permanently locked.

## 5. Tie-Safe ROC / PR Metrics & Benchmarking
An authoritative, mathematically rigorous `calc_pr_auc_tie_safe()` module was utilized to generate tie-grouped trapezoidal Precision-Recall AUC and step-wise Average Precision. This explicitly protected discrete benchmarks (like Hard Persistence) from order-sensitive artifact inflation.
- **Probability Quality (Brier Score)**: Logistic Model B demonstrated improved probability scoring, cleanly separating risk arrays and significantly beating the Persistence probability benchmark (e.g., India TEST Model B Brier ~0.078 vs. Persistence ~0.116).
- **Ranking**: Model B achieved highly robust separation logic, producing superior ROC-AUC and tie-safe PR-AUC performance relative to baseline anchors.

## 6. Temporal Prevalence Shift & Single-Class Limitations
As the modeling advanced chronologically into the September holdout, the baseline rate of adverse AQI events shifted massively.
- **Hyderabad September Limitation**: Exactly zero adverse AQI days manifested in Hyderabad during the holdout. Model B correctly issued negative forecasts throughout, and the mathematically exact 0-positive constraints were cleanly enforced (forcing two-class discrimination metrics to `NA`).
- **Classification Conclusion**: While Logistic regression excelled at probability distribution and ranking, **fixed-threshold classification performance** remained heavily sensitive to temporal prevalence shift. At static thresholds, hard metrics like F1 occasionally trailed simple Persistence natively when the seasonal background drastically disconnected from historical tuning data.
