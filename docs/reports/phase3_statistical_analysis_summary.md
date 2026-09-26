# Phase 3: Exploratory Statistical Analysis and Pollutant Drift

## 1. Pollutant Temporal Drift Definition
To assess non-stationary environmental shifts prior to deploying supervised machine learning models, the project quantified temporal drift across all 21 stations for all verified pollutants and source-scale gases.

- **Recent Evaluation Window**: 30 days (rolling $t-29$ to $t$).
- **Preceding Baseline Window**: 90 days (preceding non-overlapping $t-119$ to $t-30$).
- **Standardized Mean-Shift Drift Score ($D_z$)**: The descriptive magnitude of shift was quantified by taking the difference in means between recent and baseline windows, standardized by the **baseline standard deviation** ($s_{\text{baseline}}$):
  $$D_z = \frac{\bar{x}_{\text{recent}} - \bar{x}_{\text{baseline}}}{s_{\text{baseline}}}$$
  (The metric strictly uses baseline standard deviation $s_{\text{baseline}}$, rather than pooled dispersion).
- **Exact Drift Magnitude Classes**:
  - **Minimal**: $|D_z| < 0.5$
  - **Mild**: $0.5 \le |D_z| < 1.0$
  - **Moderate**: $1.0 \le |D_z| < 2.0$
  - **Strong**: $|D_z| \ge 2.0$

## 2. Data-Coverage Eligibility
Stringent eligibility masking was applied to ensure drift calculations were computationally sound. Stations were evaluated only if they met strict completeness thresholds:
- **Recent Window**: at least **21 valid days out of 30** ($\ge 70\%$ data completeness).
- **Baseline Window**: at least **63 valid days out of 90** ($\ge 70\%$ data completeness).
- **Positive Dispersion**: baseline standard deviation $s_{\text{baseline}} > 0$.
Series failing these criteria were flagged as non-eligible for inference without corrupting the broader statistical loop.

## 3. Hyderabad and India Representative-Station Analysis
Drift evaluation was structured independently across the geographic panels:
- **Hyderabad Representative Panel (7 stations)**
- **India Representative Panel (15 stations)**
The final Phase-3 pipeline successfully executed rigorous geographic filtering to ensure no cross-contamination (e.g., Delhi stations were strictly prevented from leaking into the Hyderabad subset calculation; Zoo Park, Hyderabad was intentionally included in both panels).

## 4. Statistical Inference & Multiple Testing Control
Because sensor time series exhibit temporal autocorrelation (violating standard parametric independence assumptions), the project deployed a block-resampling inference engine:
- **Moving-Block Bootstrap (MBB)**: Overlapping block resampling empirically derived the null distribution of the mean-shift statistic:
  - **Primary block length**: $l = 7$ days (preserving weekly cyclical structure).
  - **Sensitivity block lengths**: $l = 3$ days and $l = 14$ days.
  - **Bootstrap repetitions**: $B = 2000$ resamples per test.
- **Benjamini-Hochberg Procedure**: Adjusted all derived empirical $p$-values to control the False Discovery Rate (FDR, $\alpha = 0.05$) across eligible station-variable hypothesis tests simultaneously.

## 5. Descriptive Magnitude vs. Statistical Support
A critical finding of Phase 3 is the distinction between descriptive effect sizes and formal statistical significance. Across eligible tests, the results revealed a heterogeneous mixture of supported increases, supported decreases, unsupported shifts, and non-eligible series. Formal inference demonstrates that due to underlying variance and serial autocorrelation, fewer mean shifts could strictly reject the stationary null hypothesis after FDR correction than naïve uncorrected tests would suggest. Atmospheric causation cannot be asserted from statistical drift alone. 

## 6. Source-Scale Gas Limitations
The source-scale descriptive measurements (CO, NO2, SO2) generated drift scores relative strictly to their own variance within a single station. These within-station relative shifts provided diagnostic baseline insights but were disqualified from multi-station AQI derivations as documented in Phase 2.
