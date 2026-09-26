# Theoretical Concepts & Statistical Foundations

**Project:** `UrbanAirQualityIndex-PollutantDriftAnalysis` | **Course:** Statistics for Machine Learning (SML) PBL | **Organization:** `Code-Crew-Nexus` | **Baseline Status:** `v0.6-svm-freeze`

## 1. Overview of Theoretical Framework

This reference outlines core mathematical formulations across the pipeline: method representation, justification, mathematical specification, interpretation, and methodological cautions.

## 2. Regulatory Subindex Interpolation (Verified-Subset AQI)

### What It Is & Why Used
The Indian National Air Quality Index (NAQI) defined by the Central Pollution Control Board (CPCB) converts heterogeneous pollutant mass concentrations into a unified, dimensionless scale ($0$ to $500$) across six health bands (Good to Severe), establishing an objective benchmark without opaque third-party proprietary scores.

### Key Formula
For a given pollutant concentration $C_p$, the subindex $I_p$ is computed via segmented piecewise linear interpolation:

$$
I_p = \frac{I_{high}-I_{low}}{BP_{high}-BP_{low}}(C_p-BP_{low}) + I_{low}
$$

Where:
- $C_p$: 24-hour truncated average concentration (or trailing 8-hour maximum for $\text{O}_3$).
- $[BP_{low}, BP_{high}]$: Regulatory breakpoint interval enclosing $C_p$.
- $[I_{low}, I_{high}]$: Sub-index category range corresponding to the breakpoint interval.
- Final composite index: $I = \max(I_1, I_2, \dots, I_m)$.

### How to Interpret It
A higher subindex indicates greater acute health hazard. The overall index is determined by the "worst" subindex among all eligible pollutants.

### Project-Specific Caution
> [!IMPORTANT]
> **Verified-Subset AQI Policy:** The project strictly applies a **CPCB-methodology-aligned verified-subset AQI** computed exclusively from **PM2.5, PM10, and O3** ($\text{PM}_{2.5}$, $\text{PM}_{10}$, $\text{O}_3$). Gaseous pollutants (CO, NO2, and SO2 / $\text{CO}$, $\text{NO}_2$, $\text{SO}_2$) are conservatively **excluded** from AQI computation due to unresolved source-unit semantics in modern OpenAQ streams following the 2022 dual-unit tracking deprecation. This metric is a verified-input estimate and must NOT be cited as the official operational six-pollutant CPCB AQI.

---

## 3. Pollutant Drift Quantification (Standardized Mean Shift)

### What It Is
A dimensionless standardization used to measure shifts in pollutant concentration distributions between distinct temporal observation windows.

### Why This Project Used It
To detect and quantify environmental distribution shifts over time across multi-station monitoring networks. The primary drift analysis evaluates a **rolling 30-day recent window ($t-29$ to $t$) versus a preceding non-overlapping 90-day baseline window ($t-119$ to $t-30$)**. Seasonal designations serve strictly as descriptive context.

### Key Formula
The drift score $D_z$ is formulated as a standardized mean difference standardized by the **baseline standard deviation**:

$$
D_z = \frac{\bar{x}_{recent}-\bar{x}_{baseline}}{s_{baseline}}
$$

Where:
- $\bar{x}_{recent}$: Sample mean of pollutant concentrations during the recent 30-day window ($\ge 21/30$ valid days required).
- $\bar{x}_{baseline}$: Sample mean during the preceding 90-day baseline window ($\ge 63/90$ valid days required).
- $s_{baseline}$: Sample standard deviation during the baseline period (requires $s_{baseline} > 0$; strictly uses baseline standard deviation $s_{baseline}$, rather than pooled dispersion).

### How to Interpret It
- $D_z > 0$: Recent concentrations have shifted above baseline averages.
- $D_z < 0$: Recent concentrations have decreased below baseline averages.
- **Exact Project Magnitude Classes**:
  - **Minimal**: $|D_z| < 0.5$
  - **Mild**: $0.5 \le |D_z| < 1.0$
  - **Moderate**: $1.0 \le |D_z| < 2.0$
  - **Strong**: $|D_z| \ge 2.0$

### Project-Specific Caution
> [!NOTE]
> $D_z$ is strictly a **descriptive standardized mean-shift measure**, NOT a parametric hypothesis-test $z$-statistic. It does not assume Gaussian errors or temporal independence. Formal station-level inferential tests show a heterogeneous mixture of supported increases, supported decreases, unsupported shifts, and non-eligible series; universal single-direction claims (e.g. universal scavenging) are unsupported.

---

## 4. Statistical Inference on Autocorrelated Data (Moving-Block Bootstrap)

