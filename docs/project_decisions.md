# Project Architectural Decisions Log

**Project:** UrbanAirQualityIndex-PollutantDriftAnalysis  
**Academic Context:** B.Tech CSE (AI & ML) III Year / I Sem — Statistics for Machine Learning (PBL)  
**Status:** Approved Architectural Foundations

---

### Decision 1: Dedicated Hyderabad Dataset (`UAQI_Hyderabad_Daily.csv`)
- **Rationale:** Hyderabad is the primary local urban study area. A dedicated dataset containing 5–8 diverse monitoring stations (representing industrial, urban commercial, residential, ecological, and institutional zones) allows granular spatial-temporal modeling, intra-city pollutant drift investigation, and micro-climate analysis that cannot be captured by a single aggregate city number.

### Decision 2: Curated Multi-City India Dataset (`UAQI_India_Daily.csv`)
- **Rationale:** India possesses hundreds of monitoring stations across 30+ states, but data quality, active uptime, and sensor calibration vary drastically. Rather than indiscriminately scraping all stations (which introduces massive missingness and noise), we curate 12–15 representative cities across distinct geographical/climatic regions (North Gangetic Plain, Coastal West/South, Deccan Plateau, Eastern Delta, Northeastern Valleys) with 1–3 high-quality stations each.

### Decision 3: Shared Canonical Schema and Pipeline
- **Rationale:** To maintain scientific comparability and facilitate seamless transfer of analytical code, both datasets are produced by the exact same processing code, using identical column names, units, data types, column ordering, and Indian AQI formulas. An analysis or machine learning model written for Hyderabad can run on the India dataset without code modification.

### Decision 4: Immutability of Raw Data
- **Rationale:** Environmental data provenance is sacred. Raw payloads downloaded from APIs or data portals are saved untouched in `data/raw/` with full timestamps and source headers. All normalization, unit conversions, and aggregations occur in `data/interim/` and `data/processed/`. Raw data is never modified or overwritten.

### Decision 5: Non-Fabrication and Treatment of Missing Data
- **Rationale:** A missing sensor observation (`NA`) represents an absence of measurement (e.g., power outage, calibration cycle, sensor malfunction). A reading of zero ($0.0$) represents an active physical measurement of zero concentration. Conflating `NA` with zero artificially lowers pollution statistics and invalidates regression models. Missing data is preserved as `NA` and quantified honestly.

### Decision 6: Kaggle as Secondary Reference, Not Primary Foundation
- **Rationale:** Kaggle hosts several useful compilations of CPCB data, but many lack clear pipeline provenance, metadata updates, or documentation of transformations. We use Kaggle strictly as a secondary benchmark for cross-validation and pre-2021 historical reference, while anchoring our active pipeline in direct APIs.

### Decision 7: Deferring AQI Calculation Beyond Phase 1
- **Rationale:** Indian AQI calculation relies on specific CPCB piecewise linear sub-index equations, averaging requirements (24-hour vs 8-hour standards), and minimum pollutant sufficiency rules (at least 3 pollutants with at least one particulate $\text{PM}_{2.5}$ or $\text{PM}_{10}$). Implementing AQI before verifying official documentation and auditing data availability risks propagating calculation errors.

### Decision 8: Deferring Machine Learning and Modeling Beyond Phase 1
- **Rationale:** High-quality statistics and machine learning require clean, well-understood datasets. Training Multiple Linear Regression, Logistic Regression, PCA, or K-Means on unverified data violates data science best practices. Phase 1 focuses exclusively on discovering valid stations, auditing completeness, and verifying ingestion.

### Decision 9: Exclusion of Static `pollutant_drift_score` Column
- **Rationale:** Drift is a dynamic statistical metric computed across moving or comparative time windows (e.g., recent 30-day mean versus 3-year baseline mean), not a static physical property of a single day's air. It will be computed during analytical and modeling phases.

### Decision 10: Phase 2A Study-Period Lock
- **Rationale:** Human review of Phase 1 metadata and coverage established that many current-generation sensors provide reliable data starting early 2025. Therefore, the locked timelines for historical acquisition and modeling are:
  - **FULL INTENDED ACQUISITION PERIOD:** 2025-03-01 through 2026-09-21
  - **PRIMARY COMPLETED MODELING HISTORY:** 2025-03-01 through 2026-08-31
  - **RECENT / CURRENT EVALUATION PERIOD:** 2026-09-01 through 2026-09-21
  - **PILOT ACQUISITION (PHASE 2A ONLY):** 2025-03-01 through 2025-03-31

## Phase 2E: Verified-Subset AQI Policy Lock

*   **Decision:** Implement the VERIFIED_SUBSET_PM25_PM10_O3 AQI policy.
*   **Context:** Following the 2022 OpenAQ cessation of dual-unit mass tracking for Indian gaseous pollutants, programmatic, unauthenticated reconciliation against the official CPCB portal proved unfeasible without bypassing web security.
*   **Outcome:** To strictly preserve mathematical traceability and avoid fabricated scalars, CO, NO2, and SO2 are completely excluded from AQI derivation. The final calculated regulatory values derive entirely from PM2.5, PM10, and O3 (which are natively verified). This fulfills the CPCB structural requirement of "minimum three valid parameters including at least one particulate" while remaining scientifically conservative.
