# Setup & Quickstart Guide

**Project:** `UrbanAirQualityIndex-PollutantDriftAnalysis`  
**Organization:** `Code-Crew-Nexus`  
**Phase:** 6A — Static Project Website Foundation  

---

## 1. Quick Start Pathways

This project is architected with complete functional decoupling. Evaluators and students can explore the repository in one of two standardized modes:

```
[Mode A: Frozen Project Review]  --->  Inspect Processed Data + Run Website Preview + Run Test Suite
                                      (Zero API keys, zero downloads, immediate offline review)

[Mode B: Full Analytical Repro]  --->  Configure .Renviron + Harvest OpenAQ/Open-Meteo + Recompute Models
                                      (Requires valid OpenAQ API key and full execution sequence)
```

---

## 2. Mode A — Frozen Project Review (Recommended)

In this mode, you leverage the project's **permanently frozen scientific artifacts** (`v0.6-svm-freeze`) without making external API calls or retraining machine learning models.

### Step 1: Clone Repository & Switch to Feature Branch
```powershell
git clone https://github.com/Code-Crew-Nexus/UrbanAirQualityIndex-PollutantDriftAnalysis.git
cd UrbanAirQualityIndex-PollutantDriftAnalysis
git switch feature/project-website
```

### Step 2: Inspect Canonical Datasets & Artifacts
The canonical processed datasets are precomputed and version-controlled:
- `data/processed/UAQI_Master_Daily.csv` (11,970 station-days, 21 physical stations)
- `data/processed/UAQI_Hyderabad_Daily.csv` (3,990 station-days, 7 Hyderabad stations)
- `data/processed/UAQI_India_Daily.csv` (8,550 station-days, 15 India representative stations)
- `config/selected_stations.csv` (21 station coordinates, locations, and panel roles)
- `docs/reports/` (Canonical Phase 2 through Phase 5B milestone summaries)

### Step 3: Run the Local Website Preview
The website presentation layer is completely static (HTML5, CSS3, Vanilla JS). It requires no Node.js runtime, no npm build steps, and no R Shiny server.

Start the standard Python HTTP server from the **project root**:
```powershell
py -m http.server 8000 --directory docs
```

Open your browser and navigate to:
```
http://localhost:8000/
```

> [!WARNING]
> **Do not open `index.html` directly via the `file://` protocol.**  
> Modern browser security policies (CORS) restrict JavaScript `fetch()` calls from reading local Markdown files over `file://`. Always preview through a local HTTP server such as `py -m http.server 8000 --directory docs`.

### Step 4: Execute the Project Test Suite
Verify that all 50+ Phase 6A structural checks, mathematical rendering rules, and baseline invariants pass:
```powershell
Rscript -e "testthat::test_dir('tests/testthat')"
```

---

## 3. Mode B — Full Data & Analytical Reproduction

If you wish to re-harvest raw sensor telemetry from OpenAQ v3 and re-execute the entire data engineering and modeling pipeline from scratch, follow these instructions:

### Step 1: Configure Environment Variables
Copy `.Renviron.example` to `.Renviron`:
```powershell
Copy-Item .Renviron.example .Renviron
```
Edit `.Renviron` and insert your private OpenAQ API key:
```ini
OPENAQ_API_KEY=your_actual_api_key_here
```
*(Never commit `.Renviron` or disclose API keys in public repositories).*

### Step 2: Verify Project Scaffolding
```r
source("R/00_setup.R")
```

### Step 3: Sequential Pipeline Execution
Run the numbered scripts in exact chronological order:

1. **Station Audit & Pilot Testing:**
   - `scripts/01_run_station_audit.R`
   - `scripts/02_run_sample_ingestion.R`
2. **Canonical Data Processing & Normalization:**
   - `scripts/03_build_datasets.R`
   - `scripts/09_phase2E_generate_final_aqi.R`
3. **Exploratory Analysis & Pollutant Drift:**
   - `scripts/10_phase3A_exploratory_analysis.R`
   - `scripts/11_phase3B_pollutant_drift.R`
   - `scripts/12_phase3C_statistical_inference.R`
4. **Supervised Modeling (MLR & Logistic Regression):**
   - `scripts/13_phase4A_prediction_design.R`
   - `scripts/14a_phase4B_train_validate_select.R`
   - `scripts/15a_phase4C_train_validate_select.R`
5. **Unsupervised Learning (PCA & K-Means):**
   - `scripts/18a_phase5A_pca.R`
   - `scripts/18b_phase5A_kmeans.R`
6. **Nonlinear Margin Classification (RBF SVM):**
   - `scripts/20a_phase5B_prepare_design.R`
   - `scripts/20b_phase5B_train_validate_select.R`
   - `scripts/20c_phase5B_test_holdout_evaluation.R`
7. **Web Asset Export:**
   - `scripts/30_export_web_assets.R`
