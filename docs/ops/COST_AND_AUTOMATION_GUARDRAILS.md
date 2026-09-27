# Cost and Automation Guardrails for Live Data Extension

**Project:** Urban Air Quality Index & Pollutant Drift Analysis  
**Repository:** `Code-Crew-Nexus/UrbanAirQualityIndex-PollutantDriftAnalysis`  
**Governing Principle:** Zero-Paid-Usage & Operational Cost Protection  

---

## 1. Zero-Paid-Usage Policy Overview

This repository is hosted as a **public academic research repository** on GitHub. Under GitHub's standard product terms, public repositories receive free access to standard GitHub-hosted Actions runners (`ubuntu-latest`) with no billed runner minutes.

To guarantee that this project never incurs accidental infrastructure or API billing charges, the following hard architectural rules are strictly enforced:

1. **Standard GitHub Runners Only:**
   - All workflow jobs MUST use `runs-on: ubuntu-latest`.
   - Never use larger GitHub-hosted runners (e.g., `ubuntu-latest-4-cores`, `windows-latest-8-cores`, or GPU runners) which require paid plan allocations.
2. **No Paid Marketplace Actions:**
   - Workflows must only use official, verified GitHub Actions (`actions/checkout@v4`, `actions/setup-python@v5`, `r-lib/actions/setup-r@v2`) and open-source standard utilities.
3. **No Cloud Database or Schedulers:**
   - No external paid databases (AWS RDS, Google Cloud SQL, Supabase Pro), serverless functions, or commercial cron scheduling services.
4. **No Persistent Workflow Artifacts or Bloat:**
   - Do not upload transient hourly sensor JSON responses to GitHub Actions artifacts.
   - Raw data files are processed entirely in-memory or on runner scratch storage and discarded after daily aggregation.
   - Live extension commits include only compact, deduplicated canonical CSV/JSON datasets.
5. **No Git LFS for Generated Live Data:**
   - Processed live observations are stored in standard text-based CSV and compressed JSON. No Git Large File Storage (LFS) bandwidth is consumed.
6. **Execution Timeouts:**
   - All automated workflow jobs enforce a strict hard timeout of `timeout-minutes: 20` to prevent hanging processes from consuming runner quotas.
7. **Concurrency Control:**
   - Concurrency groups (`concurrency: group: live-data-refresh, cancel-in-progress: false`) ensure that dataset refreshes never execute concurrently, eliminating race conditions and duplicate API calls.

---

## 2. API Rate Constraints & Usage Envelopes

### OpenAQ API (v3)
- **Authentication:** Authenticated via standard general-use API Key passed through the `X-API-Key` HTTP header.
- **Rate Limit:** OpenAQ free tier provides an allowance of 60 requests per minute with rolling rate-limit windows.
- **Request Envelope:**
  - 21 fixed physical monitoring stations across India (7 Hyderabad, 15 National, 1 overlap).
  - 3 canonical verified-subset pollutants ($\text{PM}_{2.5}$, $\text{PM}_{10}$, $\text{O}_3$).
  - With sensor-level hourly chunk requests over a 3-day rolling window, each scheduled refresh requires at most **63 API requests**.
  - Rate limiting logic pauses between requests and honors HTTP 429 `Retry-After` headers.
- **Defensive Safeguard:** The ingestion script enforces a hard cap of **150 total API requests per run** to abort early if an unexpected pagination loop occurs.

### Open-Meteo Historical Weather API
- **Authentication:** Free tier, non-commercial open scientific access (requires no API key).
- **Rate Limit:** Up to 10,000 daily calls; our workflow uses **21 requests per run** (1 request per station coordinate for the 3-day rolling window).
- **Request Envelope:** ~21 requests per run, executed with 0.5-second pacing.

---

## 3. Scheduled Refresh Frequencies

| Schedule Period | Workflow File | Cron Expression | Frequency | Est. Monthly Runs | Purpose |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **Temporary Daily** (Through 2026-10-31) | `.github/workflows/live-data-daily.yml` | `17 2 * * *` (02:17 UTC) | Once per day | ~34 runs total | Live demonstration period for course presentation. Automatically terminates at cutoff date. |
| **Long-Term Monthly** (From 2026-11-01) | `.github/workflows/live-data-monthly.yml` | `47 2 1 * *` (02:47 UTC on 1st) | Once per month | 1 run / month | Ingests the previous complete calendar month with minimal automation overhead. |

---

## 4. Emergency Kill Switch / Manual Disable Instructions

If automated refreshes must be stopped immediately:

### Option A: Via GitHub Web Interface
1. Navigate to repository **Actions** tab: `https://github.com/Code-Crew-Nexus/UrbanAirQualityIndex-PollutantDriftAnalysis/actions`.
2. In the left sidebar, select **Live Data Daily Refresh** (or **Live Data Monthly Refresh**).
3. Click the **...** (three dots) button at the top right of the workflow description.
4. Click **Disable workflow**.

### Option B: Via Git (Remove Workflow File)
1. Delete or rename `.github/workflows/live-data-daily.yml`.
2. Commit and push to `main`:
   ```bash
   git rm .github/workflows/live-data-daily.yml
   git commit -m "ops: emergency disable daily live data refresh"
   git push origin main
   ```

---

## 5. Manual Admin Checklist for Organization Owner

The organization owner (`Code-Crew-Nexus`) should verify account billing safeguards directly in GitHub account settings:

- [ ] **Navigate to Account Settings:**
  - Organization Settings &rarr; **Billing and licensing** &rarr; **Budgets and alerts**.
- [ ] **Configure Spending Limit:**
  - Set the monthly Actions spending limit to **\$0.00** (or minimum allowable budget threshold) to prevent any non-free charges.
  - Enable **"Stop usage when budget limit is reached"**.
- [ ] **Configure Usage Alerts:**
  - Enable email notifications at 75%, 90%, and 100% of included resource usage.
- [ ] **Verify Larger Runners Disabled:**
  - Confirm that larger runners / self-hosted runners with billable credit consumption are disabled.
- [ ] **Confirm Repository Visibility:**
  - Verify that the repository remains **Public** (`Settings -> Danger Zone -> Change repository visibility`). Public repositories receive unlimited standard Ubuntu runner minutes for standard public workflows.
