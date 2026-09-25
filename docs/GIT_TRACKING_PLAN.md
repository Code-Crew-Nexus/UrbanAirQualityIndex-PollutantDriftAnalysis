# Repository File Manifest / Tracking Plan

## TRACK
The following core directories and files are actively tracked in Git:
- `R/`
- `scripts/`
- `config/`
- `tests/`
- `docs/reports/`
- `docs/figures/`
- `docs/PROJECT_CHECKPOINTS.md`
- `docs/TEAM.md`
- `docs/ENVIRONMENT.md`
- `docs/repository_data_policy.md`
- `docs/GIT_TRACKING_PLAN.md`
- `README.md`
- `CONTRIBUTING.md`
- `.gitignore`
- `.gitattributes`
- `.Renviron.example`
- `.github/`

## IGNORE
The following files and paths are strictly excluded to protect secrets, raw data, and internal history:
- `.Renviron` and any credential files
- `logs/`
- `scratch/`
- `data/raw/`
- `data/interim/`
- `docs/internal_phase_history/`
- `review_archive_*.zip` and all zip files
- `tmp/`, `temp/`, `cache/`
- `.Rhistory`, `.RData`, `.Ruserdata`, `.Rproj.user/`

## REVIEW BEFORE TRACKING
The following outputs require size or utility review before committing:
- Processed CSVs in `data/processed/` (tracked if < 10 MB)
- Model RDS files in `models/` (tracked if < 10 MB and finalized)
- Bulk analysis figures in `analysis/` (generally ignored; only curate top 10 into `docs/figures/`)
- Temporary modeling inputs in `data/modeling/` (generally ignored, generated on the fly)
