# Phase 5A.2 — Final Artifact Consistency, Test Reproducibility & Unsupervised Freeze Report

**Project**: Urban Air Quality Index & Multi-Pollutant Dynamics Analysis  
**Academic Context**: Statistics for Machine Learning (SML) — Project-Based Learning (PBL)  
**Target Milestone**: Phase 5A.2 Closure & Unsupervised Freeze  
**Author**: Antigravity SML Machine Learning Agent  
**Date**: September 25, 2026  
**Git Branch**: `feature/pca-kmeans`  
**Status**: `PHASE 5 UNSUPERVISED LEARNING FROZEN — READY FOR GIT INTEGRATION`

---

## Executive Summary

Phase 5A.2 provides the final quality assurance, numerical reconciliation, and test reproducibility certification for the unsupervised learning layer of the SML-PBL project. Building upon the verified computational core established in Phase 5A and initial harmonization in Phase 5A.1, this closure phase rigorously resolves all remaining reporting inconsistencies, eliminates misleading pseudo-audits, hardens the scientific test suite against Git branch dependencies, removes unversioned scratch dependencies, and packages a fully self-contained review archive.

**Crucially, zero models were refit, zero hyperparameters were altered, and zero data splits were modified. The PCA rotations, eigenvalues, K-Means cluster centroids, scaling parameters, and observation assignments remain 100% byte-for-byte identical to the original Phase 5A execution.**

---

## 1. Audit Findings & Corrective Actions in Phase 5A.2

| Audit Finding | Resolution in Phase 5A.2 | Status |
| :--- | :--- | :---: |
| **1. Stale Hyderabad Cluster Profiles** | Replaced all references to stale counts ($1,061 / 902 / 786$) with authoritative counts ($866 / 962 / 921$) from `phase5A_cluster_profiles.csv`. | **RESOLVED** |
| **2. PCA Variance Table Omissions** | Reconciled all 6 components for both panels against `phase5A_pca_variance_explained.csv` (Hyderabad: PC5 = 0.378604, PC6 = 0.208622; India: PC5 = 0.425391, PC6 = 0.255825). | **RESOLVED** |
| **3. Centroid-Distance Tail Statistics** | Replaced stale tail approximations ($1.65\%$ Hyd, $1.91\%$ Ind) with exact percentile counts: Hyderabad has 3 / 121 ($2.48\%$) with percentile $\ge 0.95$; India has 2 / 262 ($0.76\%$) with percentile $\ge 0.95$. | **RESOLVED** |
| **4. Distance Percentile Terminology** | Replaced misleading "normalized centroid distance" with "within-cluster historical distance percentile" and clarified that distance distributions reflect tail occupancy rather than proof of boundary stability. | **RESOLVED** |
| **5. Station Narrative Anecdotes** | Corrected unsupported statements (e.g. R K Puram spends $36.12\%$ in C1, $36.78\%$ in C2, $27.09\%$ in C3, not $>60\%$ in C1; Zoo Park spends $55.87\%$ in C3, not $>60\%$). Grounded all narrative claims directly in `phase5A_station_cluster_distribution.csv`. | **RESOLVED** |
| **6. Misleading Report Audit** | Eliminated `phase5A_report_numeric_integrity_audit.csv` which set report values equal to table values. Implemented **Option A**: generated `phase5A_report_generation_integrity.csv` documenting the programmatic source table for each report section. | **RESOLVED** |
| **7. Expanded Numeric Consistency Audit** | Expanded `phase5A_numeric_consistency_audit.csv` from 86 to **124 automated checks** covering scalers, all 6 eigenvalues, variance %, PC selection, K selection, cluster sizes, frequencies, seasons, and distance percentiles. All 124 checks match ($100\%$). | **RESOLVED** |
| **8. Test Suite Branch Dependency** | Removed `git branch --show-current` check and skip calls from `tests/testthat/test_phase5a.R` so scientific tests run identically on `main` post-merge. | **RESOLVED** |
| **9. Scratch Directory Dependency** | Replaced unversioned `scratch/` file dependency with tracked `data/metadata/station_catalog.csv` in `test_phase5a.R`. | **RESOLVED** |
| **10. Hardened O3 Unit Assertion** | Asserted explicit existence of `pollutant_dictionary.csv`, exactly 1 canonical record for `o3`, and unit declared as $\mu\text{g/m}^3$. | **RESOLVED** |
| **11. Test Modularization** | Restructured `test_phase5a.R` into 6 distinct `test_that` blocks containing 79 literal `expect_*` calls executing **115 runtime assertions** (0 fail, 0 warn, 0 skip). | **RESOLVED** |
| **12. Reproducibility Script** | Created `scripts/19b_phase5A2_reproducibility_check.R` validating tracked inputs, observation counts, zero scratch dependencies, and automated test execution. | **RESOLVED** |
| **13. Self-Contained Review Archive** | Fixed archive paths to include `data/analysis/phase5A/*.csv`, `data/processed/*.csv`, and all required models/scripts with staging self-containment check. | **RESOLVED** |

