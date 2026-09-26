# Theoretical Concepts & Statistical Foundations

**Project:** `UrbanAirQualityIndex-PollutantDriftAnalysis`  
**Course:** Statistics for Machine Learning (SML) — Project Based Learning (PBL)  
**Organization:** `Code-Crew-Nexus`  
**Baseline Status:** `v0.6-svm-freeze`

---

## 1. Overview of Theoretical Framework

This reference outlines the core mathematical and statistical formulations implemented across the analytical pipeline. Each topic highlights **what** the method represents, **why** this study deployed it, its **mathematical specification**, **interpretation guidelines**, and **project-specific methodological cautions**.

---

## 2. Regulatory Subindex Interpolation (Verified-Subset AQI)

### What It Is
The Indian National Air Quality Index (NAQI) defined by the Central Pollution Control Board (CPCB) converts heterogeneous pollutant mass concentrations into a unified, dimensionless scale ($0$ to $500$) categorized into six health bands (Good, Satisfactory, Moderate, Poor, Very Poor, Severe).

### Why This Project Used It
To establish a rigorous, objective benchmark for urban atmospheric quality without relying on opaque third-party proprietary scores.

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
A dimensionless standardization used to measure shifts in pollutant concentration distributions between distinct seasonal or temporal observation windows.

### Why This Project Used It
To detect and quantify environmental distribution shifts across seasons (e.g., pre-monsoon vs. monsoon) across multi-station monitoring networks.

### Key Formula
The drift score $D_z$ is formulated as a standardized mean difference:

$$
D_z = \frac{\bar{x}_{recent}-\bar{x}_{baseline}}{s_{baseline}}
$$

Where:
- $\bar{x}_{recent}$: Sample mean of pollutant concentrations during the recent observation period.
- $\bar{x}_{baseline}$: Sample mean during the reference baseline period.
- $s_{baseline}$: Sample standard deviation during the baseline period.

### How to Interpret It
- $D_z > 0$: Recent concentrations have shifted above baseline averages (worsening pollution).
- $D_z < 0$: Recent concentrations have decreased below baseline averages (atmospheric clearing / scavenging).
- Magnitudes $|D_z| > 0.5$ indicate moderate distribution shifts; $|D_z| > 1.0$ indicate major regime transitions.

### Project-Specific Caution
> [!NOTE]
> $D_z$ is strictly a **descriptive standardized mean-shift measure**, NOT a parametric hypothesis-test $z$-statistic. It does not assume Gaussian errors or temporal independence. Formal inferential significance is assessed separately using moving-block bootstrap procedures.

---

## 4. Statistical Inference on Autocorrelated Data (Moving-Block Bootstrap)

### What It Is
A non-parametric resampling technique that samples continuous temporal blocks of observations rather than individual points.

### Why This Project Used It
Urban air quality time series exhibit pronounced serial autocorrelation and diurnal/seasonal cyclicity. Standard independent identically distributed (i.i.d.) bootstrap resampling destroys temporal dependencies, causing severe downward bias in standard error estimation.

### Methodology
Given a daily time series of length $N$, the sequence is partitioned into overlapping blocks of length $b$. Random blocks are drawn with replacement to assemble synthetic bootstrap trajectories:

$$
\mathbf{B}_k = \{x_{\tau}, x_{\tau+1}, \dots, x_{\tau+b-1}\}
$$

Confidence intervals ($95\%$) for drift metrics and parameter estimates are computed from $B = 1{,}000$ block resamples.

### Project-Specific Caution
Resampling preserves serial correlation within blocks, but does not prove causal mechanisms or isolate non-meteorological emission interventions.

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
- **Model B (Persistence-Aware)** incorporates day-$t$ verified AQI as an autoregressive predictor, achieving $R^2 \approx 0.65$–$0.72$.
- **Inertia Baseline:** In periods of stagnant weather, a naive single-day persistence heuristic ($\widehat{\text{AQI}}_{t+1} = \text{AQI}_t$) frequently achieves lower Mean Absolute Error (MAE) than fitted linear models, underscoring high baseline environmental inertia.
- **Caution:** Linear models cannot represent nonlinear atmospheric chemistry or abrupt meteorological inversions.

---

## 6. Logistic Regression (Probabilistic Adverse Event Classification)

