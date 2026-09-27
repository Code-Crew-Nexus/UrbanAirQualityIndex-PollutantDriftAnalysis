# Adaptive Model Candidate Architecture & Governance

**Status:** EXPERIMENTAL — NOT ACADEMIC BASELINE  
**Auto-Promotion Policy:** `AUTO_PROMOTE_MODEL = FALSE` (Strictly Enforced)  
**Authoritative Baseline:** `v0.6-svm-freeze` (FROZEN / READ-ONLY)

---

## 1. Architectural Purpose

This directory (`models/live_candidate/`) provides a separate, quarantined candidate tracking space for evaluating potential adaptive model candidates against incoming live observations without endangering the frozen academic baseline.

The official scientific PBL study concludes on **2026-09-21**. The models locked under `models/phase4B/`, `models/phase4C/`, `models/phase5A/`, and `models/phase5B/` (tagged `v0.6-svm-freeze`) represent the immutable scientific truth evaluated in the academic report.

Under no circumstances will live daily or monthly data ingestion automatically retrain, replace, or overwrite the frozen baseline models.

---

## 2. Governance & Promotion Gates

To prevent automated drift, regression, or unauthorized model mutation in production, any adaptive candidate model must satisfy the following mandatory gates:

1. **Explicit Human-in-the-Loop Approval:**  
   Automatic promotion is permanently disabled (`AUTO_PROMOTE_MODEL = FALSE`). Promotion requires explicit manual faculty/maintainer review, a dedicated pull request, and a new semantic release tag.
2. **Strict Temporal Validation:**  
   Candidate models may only be trained on data chronologically preceding the evaluation window. Random cross-validation and future-to-past data leakage are strictly prohibited.
3. **Rigorous Benchmark Comparison:**  
   A candidate model must demonstrate statistically significant, verified improvement over the frozen `v0.6-svm-freeze` baseline on locked out-of-sample live data across co-primary metrics (MAE and RMSE for regression; PR-AUC and ROC-AUC for classification).
4. **Isolated Namespace:**  
   All experimental models, training logs, and feature scalers must reside exclusively within `models/live_candidate/` and must never overwrite `models/phase4B/`, `models/phase4C/`, or `models/phase5B/`.

---

## 3. Retraining Frequency & Execution Policy

- **Daily Retraining:** Strictly PROHIBITED. Daily data streams are subject to temporary reporting delays, sensor dropouts, and maintenance gaps. Daily retraining causes severe parameter churn and instability.
- **Monthly Retraining:** Permitted only in manual experimental mode after a complete calendar month has elapsed and passed all data-quality gates.

---

## 4. Candidate Model Specification

When an experimental candidate is fitted, it must be saved with strict metadata:

- File naming: `candidate_<scope>_<architecture>_<training_cutoff>.rds`
- Accompanied by:
  - Feature scaler parameters learned strictly on the training subset
  - Full hyperparameter log
  - Comparative evaluation table against frozen v0.6 baseline
  - Git commit SHA and author attribution
