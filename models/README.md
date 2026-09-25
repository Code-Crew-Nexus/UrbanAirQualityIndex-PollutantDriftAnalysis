# Statistical & Machine Learning Models Directory

**Status:** Placeholder for Phase 4 (Out of scope for Phase 0 & Phase 1).

This directory will host the statistical learning models developed during the later stages of the Project-Based Learning curriculum for *Statistics for Machine Learning*.

### Planned Syllabus-Aligned Methodologies:
1. **Descriptive Statistics & Inferential Tests:**
   - Confidence intervals for mean pollutant concentrations.
   - Two-sample hypothesis testing (e.g., Welch's $t$-test for pre- vs. post-monsoon pollution shifts).
   - ANOVA / Kruskal-Wallis for multi-station spatial variance.
2. **Multiple Linear Regression (MLR):**
   - Modeling AQI or $\text{PM}_{2.5}$ as a function of meteorological covariates (temperature, humidity, wind speed) and seasonal terms.
   - Diagnostic checks: residual normality, homoscedasticity, multicollinearity (VIF).
3. **Logistic Regression:**
   - Classification of air quality exceedance days (e.g., Binary indicator: $\text{AQI} > 200$ vs. $\le 200$).
   - Evaluation via Confusion Matrix, Precision, Recall, and ROC-AUC.
4. **Unsupervised Learning:**
   - Principal Component Analysis (PCA) for understanding correlated multi-pollutant variance.
   - $K$-Means Clustering for grouping stations with similar temporal pollution profiles.
5. **Support Vector Machines (SVM):**
   - Optional non-linear boundary classification if justified by decision boundary complexity.

*Note: Heavy deep learning, LSTM, spatial lag autoregression, and Gaussian plume atmospheric simulations are explicitly avoided to keep the project directly aligned with undergraduate syllabus requirements and viva explainability.*
