# Website Link & Asset Integrity Audit

**Project:** `UrbanAirQualityIndex-PollutantDriftAnalysis`  
**Organization:** `Code-Crew-Nexus`  
**Phase:** Phase 6A.1 — Website Scientific Documentation Integrity, Math Content Reconciliation & UI Foundation Closure  
**Branch:** `feature/project-website`  
**Date:** September 2026  
**Status:** `ALL_LINKS_VERIFIED_PASS`  

---

## 1. Executive Summary & Verification Metrics

A comprehensive programmatic audit of all Markdown documentation and HTML presentation pages in the `docs/` tree was conducted to verify link integrity, asset availability, and path safety prior to GitHub Pages deployment.

| Audit Metric | Observed Value | Requirement | Status |
| :--- | :--- | :--- | :--- |
| Total Scanned Documents | 36 (Markdown + HTML) | Full `docs/` coverage | PASS |
| Total Extracted Links & Assets | 161 | Complete inventory | PASS |
| Broken Links (`BROKEN`) | 0 | Exactly 0 | PASS |
| Forbidden `file:///` Links | 0 in HTML/rendered | Exactly 0 | PASS |
| Forbidden `C:\` or `D:\` Absolute Paths | 0 | Exactly 0 | PASS |
| External CDN Leaks (`cdn.jsdelivr`, `cdnjs`, etc.) | 0 | Exactly 0 (100% Vendored) | PASS |

---

## 2. Link Classification Distribution

| Category | Count | Description |
| :--- | :--- | :--- |
| `INTERNAL_PAGE` | 105 | Navigation across the six static site HTML pages (`index.html`, `documentation.html`, etc.) |
| `INTERNAL_MARKDOWN` | 11 | Cross-references to tracked Markdown guides and scientific reports |
| `INTERNAL_FIGURE` | 22 | Local PNG figures, plots, CSS stylesheets, vendor scripts, and fonts |
| `GITHUB_REPOSITORY_FILE` | 10 | Canonical GitHub URLs or repository-relative links pointing to raw data, configs, and scripts |
| `EXTERNAL_WEB` | 13 | Reputable external public services (OpenAQ API, Open-Meteo, CPCB, KaTeX, W3C) |
| `BROKEN` | 0 | Non-existent internal targets or broken references |

---

## 3. Detailed Link & Image Inventory

| Source Document | Link Type | Target Path / URL | Classification | Integrity Status |
| :--- | :--- | :--- | :--- | :--- |
| `about.html` | `HTML_LINK` | `about.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `about.html` | `HTML_LINK` | `documentation.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `about.html` | `HTML_LINK` | `documentation.html#execution` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `about.html` | `HTML_LINK` | `documentation.html#prerequisites` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `about.html` | `HTML_LINK` | `documentation.html#theory` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `about.html` | `HTML_LINK` | `explore.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `about.html` | `HTML_LINK` | `https://github.com/Code-Crew-Nexus/UrbanAirQualityIndex-Pollut...` | `GITHUB_REPOSITORY_FILE` | `RESOLVED_ONLINE` |
| `about.html` | `HTML_LINK` | `https://github.com/Saikrishna-dev-oss` | `EXTERNAL_WEB` | `RESOLVED_ONLINE` |
| `about.html` | `HTML_LINK` | `https://github.com/karthik10-dev` | `EXTERNAL_WEB` | `RESOLVED_ONLINE` |
| `about.html` | `HTML_LINK` | `https://github.com/rajghosh06-dev` | `EXTERNAL_WEB` | `RESOLVED_ONLINE` |
| `about.html` | `HTML_LINK` | `https://github.com/rayainwarrior-dev` | `EXTERNAL_WEB` | `RESOLVED_ONLINE` |
| `about.html` | `HTML_LINK` | `index.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `about.html` | `HTML_LINK` | `machine-learning.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `about.html` | `HTML_LINK` | `statistics.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `assets/vendor/VENDOR_MANIFEST.md` | `MARKDOWN_LINK` | `https://github.com/KaTeX/KaTeX` | `EXTERNAL_WEB` | `RESOLVED_ONLINE` |
| `assets/vendor/VENDOR_MANIFEST.md` | `MARKDOWN_LINK` | `https://github.com/UziTech/marked-katex-extension` | `EXTERNAL_WEB` | `RESOLVED_ONLINE` |
| `assets/vendor/VENDOR_MANIFEST.md` | `MARKDOWN_LINK` | `https://github.com/chartjs/Chart.js` | `EXTERNAL_WEB` | `RESOLVED_ONLINE` |
| `assets/vendor/VENDOR_MANIFEST.md` | `MARKDOWN_LINK` | `https://github.com/markedjs/marked` | `EXTERNAL_WEB` | `RESOLVED_ONLINE` |
| `data_sources.md` | `MARKDOWN_LINK` | `https://docs.openaq.org` | `EXTERNAL_WEB` | `RESOLVED_ONLINE` |
| `data_sources.md` | `MARKDOWN_LINK` | `https://open-meteo.com/en/docs/historical-weather-api` | `EXTERNAL_WEB` | `RESOLVED_ONLINE` |
| `documentation.html` | `HTML_LINK` | `about.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `documentation.html` | `HTML_LINK` | `documentation.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `documentation.html` | `HTML_LINK` | `documentation.html#execution` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `documentation.html` | `HTML_LINK` | `documentation.html#prerequisites` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `documentation.html` | `HTML_LINK` | `documentation.html#theory` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `documentation.html` | `HTML_LINK` | `explore.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `documentation.html` | `HTML_LINK` | `https://github.com/Code-Crew-Nexus/UrbanAirQualityIndex-Pollut...` | `GITHUB_REPOSITORY_FILE` | `RESOLVED_ONLINE` |
| `documentation.html` | `HTML_LINK` | `index.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `documentation.html` | `HTML_LINK` | `machine-learning.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `documentation.html` | `HTML_LINK` | `statistics.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `explore.html` | `HTML_LINK` | `about.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `explore.html` | `HTML_LINK` | `documentation.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `explore.html` | `HTML_LINK` | `documentation.html#exec-phase2` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `explore.html` | `HTML_LINK` | `documentation.html#execution` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `explore.html` | `HTML_LINK` | `documentation.html#prerequisites` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `explore.html` | `HTML_LINK` | `documentation.html#theory` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `explore.html` | `HTML_LINK` | `documentation.html#theory-schema` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `explore.html` | `HTML_LINK` | `explore.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `explore.html` | `HTML_LINK` | `https://github.com/Code-Crew-Nexus/UrbanAirQualityIndex-Pollut...` | `GITHUB_REPOSITORY_FILE` | `RESOLVED_ONLINE` |
| `explore.html` | `HTML_LINK` | `index.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `explore.html` | `HTML_LINK` | `machine-learning.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `explore.html` | `HTML_LINK` | `statistics.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `guide/execution_guide.md` | `MARKDOWN_LINK` | `../cpcb_aqi_methodology_verified.md` | `INTERNAL_MARKDOWN` | `VERIFIED_LOCAL` |
| `guide/execution_guide.md` | `MARKDOWN_LINK` | `../figures/03_cumulative_variance_comparison.png` | `INTERNAL_FIGURE` | `VERIFIED_LOCAL` |
| `guide/execution_guide.md` | `MARKDOWN_LINK` | `../figures/05_validation_prauc_comparison.png` | `INTERNAL_FIGURE` | `VERIFIED_LOCAL` |
| `guide/execution_guide.md` | `MARKDOWN_LINK` | `../figures/07_india_pca_pc1_pc2_by_cluster.png` | `INTERNAL_FIGURE` | `VERIFIED_LOCAL` |
| `guide/execution_guide.md` | `MARKDOWN_LINK` | `../figures/07_test_mae_comparison.png` | `INTERNAL_FIGURE` | `VERIFIED_LOCAL` |
| `guide/execution_guide.md` | `MARKDOWN_LINK` | `../figures/phase5b_10_test_prauc_comparison.png` | `INTERNAL_FIGURE` | `VERIFIED_LOCAL` |
| `guide/execution_guide.md` | `MARKDOWN_LINK` | `../figures/phase5b_20_overall_svm_comparison_summary.png` | `INTERNAL_FIGURE` | `VERIFIED_LOCAL` |
| `guide/execution_guide.md` | `MARKDOWN_LINK` | `../phase1_station_selection_decision.md` | `INTERNAL_MARKDOWN` | `VERIFIED_LOCAL` |
| `guide/execution_guide.md` | `MARKDOWN_LINK` | `../reports/phase3_statistical_analysis_summary.md` | `INTERNAL_MARKDOWN` | `VERIFIED_LOCAL` |
| `guide/prerequisites.md` | `MARKDOWN_LINK` | `../ENVIRONMENT.md` | `INTERNAL_MARKDOWN` | `VERIFIED_LOCAL` |
| `guide/prerequisites.md` | `MARKDOWN_LINK` | `../PACKAGE_REQUIREMENTS.md` | `INTERNAL_MARKDOWN` | `VERIFIED_LOCAL` |
| `guide/screenshots_and_samples.md` | `MARKDOWN_LINK` | `../figures/03_cumulative_variance_comparison.png` | `INTERNAL_FIGURE` | `VERIFIED_LOCAL` |
| `guide/screenshots_and_samples.md` | `MARKDOWN_LINK` | `../figures/05_validation_prauc_comparison.png` | `INTERNAL_FIGURE` | `VERIFIED_LOCAL` |
| `guide/screenshots_and_samples.md` | `MARKDOWN_LINK` | `../figures/07_india_pca_pc1_pc2_by_cluster.png` | `INTERNAL_FIGURE` | `VERIFIED_LOCAL` |
| `guide/screenshots_and_samples.md` | `MARKDOWN_LINK` | `../figures/07_test_mae_comparison.png` | `INTERNAL_FIGURE` | `VERIFIED_LOCAL` |
| `guide/screenshots_and_samples.md` | `MARKDOWN_LINK` | `../figures/phase5b_10_test_prauc_comparison.png` | `INTERNAL_FIGURE` | `VERIFIED_LOCAL` |
| `guide/screenshots_and_samples.md` | `MARKDOWN_LINK` | `../figures/phase5b_11_test_f1_comparison.png` | `INTERNAL_FIGURE` | `VERIFIED_LOCAL` |
| `guide/screenshots_and_samples.md` | `MARKDOWN_LINK` | `../figures/phase5b_20_overall_svm_comparison_summary.png` | `INTERNAL_FIGURE` | `VERIFIED_LOCAL` |
| `index.html` | `HTML_LINK` | `about.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `index.html` | `HTML_LINK` | `documentation.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `index.html` | `HTML_LINK` | `documentation.html#execution` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `index.html` | `HTML_LINK` | `documentation.html#prerequisites` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `index.html` | `HTML_LINK` | `documentation.html#theory` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `index.html` | `HTML_LINK` | `explore.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `index.html` | `HTML_LINK` | `https://github.com/Code-Crew-Nexus/UrbanAirQualityIndex-Pollut...` | `GITHUB_REPOSITORY_FILE` | `RESOLVED_ONLINE` |
| `index.html` | `HTML_LINK` | `index.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `index.html` | `HTML_LINK` | `machine-learning.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `index.html` | `HTML_LINK` | `statistics.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `machine-learning.html` | `HTML_LINK` | `about.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `machine-learning.html` | `HTML_LINK` | `documentation.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `machine-learning.html` | `HTML_LINK` | `documentation.html#exec-freeze` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `machine-learning.html` | `HTML_LINK` | `documentation.html#exec-phase5b` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `machine-learning.html` | `HTML_LINK` | `documentation.html#execution` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `machine-learning.html` | `HTML_LINK` | `documentation.html#prerequisites` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `machine-learning.html` | `HTML_LINK` | `documentation.html#theory` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `machine-learning.html` | `HTML_LINK` | `explore.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `machine-learning.html` | `HTML_LINK` | `https://github.com/Code-Crew-Nexus/UrbanAirQualityIndex-Pollut...` | `GITHUB_REPOSITORY_FILE` | `RESOLVED_ONLINE` |
| `machine-learning.html` | `HTML_LINK` | `index.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `machine-learning.html` | `HTML_LINK` | `machine-learning.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `machine-learning.html` | `HTML_LINK` | `statistics.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `reports/README.md` | `MARKDOWN_LINK` | `phase2_data_aqi_summary.md` | `INTERNAL_MARKDOWN` | `VERIFIED_LOCAL` |
| `reports/README.md` | `MARKDOWN_LINK` | `phase3_statistical_analysis_summary.md` | `INTERNAL_MARKDOWN` | `VERIFIED_LOCAL` |
| `reports/README.md` | `MARKDOWN_LINK` | `phase4_supervised_learning_summary.md` | `INTERNAL_MARKDOWN` | `VERIFIED_LOCAL` |
| `reports/README.md` | `MARKDOWN_LINK` | `phase5_pca_kmeans_summary.md` | `INTERNAL_MARKDOWN` | `VERIFIED_LOCAL` |
| `reports/README.md` | `MARKDOWN_LINK` | `phase5b_svm_summary.md` | `INTERNAL_MARKDOWN` | `VERIFIED_LOCAL` |
| `reports/phase5b_svm_summary.md` | `MARKDOWN_LINK` | `../../analysis/phase5B/tables/phase5B_final_report_metric_tabl...` | `GITHUB_REPOSITORY_FILE` | `RESOLVED_LOCAL_REPO` |
| `reports/phase5b_svm_summary.md` | `MARKDOWN_LINK` | `../../data/processed/UAQI_Master_Daily.csv` | `GITHUB_REPOSITORY_FILE` | `RESOLVED_LOCAL_REPO` |
| `statistics.html` | `HTML_LINK` | `about.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `statistics.html` | `HTML_LINK` | `documentation.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `statistics.html` | `HTML_LINK` | `documentation.html#exec-phase3` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `statistics.html` | `HTML_LINK` | `documentation.html#execution` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `statistics.html` | `HTML_LINK` | `documentation.html#prerequisites` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `statistics.html` | `HTML_LINK` | `documentation.html#theory` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `statistics.html` | `HTML_LINK` | `documentation.html#theory-core` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `statistics.html` | `HTML_LINK` | `explore.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `statistics.html` | `HTML_LINK` | `https://github.com/Code-Crew-Nexus/UrbanAirQualityIndex-Pollut...` | `GITHUB_REPOSITORY_FILE` | `RESOLVED_ONLINE` |
| `statistics.html` | `HTML_LINK` | `index.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `statistics.html` | `HTML_LINK` | `machine-learning.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |
| `statistics.html` | `HTML_LINK` | `statistics.html` | `INTERNAL_PAGE` | `VERIFIED_LOCAL` |

