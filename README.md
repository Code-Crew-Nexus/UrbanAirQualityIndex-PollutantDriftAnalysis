# Urban Air Quality Index and Pollutant Drift Analysis Using Statistical Machine Learning in R
**A Multi-Station Study of Hyderabad Using Real-World Air Quality and Meteorological Data**

## 1. Academic Context
- **Course**: Statistics for Machine Learning
- **Framework**: Project Based Learning

## 2. Project Overview
This project systematically analyzes the temporal drift of air quality pollutants and develops predictive models to forecast next-day Air Quality Index (AQI) boundary crossings using historical sensor arrays and localized meteorological data.

## 3. Objectives
- Establish an authoritative verified-subset AQI from disparate multi-sensor inputs.
- Formally quantify and test the statistical significance of pollutant drift across seasons.
- Develop, validate, and select out-of-sample supervised learning models to predict discrete adverse AQI risks.

## 4. Study Design
- **7 Hyderabad monitoring stations**
- **15 India representative monitoring stations**
- **21 unique physical stations**

## 5. Data Sources
- **Air Quality**: OpenAQ API
- **Meteorology**: Open-Meteo Historical Weather API

## 6. Study Period
- **Historical acquisition**: 2025-03-01 through 2026-09-21
- **Modeling history (Train/Val/Test)**: through 2026-08-31
- **Recent evaluation (Holdout)**: 2026-09-01 through 2026-09-21

## 7. Verified AQI Policy
The composite AQI strictly applies the `VERIFIED_SUBSET_PM25_PM10_O3` policy, rejecting unsupported conversion of raw unverified source-scale gases (CO, NO2, SO2).

## 8. Statistical / SML Workflow
1. Data Engineering
2. AQI Calculation
3. Exploratory Data Analysis
4. Pollutant Drift
5. Statistical Inference
6. Multiple Linear Regression
7. Logistic Regression
8. PCA / K-Means — COMPLETE
9. RBF SVM — COMPLETE
10. Static Project Website — COMPLETE (Phase 6C Final Website Release Freeze)

## 9. Key Supervised-Learning Findings
- **Selected MLR family**: Model B (Persistence-Aware).
- **Persistence benchmark**: Demonstrated a lower primary Mean Absolute Error (MAE) than MLR on frozen TEST and holdout evaluations, showing that persistence remained a strong benchmark.
- **Selected Logistic family**: Model B (Persistence-Aware).
- **Logistic Model B**: Achieved improved probability ranking and Brier scoring in several out-of-sample evaluations, especially the India subset.
- **Hard threshold performance**: The fixed-threshold F1 classification remained highly sensitive to the temporal prevalence shifts observed during season transitions.
- **RBF Support Vector Machine**: RBF SVM provided complementary nonlinear classification performance. On India TEST: SVM PR-AUC ≈ 0.8335 (vs. Logistic Model B ≈ 0.8255), and SVM native F1 ≈ 0.7218 (vs. Logistic Model B ≈ 0.5794 and Persistence ≈ 0.7267). On India September holdout: Logistic Model B retained the higher PR-AUC, while persistence retained the higher F1. In Hyderabad TEST: Logistic Model B performed better than the unweighted SVM for adverse-event ranking and positive detection.

## 10. Repository Structure
- `docs/reports/`: Canonical final phase summaries.
- `docs/internal_phase_history/`: Verbose debugging and phase closure reports (kept local, un-tracked).
- `R/`: Reusable core modules.
- `scripts/`: Sequential pipeline scripts.
- `config/`: Pipeline YAML configurations.
- `data/`: Processed canonical data sets (raw/interim ignored).

## 11. Reproducibility
The codebase uses strict functional decoupling and seed-locked statistical sampling to ensure deterministic execution for PCA, clustering, and bootstrap inference.

## 12. Running the Project

The listed analytical scripts provide a concise phase-level execution guide. For full environment setup and step-by-step reproduction modes (Mode A: frozen review and Mode B: full reproduction), consult [`docs/guide/setup.md`](docs/guide/setup.md).

