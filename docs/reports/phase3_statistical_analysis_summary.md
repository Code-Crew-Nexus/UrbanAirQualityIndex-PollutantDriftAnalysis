# Phase 3: Exploratory Statistical Analysis and Pollutant Drift

## 1. Pollutant Temporal Drift Definition
To assess non-stationary environmental shifts prior to deploying supervised machine learning models, the project quantified temporal drift across all 21 stations for all verified pollutants and source-scale gases.

- **Recent Evaluation Window**: 30 days (August 23, 2026 – September 21, 2026).
- **Preceding Baseline Window**: 90 days (May 25, 2026 – August 22, 2026).
- **Standardized Mean-Shift Drift Score (Z-Score)**: The descriptive magnitude of shift was quantified by taking the difference in means between the recent and baseline windows, normalized by the pooled variance.

## 2. Data-Coverage Eligibility
Stringent eligibility masking was applied to ensure drift calculations were computationally sound. Stations lacking sufficient historical dispersion (e.g., fewer than 5 days in a window or producing zero variance) were correctly excluded from inference calculations without corrupting the broader statistical loop.

## 3. Hyderabad and India Representative-Station Analysis
Drift evaluation was structured independently across the geographic subsets:
- **Hyderabad Representative Panel (7 stations)**
- **India Representative Panel (15 stations)**
The final Phase-3 pipeline successfully executed rigorous geographic filtering to ensure no cross-contamination (e.g., Delhi stations were strictly prevented from leaking into the Hyderabad subset calculation).

## 4. Statistical Inference & Multiple Testing Control
Because sensor data exhibits high temporal autocorrelation (violating standard t-test independence assumptions), the project deployed a sophisticated inference engine:
- **Moving-Block Bootstrap**: Overlapping block resampling (block size = 7 days) empirically derived the null distribution of the mean-shift statistic.
- **Benjamini-Hochberg Procedure**: Adjusted all derived empirical p-values to control the False Discovery Rate (FDR) across 131 eligible station-variable hypothesis tests simultaneously.

## 5. Descriptive Magnitude vs. Statistical Support
A critical finding of Phase 3 is the distinction between descriptive effect sizes and formal statistical significance. While massive descriptive reductions in verified AQI inputs (PM2.5, PM10) were observed moving into the September holdout period, the moving-block bootstrap revealed that due to massive underlying variance and heavy temporal autocorrelation, fewer of these extreme mean shifts could strictly reject the null hypothesis of stationarity than naïve parametric tests would suggest. 

## 6. Source-Scale Gas Limitations
The source-scale descriptive measurements (CO, NO2, SO2) generated drift scores relative strictly to their own variance within a single station. These within-station relative shifts provided diagnostic baseline insights but were disqualified from multi-station AQI derivations as documented in Phase 2.
