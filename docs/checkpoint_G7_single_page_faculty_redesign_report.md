# Checkpoint G7 — Single-Page Faculty Presentation Redesign Report

## 1. Stable Snapshot & Feature Branch
- **Pre-G7 Main SHA:** `611febc`
- **Backup Branch:** `main-stable` (created at `611febc`)
- **Immutable Tag:** `stable-multipage-2026-09-30` (created at `611febc`)
- **Development Branch:** `feature/single-page-faculty-redesign`

## 2. Structural Redesign
The website's primary information architecture was transitioned from a phase-oriented multi-page dashboard to a unified, scrollable single-page scientific presentation layout designed specifically for faculty review.

The new structure features:
- `#home`: Hero, Problem Statement, Objectives, Study at a Glance, Technology, End-to-End Journey, and a clear distinction between the Frozen Academic Baseline and the Operational Extension.
- `#explore`: Interactive Data Explorer with explicit Missingness Policy and KaTeX-rendered CPCB AQI sub-index formulas.
- `#statistics`: Interactive Level-1 Pollutant Drift and Statistical Inference sections with theoretical explanations of MBB, BH-FDR, and standardized mean shifts.
- `#machine-learning`: Supervised regression, classification, and unsupervised PCA/K-Means models, presented contextually as "tasks" (Continuous Regression, Adverse Classification, Regime Discovery) rather than generic evaluation metrics.

## 3. Reference Project Influences
**Ideas Adopted:**
- Single-page narrative storytelling flow
- Sticky navigation with scrollspy highlighting
- Concept/Theory $\rightarrow$ Formula $\rightarrow$ Interactive Evidence progression
- Distinct visual contrast for methodology blocks vs interactive blocks
- Formula rendering using KaTeX

**Ideas Intentionally NOT Copied:**
- The visual theme (blue/orange), typography, or layouts
- Project claims or domain language unrelated to air quality
- We strictly maintained the project's native warm pearl / jade visual identity.

## 4. Single-Page JavaScript Architecture
- **Lazy Initialization:** To prevent performance degradation and duplicate event listeners, `explore.js`, `statistics.js`, and `machine-learning.js` were refactored from auto-executing on `DOMContentLoaded` to exposing specific global initialization functions (`window.initExploreSection`, etc.).
- **Intersection Observer:** `assets/js/single-page.js` utilizes an Intersection Observer to eagerly initialize these complex sections only as the user scrolls them into view, ensuring 0 console errors and optimized load times.
- **Deep-Link Support:** Native `#hash` routes (e.g. `index.html?mode=live#explore`) immediately scroll to the section and force its initialization on page load, retaining compatibility with parameterized dashboards.

## 5. Route Compatibility & Legacy Redirects
- The original pages (`explore.html`, `statistics.html`, `machine-learning.html`) were replaced with lightweight HTML redirect scripts.
- They correctly preserve URL parameters and seamlessly transition users to `index.html?mode=...#section`.
- Deep reference documentation (`documentation.html` and `about.html`) remain independently hosted and accessible via footer/secondary links.

## 6. Enhancements
- **Missing-Data Chart UX:** If an explore window has missing AQI data, the chart subtitle dynamically updates to state: *"Valid AQI available for X of Y scheduled station-days. Missing AQI dates are intentionally not interpolated because required verified-pollutant coverage was insufficient."*
- **Mode-Aware Inspector Wording:** Dataset inspector subtitles dynamically reflect whether they are filtering "frozen study observations", "operational-extension observations", or "frozen + operational-extension observations."

## 7. Audit & Safety
- **Frozen Science Audit:** No models, data processing scripts, evaluation metrics, or `.csv`/`.json` outputs were modified. The scientific baseline remains identical to `v0.6-svm-freeze`.
- **Live-Data Audit:** Operational workflow actions (`.github/workflows`) and their respective R ingestion scripts were left untouched.

## 8. Release
- **Target Feature Merge:** To be merged strictly once into `main` after local regression passing and syncing with recent live data.
- **Release Tag:** `v0.8.0-single-page-faculty`