---

## 4. Path Safety & Zero-CDN Verification Protocol

1. **Local Filesystem Isolation:**
   - No `file:///` URLs exist in any website-facing HTML or generated documentation links.
   - No Windows absolute paths (`C:\`, `D:\`) exist in any public-facing Markdown or HTML file.
   - All repository-relative references pointing outside `docs/` (`../../data/...`, `../../analysis/...`) are dynamically transformed by `markdown-renderer.js` into canonical GitHub repository URLs (`https://github.com/Code-Crew-Nexus/UrbanAirQualityIndex-PollutantDriftAnalysis/blob/main/<path>`).

2. **Complete Offline Vendoring (Zero External CDN Dependency):**
   - `marked.min.js` (v15.0.7) vendored locally in `docs/assets/vendor/`
   - `katex.min.js`, `katex.min.css`, and KaTeX fonts vendored locally in `docs/assets/vendor/katex/`
   - `chart.umd.min.js` (v4.4.8) vendored locally in `docs/assets/vendor/`
   - All 6 HTML pages link strictly to local relative vendor paths (`assets/vendor/...`).

3. **Zero Broken Links Guarantee:**
   - Every local image and stylesheet requested by HTML and Markdown exists on disk and resolves with HTTP 200.
   - Every documentation chapter referenced in `documentation-manifest.js` exists in `docs/`.
