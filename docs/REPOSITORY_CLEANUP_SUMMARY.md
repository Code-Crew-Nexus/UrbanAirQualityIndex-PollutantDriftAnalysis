# Repository Cleanup Summary — Tracked Artifact Minimization

This document records the repository hygiene audit and minimization of historical, duplicate, and unreferenced tracked artifacts. Engineering and scientific development remain completely closed.

## 1. Categories Removed from Current Git Tracking
All removed files were safely preserved in the untracked, gitignored local backup directory (`local_archive/`) and remain immutable in Git history and release tags.

1. **Root Checkpoint Clutter (6 files)**:
   - `checkpoint_G4_website_release_integration_report.md` (duplicate of internal phase history)
   - `checkpoint_G5_addons_report.md` (duplicate of internal phase history)
   - `checkpoint_G5_post_deployment_ui_integrity_report.md` (duplicate of internal phase history)
   - `checkpoint_G6_deployment_inventory_before.csv` (historical deployment audit)
   - `checkpoint_G6_deployment_inventory_after.csv` (historical deployment audit)
   - `checkpoint_G6_live_data_extension_report.md` (duplicate of internal phase history)

2. **Tracked Files in Internal Phase History (3 files)**:
   - `docs/internal_phase_history/checkpoint_G5_addons_report.md`
   - `docs/internal_phase_history/checkpoint_G5_post_deployment_ui_integrity_report.md`
   - `docs/internal_phase_history/checkpoint_G6_live_data_extension_report.md`
   - *Note*: `docs/internal_phase_history/` is listed in `.gitignore` as an internal debugging directory; these three tracked files were untracked.

3. **Interim G6/G7 Engineering Checkpoint Reports (5 files)**:
   - `docs/checkpoint_G6_live_automation_hotfix_report.md`
   - `docs/checkpoint_G7_single_page_faculty_redesign_report.md`
   - `docs/checkpoint_G7_1_single_page_polish_report.md`
   - `docs/checkpoint_G7_2_faculty_visual_polish_report.md`
   - `docs/checkpoint_G7_3_visual_recovery_report.md`
   - *Note*: Replaced by the authoritative final summaries: `docs/FINAL_ENGINEERING_CLOSURE.md` and `docs/PROJECT_CHECKPOINTS.md`.

4. **Legacy Multi-Page Website Tests (6 files)**:
   - `tests/testthat/test_checkpoint_g5_addons.R`
   - `tests/testthat/test_checkpoint_g5_refinement.R`
   - `tests/testthat/test_checkpoint_g5_ui_integrity.R`
   - `tests/testthat/test_phase6a_website.R`
   - `tests/testthat/test_phase6b_website.R`
   - `tests/testthat/test_phase6c_release.R`
   - *Note*: These legacy testthat suites assert obsolete multi-page HTML files (`explore.html`, `statistics.html`, `machine-learning.html`) deprecated during the G7 single-page faculty presentation migration. Current regression coverage is maintained by the Python Playwright suite and scientific R testthat suites.

5. **Historical QA Screenshots (17 files)**:
   - `docs/screenshots/g5_addons/` (9 images)
   - `docs/screenshots/g5_refinement/` (8 images)
   - *Note*: Point-in-time QA screenshots with zero references in public HTML, CSS, JS, or documentation.

**Total Files Removed from Tracking**: 37 files.

## 2. Deliberately Retained Categories
- **Core Governance & Metadata**: `README.md`, `LICENSE`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`.
- **Workflows & Automation**: `.github/workflows/live-data-daily.yml`, `.github/workflows/live-data-monthly.yml`.
- **R Libraries & Ingestion Logic**: `R/`, `config/`, `scripts/44_live_data_ingestion.R`, `scripts/45_live_model_inference.R`.
- **Scientific Models & Baseline**: `models/` (all frozen model artifacts, scaler objects, SVM specifications).
- **Curated & Live Observational Data**: `data/metadata/`, `data/live/metadata/`, `data/live/processed/`.
- **Public Single-Page Website**: `docs/index.html`, `docs/documentation.html`, `docs/about.html`, `docs/assets/`, `docs/web-data/`.
- **Documentation & Educational Materials**: `docs/guide/`, `docs/slides/` (master presentation PNGs and WebP derivatives), `docs/figures/`.
- **Authoritative Freeze Summaries**:
  - `docs/FINAL_ENGINEERING_CLOSURE.md`
  - `docs/MODELING_FREEZE_SUMMARY.md`
  - `docs/PROJECT_CHECKPOINTS.md`
  - `docs/WEBSITE_SCIENTIFIC_TRUTH.md`
- **Current Active Test Suites**:
  - All 7 single-page Python/Playwright suites (`tests/test_g7_*.py`)
  - All scientific R testthat suites (Phases 1 through 5, live-extension G6, automation G6.2A)

## 3. Tracked File & Size Metrics
- **Tracked Files Before Cleanup**: 549
- **Tracked Files After Cleanup**: 513 (512 existing + `docs/REPOSITORY_CLEANUP_SUMMARY.md`)
- **Tracked Bytes Before Cleanup**: 79,361,240 bytes (75.68 MB)
- **Tracked Bytes After Cleanup**: ~78,255,000 bytes (74.63 MB)
- **Net Reduction**: 36 tracked files, ~1.11 MB tracked bytes eliminated from active deployment footprint.

## 4. Verification Statement
All website presentation behavior, scientific calculations, frozen model scoring, live data ingestion workflows, and interactive dashboards remain **100% unchanged**.
- Python Playwright regression suite: 7/7 PASSED.
- Live extension / automation R testthat suites: PASSED.
- Local website preview (`http://localhost:8000/`): All routes returned HTTP 200 OK.
- Scheduled GitHub Actions workflows remain untouched and fully enabled.