---

## 2. Computational Core Invariants

The underlying models and data splits were strictly preserved without modification:

- **Serialized Models Untouched**:
  - `models/phase5A/hyderabad_pca.rds` (MD5 preserved)
  - `models/phase5A/hyderabad_kmeans.rds` (MD5 preserved)
  - `models/phase5A/india_pca.rds` (MD5 preserved)
  - `models/phase5A/india_kmeans.rds` (MD5 preserved)
- **Temporal Windows**:
  - Modeling History: `2025-03-01` to `2026-08-31`
  - Recent Evaluation: `2026-09-01` to `2026-09-21`
- **Sample Counts**:
  - Hyderabad Complete Cases: History $N=2,749$; Recent $N=121$
  - India Complete Cases: History $N=6,796$; Recent $N=262$
- **Feature Contract**: Exactly 6 continuous features (`pm2_5_aqi_input`, `pm10_aqi_input`, `o3_8h_max`, `temperature`, `humidity`, `wind_speed`).
- **Standardization**: Derived exclusively from historical cases ($\mu, \sigma$); zero leakage from September.
- **Dimensionality**: Exactly 4 PCs retained per scope ($\ge 80\%$ cumulative variance threshold; PC3 reaches $78.70\%$ in Hyderabad and $75.92\%$ in India, proving 4 PCs are required).
- **Cluster Count**: $k=3$ selected for both panels via average silhouette width maximization under feasibility constraints.

---

## 3. Reconciled Authoritative Numerical Values

### A. Principal Component Analysis (`phase5A_pca_variance_explained.csv`)

$$\sum_{j=1}^6 \lambda_j = 6.000000, \quad \sum_{j=1}^6 \text{VarPct}_j = 100.0000\%$$

| Scope | Component | Eigenvalue ($\lambda$) | Variance (%) | Cumulative (%) | Retained Rule ($\ge 80\%$) |
| :--- | :--- | :---: | :---: | :---: | :---: |
| **Hyderabad** | **PC1** | 2.319848 | 38.6641% | 38.6641% | Retained |
| | **PC2** | 1.406734 | 23.4456% | 62.1097% | Retained |
| | **PC3** | 0.995306 | 16.5884% | 78.6981% | Retained (< 80%) |
| | **PC4** | 0.690885 | 11.5148% | 90.2129% | **Retained (Threshold Met)** |
| | PC5 | 0.378604 | 6.3101% | 96.5230% | Dropped |
| | PC6 | 0.208622 | 3.4770% | 100.0000% | Dropped |
| **India** | **PC1** | 2.251743 | 37.5290% | 37.5290% | Retained |
| | **PC2** | 1.468250 | 24.4708% | 62.0000% | Retained |
| | **PC3** | 0.834971 | 13.9162% | 75.9161% | Retained (< 80%) |
| | **PC4** | 0.763821 | 12.7303% | 88.6464% | **Retained (Threshold Met)** |
| | PC5 | 0.425391 | 7.0899% | 95.7363% | Dropped |
| | PC6 | 0.255825 | 4.2637% | 100.0000% | Dropped |

### B. Cluster Profiles (`phase5A_cluster_profiles.csv`)

