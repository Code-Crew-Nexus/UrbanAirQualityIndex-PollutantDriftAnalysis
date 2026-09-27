# Checkpoint G6 — Cost-Safe Live Data Extension, Deployment Hygiene & Production Resilience

**Project:** UrbanAirQualityIndex-PollutantDriftAnalysis  
**Organization:** Code-Crew-Nexus  
**Branch:** `feature/live-data-extension` → `main`  
**Date:** 2026-09-27  
**Status:** ✅ COMPLETE — Pipeline tested, scored, validated, and hardened

---

## 1. Executive Summary & Core Principles

Checkpoint G6 introduces an **operational live data extension** to the UrbanAirQualityIndex project without altering, retraining, or mutating the permanently frozen academic baseline (`v0.6-svm-freeze`, ending 2026-09-21).

### Core Architectural Invariants
1. **Permanent Scientific Freeze:** The primary research study spanning 570 calendar days (March 1, 2025 to September 21, 2026) across 21 CAAQMS stations remains strictly immutable in `data/processed/` and `docs/web-data/daily_observations.json`.
2. **Distinct Operational Layer:** Operational records from September 22, 2026 onward reside exclusively in `data/live/` and `docs/web-data/live_daily_observations.json`.
3. **Zero-Paid Cloud Footprint:** The entire pipeline operates within free GitHub-hosted runners (`ubuntu-latest`), free public REST APIs (OpenAQ v3 and Open-Meteo), and static GitHub Pages hosting.
4. **Deterministic Frozen Model Scoring:** Live records are scored exclusively using the frozen Phase 4B MLR and Phase 4C Logistic regression weights. No live retraining or auto-promotion is permitted (`AUTO_PROMOTE_MODEL = FALSE`).
5. **Clear UI Separation:** The public website maintains unambiguous contextual separation between the frozen academic baseline and operational live data via status banners, data mode toggles, and stream badges.

---

## 2. Ingestion Engine & Upstream Schema Governance

### Upstream Contract Specification
The data contract defined in `config/live_source_contract.json` governs:
- **OpenAQ v3:** Locations API endpoint (`/v3/locations/{id}/measurements`), parameters (`pm25`, `pm10`, `o3`, `no2`, `so2`, `co`), units, and fallback policies.
- **Open-Meteo:** Archive/Forecast API (`temperature_2m`, `relative_humidity_2m`, `wind_speed_10m`, `surface_pressure`, `precipitation`), parameter mapping, and fallback policies.
- **Station Mapping:** All 21 physical stations with their verified geographical coordinates and external sensor IDs.

### Ingestion Engine Execution (`scripts/44_live_data_ingestion.R`)
The ingestion pipeline was executed for the initial operational window (2026-09-22 through 2026-09-26):
- **Raw Measurements Retrieved:** 3,938 air quality records and 2,520 weather records.
- **Station-Days Processed:** 105 station-days (21 stations × 5 calendar days).
- **Valid AQI Days:** 59 station-days satisfying the CPCB 16-hour completion requirement (PM2.5 or PM10 + at least two auxiliary criteria).
- **Output Artifacts:**
  - `data/live/processed/live_daily_observations.csv` (105 records)
  - `docs/web-data/live_daily_observations.json` (105 records)
  - `docs/web-data/live_pipeline_status.json` (`pipeline_status: "ok"`, `latest_date: "2026-09-26"`)
  - `data/live/metadata/live_ingestion_manifest.csv` (Audit log of all 21 station ingestions)

---

## 3. Deterministic Frozen Model Scoring & Candidate Governance

### Inference Engine Execution (`scripts/45_live_model_inference.R`)
- Evaluates operational records using frozen coefficients from `models/mlr_model.rds` and `models/logistic_model.rds`.
- Emits predictions without mutating any baseline models:
  - `docs/web-data/live_predictions.json` (62 scored operational records)
  - Features scored: Continuous AQI prediction, residual error, adverse pollution event classification ($Y_{t+1}$ probability), and model performance metrics on operational data.

### Quarantined Candidate Space (`models/live_candidate/README.md`)
- Enforces `AUTO_PROMOTE_MODEL = FALSE`.
- Requires manual human approval, peer review, and academic validation before any candidate model trained on operational data can be considered for inclusion.

---

## 4. Web Presentation & User Experience

