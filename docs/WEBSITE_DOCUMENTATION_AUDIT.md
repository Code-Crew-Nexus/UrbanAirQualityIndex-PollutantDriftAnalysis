# Website Documentation Audit & Reconciliation Log

**Project:** `UrbanAirQualityIndex-PollutantDriftAnalysis`  
**Organization:** `Code-Crew-Nexus`  
**Phase:** Phase 6A.1 — Website Scientific Documentation Integrity, Math Content Reconciliation & UI Foundation Closure  
**Branch:** `feature/project-website`  
**Date:** September 2026  
**Scientific Baseline:** `v0.6-svm-freeze`  

---

## 1. Audit Policy & Classification Framework

To adhere to the **Documentation Single-Source Principle**, the public static website dynamically fetches and renders canonical Markdown documents directly from repository-tracked sources. Before rendering, all existing GitHub-facing documents were audited to verify scientific currency, eliminate obsolete roadmap descriptions, prevent accidental exposure of internal debugging traces, eliminate local filesystem paths (`file:///` protocol and local Windows absolute paths), and ensure strict mathematical and scientific fidelity with the frozen computation (`v0.6-svm-freeze`).

Each audited document is classified into one of four operational categories:
- **`VERIFIED_CURRENT`**: Authoritative, scientifically verified against Level-1 frozen computation, and suitable for direct presentation on the website without alteration.
- **`RECONCILED`**: Authoritative core where targeted reconciliation was applied to rectify terminology, formulas, thresholds, split dates, or cluster labels to align with Level-1 ground truth.
- **`REFERENCE_ONLY`**: Preserved in the repository for historical context, decision records, or developer configuration, but not part of the primary public website narrative.
- **`INTERNAL_ONLY`**: Preserved in the repository for developer history or intermediate diagnostics; excluded from website navigation.

### Scientific Ground Truth Hierarchy (Strict Order of Precedence)
1. **Level 1 (Frozen Computation):** Model configs (`config/phase4C_selected_models.yml`, `config/phase5B_selected_svm.yml`), frozen serialized models (`analysis/phase4C/models/*.rds`, `analysis/phase5B/models/*.rds`), frozen evaluation tables (`analysis/phase*/tables/*.csv`), and canonical processed datasets (`data/processed/UAQI_Master_Daily.csv`).
2. **Level 2 (Accepted Final Phase Reports):** Verified Markdown reports (`docs/reports/phase*.md`, `docs/WEBSITE_SCIENTIFIC_TRUTH.md`).
3. **Level 3 (Website Documentation & Public Guides):** Interactive website pages, guide documents (`docs/guide/*.md`), `README.md`, and methodology documentation.

*Rule:* Documentation (Level 2/3) must always be reconciled to match frozen computation (Level 1). Frozen computation is never altered to match prose.

---

## 2. Comprehensive Document Audit Inventory

