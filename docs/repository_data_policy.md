# Repository Data Tracking Policy

## 1. Raw Data (`data/raw/`)
**Policy: LOCAL ONLY**
All OpenAQ API downloads, Open-Meteo json files, and Kaggle reference files are excluded from Git. These are heavy and contain API keys in headers sometimes.

## 2. Interim Data (`data/interim/`)
**Policy: LOCAL / REGENERABLE**
Normalized hourly arrays and intermediate parsing outputs are ignored. These are directly regenerable from raw data via Phase 1 and Phase 2 scripts.

## 3. Final Processed Data (`data/processed/`)
**Policy: TRACK (if size is reasonable)**
The compact daily datasets representing the final AQI aggregations are tracked. They serve as the canonical foundation for all statistical analysis.

## 4. Metadata and Provenance (`data/metadata/`)
**Policy: TRACK**
Small station-mapping dictionaries and JSON configuration outputs are tracked.

## 5. Modeling Input/Output (`data/modeling/`)
**Policy: REGENERATE_NOT_TRACK**
Bulk matrices (e.g. 147-row cross-joins, dummy-encoded design matrices) are largely excluded unless they form the exact compact final summary table.

## 6. Review ZIP Archives
**Policy: NEVER TRACK**
Development milestones are logged as zip files locally but must never enter the repository tree.

## 7. Secrets
**Policy: NEVER TRACK**
`.Renviron`, private keys, and credential tokens are strictly ignored.
