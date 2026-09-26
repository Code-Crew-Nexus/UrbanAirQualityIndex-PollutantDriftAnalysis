# Website Documentation Audit & Reconciliation Log

**Project:** `UrbanAirQualityIndex-PollutantDriftAnalysis`  
**Organization:** `Code-Crew-Nexus`  
**Phase:** Phase 6A — Static Project Website Foundation  
**Branch:** `feature/project-website`  
**Date:** September 2026  

---

## 1. Audit Policy & Classification Framework

To adhere to the **Documentation Single-Source Principle**, the public static website dynamically fetches and renders canonical Markdown documents directly from repository-tracked sources. Before rendering, all existing GitHub-facing documents were audited to verify scientific currency, eliminate obsolete roadmap descriptions, prevent accidental exposure of internal debugging traces, and remove local filesystem paths (`file:///` protocol and local Windows absolute paths).

Each audited document is classified into one of three operational categories:
- **`CURRENT`**: Authoritative, scientifically accurate, and suitable for direct presentation on the website without alteration.
- **`NEEDS_RECONCILIATION`**: Authoritative core, but required targeted reconciliation of obsolete roadmap, interface (e.g., legacy Shiny references), or superseded target specifications (e.g., $\text{AQI}_{t+1} > 100$ vs. outdated draft targets).
- **`INTERNAL_ONLY`**: Preserved in repository for internal audit or developer history, but excluded from public website navigation.

---

## 2. Document Audit Inventory