### What It Is
A generalized linear model for binary classification that estimates the posterior probability of next-day adverse air quality episodes via the logistic sigmoid function.

### Why This Project Used It
Stakeholders and public health advisories often require probabilistic alerts for whether tomorrow's air will cross regulatory thresholds rather than exact continuous concentrations.

### Key Formula

$$
P(Y=1\mid\mathbf{x}) = \frac{1}{1+\exp(-(\beta_0+\mathbf{x}^{T}\boldsymbol{\beta}))}
$$

The log-odds (logit) transformation is linear:

$$
\ln\left(\frac{p}{1-p}\right) = \beta_0 + \sum_{j=1}^{p}\beta_j x_j
$$

### Target Definition
The frozen supervised adverse event target is:

$$
\text{target\_adverse\_next\_day} = 1 \iff \text{AQI}_{t+1} > 100
$$

Where $\text{AQI}_{t+1} > 100$ designates Moderate, Poor, Very Poor, or Severe air quality under CPCB guidelines.

### How to Interpret It
Exponentials of coefficients $\exp(\beta_j)$ correspond to multiplicative odds ratios. If $\exp(\beta_j) = 1.25$, a one-unit increase in $x_j$ multiplies the odds of an adverse event tomorrow by $1.25$.

### Project-Specific Caution
Under severe seasonal prevalence shifts (e.g., monsoon clearing where adverse prevalence drops to $2.3\%$), fixed threshold classification ($p^* = 0.50$) experiences a drastic drop in sensitivity. Model performance must be evaluated using threshold-independent Precision-Recall AUC (PR-AUC).

---

## 7. Principal Component Analysis (Orthogonal Feature Compression)

### What It Is
An unsupervised linear dimensionality reduction technique that projects correlated multi-sensor features onto an orthogonal set of principal axes maximizing explained variance.

### Why This Project Used It
To evaluate the intrinsic dimensionality of urban air quality sensor arrays (PM2.5, PM10, O3, temperature, humidity, wind speed) and eliminate multicollinearity.

### Key Formula
Given the sample covariance or correlation matrix $S$, principal directions $\mathbf{v}_j$ and variance eigenvalues $\lambda_j$ satisfy the eigenvalue relation:

$$
S\mathbf{v}_j = \lambda_j\mathbf{v}_j
$$

Subject to the orthogonality constraint:

$$
\mathbf{v}_j^T \mathbf{v}_k = \begin{cases} 1 & \text{if } j = k \\ 0 & \text{if } j \neq k \end{cases}
$$

### How to Interpret It
- **PC1 (Particulate Axis):** Strong positive loadings on PM2.5 and PM10; tracks overall atmospheric particulate burden.
- **PC2 (Photochemical / Thermal Axis):** Strong positive loadings on ozone and temperature with negative humidity; tracks secondary photochemical smog.
- **Cumulative Variance:** The first 4 principal components account for $>83\%$ of total multi-sensor variance across both Hyderabad and India panels.

---

## 8. $K$-Means Clustering (Urban Pollution Regime Discovery)

### What It Is
An iterative partitional clustering algorithm that partitions $N$ multi-sensor observations into $k$ discrete clusters, minimizing within-cluster sum of squares.

### Why This Project Used It
To discover whether multi-station urban air quality organizes into discrete, reproducible environmental "regimes" across seasons and geography.

### Key Formula

$$
\underset{C_1,\ldots,C_k}{\operatorname{minimize}} \sum_{r=1}^{k} \sum_{\mathbf{x}_i\in C_r} \|\mathbf{x}_i-\boldsymbol{\mu}_r\|^2
$$

Where:
- $\boldsymbol{\mu}_r = \frac{1}{|C_r|}\sum_{\mathbf{x}_i\in C_r}\mathbf{x}_i$ is the centroid of cluster $C_r$.
- $\|\cdot\|$ denotes Euclidean distance in standardized feature space.

### Regimes Discovered ($k=4$)
1. **Cluster 1 — Clean / Scavenged:** Low particulates, moderate humidity, active dispersion.
2. **Cluster 2 — Photochemical Moderate:** High ozone, elevated temperatures, moderate particulates.
3. **Cluster 3 — Particulate High:** Elevated PM2.5 and PM10, stable nocturnal atmosphere.
4. **Cluster 4 — Severe Inversion / Stagnation:** Extreme particulate concentrations, calm winds, low boundary layer.