### What It Is
A non-parametric resampling technique that samples continuous temporal blocks of observations rather than individual points.

### Why This Project Used It
Urban air quality time series exhibit pronounced serial autocorrelation and diurnal/cyclical structure. Standard independent identically distributed (i.i.d.) bootstrap resampling destroys temporal dependencies, causing downward bias in standard error estimation.

### Methodology
Given a daily time series of length $N$, the sequence is partitioned into overlapping blocks of length $l$. Random blocks are drawn with replacement to assemble synthetic bootstrap trajectories:

$$
\mathbf{B}_k = \{x_{\tau}, x_{\tau+1}, \dots, x_{\tau+l-1}\}
$$

- **Primary Block Length:** $l = 7$ days (captures weekly cyclical persistence).
- **Sensitivity Block Lengths:** $l = 3$ days and $l = 14$ days.
- **Bootstrap Repetitions:** $B = 2000$ ($2{,}000$) resamples for Phase-3C primary inference.
- **Multiple Testing:** Global Benjamini–Hochberg False Discovery Rate (BH-FDR, $\alpha = 0.05$) correction.

### Project-Specific Caution
Resampling preserves serial correlation within blocks, but does not prove causal mechanisms or isolate non-meteorological emission interventions. Statistical significance of temporal shift does not equal atmospheric causation.

---

## 5. Multiple Linear Regression (Continuous Next-Day AQI)

### What It Is
A classical parametric supervised regression model expressing continuous next-day verified AQI ($\widehat{\text{AQI}}_{t+1}$) as a linear combination of day-$t$ predictors.

### Why This Project Used It
Provides an interpretable baseline to evaluate how much next-day variance can be explained by linear relationships with day-$t$ environmental features, temporal harmonics, and station fixed effects.

### Key Formula

$$
\hat{y} = \beta_0 + \sum_{j=1}^{p}\beta_j x_j
$$

In vector notation:

$$
\hat{y} = \beta_0 + \mathbf{x}^{T}\boldsymbol{\beta}
$$

### How to Interpret It
Each coefficient $\beta_j$ represents the estimated marginal change in next-day AQI for a one-unit increase in predictor $x_j$, holding all other predictors fixed.

### Key Project Findings & Caution
- **Model B (Persistence-Aware)** incorporates day-$t$ verified AQI as an autoregressive predictor and was selected on validation MAE across both scopes.
- **Persistence Benchmark:** On frozen out-of-sample TEST and holdout evaluations, simple single-day persistence ($\widehat{\text{AQI}}_{t+1} = \text{AQI}_t$) retained lower primary Mean Absolute Error (MAE) than fitted linear models. The persistence benchmark was strong, reflecting high continuous temporal correlation.
- **Caution:** Linear models cannot represent nonlinear boundaries or multi-pollutant interactions.

---

## 6. Logistic Regression (Probabilistic Adverse Event Classification)

### What It Is
A generalized linear model for binary classification that estimates the **conditional probability of the adverse class** for next-day air quality episodes via the logistic sigmoid function.

### Why This Project Used It
Stakeholders and public health advisories benefit from probabilistic alerts indicating whether tomorrow's air will cross regulatory thresholds rather than uncalibrated point estimates.

### Key Formula

$$
P(Y=1\mid\mathbf{x}) = \frac{1}{1+\exp(-(\beta_0+\mathbf{x}^{T}\boldsymbol{\beta}))}
$$

The log-odds (logit) transformation is linear:

$$
\ln\left(\frac{\pi}{1-\pi}\right) = \beta_0 + \sum_{j=1}^{p}\beta_j x_j
$$

Where $\pi = P(Y=1\mid\mathbf{x})$ denotes the estimated conditional adverse-event probability.

### Target Definition
The frozen supervised adverse event target is:

$$
\text{target\_adverse\_next\_day} = 1 \iff \text{AQI}_{t+1} > 100
$$

Where $\text{AQI}_{t+1} > 100$ designates Moderate, Poor, Very Poor, or Severe air quality under CPCB guidelines.

### How to Interpret It
Exponentials of coefficients $\exp(\beta_j)$ correspond to multiplicative odds ratios. If $\exp(\beta_j) = 1.25$, a one-unit increase in $x_j$ multiplies the odds of an adverse event tomorrow by $1.25$.

### Decision Threshold Selection & Caution
Logistic classification does **not** assume a universal default $p^* = 0.50$. Instead, operating decision thresholds were selected strictly on the **VALIDATION** split to maximize Balanced Accuracy and frozen prior to out-of-sample testing:
- **Hyderabad Selected Threshold:** $p^* \approx \mathbf{0.311268}$ (`0.3112681`)
- **India Selected Threshold:** $p^* \approx \mathbf{0.713448}$ (`0.713448`)