### 1. Global Pipeline Status Banner
- Added to all 6 public pages below the global header:
  - Shows operational status, latest validated observation date, and link to data documentation.
  - Automatically adapts its style based on `pipeline_status` in `live_pipeline_status.json` (`ok` -> emerald, `stale`/`partial` -> amber, `danger`/`maintenance` -> crimson).

### 2. Explore Data Modes (`docs/explore.html` & `docs/assets/js/explore.js`)
- **Data Mode Selector:**
  - `Frozen Study (through Sep 21, 2026)` (default): Loads only frozen academic data; full study period button defaults to 570 days.
  - `Extended / Live (Sep 22, 2026 onward)`: Lazily loads `live_daily_observations.json`; updates date inputs and displays operational records.
  - `Complete Continuity (Frozen + Live)`: Combines frozen baseline and operational records seamlessly for full-timeline analysis.
- **Dataset Inspector:**
  - Displays a dedicated `Stream` column with semantic badges (`Frozen Study` in jade vs. `Live Extension` in amber).
  - Stream information is preserved in CSV export downloads (`Stream: Frozen Study` vs `Stream: Live Extension`).
- **Deep Linking:** Supports `?mode=live` and `?mode=combined` URL query parameters.

### 3. Frozen Baseline Disclaimers
- Prominently placed on `docs/statistics.html` and `docs/machine-learning.html` to guarantee reviewers know the analytical figures reflect the permanently frozen academic evaluation period.

---

## 5. Deployment Hygiene & Workflow Automation

### GitHub Deployments Decluttering (`scripts/43_declutter_deployments.py`)
- Audited GitHub Pages deployments using GitHub REST API.
- **Before:** 13 deployment records accumulated across prior commits.
- **After:** 3 active/canonical deployment records retained (active production deployment + release freeze tags).

### Automation Guardrails (`docs/ops/COST_AND_AUTOMATION_GUARDRAILS.md`)
- **Daily Workflow (`.github/workflows/live-data-daily.yml`):**
  - Cron schedule: `17 2 * * *` (02:17 UTC daily).
  - Automatic sunset: Skips execution after `2026-10-31` to prevent indefinite execution.
  - Concurrency group: `live-data-refresh` (cancels redundant runs).
  - Timeout: 20 minutes maximum.
- **Monthly Workflow (`.github/workflows/live-data-monthly.yml`):**
  - Cron schedule: `47 2 1 * *` (02:47 UTC on the 1st of each month).
  - Active starting: `2026-11-01`.
  - Concurrency group: `live-data-refresh`.
  - Timeout: 20 minutes maximum.
  - Includes deployment audit step to prevent clutter buildup.

---

## 6. Verification & Quality Assurance

### Automated Test Suites
| Test Suite | Total Tests | Passed | Failed |
|------------|-------------|--------|--------|
| `test_checkpoint_g6_live_extension.R` | 82 | 82 | 0 |
| `test_phase6c_release.R` | 273 | 273 | 0 |
| `test_phase6a_website.R` | 644 | 644 | 0 |
| `test_checkpoint_g5_refinement.R` | 132 | 132 | 0 |
| **Total Automated Invariant Tests** | **1,131** | **1,131** | **0** |

### Playwright Browser QA (`scripts/46_checkpoint_g6_browser_qa.py`)
- Evaluated all 6 public web pages under Chromium headless:
  - `Home`: HTTP 200, 0 console errors, status banner active.
  - `Explore`: HTTP 200, 0 console errors, data modes verified, dataset inspector stream badges verified.
  - `Statistics`: HTTP 200, 0 console errors, frozen baseline disclaimer rendered.
  - `Machine Learning`: HTTP 200, 0 console errors, frozen baseline disclaimer rendered.
  - `Documentation`: HTTP 200, 0 console errors, status banner active.
  - `About`: HTTP 200, 0 console errors, status banner active.

---

## 7. Sign-off & Release Plan

- **Release Tag:** `v0.7.3-live-extension`
- **Baseline Integrity:** `v0.6-svm-freeze` untouched (SHA verification confirms zero byte divergence in baseline datasets and models).
- **Target Branch:** `main`
- **Public URL:** `https://code-crew-nexus.github.io/UrbanAirQualityIndex-PollutantDriftAnalysis/`
