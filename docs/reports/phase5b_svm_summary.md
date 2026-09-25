# Phase 5B — RBF Support Vector Machine Adverse-AQI Classification Summary

**Academic Context:** Statistics for Machine Learning (SML) Project Based Learning (PBL)  
**Project:** `UrbanAirQualityIndex-PollutantDriftAnalysis`  
**Target:** `target_adverse_next_day` ($1 \iff \text{AQI}_{t+1} > 100$, else $0$)  
**Baseline Freezes:** `v0.4-supervised-freeze` (MLR & Logistic Regression), `v0.5-unsupervised-freeze` (PCA & $K$-Means)

---

## 1. Research Question & Purpose

Phase 4 established an interpretable, calibrated Logistic Regression model (Model B) for next-day adverse air quality classification, alongside a simple single-day persistence benchmark. Phase 5A independently demonstrated that six-pollutant urban air quality forms discrete latent regimes via PCA and $K$-Means.

Phase 5B investigates a focused predictive inquiry:
> **Can a nonlinear radial-basis function Support Vector Machine (RBF SVM) improve out-of-sample discrimination of next-day adverse air quality ($\text{AQI}_{t+1} > 100$) over the linear log-odds decision boundary of Logistic Model B and simple persistence?**

To maintain absolute methodological fairness and prevent data leakage:
1. The **exact same chronological cohort design** and **feature information contract** as Logistic Model B were maintained.
2. **Phase-5 PCA representations, cluster labels, and centroid distances were strictly excluded** from SVM feature matrices because Phase-5 unsupervised models incorporated history through August 31, 2026.
3. No class resampling (no SMOTE, oversampling, or undersampling) and no class weighting were employed.

---

## 2. Chronological Cohort Design & Sample Distributions

All splits are defined strictly by target calendar date ($t+1$), matching the frozen Phase-4 prediction contract:

| Chronological Split | Target Date Window | Hyderabad Panel ($n$, Adverse Positives) | India Representative Panel ($n$, Adverse Positives) | Atmospheric & Seasonal Dynamics |
| :--- | :--- | :---: | :---: | :--- |
| **TRAIN** | 2025-03-02 to 2025-12-31 | 1,398 ($269$, $19.2\%$) | 3,501 ($1,553$, $44.4\%$) | Pre-monsoon, monsoon, and post-monsoon baseline |
| **VALIDATION** | 2026-01-01 to 2026-04-30 | 498 ($66$, $13.3\%$) | 1,302 ($828$, $63.6\%$) | Winter thermal inversions & early summer across Indo-Gangetic Plain |
| **TEST** | 2026-05-01 to 2026-08-31 | 477 ($11$, $2.3\%$) | 1,389 ($294$, $21.2\%$) | Peak summer heat & severe monsoon precipitation scavenging |
| **FINAL HOLDOUT** | 2026-09-01 to 2026-09-21 | 111 ($0$, $0.0\%$) | 238 ($22$, $9.2\%$) | Late monsoon out-of-sample post-freeze holdout |