Model performance is evaluated using threshold-independent Precision-Recall AUC (PR-AUC) alongside thresholded metrics.

---

## 7. Principal Component Analysis (Orthogonal Feature Compression)

### What It Is
An unsupervised linear dimensionality reduction technique that projects correlated multi-sensor features onto an orthogonal set of principal axes maximizing explained variance.

### Why This Project Used It
To evaluate the intrinsic dimensionality of urban air quality sensor arrays and eliminate multicollinearity prior to clustering.
- **Input Features ($p = 6$):** $\text{PM}_{2.5}$, $\text{PM}_{10}$, $\text{O}_3$, temperature, relative humidity, wind speed (standardized $z$-scores).
- **Explicit Exclusions:** Composite AQI is excluded from input (avoids derivation circularity); unresolved gases ($\text{CO}, \text{NO}_2, \text{SO}_2$) are excluded.

### Key Formula
Given the sample correlation matrix $S$, principal directions $\mathbf{v}_j$ and variance eigenvalues $\lambda_j$ satisfy:

$$
S\mathbf{v}_j = \lambda_j\mathbf{v}_j, \quad \text{subject to } \mathbf{v}_j^T \mathbf{v}_k = \delta_{jk}
$$

### Scope Independence & Retained Dimensions
PCA was fitted independently for the two geographic panels:
- **Hyderabad Panel:** Exactly **4 Principal Components** retained, explaining **$90.21\%$** cumulative variance ($\lambda_1=2.32, \lambda_2=1.41, \lambda_3=1.00, \lambda_4=0.69$).
- **India Representative Panel:** Exactly **4 Principal Components** retained, explaining **$88.65\%$** cumulative variance ($\lambda_1=2.25, \lambda_2=1.47, \lambda_3=0.83, \lambda_4=0.76$).

### Latent Axis Descriptions
Loadings differ between panels and are described by empirical data table contrasts:
- **Particulate / Ventilation Contrast:** Particulate concentrations opposing wind speed and moisture.
- **Thermal-Moisture Contrast:** Opposition between high temperature and relative humidity.
- **Ozone-Dominated Axis:** Distinct variance contribution from $\text{O}_3$.
- **Wind / Environmental Contrast:** Localized dispersion dynamics.
*(Universal labels such as "Photochemical Smog Axis" are avoided).*

---

## 8. $K$-Means Clustering (Urban Pollution Regime Discovery)

### What It Is
An iterative partitional clustering algorithm that partitions observations in the 4-dimensional retained PCA space into $k$ discrete clusters, minimizing within-cluster sum of squares.

### Why This Project Used It
To discover whether multi-station urban air quality organizes into discrete, reproducible environmental regimes across seasons and geography.

### Methodology & Selection Rule
- **Candidate Regimes:** $k \in \{2, 3, 4, 5, 6, 7, 8\}$ ($nstart=50$, deterministic seed).
- **Selection Decision:** Disqualified candidate $k$ with small clusters ($< 2\%$ of history or $< 30$ observations) and maximized average silhouette width, subject to a within-0.01 parsimony tie rule. Within-cluster sum of squares (WSS) served as supportive context.
- **Deterministic Outcome:** **$k = 3$ was selected for Hyderabad** and **$k = 3$ was selected for India**.

### Key Formula

$$
\underset{C_1,\ldots,C_k}{\operatorname{minimize}} \sum_{r=1}^{k} \sum_{\mathbf{z}_i\in C_r} \|\mathbf{z}_i-\boldsymbol{\mu}_r\|^2
$$

Where $\mathbf{z}_i$ is the 4-dimensional PCA coordinate vector and $\boldsymbol{\mu}_r$ is the cluster centroid.

### Authoritative Table-Derived Cluster Regimes ($k=3$)
- **Hyderabad Urban Regimes ($k=3$):**
  1. `warm-dry-moderate-pollution`: Elevated temperature ($30.3^\circ\text{C}$), low humidity ($42.8\%$), moderate particulates.
  2. `humid-windy-lower-pollution`: High humidity ($75.6\%$), elevated wind ($3.87\text{ m/s}$), low particulates.
  3. `cool-low-wind-particulate-elevated`: Cooler temperature ($23.9^\circ\text{C}$), calm wind ($2.02\text{ m/s}$), elevated particulates.
