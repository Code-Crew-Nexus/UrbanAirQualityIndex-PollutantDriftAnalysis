# Contributing Guidelines

## Collaborative Workflow
- The `main` branch is locked for direct pushes after collaboration begins.
- Use explicit branches for features (e.g., `feature/pca-kmeans`, `feature/svm-classifier`, `feature/shiny-dashboard`, `docs/final-report`, `docs/presentation`, `fix/<issue>`).
- Merge code exclusively via Pull Requests (PRs).
- Run all relevant tests before submitting a PR.
- Clearly describe data or model impacts in the PR body.
- **NEVER** commit secrets (API keys, `.Renviron` files).
- **NEVER** modify frozen phase outputs silently without team consensus.

## Commit Convention
We follow standard semantic commit message prefixes:

- `feat:` (New features, models, or pipeline stages)
- `fix:` (Bug fixes in data processing or modeling scripts)
- `docs:` (Updates to markdown reports, summaries, or README)
- `test:` (Adding or fixing tests in `testthat`)
- `refactor:` (Code structural changes that do not affect model output)
- `chore:` (Routine repository maintenance, gitignore updates)
- `data:` (Updates to frozen datasets or data mappings)

**Examples:**
- `feat: add PCA pollution regime analysis`
- `fix: correct station metadata filter`
- `docs: summarize supervised learning results`
- `test: add PCA preprocessing integrity checks`
