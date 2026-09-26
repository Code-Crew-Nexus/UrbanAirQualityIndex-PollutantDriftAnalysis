# System Prerequisites & Environment Specifications

**Project:** `UrbanAirQualityIndex-PollutantDriftAnalysis`  
**Course:** Statistics for Machine Learning (SML) — Project Based Learning (PBL)  
**Organization:** `Code-Crew-Nexus`  
**Reference Document:** [`docs/ENVIRONMENT.md`](../ENVIRONMENT.md)

---

## 1. Operating Environment & Runtime Foundations

This project is built and audited on an official, verified scientific computational environment.

| Component | Baseline Specification | Notes |
| :--- | :--- | :--- |
| **Operating System** | Windows 11 x64 (build 26200+) | Tested with native PowerShell 7 / Windows Terminal. Compatible with Linux / macOS. |
| **Statistical Engine (R)** | **R version 4.6.1** (2026-06-24 ucrt) | Platform: `x86_64-w64-mingw32/x64`. LAPACK version `3.12.1`. |
| **Interactive IDE** | RStudio Desktop (optional / recommended) | Recommended for inspecting `.Rproj` and visualization output. |
| **Version Control** | Git 2.40+ | Required for branch switching and tag inspection. |
| **Preview Server (Python)** | Python 3.9+ (`py -m http.server`) | Lightweight standard library HTTP server for static website preview. |
| **Web Browser** | Modern standards-compliant browser | Chrome 120+, Edge 120+, Firefox 120+, Safari 17+ with MathML and ES6 support. |

---

## 2. Required R Packages

All statistical computing, feature engineering, and model training are implemented natively in R. Dependencies are categorized by their role in the project lifecycle:

### A. Production & Data Engineering Packages
- **`yaml`**: Reads pipeline configurations (`config/project_config.yml`, `config/final_aqi_input_policy.yml`).
- **`readr`**: High-performance, reproducible CSV parsing and strict typed column ingestion.
- **`jsonlite`**: Generates and parses serialized metadata assets (`docs/web-data/*.json`).
- **`httr2`**: Handles authenticated REST requests to OpenAQ v3 and Open-Meteo APIs (used in Phase 2 ingestion).
- **`digest`**: Cryptographic SHA-256 hash auditing for data immutability and provenance tracking.
- **`dplyr` & `tidyr`**: Data manipulation, aggregation, and panel reshaping.
- **`stringr` & `purrr`**: String sanitization and functional iterations across stations.
- **`zoo`**: Rolling window calculations (e.g., trailing 8-hour ozone evaluation).

### B. Statistical Modeling & Unsupervised Learning Packages
- **`broom`**: Tidy model summaries for Multiple Linear Regression and Logistic Regression coefficients.
- **`car`**: Variance Inflation Factor (VIF) collinearity diagnostics.
- **`cluster`**: Silhouette width computation and PAM clustering validation for K-Means.
- **`e1071`**: Support Vector Machine (SVM) implementation with libsvm backend.
- **`ggplot2`**: Diagnostic residual plots, PR curves, and PCA projection figures.

### C. Testing & Verification Packages
- **`testthat`**: Automated unit testing and structural verification framework (`tests/testthat/`).

To install all required packages in an interactive R session:
```r
install.packages(c(
  "yaml", "readr", "jsonlite", "httr2", "digest",
  "dplyr", "tidyr", "stringr", "purrr", "zoo",
  "broom", "car", "cluster", "e1071", "ggplot2",
  "testthat"
))
```

---

## 3. Execution Modes & API Credential Policies

The repository supports two distinct operational modes:

### Mode A: Frozen Project Review (Recommended for Viva / Evaluation)
- **API Key Required:** **NO**.
- **Internet Access Required:** **NO** (all vendor libraries and datasets are vendored locally).
- **Data Ingestion Required:** **NO** (consumes canonical processed datasets in `data/processed/` and precomputed tables in `analysis/`).
- **Use Case:** Faculty evaluation, viva demonstration, static website browsing, test suite execution, and model performance verification.

### Mode B: Full Historical Re-Ingestion (Raw Harvest)
- **API Key Required:** **YES** (`OPENAQ_API_KEY`).
- **Configuration:** Copy `.Renviron.example` to `.Renviron` and supply a valid OpenAQ API token.
- **Security Rule:** Never commit `.Renviron` or expose private API keys in Git history.
- **Note on Open-Meteo:** Open-Meteo historical weather queries operate without API keys for non-commercial academic research.
