# Canonical Milestone Reports

This directory contains the final consolidated summaries for the frozen analytical phases of the project.

- [Phase 2: Data Engineering and AQI Calculation](phase2_data_aqi_summary.md)
  Summarizes the real-data pipeline, station selections, and the authoritative verified-subset AQI policy.
- [Phase 3: Exploratory Statistical Analysis and Pollutant Drift](phase3_statistical_analysis_summary.md)
  Summarizes descriptive drift quantification and rigorous statistical inference using moving-block bootstraps.
- [Phase 4: Supervised Machine Learning Summary](phase4_supervised_learning_summary.md)
  Summarizes the next-day AQI prediction design, MLR vs Logistic classification, model selection, tie-safe metrics, and temporal prevalence shift impacts.
- [Phase 5: PCA Dimensionality Analysis & K-Means Pollution-Regime Discovery](phase5_pca_kmeans_summary.md)
  Summarizes the unsupervised latent dimensionality reduction (4 PCs retained, ~90% variance) and K-Means pollution regime discovery ($k=3$) across Hyderabad and India panels.

*Note: Detailed intermediate phase audit reports, debugging traces, and closure validations are retained locally in the `docs/internal_phase_history/` directory and are not part of the collaborative repository to maintain clarity.*