| Document | Website Use | Status | Source of Truth | Validation Method | Reason / Reconciliations Applied |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `README.md` | Root GitHub Overview & Project Guide | `RECONCILED` | Level 1/2 Project Status | Manual inspection & regex | Replaced obsolete `R Shiny — NEXT` with `Static Project Website — IN DEVELOPMENT`; updated milestone `v0.6-svm-freeze — COMPLETE`; distinguished R analytical engine from static presentation layer. |
| `docs/WEBSITE_SCIENTIFIC_TRUTH.md` | Authoritative Scientific Ground Truth Table | `VERIFIED_CURRENT` | Level 1 frozen configs & tables | Programmatic extraction & code inspection | Authoritative Level-2 truth table covering Study Design, AQI Policy, Drift Parameters & Magnitude Classes, MBB Inference, Splits, Logistic Thresholds, PCA, K-Means $k=3$ labels, and SVM specifications. |
| `docs/PACKAGE_REQUIREMENTS.md` | Package Dependency Audit & Reproduction Matrix | `VERIFIED_CURRENT` | Codebase scripts audit | Programmatic code inspection | Classifies dependencies into Core Frozen-Review, Full Reproduction, and API Harvesting; records installed vs required runtime versions. |
| `docs/WEBSITE_DOCUMENTATION_AUDIT.md` | Documentation Audit & Reconciliation Log | `VERIFIED_CURRENT` | Project audit framework | Comprehensive audit inventory | Reconciled audit log tracking documentation status, source of truth, validation methods, and specific corrections. |
| `docs/WEBSITE_LINK_AUDIT.md` | Website Link & Asset Integrity Audit | `VERIFIED_CURRENT` | Codebase markdown scan | Programmatic regex parser | Catalogs all links and images; confirms 0 broken links, 0 CDN leaks, and 0 local absolute paths (`file:///`, `C:\`, `D:\`). |
| `docs/TEAM.md` | About Page / Project Attribution | `VERIFIED_CURRENT` | Project proposal & roster | Static verification | Authoritative record of 4 student team members, roll numbers, and GitHub handles. |
| `docs/ENVIRONMENT.md` | Prerequisites / Environment Reference | `REFERENCE_ONLY` | Primary tested developer environment | Static verification | Record of primary R 4.6.1 runtime, Windows platform, and base package configuration. |
| `docs/data_sources.md` | Data Sources Documentation | `VERIFIED_CURRENT` | Phase 1 & 2 data pipeline | Static verification | Accurate provenance description of OpenAQ v3 API, Open-Meteo Historical Weather API, and CPCB regulatory standards. |
| `docs/dataset_schema.md` | Data Schema Reference | `VERIFIED_CURRENT` | `data/processed/UAQI_Master_Daily.csv` | Codebase schema inspection | Authoritative schema definition of canonical variables, pollutant inputs, meteorological metrics, and spatial attributes. |
| `docs/cpcb_aqi_methodology_verified.md` | AQI Methodology Guide | `VERIFIED_CURRENT` | CPCB Regulatory Guidelines (2014) | Formulaic verification | Locked CPCB breakpoint tables, linear interpolation formulas, and verified-subset policy ($\ge 3$ pollutants including PM2.5 or PM10). |
| `docs/MODELING_FREEZE_SUMMARY.md` | Machine Learning / Freeze Overview | `RECONCILED` | Level 1 modeling artifacts (`v0.6-svm-freeze`) | Cross-report validation | Updated status header to `Frozen Modeling Baseline (v0.6-svm-freeze)`; references static website presentation layer rather than legacy Shiny runtime. |
| `docs/PROJECT_CHECKPOINTS.md` | Project Milestones Reference | `RECONCILED` | Repository roadmap | Milestone verification | Updated Phase 6 checkpoint from `R Shiny integration - NEXT` to `Static Project Website (HTML5/CSS3/Vanilla JS for GitHub Pages) - IN DEVELOPMENT`. |
| `docs/methodology.md` | Analytical Architecture Guide | `RECONCILED` | Phase 0–5B pipeline & configs | Formulaic & code verification | Updated flowchart to $k=3$; Phase 3, 4, 5 text updated with drift baseline SD, validation thresholds, PCA variance, and $k=3$ regimes. |
| `docs/project_decisions.md` | Decision Log | `REFERENCE_ONLY` | Phase 0–5B commit history | Static verification | Historical log of architectural, data-engineering, and modeling decisions. |
| `docs/phase1_station_selection_decision.md` | Station Selection Justification | `VERIFIED_CURRENT` | `config/selected_stations.csv` | Programmatic verification | Authoritative rationale for 21 physical stations (7 Hyderabad, 15 India representative; Zoo Park `PROJ_007` in both). |
| `docs/repository_data_policy.md` | Data Tracking Policy | `REFERENCE_ONLY` | Git tracking rules | Static verification | Explains Git tracking rules (processed data tracked, raw/interim gitignored). |
| `docs/GIT_TRACKING_PLAN.md` | Git Architecture Plan | `REFERENCE_ONLY` | Repository configuration | Static verification | Curation rules and repository boundaries. |
| `docs/github_checkpoint_G1_report.md` | Checkpoint G1 Report | `REFERENCE_ONLY` | Static milestone report | Historical record | Repository curation milestone G1. |
| `docs/github_checkpoint_G1_1_report.md` | Checkpoint G1.1 Report | `REFERENCE_ONLY` | Static milestone report | Historical record | Repository curation milestone G1.1. |
| `docs/reports/phase2_data_aqi_summary.md` | Phase 2 Canonical Summary | `VERIFIED_CURRENT` | Phase 2 pipeline & CSVs | Data validation | Summary of data acquisition, normalization, and verified AQI calculation. |
| `docs/reports/phase3_statistical_analysis_summary.md` | Phase 3 Canonical Summary | `RECONCILED` | `analysis/phase3/tables/` & scripts | Programmatic verification | Reconciled drift denominator to baseline SD ($s_{\text{baseline}}$); added eligibility rules ($\ge 21/30$, $\ge 63/90$, $s_{\text{baseline}}>0$); exact magnitude classes; MBB $B=2000$ bootstrap ($l=7, 3, 14$); removed false single-direction claims. |
| `docs/reports/phase4_supervised_learning_summary.md` | Phase 4 Canonical Summary | `RECONCILED` | `config/phase4C_selected_models.yml` & tables | Config & metrics audit | Corrected TEST window to `2026-05-01` to `2026-08-31`; removed generic $R^2$; added persistence findings, conditional adverse probability terminology, and validation thresholds (Hyd $0.311268$, India $0.713448$). |
| `docs/reports/phase5_pca_kmeans_summary.md` | Phase 5A Canonical Summary | `RECONCILED` | `analysis/phase5A/tables/` | Programmatic verification | Reconciled PCA variance (Hyd 4 PCs $90.21\%$, India 4 PCs $88.65\%$) and K-Means $k=3$ table-derived regime labels; corrected obsolete $k=4$ references. |
| `docs/reports/phase5b_svm_summary.md` | Phase 5B Canonical Summary | `RECONCILED` | `config/phase5B_selected_svm.yml` & tables | Table & path audit | Removed local absolute file paths; clarified SVM decision score event ranking (PR-AUC ranking) vs margin classification; preserved frozen metrics. |
| `docs/reports/README.md` | Reports Index | `VERIFIED_CURRENT` | `docs/reports/` folder contents | Directory verification | Accurate index of Phase 2–5B canonical reports. |
| `docs/guide/prerequisites.md` | Prerequisites Guide | `RECONCILED` | `docs/PACKAGE_REQUIREMENTS.md` & `docs/ENVIRONMENT.md` | Cross-document verification | Distinguishes tested development environment from general requirements; separates frozen review vs full reproduction packages; references `PACKAGE_REQUIREMENTS.md`. |
| `docs/guide/setup.md` | Setup & Execution Guide | `RECONCILED` | Pipeline execution scripts | Script verification | Structured into Mode A (Frozen Review), Mode B (Pipeline Reproduction), Mode C (Full Raw API Re-Acquisition warning). |
| `docs/guide/theoretical_concepts.md` | Theoretical Concepts Reference | `RECONCILED` | Level 1 formulas & configs | KaTeX and mathematical audit | Reconciled drift baseline SD, magnitude classes, MBB $B=2000$, Logistic conditional probability and validation thresholds, PCA exact variance, K-Means $k=3$ table-derived labels, SVM decision score ranking, Brier score. |
| `docs/guide/execution_guide.md` | Step-by-Step Execution Guide | `RECONCILED` | Repository scripts & workflows | Workflow verification | Reconciled Phase 3, 4, 5 summaries; eliminated universal scavenging claims; corrected PCA variance; updated $k=3$ regimes. |
| `docs/guide/screenshots_and_samples.md` | Visual Evidence Gallery Guide | `RECONCILED` | Saved plots & figures | Asset verification | Reconciled SVM ranking, PCA variance, and biplot description to 3 selected regimes. |
| `docs/internal_phase_history/*` | Intermediate Engineering Logs | `INTERNAL_ONLY` | Developer scratch/logs | Git history | Verbose debug reports, closure logs, and interim diagnostics; intentionally excluded from public website navigation. |
| `app/README.md` | Abandoned Shiny Placeholder | `RETIRED` | Architecture Decision 006 | Directory deletion | Obsolete placeholder for abandoned R Shiny GUI; deleted along with `app/` directory. |

---

## 3. Summary of Core Reconciliations

1. **Elimination of Absolute Local Paths:** Removed local machine URLs (`file:///d:/...`) in `docs/reports/phase5b_svm_summary.md` and replaced with safe repository-relative links so website rendering operates seamlessly under GitHub Pages.
2. **Transition from Shiny to Static Website:** Updated `README.md`, `docs/PROJECT_CHECKPOINTS.md`, `docs/MODELING_FREEZE_SUMMARY.md`, and `docs/methodology.md` to establish that the GUI layer is a zero-dependency static web application hosted on GitHub Pages that consumes frozen R outputs.
3. **Consistency of Classification Targets & Thresholds:** Ensured supervised learning documentation uniformly defines the adverse air quality target as $\text{AQI}_{t+1} > 100$, retiring obsolete draft references to $\text{AQI} > 200$. Documented exact validation-tuned decision thresholds ($0.311268$ for Hyderabad, $0.713448$ for India).
4. **Drift Metric & Hypothesis Precision:** Standardized drift metric $D_z$ uses baseline standard deviation $s_{\text{baseline}}$ (not pooled variance). Documented exact window eligibility ($\ge 21/30$ recent days, $\ge 63/90$ baseline days, $s_{\text{baseline}} > 0$), exact magnitude classes (Minimal, Mild, Moderate, Strong), and block bootstrap parameters ($B=2000$, block length $l=7$, sensitivity at $l=3, 14$). Eliminated universal monsoon scavenging claims in favor of empirical mixed-direction observations.
5. **Supervised Split Window Alignment:** Corrected TEST split date range in `docs/reports/phase4_supervised_learning_summary.md` to `2026-05-01` to `2026-08-31` (123 days). Documented temporal persistence properties and proper conditional probability interpretation.
6. **Unsupervised Dimensionality & Clustering:** Corrected Phase 5A documentation to reflect $K=3$ selected clusters for both Hyderabad and India panels, eliminating obsolete $k=4$ drafts and speculative cluster labels. Updated PCA cumulative variance explained to exact Level-1 figures: 4 PCs explain $90.21\%$ in Hyderabad and $88.65\%$ in India.
7. **SVM Decision Boundary & Probability Clarification:** Clarified that hard classification is governed by the native margin $s(\mathbf{x}) = 0$, while continuous decision scores $s(\mathbf{x})$ serve as event ranking scores for PR-AUC rather than calibrated class probabilities.
8. **Maintenance of Scientific Freeze:** No statistical metrics, model parameters, hyperparameter grids, p-values, or dataset row counts were modified during documentation reconciliation. All Level-1 computation artifacts remain completely untouched.
