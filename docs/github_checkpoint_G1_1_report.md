# GitHub Checkpoint G1.1 Report

## SECTION A — COLLABORATION POLICY ALIGNMENT
The repository collaboration policy was specifically tailored for an academic **Project Based Learning (PBL)** setting for **Statistics for Machine Learning (SML)**:
- External code contributions and Pull Requests are **explicitly not accepted**.
- External Issue / bug-fix tracking is disabled in favor of constructive academic interaction.
- Scholarly questions, references, and suggestions are welcomed through **GitHub Discussions**.
- The `.github/PULL_REQUEST_TEMPLATE.md` asset was deleted, and the `.github` directory was completely removed.
- `CONTRIBUTING.md` was rewritten to state the academic PBL scope, team authorship, and internal git-branch integration workflow.
- `README.md` was updated with a dedicated "Suggestions & Feedback" section directing community questions to GitHub Discussions without referencing Pull Requests.

## SECTION B — TEAM IDENTITY
`docs/TEAM.md` and `README.md` were updated with the verified GitHub usernames for all four project team members:
1. **Mangali Sai Krishna** (24R11A6669) — `@Saikrishna-dev-oss`
2. **Md. Abdul Rayain** (24R11A6673) — `@rayainwarrior-dev`
3. **RISHIT GHOSH** (24R11A6685) — `@rajghosh06-dev`
4. **Yaram Karthik** (24R11A66A1) — `@karthik10-dev`

## SECTION C — SECURITY & EXCLUSION AUDIT
A comprehensive audit confirmed that zero secrets or intermediate history artifacts are tracked by Git:
- `.Renviron`: NOT tracked (cleanly ignored).
- `docs/internal_phase_history/`: NOT tracked (cleanly ignored).
- `data/raw/`, `data/interim/`, `data/quarantine/`, `data/modeling/`: NOT tracked.
- `scratch/`, `logs/`, `review_archive_*.zip`: NOT tracked.

## SECTION D — GIT TRACKING PLAN UPDATE
`docs/GIT_TRACKING_PLAN.md` was updated to remove all references to `.github/` and the PR template.

## SECTION E — TAG ALIGNMENT
The local annotated tag `v0.4-supervised-freeze` was realigned to point exactly to the latest commit on `main`, resolving the previous post-amend discrepancy. Both `git rev-parse HEAD` and `git rev-list -n 1 v0.4-supervised-freeze` evaluate to identical commit hashes.

## SECTION F — STATUS
**GITHUB CHECKPOINT G1.1 READY — SAFE TO CREATE ORGANIZATION REMOTE**
