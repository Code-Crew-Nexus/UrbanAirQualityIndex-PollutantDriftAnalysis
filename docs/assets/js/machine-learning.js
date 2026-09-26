/**
 * machine-learning.js
 * Interactive presentation of frozen supervised regression, classification, and unsupervised PCA/K-Means regimes.
 * Project: UrbanAirQualityIndex-PollutantDriftAnalysis
 * Baseline: v0.6-svm-freeze (FROZEN — READ ONLY)
 */

document.addEventListener('DOMContentLoaded', async () => {
  'use strict';

  // DOM Elements - Tabs
  const tabBtns = document.querySelectorAll('.tab-btn');
  const tabPanes = document.querySelectorAll('.tab-pane');

  // Regression Controls & Elements
  const regScopeSelect = document.getElementById('reg-filter-scope');
  const regSplitSelect = document.getElementById('reg-filter-split');
  const regChartCanvas = document.getElementById('regressionComparisonChart');
  const regTableTbody = document.getElementById('regression-table-tbody');
  const regInterpretationElem = document.getElementById('regression-interpretation');

  // Classification Controls & Elements
  const clsScopeSelect = document.getElementById('cls-filter-scope');
  const clsSplitSelect = document.getElementById('cls-filter-split');
  const clsChartCanvas = document.getElementById('classificationComparisonChart');
  const clsChartWrapper = document.getElementById('cls-chart-wrapper');
  const clsNoticeCard = document.getElementById('cls-notice-card');
  const clsTableTbody = document.getElementById('classification-table-tbody');

  // Regimes Controls & Elements
  const regimeScopeSelect = document.getElementById('regime-filter-scope');
  const pcaScatterCanvas = document.getElementById('pcaScatterChart');
  const regimeCumulativeVarElem = document.getElementById('regime-cum-var');
  const regimeRetainedPcsElem = document.getElementById('regime-retained-pcs');
  const regimeCardsContainer = document.getElementById('regime-profile-cards');

  // Chart instances
  let regChart = null;
  let clsChart = null;
  let pcaChart = null;

  // Cached data
  let regressionMetrics = [];
  let classificationMetrics = [];
  let pcaVariance = [];
  let clusterProfiles = {};
  let pcaScores = [];

  try {
    const [regData, clsData, varData, prfData, scrData] = await Promise.all([
      DataUtils.fetchJSON('web-data/regression_metrics.json'),
      DataUtils.fetchJSON('web-data/classification_metrics.json'),
      DataUtils.fetchJSON('web-data/pca_variance.json'),
      DataUtils.fetchJSON('web-data/cluster_profiles.json'),
      DataUtils.fetchJSON('web-data/pca_scores.json')
    ]);

    regressionMetrics = regData;
    classificationMetrics = clsData;
    pcaVariance = varData;
    clusterProfiles = prfData;
    pcaScores = scrData;

    initTabs();
    initControls();

    // Render initial views
    updateRegressionView();
    updateClassificationView();
    updateRegimesView();

  } catch (err) {
    console.error('Error loading Machine Learning assets:', err);
  }

  function initTabs() {
    tabBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        const targetId = btn.getAttribute('data-target');

        tabBtns.forEach(b => {
          b.classList.remove('active');
          b.setAttribute('aria-selected', 'false');
        });
        tabPanes.forEach(p => p.classList.remove('active'));

        btn.classList.add('active');
        btn.setAttribute('aria-selected', 'true');

        const targetPane = document.getElementById(targetId);
        if (targetPane) targetPane.classList.add('active');

        // Trigger chart resize on tab switch
        if (targetId === 'tab-regression' && regChart) regChart.resize();
        if (targetId === 'tab-classification' && clsChart) clsChart.resize();
        if (targetId === 'tab-regimes' && pcaChart) pcaChart.resize();
      });
    });

    // Deep link tab selection from hash or query
    const hash = window.location.hash;
    const urlParams = new URLSearchParams(window.location.search);
    let targetTab = urlParams.get('tab');
    if (!targetTab && hash) {
      if (hash === '#classification') targetTab = 'tab-classification';
      else if (hash === '#regimes') targetTab = 'tab-regimes';
      else if (hash === '#regression') targetTab = 'tab-regression';
    } else if (targetTab && !targetTab.startsWith('tab-')) {
      targetTab = `tab-${targetTab}`;
    }
    if (targetTab) {
      const targetBtn = Array.from(tabBtns).find(b => b.getAttribute('data-target') === targetTab);
      if (targetBtn) {
        targetBtn.click();
      }
    }
  }

  function initControls() {
    regScopeSelect.addEventListener('change', updateRegressionView);
    regSplitSelect.addEventListener('change', updateRegressionView);

    clsScopeSelect.addEventListener('change', updateClassificationView);
    clsSplitSelect.addEventListener('change', updateClassificationView);

    regimeScopeSelect.addEventListener('change', updateRegimesView);
  }

  // ===========================================================================
  // 1. REGRESSION VIEW
  // ===========================================================================
  function updateRegressionView() {
    const scope = regScopeSelect.value;
    const split = regSplitSelect.value;

    const filtered = regressionMetrics.filter(r => r.scope === scope && r.evaluation_period === split);
    renderRegressionChart(filtered, scope, split);
    renderRegressionTable(filtered);
    renderRegressionInterpretation(filtered, scope, split);
  }

  function renderRegressionChart(rows, scope, split) {
    if (regChart) regChart.destroy();

    const modelLabels = rows.map(r => r.model);
    const maeValues = rows.map(r => r.MAE);
    const rmseValues = rows.map(r => r.RMSE);

    const ctx = regChartCanvas.getContext('2d');
    regChart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: modelLabels,
        datasets: [
          {
            label: 'MAE (Mean Absolute Error)',
            data: maeValues,
            backgroundColor: 'rgba(40, 95, 73, 0.85)',
            borderColor: '#285F49',
            borderWidth: 1.5,
            borderRadius: 4
          },
          {
            label: 'RMSE (Root Mean Squared Error)',
            data: rmseValues,
            backgroundColor: 'rgba(196, 154, 88, 0.85)',
            borderColor: '#C49A58',
            borderWidth: 1.5,
            borderRadius: 4
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'top',
            labels: { font: { family: 'inherit', size: 12, weight: 600 } }
          },
          tooltip: {
            callbacks: {
              label: function (ctx) {
                return `${ctx.dataset.label}: ${ctx.parsed.y.toFixed(2)} AQI units`;
              }
            }
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            title: {
              display: true,
              text: 'Error in AQI Index Units',
              color: DataUtils.THEME.graphiteDark,
              font: { family: 'inherit', size: 12, weight: 600 }
            }
          }
        }
      }
    });
  }

  function renderRegressionTable(rows) {
    if (!regTableTbody) return;
    regTableTbody.innerHTML = '';

    rows.forEach(r => {
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td><strong>${r.model}</strong></td>
        <td>${DataUtils.formatNumber(r.MAE, 4)}</td>
        <td>${DataUtils.formatNumber(r.RMSE, 4)}</td>
        <td>${DataUtils.formatNumber(r.bias, 4)}</td>
        <td>${DataUtils.formatNumber(r.median_absolute_error, 4)}</td>
        <td>${DataUtils.formatNumber(r.R2, 4)}</td>
      `;
      regTableTbody.appendChild(tr);
    });
  }

  function renderRegressionInterpretation(rows, scope, split) {
    const modelB = rows.find(r => r.model === 'Selected MLR Model B');
    const persistence = rows.find(r => r.model === 'Persistence');

    if (!modelB || !persistence) {
      regInterpretationElem.innerHTML = '';
      return;
    }

    const maeDiff = (modelB.MAE - persistence.MAE).toFixed(2);
    let comparisonText = '';
    if (modelB.MAE < persistence.MAE) {
      comparisonText = `Model B achieved lower MAE by ${Math.abs(maeDiff)} AQI units compared to the persistence benchmark.`;
    } else {
      comparisonText = `The simple single-day persistence benchmark maintained lower MAE by ${Math.abs(maeDiff)} AQI units than Model B.`;
    }

    regInterpretationElem.innerHTML = `
      <strong>Empirical Evaluation Summary (${scope} Panel — ${split}):</strong>
      Model B (${split} MAE: ${modelB.MAE.toFixed(2)}, RMSE: ${modelB.RMSE.toFixed(2)}) incorporates verified environmental variables and same-day AQI.
      ${comparisonText}
      Findings indicate that while linear features capture broad seasonal tendencies, atmospheric persistence remains a competitive baseline on holdout evaluations.
    `;
  }

  // ===========================================================================
  // 2. CLASSIFICATION VIEW
  // ===========================================================================
  function updateClassificationView() {
    const scope = clsScopeSelect.value;
    const split = clsSplitSelect.value;

    const filtered = classificationMetrics.filter(r => r.scope === scope && r.evaluation_period === split);

    // Single-class handling for Hyderabad September holdout
    const isSingleClass = filtered.every(r => r.positive_n === 0);

    if (isSingleClass) {
      clsChartWrapper.style.display = 'none';
      clsNoticeCard.style.display = 'block';
      clsNoticeCard.innerHTML = `
        <strong>Single-Class Evaluation Period (${scope} — ${split}):</strong>
        Two-class discrimination metrics (PR-AUC, ROC-AUC, F1, Sensitivity) are undefined because the evaluation set contains <strong>zero positive adverse-class observations</strong> ($Y_{t+1}=1, \\text{AQI}_{t+1} > 100$) among 111 eligible station-days.
        Single-class descriptive quantities such as Specificity ($1.0000$) and True Negatives ($111$) are reported in the table below.
      `;
    } else {
      clsNoticeCard.style.display = 'none';
      clsChartWrapper.style.display = 'block';
      renderClassificationChart(filtered, scope, split);
    }

    renderClassificationTable(filtered);
  }

  function renderClassificationChart(rows, scope, split) {
    if (clsChart) clsChart.destroy();

    const modelLabels = rows.map(r => r.model);
    const praucValues = rows.map(r => r.PR_AUC !== null ? r.PR_AUC : 0);
    const f1Values = rows.map(r => r.F1 !== null ? r.F1 : 0);

    const ctx = clsChartCanvas.getContext('2d');
    clsChart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: modelLabels,
        datasets: [
          {
            label: 'PR-AUC (Precision-Recall Area)',
            data: praucValues,
            backgroundColor: 'rgba(40, 95, 73, 0.85)',
            borderColor: '#285F49',
            borderWidth: 1.5,
            borderRadius: 4
          },
          {
            label: 'F1 Score (Validation-Tuned Operating Threshold)',
            data: f1Values,
            backgroundColor: 'rgba(196, 154, 88, 0.85)',
            borderColor: '#C49A58',
            borderWidth: 1.5,
            borderRadius: 4
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'top',
            labels: { font: { family: 'inherit', size: 12, weight: 600 } }
          },
          tooltip: {
            callbacks: {
              label: function (ctx) {
                const val = ctx.parsed.y;
                return `${ctx.dataset.label}: ${val > 0 ? val.toFixed(4) : 'Undefined'}`;
              }
            }
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            max: 1.0,
            title: {
              display: true,
              text: 'Metric Value (0.0 to 1.0)',
              color: DataUtils.THEME.graphiteDark,
              font: { family: 'inherit', size: 12, weight: 600 }
            }
          }
        }
      }
    });
  }

  function renderClassificationTable(rows) {
    if (!clsTableTbody) return;
    clsTableTbody.innerHTML = '';

    rows.forEach(r => {
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td>
          <strong>${r.model}</strong><br>
          <span style="font-size: 0.72rem; color: #6B7280; text-transform: uppercase;">
            ${r.model_type.replace(/_/g, ' ')}
          </span>
        </td>
        <td>${DataUtils.formatNumber(r.PR_AUC, 4)}</td>
        <td>${DataUtils.formatNumber(r.ROC_AUC, 4)}</td>
        <td>${DataUtils.formatNumber(r.avg_prec, 4)}</td>
        <td>${DataUtils.formatNumber(r.F1, 4)}</td>
        <td>${DataUtils.formatNumber(r.sensitivity, 4)}</td>
        <td>${DataUtils.formatNumber(r.specificity, 4)}</td>
        <td>${r.TP !== null ? r.TP : '—'}</td>
        <td>${r.TN !== null ? r.TN : '—'}</td>
        <td>${r.FP !== null ? r.FP : '—'}</td>
        <td>${r.FN !== null ? r.FN : '—'}</td>
        <td>${r.Brier_Score !== null ? DataUtils.formatNumber(r.Brier_Score, 4) : '<span style="color: #9CA3AF;">Undefined</span>'}</td>
      `;
      clsTableTbody.appendChild(tr);
    });
  }

  // ===========================================================================
  // 3. POLLUTION REGIMES (PCA & K-MEANS) VIEW
  // ===========================================================================
  function updateRegimesView() {
    const scope = regimeScopeSelect.value;
    const isHyd = scope === 'Hyderabad';

    // Update variance info
    if (isHyd) {
      regimeCumulativeVarElem.textContent = '90.21%';
      regimeRetainedPcsElem.textContent = '4 PCs (of 6 sensor features)';
    } else {
      regimeCumulativeVarElem.textContent = '88.65%';
      regimeRetainedPcsElem.textContent = '4 PCs (of 6 sensor features)';
    }

    renderRegimesScatter(scope);
    renderClusterProfileCards(scope);
  }

  function renderRegimesScatter(scope) {
    if (pcaChart) pcaChart.destroy();

    const filtered = pcaScores.filter(s => s.scope === scope);

    // Group points by cluster label
    const clusterGroups = {};
    const clusterColors = [
      { bg: 'rgba(196, 154, 88, 0.65)', border: '#C49A58' }, // Amber/Champagne
      { bg: 'rgba(40, 95, 73, 0.65)', border: '#285F49' },   // Deep Jade
      { bg: 'rgba(75, 85, 99, 0.65)', border: '#374151' }    // Graphite/Slate
    ];

    filtered.forEach(pt => {
      const cl = pt.cluster_label;
      if (!clusterGroups[cl]) {
        clusterGroups[cl] = [];
      }
      clusterGroups[cl].push({
        x: pt.PC1,
        y: pt.PC2,
        station: pt.project_station_id,
        date: pt.date,
        period: pt.period,
        cluster: cl
      });
    });

    const datasets = Object.keys(clusterGroups).map((clKey, idx) => {
      const color = clusterColors[idx % clusterColors.length];
      return {
        label: clKey,
        data: clusterGroups[clKey],
        backgroundColor: color.bg,
        borderColor: color.border,
        borderWidth: 1,
        pointRadius: 2.5,
        pointHoverRadius: 5
      };
    });

    const ctx = pcaScatterCanvas.getContext('2d');
    pcaChart = new Chart(ctx, {
      type: 'scatter',
      data: { datasets },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: false, // Performance optimization for large point sets
        plugins: {
          legend: {
            position: 'top',
            labels: {
              font: { family: 'inherit', size: 12, weight: 600 },
              usePointStyle: true
            }
          },
          tooltip: {
            callbacks: {
              label: function (ctx) {
                const pt = ctx.raw;
                return [
                  `Cluster: ${pt.cluster}`,
                  `Station: ${pt.station} (${pt.date})`,
                  `PC1: ${pt.x.toFixed(2)}, PC2: ${pt.y.toFixed(2)} (${pt.period})`
                ];
              }
            }
          }
        },
        scales: {
          x: {
            title: {
              display: true,
              text: 'Principal Component 1 (Particulate & Sensor Magnitude)',
              color: DataUtils.THEME.graphiteDark,
              font: { family: 'inherit', size: 12, weight: 600 }
            },
            grid: { color: 'rgba(0, 0, 0, 0.05)' }
          },
          y: {
            title: {
              display: true,
              text: 'Principal Component 2 (Photochemical & Thermal Gradient)',
              color: DataUtils.THEME.graphiteDark,
              font: { family: 'inherit', size: 12, weight: 600 }
            },
            grid: { color: 'rgba(0, 0, 0, 0.05)' }
          }
        }
      }
    });
  }

  function renderClusterProfileCards(scope) {
    if (!regimeCardsContainer || !clusterProfiles.labels) return;
    regimeCardsContainer.innerHTML = '';

    const labels = clusterProfiles.labels.filter(l => l.scope === scope);
    const centroids = clusterProfiles.centroids ? clusterProfiles.centroids.filter(c => c.scope === scope) : [];

    labels.forEach((l, idx) => {
      const card = document.createElement('div');
      card.className = 'metric-card';
      card.style.borderTop = `4px solid ${idx === 0 ? '#C49A58' : idx === 1 ? '#285F49' : '#374151'}`;

      const cnt = centroids.find(c => c.cluster === l.cluster);
      const pcCoords = cnt ? `PC1: ${cnt.PC1}, PC2: ${cnt.PC2}` : '';

      card.innerHTML = `
        <span class="metric-card-label">${l.cluster} — ${l.scope}</span>
        <span class="metric-card-value" style="font-size: 1.15rem; color: var(--jade-deep); margin-bottom: 0.5rem;">
          ${l.descriptive_label}
        </span>
        <p style="font-size: 0.8rem; color: var(--graphite-dark); line-height: 1.4; margin-bottom: 0.5rem;">
          ${l.profile_basis}
        </p>
        <span class="metric-card-sub" style="font-family: monospace; font-size: 0.75rem;">
          Centroid Coordinates: ${pcCoords}
        </span>
      `;
      regimeCardsContainer.appendChild(card);
    });
  }
});