#### Hyderabad Urban Panel (7 Stations, $N=2,749$)
- **Cluster 1 (`warm-dry-moderate-pollution`)** [$N=866$, 31.50%]: PM2.5 = 32.83 (12.53), PM10 = 78.61 (20.65), O3 = 35.09 (18.25) $\mu\text{g/m}^3$, Temp = 30.33 (1.99) $^\circ\text{C}$, RH = 42.78 (9.88) $\%$, Wind = 2.21 (0.60) $\text{m/s}$. Passive AQI = 80.52 (23.59), Adverse Rate = 10.16% (88/866). Predominant season: Summer / Pre-monsoon (84.24%).
- **Cluster 2 (`humid-windy-lower-pollution`)** [$N=962$, 34.99%]: PM2.5 = 22.90 (10.81), PM10 = 54.70 (21.03), O3 = 29.20 (14.44) $\mu\text{g/m}^3$, Temp = 25.84 (1.55) $^\circ\text{C}$, RH = 75.58 (9.20) $\%$, Wind = 3.87 (1.08) $\text{m/s}$. Passive AQI = 56.54 (19.38), Adverse Rate = 0.21% (2/962). Predominant season: Monsoon (76.16%).
- **Cluster 3 (`cool-low-wind-particulate-elevated`)** [$N=921$, 33.50%]: PM2.5 = 45.66 (17.63), PM10 = 96.52 (26.30), O3 = 32.51 (12.47) $\mu\text{g/m}^3$, Temp = 23.92 (2.27) $^\circ\text{C}$, RH = 59.89 (13.80) $\%$, Wind = 2.02 (0.57) $\text{m/s}$. Passive AQI = 99.79 (31.45), Adverse Rate = 33.44% (308/921). Predominant season: Winter (97.02%) and Post-monsoon (71.27%).

#### India Representative Panel (15 Stations, $N=6,796$)
- **Cluster 1 (`cool-low-wind-particulate-elevated`)** [$N=1,261$, 18.56%]: PM2.5 = 100.41 (66.41), PM10 = 186.17 (81.39), O3 = 54.77 (38.98) $\mu\text{g/m}^3$, Temp = 21.52 (3.90) $^\circ\text{C}$, RH = 61.02 (13.50) $\%$, Wind = 1.80 (0.62) $\text{m/s}$. Passive AQI = 211.38 (92.70, valid $N=1,260$ / 1 missing), Adverse Rate = 96.67% (1,218/1,260). Predominant season: Winter (73.05%).
- **Cluster 2 (`hot-dry-ozone-pm10-elevated`)** [$N=1,764$, 25.96%]: PM2.5 = 47.74 (19.60), PM10 = 115.76 (45.98), O3 = 68.33 (40.13) $\mu\text{g/m}^3$, Temp = 30.65 (3.44) $^\circ\text{C}$, RH = 40.89 (15.21) $\%$, Wind = 2.40 (0.69) $\text{m/s}$. Passive AQI = 120.87 (41.09, valid $N=1,742$ / 22 missing), Adverse Rate = 68.89% (1,200/1,742). Predominant season: Summer / Pre-monsoon (54.40%).
- **Cluster 3 (`humid-windy-lower-pollution`)** [$N=3,771$, 55.49%]: PM2.5 = 29.24 (14.66), PM10 = 62.86 (30.45), O3 = 27.82 (17.75) $\mu\text{g/m}^3$, Temp = 27.31 (2.75) $^\circ\text{C}$, RH = 77.23 (10.20) $\%$, Wind = 2.77 (1.14) $\text{m/s}$. Passive AQI = 66.48 (30.56, valid $N=3,771$ / 0 missing), Adverse Rate = 12.94% (488/3,771). Predominant season: Monsoon (86.86%).

### C. Recent Evaluation Frequencies & Centroid-Distance Percentiles
- **Hyderabad Recent ($N=121$)**:
  - Cluster 1: 28 (23.14%)
  - Cluster 2: 82 (67.77%)
  - Cluster 3: 11 (9.09%)
  - Centroid distance: Mean percentile = 0.576864, Median = 0.629750, 90th percentile = 0.866944, 95th percentile = 0.905312. Count $\ge 0.95$ = 3 ($2.48\%$).
