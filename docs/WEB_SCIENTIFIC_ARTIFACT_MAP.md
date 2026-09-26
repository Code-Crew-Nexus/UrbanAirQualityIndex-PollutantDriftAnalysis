# Web Scientific Artifact Map

**Project:** `UrbanAirQualityIndex-PollutantDriftAnalysis`  
**Milestone Baseline:** `v0.6-svm-freeze` (FROZEN — READ ONLY)  
**Status:** `ALL_SOURCE_PATHS_PASS`  
**Generated:** September 2026  

This document inventories the authoritative Level-1 frozen input artifacts consumed by the Phase-6B static presentation and web data exporter (`scripts/32_export_web_scientific_assets.R`). Every referenced path exists on the filesystem and was verified for row count, column schema, and numerical consistency.

---

## Authoritative Artifact Mapping Matrix

| # | website_component | source_path | source_exists | source_rows | source_role | frozen_phase | status |
| :-: | :--- | :--- | :---: | :---: | :--- | :---: | :---: |
| 1 | Explore Data / Daily Observations | `data/processed/UAQI_Master_Daily.csv` | `TRUE` | 11970 | Master daily panel containing scheduled station-days | Phase 2E | **PASS** |
| 2 | Explore Data / Station Hierarchy | `config/selected_stations.csv` | `TRUE` | 21 | Official 21 physical station network definitions and panel memberships | Phase 1 / Phase 2 | **PASS** |
| 3 | Statistical Analysis / Pollutant Drift Summary | `data/analysis/phase3B/phase3B_current_drift_snapshot.csv` | `TRUE` | 147 | Current evaluation point rolling 30d/90d standardized mean shift ($D_z$) | Phase 3B | **PASS** |
| 4 | Statistical Analysis / Statistical Inference Summary | `data/analysis/phase3C/phase3C_current_drift_inference_results.csv` | `TRUE` | 147 | Moving-block bootstrap ($B=2000, l=7$), BH-FDR $q$-values, and effect sizes | Phase 3C | **PASS** |
| 5 | Machine Learning / Regression Test Metrics | `analysis/phase4B/tables/phase4B_test_metrics.csv` | `TRUE` | 6 | Supervised MLR Model B vs Persistence performance on TEST split | Phase 4B | **PASS** |
| 6 | Machine Learning / Regression Holdout Metrics | `analysis/phase4B/tables/phase4B_holdout_metrics.csv` | `TRUE` | 6 | Supervised MLR Model B vs Persistence performance on HOLDOUT split | Phase 4B | **PASS** |
| 7 | Machine Learning / Logistic Classification Test Metrics | `analysis/phase4C/tables/phase4C_test_metrics.csv` | `TRUE` | 6 | Logistic Model B vs Persistence performance on TEST split | Phase 4C | **PASS** |
| 8 | Machine Learning / Logistic Classification Holdout Metrics | `analysis/phase4C/tables/phase4C_holdout_metrics.csv` | `TRUE` | 6 | Logistic Model B vs Persistence performance on HOLDOUT split | Phase 4C | **PASS** |
| 9 | Machine Learning / SVM Classification Test Metrics | `analysis/phase5B/tables/phase5B_test_metrics.csv` | `TRUE` | 2 | Nonlinear RBF SVM classification performance on TEST split | Phase 5B | **PASS** |
| 10 | Machine Learning / SVM Classification Holdout Metrics | `analysis/phase5B/tables/phase5B_holdout_metrics.csv` | `TRUE` | 2 | Nonlinear RBF SVM classification performance on HOLDOUT split | Phase 5B | **PASS** |
| 11 | Machine Learning / PCA Variance Explained | `analysis/phase5A/tables/phase5A_pca_variance_explained.csv` | `TRUE` | 12 | 6-PC eigenvalue and cumulative variance profiles for Hyderabad and India | Phase 5A | **PASS** |
| 12 | Machine Learning / PCA Loadings | `analysis/phase5A/tables/phase5A_pca_loadings.csv` | `TRUE` | 72 | Sensor variable loadings across principal components | Phase 5A | **PASS** |
| 13 | Machine Learning / K-Means Cluster Labels | `analysis/phase5A/tables/phase5A_cluster_labels.csv` | `TRUE` | 6 | Selected $K=3$ descriptive regime labels and profile basis for both scopes | Phase 5A | **PASS** |
| 14 | Machine Learning / K-Means Cluster Profiles | `analysis/phase5A/tables/phase5A_cluster_profiles.csv` | `TRUE` | 42 | Summary statistics (mean, median, IQR) for clusters across sensor inputs | Phase 5A | **PASS** |
| 15 | Machine Learning / Hyderabad PCA History Scores | `data/analysis/phase5A/Hyderabad_PCA_History.csv` | `TRUE` | 2749 | Historical PC1–PC6 projection scores and initial $K=3$ cluster assignments | Phase 5A | **PASS** |
| 16 | Machine Learning / Hyderabad PCA Recent Scores | `data/analysis/phase5A/Hyderabad_Recent_Cluster_Assignments.csv` | `TRUE` | 121 | Recent evaluation PC1–PC6 projection scores and assigned clusters | Phase 5A | **PASS** |
| 17 | Machine Learning / India PCA History Scores | `data/analysis/phase5A/India_PCA_History.csv` | `TRUE` | 6796 | Historical PC1–PC6 projection scores and initial $K=3$ cluster assignments | Phase 5A | **PASS** |
| 18 | Machine Learning / India PCA Recent Scores | `data/analysis/phase5A/India_Recent_Cluster_Assignments.csv` | `TRUE` | 262 | Recent evaluation PC1–PC6 projection scores and assigned clusters | Phase 5A | **PASS** |

---

## Verification Criteria & Policy Adherence

1. **Zero Model Fitting:** None of the above paths are generated via dynamic runtime estimation in Phase 6. All files are immutable Level-1 computational artifacts produced and validated in Phases 1 through 5B.
2. **Missingness Preservation:** Missing values in raw sensor observations and undefined single-class evaluation metrics are preserved as `NA` in R tables and must strictly serialize to JSON `null`.
3. **No Unverified Gaseous Substitution:** Gaseous pollutants ($\text{CO}, \text{NO}_2, \text{SO}_2$) are maintained as within-series source-scale items in drift and inference tables, and are strictly absent from AQI composite inputs.