| Document | Website Use | Classification | Reason / Reconciliations Applied |
| :--- | :--- | :--- | :--- |
| `README.md` | Root GitHub Overview & Project Guide | `NEEDS_RECONCILIATION` | **Reconciled:** Replaced obsolete `R Shiny — NEXT` with `Static Project Website — IN DEVELOPMENT`; updated milestone `v0.6-svm-freeze — COMPLETE`; restructured Section 12 to clearly distinguish the R analytical/modeling engine from the static website presentation layer. |
| `docs/TEAM.md` | About Page / Project Attribution | `CURRENT` | Authoritative record of the 4 student team members, roll numbers, and GitHub handles. No modifications required. |
| `docs/ENVIRONMENT.md` | Prerequisites / Environment Reference | `CURRENT` | Authoritative record of primary R 4.6.1 runtime, Windows platform, and base package configuration. |
| `docs/data_sources.md` | Data Sources Documentation | `CURRENT` | Accurate provenance description of OpenAQ v3 API, Open-Meteo Historical Weather API, and CPCB regulatory standards. |
| `docs/dataset_schema.md` | Data Schema Reference | `CURRENT` | Authoritative schema definition of canonical variables, pollutant inputs, meteorological metrics, and spatial attributes. |
| `docs/cpcb_aqi_methodology_verified.md` | AQI Methodology Guide | `CURRENT` | Fully verified and locked CPCB regulatory breakpoint tables, linear interpolation formulas, and verified-subset policy. |
| `docs/MODELING_FREEZE_SUMMARY.md` | Machine Learning / Freeze Overview | `NEEDS_RECONCILIATION` | **Reconciled:** Updated status header to `Frozen Modeling Baseline (v0.6-svm-freeze)` and revised closing sentence to reference the static website presentation layer rather than legacy Shiny runtime. All frozen statistical metrics and findings preserved intact. |
| `docs/PROJECT_CHECKPOINTS.md` | Project Milestones Reference | `NEEDS_RECONCILIATION` | **Reconciled:** Updated Phase 6 checkpoint from `R Shiny integration - NEXT` to `Static Project Website (HTML5/CSS3/Vanilla JS for GitHub Pages) - IN DEVELOPMENT`. |
| `docs/methodology.md` | Analytical Architecture Guide | `NEEDS_RECONCILIATION` | **Reconciled:** Updated flowchart to reflect completed/frozen Phases 0–5B (`v0.6-svm-freeze`) and Phase 6 static website; corrected Section 5 phase progression to replace outdated draft targets ($\text{AQI} > 200$) with frozen adverse target $\text{AQI}_{t+1} > 100$; noted RBF SVM completion; preserved core CPCB formulas. |
| `docs/project_decisions.md` | Decision Log | `CURRENT` | Accurate historical log of architectural, data-engineering, and modeling decisions. |
| `docs/phase1_station_selection_decision.md` | Station Selection Justification | `CURRENT` | Authoritative rationale for 21 physical stations (7 Hyderabad, 15 India representative). |
| `docs/repository_data_policy.md` | Data Tracking Policy | `CURRENT` | Explains Git tracking rules (processed data tracked, raw/interim gitignored). |
| `docs/GIT_TRACKING_PLAN.md` | Git Architecture Plan | `CURRENT` | Curation rules and repository boundaries. |
| `docs/github_checkpoint_G1_report.md` | Checkpoint G1 Report | `CURRENT` | Static milestone report for repository curation. |
| `docs/github_checkpoint_G1_1_report.md` | Checkpoint G1.1 Report | `CURRENT` | Static milestone report for repository curation. |
| `docs/reports/phase2_data_aqi_summary.md` | Phase 2 Canonical Summary | `CURRENT` | Authoritative summary of data acquisition, normalization, and verified AQI calculation. |
| `docs/reports/phase3_statistical_analysis_summary.md` | Phase 3 Canonical Summary | `CURRENT` | Authoritative summary of EDA, standardized drift ($D_z$), and moving-block bootstrap inference. |
| `docs/reports/phase4_supervised_learning_summary.md` | Phase 4 Canonical Summary | `CURRENT` | Authoritative summary of MLR Model B, Logistic Model B, out-of-sample metrics, and prevalence shifts. |
| `docs/reports/phase5_pca_kmeans_summary.md` | Phase 5A Canonical Summary | `CURRENT` | Authoritative summary of PCA feature compression (4 PCs, $>83\%$ variance) and K-Means regimes ($k=4$). |
| `docs/reports/phase5b_svm_summary.md` | Phase 5B Canonical Summary | `NEEDS_RECONCILIATION` | **Reconciled:** Removed 3 local absolute `file:///d:/...` Windows path links (lines 35, 76, 103) and replaced with safe repository-relative links (`../../data/processed/UAQI_Master_Daily.csv` and `../../analysis/phase5B/tables/...`). All frozen SVM metrics and evaluation numbers preserved. |
| `docs/reports/README.md` | Reports Index | `CURRENT` | Accurate index of Phase 2–5B canonical reports. |
| `docs/internal_phase_history/*` | Intermediate Engineering Logs | `INTERNAL_ONLY` | Verbose debug reports, closure logs, and interim diagnostics; intentionally gitignored and excluded from primary public website navigation. |
| `app/README.md` | Abandoned Shiny Placeholder | `RETIRED` | **Removed:** Obsolete placeholder for abandoned R Shiny GUI. Removed along with `app/` directory to eliminate conflicting documentation. |

---

## 3. Summary of Reconciliations

1. **Elimination of Absolute Local Paths:** Fixed local machine URLs in `docs/reports/phase5b_svm_summary.md` so that website rendering operates seamlessly under GitHub Pages.
2. **Transition from Shiny to Static Website:** Updated `README.md`, `docs/PROJECT_CHECKPOINTS.md`, `docs/MODELING_FREEZE_SUMMARY.md`, and `docs/methodology.md` to reflect that the GUI layer is a zero-dependency static web application hosted on GitHub Pages that consumes frozen R outputs.
3. **Consistency of Classification Targets:** Ensured that supervised learning documentation uniformly defines the adverse air quality target as $\text{AQI}_{t+1} > 100$, retiring obsolete draft references to $\text{AQI} > 200$.
4. **Maintenance of Scientific Freeze:** No statistical metrics, model parameters, hyperparameter grids, p-values, or dataset row counts were modified during documentation reconciliation.