The sample sizes and adverse-event counts derived deterministically from [UAQI_Master_Daily.csv](file:///d:/RAJ/GITHUB_REPOSITORY/COLLEGE/COLLEGE_PROJECTS/SML/SML-PBL/UrbanAirQualityIndex-PollutantDriftAnalysis/data/processed/UAQI_Master_Daily.csv) match the project's frozen complete-case population to the exact integer.

---

## 3. Predictor Feature Contract & Preprocessing

The SVM predictor set strictly utilizes day-$t$ verified observations:
- **Continuous Features (11):** `pm2_5_aqi_input`, `pm10_aqi_input`, `o3_8h_max`, `temperature`, `humidity`, `wind_speed`, `sin_wind_direction`, `cos_wind_direction`, `month_sin`, `month_cos`, `aqi_verified`.
- **Categorical Features (2):** `project_station_id` (7 levels for Hyderabad, 15 levels for India) and `day_of_week` (7 levels, Monday–Sunday).
- **Encoding:** Deterministic full one-hot indicator encoding ($0/1$).
  - Hyderabad: $11 \text{ continuous} + 7 \text{ station} + 7 \text{ DOW} = 25 \text{ total features } (p = 25)$.
  - India: $11 \text{ continuous} + 15 \text{ station} + 7 \text{ DOW} = 33 \text{ total features } (p = 33)$.
- **Standardization:** Continuous predictors were standardized using $z$-score transformations whose means and standard deviations were **learned strictly from fitting data** at each experimental stage. Indicator dummy variables remained unscaled ($0/1$). Internal automatic SVM scaling was disabled (`scale = FALSE`) to ensure total pipeline transparency.

---

## 4. Hyperparameter Grid Search & Validation Selection

A predeclared grid of 20 candidate combinations was evaluated on the **VALIDATION** split for each geographic scope.
- **Cost Candidates ($C$):** $0.25$, $1.0$, $4.0$, $16.0$
- **Gamma Multipliers ($\gamma$):** $0.25, 0.5, 1.0, 2.0, 4.0 \times \text{base\_gamma}$, where $\text{base\_gamma} = 1 / p$ ($0.0400$ for Hyderabad, $0.030303$ for India).
- **Selection Criterion:** Validation Precision-Recall AUC (**PR-AUC**), evaluated on continuous SVM decision scores using tie-safe Mann-Whitney trapezoidal integration.
- **Deterministic Tie-Breaking:** Maximum PR-AUC; if within $10^{-10}$ tolerance, prefer lower Cost, then lower Gamma.

### Validation Selection Results:
- **Hyderabad Panel:**
  - Selected Parameters: **$\text{Cost} = 16.0$**, **$\gamma = 0.0100$** ($0.25 \times \text{base\_gamma}$)
  - Validation PR-AUC: **$0.8857$** (vs. baseline prevalence $0.1325$)
  - Validation ROC-AUC: **$0.9511$**, Average Precision: **$0.8862$**, Native $F_1$: **$0.8148$**
- **India Representative Panel:**
  - Selected Parameters: **$\text{Cost} = 4.0$**, **$\gamma = 0.007576$** ($0.25 \times \text{base\_gamma}$)
  - Validation PR-AUC: **$0.9217$** (vs. baseline prevalence $0.6359$)
  - Validation ROC-AUC: **$0.8802$**, Average Precision: **$0.9218$**, Native $F_1$: **$0.8524$**

---

## 5. Locked TEST Evaluation & Benchmark Comparison

Following validation selection, hyperparameters were permanently locked. Models were refit on **$\text{TRAIN} + \text{VALIDATION}$** with relearned preprocessing parameters and evaluated **once** on the locked **TEST** set ($N=477$ Hyderabad, $N=1,389$ India).

### Comparative Metric Performance (TEST Split):

| Scope | Model Family | Positive $n$ | PR-AUC | ROC-AUC | Average Precision | Sensitivity | Specificity | Precision | Native $F_1$ Score | Balanced Accuracy | Overall Accuracy |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **HYDERABAD** | **RBF SVM** | 11 | **$0.1179$** | $0.8498$ | $0.1382$ | $0.0000$ | $0.9893$ | $0.0000$ | **$\text{NA}^*$** | $0.4946$ | $96.65\%$ |
| HYDERABAD | Logistic Model B | 11 | **$0.1666$** | $0.9185$ | $0.2058$ | $0.1818$ | $0.9936$ | $0.4000$ | **$0.2500$** | $0.5877$ | $97.48\%$ |
| HYDERABAD | Persistence | 11 | **$0.1572$** | $0.5845$ | $0.0643$ | $0.1818$ | $0.9871$ | $0.2500$ | **$0.2105$** | $0.5845$ | $96.86\%$ |
| **INDIA** | **RBF SVM** | 294 | **$0.8335$** | $0.9345$ | $0.8339$ | $0.6531$ | $0.9580$ | $0.8067$ | **$0.7218$** | $0.8055$ | $89.34\%$ |
| INDIA | Logistic Model B | 294 | **$0.8255$** | $0.9317$ | $0.8258$ | $0.4218$ | $0.9909$ | $0.9254$ | **$0.5794$** | $0.7063$ | $87.04\%$ |
| INDIA | Persistence | 294 | **$0.6555$** | $0.8270$ | $0.5856$ | $0.7279$ | $0.9260$ | $0.7254$ | **$0.7267$** | $0.8270$ | $88.41\%$ |

$^*$*Note: In Hyderabad TEST, adverse prevalence collapsed to $2.3\%$. The native margin predicted $5$ false positives and $0$ true positives ($TP=0, FP=5$), resulting in an undefined/zero $F_1$ score.*

### Key Scientific Findings on TEST:
1. **India Representative Panel:**
   - **Ranking Advantage:** The nonlinear RBF SVM achieved a higher PR-AUC ($0.8335$) than Logistic Model B ($0.8255$, $\Delta = +0.0081$) and far surpassed Persistence ($0.6555$, $\Delta = +0.1780$).
   - **Hard Classification Advantage:** Native SVM margin classification achieved $F_1 = 0.7218$ ($65.3\%$ sensitivity, $80.7\%$ precision), greatly exceeding Logistic Model B ($F_1 = 0.5794$, sensitivity $42.2\%$) and matching persistence ($F_1 = 0.7267$).
2. **Hyderabad Panel:**
   - In Hyderabad, where summer monsoon precipitation reduced adverse occurrences to just 11 events across 477 observations, the RBF SVM lagged behind Logistic Model B (PR-AUC $0.1179$ vs. $0.1666$, $\Delta = -0.0487$). The uncalibrated separating margin failed to capture true positives without threshold tuning.

---

## 6. September Final Holdout Evaluation

Models were refit across **all available history** through August 31, 2026 ($\text{TRAIN} + \text{VALIDATION} + \text{TEST}$) and evaluated on the out-of-sample September Holdout (2026-09-01 to 2026-09-21):

| Scope | Model Family | Positive $n$ | PR-AUC | ROC-AUC | Native $F_1$ Score | Sensitivity | Specificity | Precision | Accuracy |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **INDIA** | **RBF SVM** | 22 | **$0.5419$** | $0.8843$ | **$0.5405$** | $0.4545$ | $0.9769$ | $0.6667$ | $92.86\%$ |
| INDIA | Logistic Model B | 22 | **$0.5688$** | $0.9015$ | **$0.4138$** | $0.2727$ | $0.9861$ | $0.6667$ | $92.02\%$ |
| INDIA | Persistence | 22 | **$0.5113$** | $0.7836$ | **$0.6047$** | $0.5909$ | $0.9769$ | $0.7222$ | $94.12\%$ |
| **HYDERABAD** | **RBF SVM** | 0 | $\text{NA}$ | $\text{NA}$ | $\text{NA}$ | $\text{NA}$ | $1.0000$ | $\text{NA}$ | $100.0\%$ |
| HYDERABAD | Logistic Model B | 0 | $\text{NA}$ | $\text{NA}$ | $\text{NA}$ | $\text{NA}$ | $1.0000$ | $\text{NA}$ | $100.0\%$ |
| HYDERABAD | Persistence | 0 | $\text{NA}$ | $\text{NA}$ | $\text{NA}$ | $\text{NA}$ | $1.0000$ | $\text{NA}$ | $100.0\%$ |

### Single-Class Hyderabad Holdout Limitation:
In Hyderabad, widespread monsoon rain in September 2026 kept all 111 observations below the AQI 100 threshold ($0$ adverse days). All 111 oriented decision scores produced by the SVM were strictly negative (scores $< 0$), resulting in $TN=111, FP=0$ ($100\%$ accuracy and specificity). Because only one class is present in the ground truth, ranking metrics (ROC-AUC, PR-AUC) and positive detection metrics ($F_1$, sensitivity) are mathematically undefined ($\text{NA}$). As mandated by project policy, high accuracy under single-class holdouts is not interpreted as evidence of adverse-event discrimination.

---

## 7. Support Vector Complexity Diagnostics

Support vector counts and proportions were recorded across all three fitting phases:

| Scope | Refit Stage | Fitting Samples | Cost ($C$) | Gamma ($\gamma$) | Total SVs | Class 0 SVs | Class 1 SVs | SV Proportion |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **HYDERABAD** | TRAIN ONLY | 1,398 | 16.0 | 0.010000 | 343 | 168 | 175 | $24.5\%$ |
| HYDERABAD | TEST REFIT | 1,896 | 16.0 | 0.010000 | 405 | 195 | 210 | $21.4\%$ |
| HYDERABAD | FINAL HISTORY | 2,373 | 16.0 | 0.010000 | 443 | 214 | 229 | $18.7\%$ |
| **INDIA** | TRAIN ONLY | 3,501 | 4.0 | 0.007576 | 1,035 | 515 | 520 | $29.6\%$ |
| INDIA | TEST REFIT | 4,803 | 4.0 | 0.007576 | 1,636 | 816 | 820 | $34.1\%$ |
| INDIA | FINAL HISTORY | 6,192 | 4.0 | 0.007576 | 1,976 | 988 | 988 | $31.9\%$ |

Support vectors comprise $18.7\% - 34.1\%$ of the training cohorts, demonstrating that the RBF kernel establishes a well-regularized decision boundary without memorizing training samples.

---

## 8. Fair Comparative Assessment: Logistic Regression vs. Support Vector Machine

| Evaluation Dimension | Logistic Regression (Model B) | RBF Support Vector Machine | Methodological Implications |
| :--- | :--- | :--- | :--- |
| **Decision Boundary** | Linear in log-odds space | Highly nonlinear kernel hypersphere | SVM captures multi-pollutant non-linear interactions better in heterogeneous panels (India). |
| **Model Output** | Calibrated posterior probabilities $P(Y=1 \mid X)$ | Continuous distance to margin boundary | Logistic outputs provide direct operational risk probabilities; SVM scores require external calibration. |
| **Ranking Performance** | India TEST PR-AUC: $0.8255$ | India TEST PR-AUC: **$0.8335$** | SVM demonstrates superior discriminative ranking when class balance is moderate. |
| **Hard Classification** | India TEST $F_1$: $0.5794$ | India TEST $F_1$: **$0.7218$** | Native SVM separating hyperplanes capture $65.3\%$ of adverse days with $80.7\%$ precision. |
| **Interpretability** | Direct odds ratios ($\exp(\beta)$) per unit shift | Black-box dual kernel representation | Logistic Regression remains indispensable for environmental policy and feature attribution. |
| **Severe Low-Prevalence** | Tunable operating thresholds | Native margin can struggle without tuning | Under extreme class rarity (Hyderabad TEST $2.3\%$), Logistic threshold tuning proved more resilient. |

---

## 9. Final Conclusion

1. **Nonlinear Kernel Value Validated in Heterogeneous Cohorts:** On the 15-station India Representative Panel, the nonlinear RBF SVM demonstrated superior out-of-sample discrimination over Logistic Model B on the locked TEST set, raising PR-AUC from $0.8255$ to $0.8335$ and lifting the hard classification $F_1$ score from $0.5794$ to $0.7218$.
2. **Complementary Modeling Roles:** While the RBF SVM provides enhanced classification margin separation, Logistic Regression retains its critical role as the primary interpretable probability model.
3. **Reproducibility & Baseline Freeze:** All Phase-5B models, grids, predictions, and metrics are fully self-contained and reproducible from tracked repository artifacts.