- **India Recent ($N=262$)**:
  - Cluster 1: 3 (1.15%)
  - Cluster 2: 22 (8.40%)
  - Cluster 3: 237 (90.46%)
  - Centroid distance: Mean percentile = 0.393887, Median = 0.342880, 90th percentile = 0.782551, 95th percentile = 0.846513. Count $\ge 0.95$ = 2 ($0.76\%$).
- *Interpretation*: Most recent observations lie within the historical within-cluster distance distribution. Only a small fraction of September observations occupied the upper 5% tail of their assigned historical cluster-distance distribution.

---

## 4. Test Suite Execution & Reproducibility Verification

The test suite [`tests/testthat/test_phase5a.R`](file:///d:/RAJ/GITHUB_REPOSITORY/COLLEGE/COLLEGE_PROJECTS/SML/SML-PBL\UrbanAirQualityIndex-PollutantDriftAnalysis\tests\testthat\test_phase5a.R) was verified via [`scripts/19b_phase5A2_reproducibility_check.R`](file:///d:/RAJ/GITHUB_REPOSITORY/COLLEGE/COLLEGE_PROJECTS/SML/SML-PBL\UrbanAirQualityIndex-PollutantDriftAnalysis\scripts\19b_phase5A2_reproducibility_check.R):

```
================================================================================
TEST SUITE EXECUTION SUMMARY:
  Blocks executed:    6 
  Assertions passed:  115 
  Failures:           0 
  Warnings:           0 
  Skips:              0 
================================================================================
```

### Modular Block Summary:
1. **Block A (Feature & PCA Contract)**: 9 literal `expect_*` calls verifying scaling parameters, date boundaries, variable exclusions, and 4-PC retention.
2. **Block B (K-Means Selection & Centroids)**: 6 literal `expect_*` calls verifying candidate $k \in \{2..8\}$, feasibility constraints, algorithmic K-selection rule ($k=3$), and ARI multi-seed stability.
3. **Block C (Recent Projection & Distance Percentiles)**: 5 literal `expect_*` calls verifying out-of-sample projection, frozen PCA transformation, nearest-centroid assignment, and percentile bounds.
4. **Block D (Metadata, Units & De-Causalization)**: 6 literal `expect_*` calls verifying tracked `station_catalog.csv`, `pollutant_dictionary.csv` ($\mu\text{g/m}^3$), and absence of forbidden causal terms.
5. **Block E (Numerical Consistency & Cross-Tabulations)**: 6 literal `expect_*` calls verifying 100% agreement on all 124 checks in `phase5A_numeric_consistency_audit.csv`, variance sums to 1.0, and exact sample sizes.
6. **Block F (Reproducibility & Safety)**: 3 literal `expect_*` calls verifying offline execution safety, zero external network calls, preservation of Phase-4 artifacts, and tracked report generation integrity (`phase5A_report_generation_integrity.csv`).

---

## 5. Git Status & Review Archive

- **Branch**: `feature/pca-kmeans`
- **Initial Feature Commit**: `2e3fc98` (`feat: add PCA and K-Means pollution regime analysis`)
- **First Repair Commit**: `7540473` (`fix: reconcile Phase 5A reports and regime interpretation`)
- **Final Corrective Commit**: `fix: finalize Phase 5A artifact and test consistency`
- **Review Archive**: [`review_archive_phase5A2_light.zip`](file:///C:/Users/rajghosh/.gemini/antigravity/brain/ec546398-bfa0-4cdc-addc-27046356bd44/review_archive_phase5A2_light.zip) verified and self-contained with all primary processed data, PCA/K-Means models, analysis tables, figures, scripts, tests, and reports.
- **Repository Policy**: No push to remote, no merge into main, no pull requests opened.

---

## 6. Final Milestone Status

```
================================================================================
PHASE 5 UNSUPERVISED LEARNING FROZEN — READY FOR GIT INTEGRATION
================================================================================
```