- **India Representative Regimes ($k=3$):**
  1. `cool-low-wind-particulate-elevated`: Low temperature ($21.5^\circ\text{C}$), low wind ($1.80\text{ m/s}$), elevated particulate concentrations.
  2. `hot-dry-ozone-pm10-elevated`: High temperature ($30.7^\circ\text{C}$), low humidity ($40.9\%$), elevated $\text{O}_3$ and $\text{PM}_{10}$.
  3. `humid-windy-lower-pollution`: High humidity ($77.2\%$), active wind ($2.77\text{ m/s}$), lower overall pollution.

### Project-Specific Caution
> [!CAUTION]
> Cluster labels are **descriptive regime summaries**. They summarize empirical multi-sensor states and do not identify specific emission sources or atmospheric chemical mechanisms. Historical exploratory 4-cluster draft labels are completely superseded and retired in favor of table-derived empirical profiles.

---

## 9. Nonlinear Support Vector Machine (RBF Kernel Margin Classifier)

### What It Is
A maximum-margin classifier that maps input predictor vectors into an implicit feature space using the Radial Basis Function (RBF) kernel to construct an optimal separating hyperplane.

### Why This Project Used It
To test whether nonlinear decision boundaries provide superior ranking for next-day adverse AQI events compared to linear Logistic Model B and persistence.

### Key Formulas

**Radial Basis Function Kernel:**

$$
K(\mathbf{x},\mathbf{x}') = \exp\left(-\gamma \|\mathbf{x}-\mathbf{x}'\|^2\right)
$$

**Continuous Margin Decision Score:**

$$
s(\mathbf{x}) = \sum_{i=1}^{N_{sv}} \alpha_i y_i K(\mathbf{x}_i,\mathbf{x}) + b
$$

Hard classification uses the native decision boundary: $f(\mathbf{x}) = \operatorname{sgn}(s(\mathbf{x}))$.

### Hyperparameter Selection
Selected on **VALIDATION** split by PR-AUC:
- **Hyderabad Panel:** Cost $C = 16.0$, Gamma $\gamma = 0.0100$
- **India Panel:** Cost $C = 4.0$, Gamma $\gamma \approx 0.007575758$ (`0.0075758`)

### Key Project Findings & Limitation
- On the India Representative Panel, RBF SVM achieved **superior PR-AUC ranking on the locked TEST set** ($0.8335$ vs. Logistic Model B $0.8255$).
- Raw SVM decision scores $s(\mathbf{x})$ represent **uncalibrated event/classification rankings** (evaluated via PR-AUC), NOT calibrated posterior probabilities.
- On native uncalibrated hard classification ($s(\mathbf{x}) \ge 0$), SVM achieved $F_1 = 0.7218$ on India TEST. In low-prevalence regimes (Hyderabad TEST with $2.3\%$ adverse rate), the native zero boundary yielded zero true positive predictions ($F_1 = \text{NA}$). Alternative operating thresholds or calibration could be evaluated as future extensions.

---

## 10. Summary of Evaluation Metrics

| Metric | Formulation | Domain / Purpose | Project Application |
| :--- | :--- | :--- | :--- |
| **MAE** | $\frac{1}{N}\sum \|y_i - \hat{y}_i\|$ | Continuous regression error | Evaluates average AQI point forecast deviation |
| **RMSE** | $\sqrt{\frac{1}{N}\sum (y_i - \hat{y}_i)^2}$ | Continuous regression error | Penalizes large acute forecast misses |
| **$R^2$** | $1 - \frac{\sum (y_i - \hat{y}_i)^2}{\sum (y_i - \bar{y})^2}$ | Explained variance fraction | Assesses explanatory power of MLR specifications |
| **PR-AUC** | $\int_0^1 p(r) \, dr$ | Classification / event ranking | Primary selection metric under class imbalance (evaluated tie-safely) |
| **ROC-AUC** | $\int_0^1 \text{TPR}(\text{FPR}) \, d\text{FPR}$ | Diagnostic discrimination | Evaluates true positive vs. false positive tradeoff |
| **Brier Score** | $\frac{1}{N}\sum (p_i - y_i)^2$ | Probabilistic scoring rule | Probability-error metric evaluating accuracy and sharpness of estimated probabilities |
| **$F_1$ Score** | $\frac{2 \cdot \text{Precision} \cdot \text{Recall}}{\text{Precision} + \text{Recall}}$ | Hard classification balance | Evaluated at frozen validation thresholds ($p^*$) for Logistic; at native margin boundary $s(\mathbf{x})=0$ for SVM |
| **Balanced Accuracy** | $\frac{\text{Sensitivity} + \text{Specificity}}{2}$ | Class-normalized accuracy | Arithmetic mean of sensitivity and specificity, preventing majority-class dominance |