### A. R Analytical & Modeling Pipeline
The scientific computation, statistical inference, and machine learning models remain strictly implemented in R.
1. Initialize environment and check dependencies:
   ```r
   source("R/00_setup.R")
   ```
2. Run data engineering, verified AQI calculation, and exploratory analysis:
   ```r
   source("scripts/03_build_datasets.R")
   source("scripts/09_phase2E_generate_final_aqi.R")
   source("scripts/10_phase3A_exploratory_analysis.R")
   source("scripts/11_phase3B_pollutant_drift.R")
   source("scripts/12_phase3C_statistical_inference.R")
   ```
3. Run supervised models (MLR & Logistic Regression):
   ```r
   source("scripts/13_phase4A_prediction_design.R")
   source("scripts/14a_phase4B_train_validate_select.R")
   source("scripts/15a_phase4C_train_validate_select.R")
   ```
4. Run unsupervised models (PCA & K-Means):
   ```r
   source("scripts/18a_phase5A_pca.R")
   source("scripts/18b_phase5A_kmeans.R")
   ```
5. Run support vector machines (RBF SVM):
   ```r
   source("scripts/20a_phase5B_prepare_design.R")
   source("scripts/20b_phase5B_train_validate_select.R")
   source("scripts/20c_phase5B_test_holdout_evaluation.R")
   ```
6. Export website summary data assets:
   ```r
   source("scripts/30_export_web_assets.R")
   ```
7. Run project test suite:
   ```r
   testthat::test_dir("tests/testthat")
   ```

### B. Static Project Website (Presentation Layer)
The presentation layer is a lightweight static website built with HTML5, CSS3, and Vanilla JavaScript, targeted for GitHub Pages hosting. It consumes frozen results exported from the R pipeline.

#### Local Website Preview
The interactive website loads frozen JSON datasets and Markdown assets using `fetch()`, which requires an HTTP/HTTPS origin in modern browsers. Opening HTML files directly from disk via `file://` causes browser security policies (CORS) to block data loading.

To serve and preview the website locally from the project root:
```powershell
py scripts/serve_website_local.py
```
*(Alternatively using standard Python or the PowerShell convenience launcher)*:
```powershell
py -m http.server 8000 --directory docs
# Or: .\scripts\start_website_preview.ps1
```
Then navigate in a browser to:
```
http://localhost:8000/
```

## 13. Team
| Name | Roll Number | GitHub |
|---|---|---|
| Mangali Sai Krishna | 24R11A6669 | @Saikrishna-dev-oss |
| Md. Abdul Rayain | 24R11A6673 | @rayainwarrior-dev |
| Rishit Ghosh | 24R11A6685 | @rajghosh06-dev |
| Yaram Karthik | 24R11A66A1 | @karthik10-dev |

## 14. Suggestions & Feedback
This repository is maintained as an academic Statistics for Machine Learning · Project Based Learning project by the listed project team.

External Pull Requests and direct code contributions are not accepted.

Suggestions, ideas and academic feedback are welcome through GitHub Discussions.

## 15. Limitations
Supervised static models struggle to adapt classification boundaries gracefully when background baseline prevalences collapse.

## 16. Current Status
**STATISTICAL / SML MODELING CORE COMPLETE.**

All statistical and machine learning model development is frozen. R remains the canonical analytical and modeling implementation language.

Frozen modeling milestones:
- `v0.4-supervised-freeze` — COMPLETE (Supervised baselines: MLR & Logistic Regression)
- `v0.5-unsupervised-freeze` — COMPLETE (Unsupervised learning: PCA & K-Means)
- `v0.6-svm-freeze` — COMPLETE (Nonlinear classification: RBF SVM)

Presentation Layer Milestone:
- `v0.7-website-freeze` — FINAL WEBSITE RELEASE FREEZE (Responsive, Accessibility, Deployment QA Verified for GitHub Pages)


## 17. License
License to be finalized by the project team.

