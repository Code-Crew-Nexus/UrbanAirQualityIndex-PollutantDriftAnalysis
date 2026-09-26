# Mathematical Smoke Test Fixtures

**Project:** `UrbanAirQualityIndex-PollutantDriftAnalysis`  
**Purpose:** Development-only mathematical fixture used by test suites and KaTeX validation.  
**Policy:** Not exposed in primary navigation.

---

## 1. CPCB Interpolation Formula (Verified-Subset AQI)

Inline representation: The subindex $I_p$ for pollutant concentration $C_p$.

Display equation:
$$
I_p = \frac{I_{high}-I_{low}}{BP_{high}-BP_{low}}(C_p-BP_{low}) + I_{low}
$$

---

## 2. Drift Standardized Mean Shift

Inline representation: The standardized drift score $D_z$.

Display equation:
$$
D_z = \frac{\bar{x}_{recent}-\bar{x}_{baseline}}{s_{baseline}}
$$

---

## 3. Multiple Linear Regression Equation

Inline representation: Continuous prediction $\hat{y}$ for feature vector $x_j$.

Display equation:
$$
\hat{y} = \beta_0 + \sum_{j=1}^{p}\beta_j x_j
$$

---

## 4. Logistic Sigmoid Function

Inline representation: Conditional adverse probability $P(Y=1\mid\mathbf{x})$.

Display equation:
$$
P(Y=1\mid\mathbf{x}) = \frac{1}{1+\exp(-(\beta_0+\mathbf{x}^{T}\boldsymbol{\beta}))}
$$

---

## 5. PCA Eigenvalue Relation

Inline representation: Eigenvector $\mathbf{v}_j$ with associated variance eigenvalue $\lambda_j$.

Display equation:
$$
S\mathbf{v}_j = \lambda_j\mathbf{v}_j
$$

---

## 6. $K$-Means Objective Function

Inline representation: Within-cluster sum of squares around centroid $\boldsymbol{\mu}_r$.

Display equation:
$$
\underset{C_1,\ldots,C_k}{\operatorname{minimize}} \sum_{r=1}^{k} \sum_{\mathbf{x}_i\in C_r} \|\mathbf{x}_i-\boldsymbol{\mu}_r\|^2
$$

---

## 7. Radial Basis Function (RBF) Kernel

Inline representation: Kernel function $K(\mathbf{x},\mathbf{x}')$ with bandwidth $\gamma$.

Display equation:
$$
K(\mathbf{x},\mathbf{x}') = \exp\left(-\gamma \|\mathbf{x}-\mathbf{x}'\|^2\right)
$$

---

## 8. Support Vector Machine Decision Function

Inline representation: Decision score $s(\mathbf{x})$ and sign classification $f(\mathbf{x})$.

Display equation:
$$
f(\mathbf{x}) = \operatorname{sgn}\left(\sum_{i=1}^{N_{sv}} \alpha_i y_i K(\mathbf{x}_i,\mathbf{x}) + b\right)
$$

Continuous margin score:
$$
s(\mathbf{x}) = \sum_{i=1}^{N_{sv}} \alpha_i y_i K(\mathbf{x}_i,\mathbf{x}) + b
$$
