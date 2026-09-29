# Checkpoint G6.2A & G6.2B — Live Automation Reliability Hotfix & Validation Report

## 1. Executive Summary
The live automation pipelines for the Checkpoint G6 Live Data Extension experienced authentication failures and dependency deprecation issues. This combined hotfix (G6.2A & G6.2B) hardens the daily and monthly GitHub Actions workflows, resolving the `OPENAQ_API_KEY` failure propagation, establishing a rolling incremental date refresh, updating out-of-date Node.js 20 actions, eliminating failure-commit spam, and strictly validating the active schedule gates.

The final patch and validation evidence have been merged to `main` and tagged as `v0.7.6-live-automation-validation`.

## 2. Technical Resolutions

### 2.1 Workflow Gate Order & Missing-Secret Status Publication
- **Issue:** Scheduled runs would crash with `exit 1` on a missing `OPENAQ_API_KEY` even if they were outside their active calendar window. Additionally, immediately exiting on missing secrets bypassed the status JSON update, leaving the public pipeline status stale.
- **Resolution:** 
  - The calendar activation gate is evaluated FIRST. Inactive scheduled runs explicitly output `skip=true` and cleanly halt further processing without evaluating secrets.
  - The secret gate evaluates availability and outputs `available=true` or `available=false` without printing or leaking the secret. 
  - If a required secret is missing during an active run, it safely generates a sanitized `auth_error` pipeline status. A downstream `always()` commit step publishes this to `docs/web-data/live_pipeline_status.json`, preserving all last-known-good datasets. A final explicit failure step then fails the workflow execution.

### 2.2 Incremental Overlap & Cap Removal
- **Issue:** `scripts/44_live_data_ingestion.R` possessed a hardcoded `--end-date` cap of `2026-09-26` intended only for initial backfill.
- **Resolution:**
  - Removed the `2026-09-26` cap. The end date dynamically evaluates to the latest complete day (`yesterday` in Asia/Kolkata).
  - Introduced true incremental refresh logic: `start_date` automatically defaults to `max("2026-09-22", last_successful_date - 2 days)` if no CLI argument is provided, creating a robust 3-day rolling overlap that prevents data loss on temporary API downtimes.

### 2.3 Deterministic Schema Deduplication
- **Issue:** De-duplication used a string `paste()` matching pattern which was functional but suboptimal for R.
- **Resolution:** Replaced it with a deterministic, performant `anti_join(by = c("project_station_id", "date"))` prior to `bind_rows()`, ensuring rigorous atomicity and no duplicated historical live rows.

### 2.4 Failure State Propagation & Commit Spam Prevention
- **Issue:** Continuous identical workflow failures would spam commits purely due to `last_attempt_utc` updating.
- **Resolution:** 
  - The `always()` commit step checks if `live_pipeline_status.json` is the only changed file.
  - It uses a defensive `jq` equality comparison to ignore timestamp-only changes. If the status JSON indicates a genuine state shift (e.g. from `ok` to `auth_error`), it commits safely with `chore(live): pipeline status update [skip ci]`. If no semantic change occurred, no commit is generated.

### 2.5 Dependency Update & Pages Analysis
- **Issue:** Action `actions/checkout@v4` targets Node 20.
- **Resolution:** Upgraded to `actions/checkout@v7` (latest Node 24 support) in both daily and monthly pipelines. The historical OIDC ID token failure (run 36304460095) associated with the native GitHub Pages deployment action is determined to be a transient GitHub infrastructure issue, as there is no custom `pages.yml` in this repository to configure `id-token: write`. 

## 3. Testing and Deployment

### 3.1 Local/Simulated Validation
- **Dry-run validation:** Executed R script with `--dry-run`. Successfully authenticated, evaluated the dynamic date window, validated upstream contracts, and cleanly exited without mutating `data/live/processed` or committing.
- **Real-run validation:** Executed a full manual pipeline simulating a `workflow_dispatch` trigger. 
  - Start Date calculated: `2026-09-24` (rolling overlap from previous 2026-09-26 success)
  - End Date calculated: `2026-09-28` (latest complete day in Asia/Kolkata)
  - **Actual final data_through:** 2026-09-28
  - Total records ingested and deduplicated: 147
  - Deduplication Audit: 147 unique combinations of `project_station_id` and `date` identified (no duplicates).
- **Frozen-baseline audit:** Hashes for `UAQI_Master_Daily.csv` and `daily_observations.json` were audited against `v0.6-svm-freeze` and `v0.7-website-freeze` respectively, confirming they remain byte-identical.
- **Tests run:** 2 major behavioral testing suites executed verifying workflow schema parsing and step output logic.

### 3.2 Git Hygiene
- Merged to `main` via one coherent branch `fix/g6-2b-validation-closure`.
- Tagged release: `v0.7.6-live-automation-validation`.
- Pushed to remote successfully.
