# System Prerequisites & Environment Specifications

**Project:** `UrbanAirQualityIndex-PollutantDriftAnalysis`  
**Course:** Statistics for Machine Learning — Project Based Learning  
**Organization:** `Code-Crew-Nexus`  
**Reference Document:** [`docs/ENVIRONMENT.md`](../ENVIRONMENT.md), [`docs/PACKAGE_REQUIREMENTS.md`](../PACKAGE_REQUIREMENTS.md)

---

## 1. Operating Environment Specifications

To ensure strict scientific reproducibility, the repository distinguishes between the **authoritative tested development environment** and **general operational requirements**.

### A. Tested Development Environment (Authoritative)
The computational pipeline, frozen RDS model artifacts, and test suites were executed and verified on the following hardware/software configuration:
- **Operating System:** Microsoft Windows 11 Home / Pro (x64 architecture).
- **Primary Shell:** PowerShell `7.6.6` (also verified in Windows PowerShell `5.1`).
- **Statistical Engine:** **R version 4.6.1** (`2026-06-24 ucrt`, Platform: `x86_64-w64-mingw32/x64`).
- **C/C++ Toolchain:** Rtools44 (required for compiling native package extensions if building from source).
- **Linear Algebra Acceleration:** Standard BLAS / LAPACK `3.12.1`.

### B. General Recommendations & Cross-Platform Notes
- **POSIX Shell / Linux / macOS:** The R scripts and static website architecture adhere to standard portable paths (forward slashes `/`). However, formal continuous integration testing was completed specifically on Windows 11; cross-platform users should run R test suites to verify local path and environment compatibility.
- **Local HTTP Preview Server:** Python standard library `http.server` (`python -m http.server 8000 --directory docs`) or any lightweight static file server (e.g. Node `http-server`, Caddy, Nginx).
- **Web Browser:** Any modern web browser supporting ECMAScript 6 (ES6 Modules) and MathML / SVG rendering (Google Chrome, Microsoft Edge, Mozilla Firefox, Apple Safari).

---

## 2. Required R Packages

Dependencies are derived strictly from static code analysis of the repository codebase (`R/`, `scripts/`, `tests/`). For comprehensive details and counts, refer to [`docs/PACKAGE_REQUIREMENTS.md`](../PACKAGE_REQUIREMENTS.md).

### A. Core Frozen-Review Packages
Required for running unit tests, inspecting frozen CSV tables, verifying JSON metadata, and checking cryptographic SHA-256 signatures:
```r
install.packages(c("readr", "dplyr", "testthat", "jsonlite", "yaml", "digest"))
```

### B. Full Modeling & Reproduction Packages
Required if re-executing statistical regressions, PCA, K-Means clustering, SVM training, and figure generation:
```r
install.packages(c(
  "readr", "dplyr", "testthat", "jsonlite", "yaml", "digest",
  "tidyr", "tibble", "broom", "scales", "purrr", "zoo",
  "cluster", "e1071", "car", "ggplot2"
))
```

### C. Live API Data Harvesting Packages
Required only for re-querying external OpenAQ v3 and Open-Meteo weather APIs from scratch:
```r
install.packages(c("httr2", "stringr"))
```

---

## 3. Execution Modes & Credential Requirements

The project enforces strict separation between evaluation review and raw data acquisition:

### Mode A: Frozen Project Review (Recommended for Viva / Evaluation)
- **API Key Required:** **NO** (Zero external network requests).
- **Data Ingestion Required:** **NO** (Consumes frozen Level-1 datasets in `data/processed/` and precomputed tables in `analysis/`).
- **Use Case:** Faculty grading, viva presentation, offline website navigation, test execution, and model benchmark verification.

### Mode B: Full Pipeline Reproduction (Local Cached Data)
- **API Key Required:** **NO** (Executes feature engineering, model fitting, and export starting from local interim data).
- **Use Case:** Validating algorithm implementations, testing hyperparameter grids, and verifying metric tables.

### Mode C: Full API Re-Acquisition (Raw Harvest)
- **API Key Required:** **YES** (`OPENAQ_API_KEY`).
- **Configuration:** Copy `.Renviron.example` to `.Renviron` and configure a private OpenAQ API token.
- **Security Invariant:** Never commit `.Renviron` or expose private tokens to version control.
