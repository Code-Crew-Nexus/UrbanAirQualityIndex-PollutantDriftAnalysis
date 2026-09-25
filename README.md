# Urban Air Quality Index and Pollutant Drift Analysis Using Statistical Machine Learning in R
**A Multi-Station Study of Hyderabad Using Real-World Air Quality and Meteorological Data**

## 1. Academic Context
- **Course**: Statistics for Machine Learning (SML)
- **Framework**: Project Based Learning (PBL)

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
3. Exploratory Data Analysis (EDA)
4. Pollutant Drift (Block-Bootstrap Inference)
5. Statistical Inference (Benjamini-Hochberg FDR)
6. Multiple Linear Regression (MLR)
7. Logistic Regression Classification
8. PCA / K-Means — *NEXT*
9. SVM — *OPTIONAL*
10. R Shiny — *PLANNED*

## 9. Key Supervised-Learning Findings
- **Selected MLR family**: Model B (Persistence-Aware).
- **Persistence benchmark**: Demonstrated a lower primary Mean Absolute Error (MAE) than MLR on frozen TEST and holdout evaluations, highlighting severe baseline inertia.
- **Selected Logistic family**: Model B (Persistence-Aware).
- **Logistic Model B**: Achieved improved probability ranking and Brier scoring in several out-of-sample evaluations, especially the India subset.
- **Hard threshold performance**: The fixed-threshold F1 classification remained highly sensitive to the temporal prevalence shifts observed during season transitions.

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
*Instructions to be populated upon final Shiny integration.*

## 13. Team
| Name | Roll Number | GitHub |
|---|---|---|
| Mangali Sai Krishna | 24R11A6669 | @Saikrishna-dev-oss |
| Md. Abdul Rayain | 24R11A6673 | @rayainwarrior-dev |
| RISHIT GHOSH | 24R11A6685 | @rajghosh06-dev |
| Yaram Karthik | 24R11A66A1 | @karthik10-dev |

## 14. Suggestions & Feedback
This repository is maintained as an academic SML PBL by the listed project team.

External Pull Requests and direct code contributions are not accepted.

Suggestions, ideas and academic feedback are welcome through GitHub Discussions.

## 15. Limitations
Supervised static models struggle to adapt classification boundaries gracefully when background baseline prevalences collapse.

## 16. Current Status
**PHASE 4 SUPERVISED LEARNING FROZEN.**

## 17. License
License to be finalized by the project team.

