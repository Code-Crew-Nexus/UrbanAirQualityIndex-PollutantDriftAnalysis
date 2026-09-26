# Authoritative Package Requirements

**Project:** `UrbanAirQualityIndex-PollutantDriftAnalysis`  
**Milestone:** `v0.6-svm-freeze`  
**Environment Baseline:** R `4.6.1` (Windows 11 x64, PowerShell 7.6.6)  
**Generation Method:** Programmatically extracted from repository codebase (`R/`, `scripts/`, `tests/`)  

---

## 1. Package Classification Matrix

| Package Name | Codebase Invocations | Classification | Primary Project Function |
| :--- | :---: | :--- | :--- |
| **`readr`** | 54 | **Core Frozen-Review** | Reading and writing CSV datasets and metric tables |
| **`dplyr`** | 59 | **Core Frozen-Review** | Data manipulation, transformation, filtering, and summary statistics |
| **`testthat`** | 32 | **Core Frozen-Review** | Unit testing, integrity assertions, and audit suites |
| **`jsonlite`** | 31 | **Core Frozen-Review** | Parsing and serializing web-data JSON artifacts and API payloads |
| **`yaml`** | 24 | **Core Frozen-Review** | Loading YAML configuration and model specification files |
| **`digest`** | 14 | **Core Frozen-Review** | Generating and validating SHA-256 cryptographic checksums |
| **`tidyr`** | 10 | **Full Reproduction** | Reshaping tables, pivot wider/longer operations |
| **`tibble`** | 7 | **Full Reproduction** | Structured tabular data frame operations |
| **`broom`** | 6 | **Full Reproduction** | Tidy summarization of regression and inference objects |
| **`scales`** | 5 | **Full Reproduction** | Plot axis transformations and percentage formatting |
| **`purrr`** | 3 | **Full Reproduction** | Functional programming, map iteration over stations |
| **`zoo`** | 3 | **Full Reproduction** | Rolling window calculations (30-day and 90-day drift metrics) |
| **`cluster`** | 2 | **Full Reproduction** | Silhouette coefficient computation for K-Means $K$ selection |
| **`e1071`** | 2 | **Full Reproduction** | Support Vector Machine (RBF kernel) training and decision scores |
| **`car`** | 1 | **Full Reproduction** | Variance Inflation Factor (VIF) collinearity diagnostics in MLR |
| **`ggplot2`** | 12 | **Full Reproduction** | Diagnostic and exploratory publication-quality figure generation |
| **`httr2`** | 50 | **API Re-Acquisition** | HTTP request pipelines, rate-limiting, and OpenAQ / Open-Meteo queries |
| **`stringr`** | 2 | **API Re-Acquisition** | String manipulation in raw API response processing |

---

## 2. Tiered Installation Instructions

### Tier 1: Core Frozen-Review (Mode A - Default)
For reviewers, evaluators, and faculty inspecting frozen modeling artifacts, running test suites, or previewing the static website presentation layer, only the **Core Frozen-Review** packages are required:

```r
install.packages(c("readr", "dplyr", "testthat", "jsonlite", "yaml", "digest"))
```

### Tier 2: Full Reproduction (Mode B)
To re-run the entire statistical learning pipeline from local interim data through Phase 5B:

```r
install.packages(c(
  "readr", "dplyr", "testthat", "jsonlite", "yaml", "digest",
  "tidyr", "tibble", "broom", "scales", "purrr", "zoo",
  "cluster", "e1071", "car", "ggplot2"
))
```

### Tier 3: Raw Acquisition (Mode C - Full Pipeline with Live API Re-Acquisition)
To execute fresh data harvesting from OpenAQ and Open-Meteo APIs (requires network access and appropriate API keys):

```r
install.packages(c(
  "readr", "dplyr", "testthat", "jsonlite", "yaml", "digest",
  "tidyr", "tibble", "broom", "scales", "purrr", "zoo",
  "cluster", "e1071", "car", "ggplot2",
  "httr2", "stringr"
))
```

---

## 3. Strict Dependency Policy

1. **No Unused Dependencies:** Packages are documented strictly based on demonstrated static code analysis of repository scripts. Packages are never added based on speculation.
2. **Deterministic Runtimes:** All scientific computation was conducted on R `4.6.1`.
3. **Zero Frontend Dependencies:** The static web layer (`docs/`) requires no R packages and no Node/npm packages for rendering.
