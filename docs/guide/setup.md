# Setup & Execution Guide

**Project:** `UrbanAirQualityIndex-PollutantDriftAnalysis`  
**Organization:** `Code-Crew-Nexus`  
**Milestone:** `v0.6-svm-freeze`  
**Presentation Layer:** Phase 6A Static Project Website Foundation  

---

## 1. Quick Start Pathways

This project is architected with complete functional decoupling between the frozen scientific computing engine (R) and the presentation layer (Static HTML/JS). Evaluators and students can explore the repository in one of three standardized modes:

```
[Mode A: Frozen Project Review]  ───> Inspect Processed Data + Run Website Preview + Run Test Suite
(Recommended)                         (Zero API keys, zero network traffic, immediate offline review)

[Mode B: Pipeline Reproduction]  ───> Recompute MLR / Logistic / PCA / K-Means / SVM from Processed Data
                                      (Verifies deterministic mathematical reproduction from local CSVs)

[Mode C: Full API Re-Acquisition] ───> Configure .Renviron + Harvest OpenAQ / Open-Meteo + Rebuild Data
                                      (Extremely heavy; multi-hour rate-limited external network harvest)
```

---

## 2. Mode A — Frozen Project Review (Recommended for Viva / Evaluation)

In this mode, you leverage the project's **permanently frozen scientific artifacts** (`v0.6-svm-freeze`) without making external API calls or retraining machine learning models.

### Step 1: Clone Repository & Switch to Feature Branch
```powershell
git clone https://github.com/Code-Crew-Nexus/UrbanAirQualityIndex-PollutantDriftAnalysis.git
cd UrbanAirQualityIndex-PollutantDriftAnalysis
git switch feature/project-website
```

### Step 2: Inspect Canonical Datasets & Artifacts
The canonical processed datasets are precomputed and version-controlled:
- `data/processed/UAQI_Master_Daily.csv` (11,970 station-days across 21 physical stations)
- `data/processed/UAQI_Hyderabad_Daily.csv` (3,990 station-days, 7 Hyderabad stations)
- `data/processed/UAQI_India_Daily.csv` (8,550 station-days, 15 India representative stations)
- `config/selected_stations.csv` (21 station coordinates, locations, and panel roles)
- `docs/reports/` (Canonical Phase 2 through Phase 5B milestone summaries)

### Step 3: Run the Local Website Preview
The website presentation layer is completely static (HTML5, CSS3, Vanilla JS). It requires no Node.js runtime, no npm build steps, and no R Shiny server.

Start the local web server from the **project root**:
```powershell
py scripts/serve_website_local.py
```
*(Alternatively using standard Python or PowerShell)*:
```powershell
py -m http.server 8000 --directory docs
# Or: .\scripts\start_website_preview.ps1
```

Open your browser and navigate to:
```
http://localhost:8000/
```

> [!WARNING]
> **Do not open HTML files directly via the `file://` protocol.**  
> Modern browser security policies (CORS) restrict JavaScript `fetch()` calls from reading local JSON and Markdown files over `file://`. Always preview through a local HTTP server such as `py scripts/serve_website_local.py` or `py -m http.server 8000 --directory docs`.

### Step 4: Execute the Project Test Suite
Verify that all Phase 6A structural checks, mathematical rendering rules, and baseline invariants pass:
```powershell
Rscript -e "testthat::test_file('tests/testthat/test_phase6a_website.R')"
```

---

## 3. Mode B — Pipeline Reproduction from Processed Data

To reproduce model training, evaluation, and unsupervised clustering from the precomputed master dataset `data/processed/UAQI_Master_Daily.csv`:

### Step 1: Install Modeling Dependencies
```r
install.packages(c(
  "readr", "dplyr", "testthat", "jsonlite", "yaml", "digest",
  "tidyr", "tibble", "broom", "scales", "purrr", "zoo",
  "cluster", "e1071", "car", "ggplot2"
))
```

### Step 2: Execute Phase Pipelines in Sequence
Execute the analytical phases in chronological order:

1. **Phase 3: Exploratory Analysis, Pollutant Drift & Statistical Inference**
   ```powershell
   Rscript scripts/10_phase3A_exploratory_analysis.R
   Rscript scripts/11_phase3B_pollutant_drift.R
   Rscript scripts/12_phase3C_statistical_inference.R
   ```
2. **Phase 4: Supervised Learning (MLR & Logistic Regression)**
   ```powershell
   Rscript scripts/13_phase4A_prediction_design.R
   Rscript scripts/14a_phase4B_train_validate_select.R
   Rscript scripts/14b_phase4B_locked_test_holdout.R
   Rscript scripts/14c_phase4B_figures.R
   Rscript scripts/15a_phase4C_train_validate_select.R
   Rscript scripts/15b_phase4C_locked_test_holdout.R
   Rscript scripts/15c_phase4C_figures.R
   ```
3. **Phase 5A: Unsupervised Learning (PCA & K-Means Regimes)**
   ```powershell
   Rscript scripts/18a_phase5A_pca.R
   Rscript scripts/18b_phase5A_kmeans.R
   Rscript scripts/18c_phase5A_profiles_figures.R
   ```
4. **Phase 5B: Nonlinear Margin Classification (RBF SVM)**
   ```powershell
   Rscript scripts/20a_phase5B_prepare_design.R
   Rscript scripts/20b_phase5B_train_validate_select.R
   Rscript scripts/20c_phase5B_test_holdout_evaluation.R
   Rscript scripts/20d_phase5B_figures.R
   Rscript scripts/21b_phase5B2_archive_audit.R
   ```
5. **Phase 6A: Web Asset Export**
   ```powershell
   Rscript scripts/30_export_web_assets.R
   ```

---

## 4. Mode C — Full API Re-Acquisition (Raw Harvest Warning)

> [!CAUTION]
> Full re-acquisition queries 19 months of hourly air quality records across 21 stations from OpenAQ v3 alongside hourly weather from Open-Meteo. Due to API rate limits, this process takes several hours and requires a registered OpenAQ API key. It is strictly optional and not required for evaluating project findings.

### Step 1: Configure Environment Variables
Copy `.Renviron.example` to `.Renviron`:
```powershell
Copy-Item .Renviron.example .Renviron
```
Edit `.Renviron` and insert your private OpenAQ API key:
```ini
OPENAQ_API_KEY=your_actual_api_key_here
```

### Step 2: Install API Packages
```r
install.packages(c("httr2", "stringr"))
```

### Step 3: Run Harvesting & Normalization Pipeline
```powershell
# 1. Station audit and selection
Rscript scripts/01_run_station_audit.R
Rscript scripts/01a_build_metadata_shortlist.R
Rscript scripts/01c_build_station_selection_summary.R

# 2. Ingestion and harmonization
Rscript scripts/04b_phase2B_full_acquisition.R
Rscript scripts/04c_phase2B_weather.R
Rscript scripts/04d_phase2B_normalize_and_audit.R
Rscript scripts/05a_phase2C_preAQI_engineering.R
Rscript scripts/09_phase2E_generate_final_aqi.R
```
Proceed with Mode B steps above to retrain models on freshly harvested data.