### Project-Specific Caution
$K$-Means assumes isotropic (spherical) cluster geometries in normalized feature space and is sensitive to initialization. Deterministic seed locking is required for strict reproducibility.

---

## 9. Nonlinear Support Vector Machine (RBF Kernel Margin Classifier)

### What It Is
A maximum-margin classifier that maps input predictor vectors into an infinite-dimensional feature space using the Radial Basis Function (RBF) kernel to construct an optimal separating hyperplane.

### Why This Project Used It
To test whether nonlinear decision boundaries provide superior discrimination for next-day adverse AQI boundary crossings compared to linear Logistic Model B and simple persistence.

### Key Formulas

**Radial Basis Function Kernel:**

$$
K(\mathbf{x},\mathbf{x}') = \exp\left(-\gamma \|\mathbf{x}-\mathbf{x}'\|^2\right)
$$

**Continuous SVM Decision Function:**

$$
f(\mathbf{x}) = \operatorname{sgn}\left(\sum_{i=1}^{N_{sv}} \alpha_i y_i K(\mathbf{x}_i,\mathbf{x}) + b\right)
$$

Continuous margin score:

$$
s(\mathbf{x}) = \sum_{i=1}^{N_{sv}} \alpha_i y_i K(\mathbf{x}_i,\mathbf{x}) + b
$$

Where:
- $\mathbf{x}_i$: Support vectors with dual coefficients $\alpha_i > 0$.
- $y_i \in \{-1, +1\}$: Ground truth adverse event indicators.
- $\gamma$: RBF kernel bandwidth parameter ($\gamma > 0$).
- $C$: Cost parameter penalizing margin slack violations.

### Key Project Findings & Limitation
- On the heterogeneous 15-station India Representative Panel, RBF SVM ($C=4.0, \gamma=0.007576$) achieved **superior ranking on the locked TEST set** (PR-AUC $= 0.8335$ vs. Logistic Model B $= 0.8255$).
- On native uncalibrated hard classification ($s(\mathbf{x}) \ge 0$), SVM achieved $F_1 = 0.7218$, substantially higher than Logistic Model B ($0.5794$) and comparable to persistence ($0.7267$).
- **Caution:** In low-prevalence regimes (Hyderabad TEST with $2.3\%$ adverse events), the uncalibrated zero-threshold margin produced zero true positives ($F_1 = \text{NA}$), illustrating that flexible kernel boundaries require careful decision-threshold calibration under severe class imbalance.

---

## 10. Summary of Evaluation Metrics

| Metric | Formulation | Domain / Purpose | Project Application |
| :--- | :--- | :--- | :--- |
| **MAE** | $\frac{1}{N}\sum \|y_i - \hat{y}_i\|$ | Continuous regression error | Evaluates average AQI point forecast deviation |
| **RMSE** | $\sqrt{\frac{1}{N}\sum (y_i - \hat{y}_i)^2}$ | Continuous regression error | Penalizes large acute forecast misses |
| **$R^2$** | $1 - \frac{\sum (y_i - \hat{y}_i)^2}{\sum (y_i - \bar{y})^2}$ | Explained variance fraction | Assesses explanatory power of MLR specifications |
| **PR-AUC** | $\int_0^1 p(r) \, dr$ | Probability ranking under imbalance | Primary model-selection metric for Logistic and SVM |
| **ROC-AUC** | $\int_0^1 \text{TPR}(\text{FPR}) \, d\text{FPR}$ | Diagnostic discrimination | Evaluates true positive vs. false positive tradeoff |
| **Brier Score** | $\frac{1}{N}\sum (p_i - y_i)^2$ | Probability calibration | Evaluates accuracy and sharpness of probabilities |
| **Native $F_1$** | $\frac{2 \cdot \text{Precision} \cdot \text{Recall}}{\text{Precision} + \text{Recall}}$ | Hard classification balance | Harmonic mean of precision and recall at $p^*=0.5$ or $s(\mathbf{x})=0$ |
| **Balanced Accuracy** | $\frac{\text{Sensitivity} + \text{Specificity}}{2}$ | Class-normalized accuracy | Prevents majority-class dominance in evaluation |
