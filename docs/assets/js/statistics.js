/**
 * statistics.js
 * Interactive presentation of frozen Level-1 Pollutant Drift (Dz) and Statistical Inference (MBB/BH-FDR).
 * Project: UrbanAirQualityIndex-PollutantDriftAnalysis
 * Baseline: v0.6-svm-freeze (FROZEN — READ ONLY)
 */

let isStatisticsSectionInitialized = false;
window.initStatisticsSection = async function() {
  if (isStatisticsSectionInitialized) return;
  isStatisticsSectionInitialized = true;

  'use strict';

  // DOM Elements - Controls
  const scopeSelect = document.getElementById('stat-filter-scope');
  const stationSelect = document.getElementById('stat-filter-station');
  const variableSelect = document.getElementById('stat-filter-variable');

  // Tabs
  const tabBtns = document.querySelectorAll('.tab-btn');
  const tabPanes = document.querySelectorAll('.tab-pane');

  // Drift UI Elements
  const driftDzElem = document.getElementById('drift-dz');
  const driftMagnitudeElem = document.getElementById('drift-magnitude');
  const driftRecentMeanElem = document.getElementById('drift-recent-mean');
  const driftBaselineMeanElem = document.getElementById('drift-baseline-mean');
  const driftRecentDaysElem = document.getElementById('drift-recent-days');
  const driftBaselineDaysElem = document.getElementById('drift-baseline-days');
  const driftAsOfElem = document.getElementById('drift-as-of');
  const driftStatusElem = document.getElementById('drift-status');
  const driftDirectionElem = document.getElementById('drift-direction');
  const driftComparisonCanvas = document.getElementById('driftComparisonChart');

  // Inference UI Elements
  const infTestedElem = document.getElementById('inf-tested');
  const infSupportElem = document.getElementById('inf-support');
  const infBhQElem = document.getElementById('inf-bh-q');
  const infCiElem = document.getElementById('inf-ci');
  const infHedgesElem = document.getElementById('inf-hedges');
  const infCliffsElem = document.getElementById('inf-cliffs');
  const infRobustElem = document.getElementById('inf-robust');
  const infNoticeElem = document.getElementById('inf-notice');
  const stationInferenceTbody = document.getElementById('station-inference-tbody');

  // Chart instances
  let driftComparisonChart = null;

  // Cached data
  let stationsData = [];
  let driftData = [];
  let inferenceData = [];

  // Variable Display Configuration
  const STAT_VARIABLES = [
    { key: 'aqi_verified', label: 'AQI', full: 'Verified-Subset AQI', unit: 'Index units', verified: true },
    { key: 'pm2_5_aqi_input', label: 'PM2.5', full: 'Fine Particulate Matter (PM2.5)', unit: 'µg/m³', verified: true },
    { key: 'pm10_aqi_input', label: 'PM10', full: 'Coarse Particulate Matter (PM10)', unit: 'µg/m³', verified: true },
    { key: 'o3_8h_max', label: 'O3', full: 'Daily maximum rolling 8-hour ozone (o3_8h_max)', unit: 'µg/m³', verified: true },
    { key: 'co_source_mean', label: 'CO (Source)', full: 'Carbon Monoxide (Source Scale)', unit: 'raw units', verified: false },
    { key: 'no2_source_mean', label: 'NO2 (Source)', full: 'Nitrogen Dioxide (Source Scale)', unit: 'raw units', verified: false },
    { key: 'so2_source_mean', label: 'SO2 (Source)', full: 'Sulphur Dioxide (Source Scale)', unit: 'raw units', verified: false }
  ];

  try {
    const [stations, drift, inference] = await Promise.all([
      DataUtils.fetchJSON('web-data/stations.json'),
      DataUtils.fetchJSON('web-data/drift_summary.json'),
      DataUtils.fetchJSON('web-data/inference_summary.json')
    ]);

    stationsData = stations;
    driftData = drift;
    inferenceData = inference;

    initTabs();
    initControls();
    updateView();

  } catch (err) {
    console.error('Error loading Statistical Analysis assets:', err);
    if (driftStatusElem) driftStatusElem.textContent = 'Error loading frozen data.';
    const errRegion = document.getElementById('stat-load-error');
    if (errRegion) {
      errRegion.classList.remove('visually-hidden');
      if (window.location.protocol === 'file:') {
        errRegion.innerHTML = '<div class="load-error-card local-preview-card" style="margin-bottom: 1.5rem;"><div class="load-error-header"><span class="load-error-badge">LOCAL PREVIEW REQUIRED</span><h3 class="load-error-title">Interactive Datasets Require Local HTTP Server</h3></div><p class="load-error-desc">Datasets cannot be loaded when opening this page directly from disk (<code>file://</code>). Start the local server with <code>py scripts/serve_website_local.py</code> or <code>py -m http.server 8000 --directory docs</code> and open <a href="http://localhost:8000/statistics.html" class="preview-direct-link">http://localhost:8000/statistics.html</a>.</p></div>';
      } else {
        errRegion.textContent = 'Error: Statistical Analysis data could not be loaded. Please refresh the page.';
      }
    }
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

        // Resize chart if tab was hidden
        if (targetId === 'tab-drift' && driftComparisonChart) {
          driftComparisonChart.resize();
        }
      });
    });

    // Deep link tab selection from hash or query
    const hash = window.location.hash;
    const urlParams = new URLSearchParams(window.location.search);
    const initialTab = urlParams.get('tab') || (hash === '#inference' ? 'tab-inference' : (hash === '#drift' ? 'tab-drift' : null));
    if (initialTab) {
      const targetBtn = Array.from(tabBtns).find(b => b.getAttribute('data-target') === initialTab || b.getAttribute('data-target') === `tab-${initialTab}`);
      if (targetBtn) {
        targetBtn.click();
      }
    }
  }

  function normalizeScope(scopeStr) {
    if (!scopeStr) return null;
    const s = decodeURIComponent(scopeStr).trim().toLowerCase();
    if (s === 'hyderabad') return 'Hyderabad';
    if (s === 'india' || s === 'india representative panel') return 'India';
    return null;
  }

  function initControls() {
    // Check URL parameters for deep-linking before initial station population
    const urlParams = new URLSearchParams(window.location.search);
    const scopeParam = urlParams.get('scope');
    const normScope = normalizeScope(scopeParam) || 'Hyderabad';
    scopeSelect.value = normScope;
    
    populateStations(normScope);

    if (urlParams.has('station')) {
      const stParam = urlParams.get('station');
      const exists = Array.from(stationSelect.options).some(o => o.value === stParam);
      if (exists) {
        stationSelect.value = stParam;
      }
    }
    if (urlParams.has('variable')) {
      const v = urlParams.get('variable');
      const match = STAT_VARIABLES.find(sv => sv.key === v || sv.label.toLowerCase() === v.toLowerCase());
      if (match) {
        variableSelect.value = match.key;
      } else if (Array.from(variableSelect.options).some(o => o.value === v)) {
        variableSelect.value = v;
      }
    }

    scopeSelect.addEventListener('change', () => {
      populateStations(scopeSelect.value);
      updateView();
    });

    stationSelect.addEventListener('change', updateView);
    variableSelect.addEventListener('change', updateView);
  }

  function populateStations(selectedScope) {
    const prevStation = stationSelect.value;
    stationSelect.innerHTML = '';

    const isHyd = selectedScope === 'Hyderabad';
    const filteredStations = stationsData.filter(st => {
      if (isHyd) return st.use_hyderabad === true;
      return st.use_india === true;
    });

    filteredStations.forEach(st => {
      const opt = document.createElement('option');
      opt.value = st.project_station_id;
      opt.textContent = `${st.project_station_id}: ${st.station_name} (${st.city})`;
      stationSelect.appendChild(opt);
    });

    const exists = Array.from(stationSelect.options).some(o => o.value === prevStation);
    if (exists && prevStation) {
      stationSelect.value = prevStation;
    } else {
      // Deterministically default to first configured station in scope where variable == 'aqi_verified' and eligible == TRUE
      const eligibleStation = filteredStations.find(st => {
        return driftData.some(d => d.project_station_id === st.project_station_id && d.variable === 'aqi_verified' && d.eligible === true);
      });
      if (eligibleStation) {
        stationSelect.value = eligibleStation.project_station_id;
      } else if (stationSelect.options.length > 0) {
        stationSelect.selectedIndex = 0;
      }
    }
  }

  function updateView() {
    const stationId = stationSelect.value;
    const varKey = variableSelect.value;
    const varMeta = STAT_VARIABLES.find(v => v.key === varKey) || STAT_VARIABLES[0];

    // Find records in drift and inference datasets
    const driftRow = driftData.find(d => d.project_station_id === stationId && d.variable === varKey);
    const infRow = inferenceData.find(i => i.project_station_id === stationId && i.variable === varKey);

    renderDriftTab(driftRow, varMeta);
    renderInferenceTab(infRow, driftRow, varMeta, stationId);
  }

  function renderDriftTab(dRow, varMeta) {
    if (!dRow) {
      driftDzElem.textContent = '—';
      driftMagnitudeElem.textContent = '—';
      driftRecentMeanElem.textContent = '—';
      driftBaselineMeanElem.textContent = '—';
      driftStatusElem.textContent = 'No record found';
      return;
    }

    driftAsOfElem.textContent = dRow.as_of_date || '2026-09-21';
    driftRecentDaysElem.textContent = `${dRow.recent_n} / 30 days (≥21 required)`;
    driftBaselineDaysElem.textContent = `${dRow.baseline_n} / 90 days (≥63 required)`;

    if (dRow.eligible) {
      const dzVal = Number(dRow.drift_z);
      const sign = dzVal > 0 ? '+' : '';
      driftDzElem.textContent = `${sign}${dzVal.toFixed(3)}`;

      // Exact magnitude class labels: MINIMAL, MILD, MODERATE, STRONG
      const mag = (dRow.drift_magnitude || 'MINIMAL').toUpperCase();
      driftMagnitudeElem.textContent = mag;

      // Color magnitude
      if (mag === 'STRONG') {
        driftMagnitudeElem.style.color = '#B91C1C';
      } else if (mag === 'MODERATE') {
        driftMagnitudeElem.style.color = '#D97706';
      } else if (mag === 'MILD') {
        driftMagnitudeElem.style.color = '#4B5563';
      } else {
        driftMagnitudeElem.style.color = '#15803D';
      }

      driftRecentMeanElem.textContent = `${dRow.recent_mean.toFixed(2)} ${varMeta.unit}`;
      driftBaselineMeanElem.textContent = `${dRow.baseline_mean.toFixed(2)} ${varMeta.unit}`;

      // Signed direction directly from exported drift_direction
      if (dRow.drift_direction === 'upward' || (!dRow.drift_direction && dzVal > 0)) {
        driftDirectionElem.textContent = 'Increase';
      } else if (dRow.drift_direction === 'downward' || (!dRow.drift_direction && dzVal < 0)) {
        driftDirectionElem.textContent = 'Decrease';
      } else {
        driftDirectionElem.textContent = 'Undefined';
      }

      driftStatusElem.innerHTML = `<span class="badge-evidence badge-decrease">Eligible for Drift Evaluation</span>`;

      renderDriftChart(dRow.recent_mean, dRow.baseline_mean, varMeta);
    } else {
      driftDzElem.textContent = '—';
      driftMagnitudeElem.textContent = 'INELIGIBLE';
      driftMagnitudeElem.style.color = 'var(--graphite-muted)';
      driftRecentMeanElem.textContent = dRow.recent_mean !== null ? `${dRow.recent_mean.toFixed(2)} ${varMeta.unit}` : '—';
      driftBaselineMeanElem.textContent = dRow.baseline_mean !== null ? `${dRow.baseline_mean.toFixed(2)} ${varMeta.unit}` : '—';
      driftDirectionElem.textContent = 'Undefined';

      const reasonFormatted = (dRow.ineligibility_reason || 'Insufficient observations').replace(/_/g, ' ');
      driftStatusElem.innerHTML = `<span class="badge-evidence badge-not-tested">Ineligible: ${reasonFormatted}</span>`;

      renderDriftChart(dRow.recent_mean, dRow.baseline_mean, varMeta);
    }
  }

  function renderDriftChart(recentVal, baselineVal, varMeta) {
    if (driftComparisonChart) {
      driftComparisonChart.destroy();
    }

    const ctx = driftComparisonCanvas.getContext('2d');
    driftComparisonChart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: ['Baseline (Preceding 90-Day Window)', 'Recent (Rolling 30-Day Window)'],
        datasets: [{
          label: `${varMeta.label} (${varMeta.unit})`,
          data: [baselineVal, recentVal],
          backgroundColor: [
            'rgba(107, 114, 128, 0.65)',
            'rgba(40, 95, 73, 0.85)'
          ],
          borderColor: [
            '#4B5563',
            '#285F49'
          ],
          borderWidth: 1.5,
          borderRadius: 4
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              label: function (ctx) {
                const val = ctx.parsed.y;
                return val !== null ? `${val.toFixed(2)} ${varMeta.unit}` : 'Not available';
              }
            }
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            title: {
              display: true,
              text: `${varMeta.label} (${varMeta.unit})`,
              color: DataUtils.THEME.graphiteDark
            }
          }
        }
      }
    });
  }

  function renderInferenceTab(iRow, dRow, varMeta, stationId) {
    if (!iRow) {
      infTestedElem.textContent = '—';
      infSupportElem.textContent = '—';
      infBhQElem.textContent = '—';
      infCiElem.textContent = '—';
      infHedgesElem.textContent = '—';
      infCliffsElem.textContent = '—';
      infRobustElem.textContent = '—';
      infNoticeElem.textContent = 'No inference records found for this selection.';
      return;
    }

    if (iRow.tested && iRow.eligible) {
      infTestedElem.innerHTML = `<span class="badge-evidence badge-decrease">Tested (B\u202f=\u202f2000, l\u202f=\u202f7)</span>`;
      
      // Support Direction
      let badgeClass = 'badge-unsupported';
      if (iRow.support_direction === 'Supported Increase') badgeClass = 'badge-increase';
      else if (iRow.support_direction === 'Supported Decrease') badgeClass = 'badge-decrease';
      
      infSupportElem.innerHTML = `<span class="badge-evidence ${badgeClass}">${iRow.support_direction}</span>`;

      // BH-q value
      if (iRow.bh_q_value !== null && iRow.bh_q_value !== undefined) {
        infBhQElem.textContent = iRow.bh_q_value < 0.0001 ? '< 0.0001' : iRow.bh_q_value.toFixed(4);
      } else {
        infBhQElem.textContent = '—';
      }

      // Bootstrap CI
      if (iRow.ci_lower !== null && iRow.ci_upper !== null) {
        infCiElem.textContent = `[${iRow.ci_lower.toFixed(2)}, ${iRow.ci_upper.toFixed(2)}] ${varMeta.unit}`;
      } else {
        infCiElem.textContent = '—';
      }

      // Effect Sizes
      infHedgesElem.textContent = iRow.hedges_g !== null ? iRow.hedges_g.toFixed(3) : '—';
      infCliffsElem.textContent = iRow.cliffs_delta !== null ? iRow.cliffs_delta.toFixed(3) : '—';
      infRobustElem.textContent = iRow.robustness_agreement ? iRow.robustness_agreement.replace(/_/g, ' ') : 'Not Applicable';

      // Interpretive phrasing
      if (iRow.support_direction === 'Unsupported') {
        infNoticeElem.innerHTML = `<strong>Inferential Finding:</strong> No statistically supported temporal shift under the frozen inference criteria (moving-block bootstrap B\u202f=\u202f2000, block length l\u202f=\u202f7, global Benjamini\u2013Hochberg FDR &alpha;\u202f=\u202f0.05).`;
      } else {
        infNoticeElem.innerHTML = `<strong>Inferential Finding:</strong> Statistically supported temporal shift in the ${iRow.support_direction.toLowerCase()} direction (BH-FDR <i>q</i>\u202f=\u202f${iRow.bh_q_value !== null ? iRow.bh_q_value.toFixed(4) : '\u2014'}, CI excludes zero).`;
      }
    } else {
      infTestedElem.innerHTML = `<span class="badge-evidence badge-not-tested">Not Tested</span>`;
      infSupportElem.innerHTML = `<span class="badge-evidence badge-not-tested">Not Tested</span>`;
      infBhQElem.textContent = '—';
      infCiElem.textContent = '—';
      infHedgesElem.textContent = '—';
      infCliffsElem.textContent = '—';
      infRobustElem.textContent = '—';

      infNoticeElem.innerHTML = `<strong>Ineligibility Notice:</strong> This station-variable combination did not satisfy the frozen inference eligibility requirements. Reason: <em>${iRow.ineligibility_reason}</em>.`;
    }

    // Render station overview table for all 7 variables
    renderStationInferenceTable(stationId);
  }

  function renderStationInferenceTable(stationId) {
    if (!stationInferenceTbody) return;
    stationInferenceTbody.innerHTML = '';

    STAT_VARIABLES.forEach(v => {
      const iRow = inferenceData.find(i => i.project_station_id === stationId && i.variable === v.key);
      const dRow = driftData.find(d => d.project_station_id === stationId && d.variable === v.key);

      const tr = document.createElement('tr');

      const varTd = document.createElement('td');
      varTd.innerHTML = `<strong>${v.label}</strong> ${v.verified ? '' : '<span style="font-size: 0.72rem; color: #9CA3AF;">(Source)</span>'}`;

      const dzTd = document.createElement('td');
      dzTd.textContent = (dRow && dRow.drift_z !== null) ? dRow.drift_z.toFixed(3) : '—';

      const magTd = document.createElement('td');
      magTd.textContent = (dRow && dRow.drift_magnitude) ? dRow.drift_magnitude.toUpperCase() : 'INELIGIBLE';

      const testedTd = document.createElement('td');
      testedTd.innerHTML = (iRow && iRow.tested) 
        ? '<span style="color: #15803D; font-weight: 600;">Yes</span>' 
        : '<span style="color: #9CA3AF;">No</span>';

      const dirTd = document.createElement('td');
      if (iRow && iRow.tested) {
        let bCls = 'badge-unsupported';
        if (iRow.support_direction === 'Supported Increase') bCls = 'badge-increase';
        else if (iRow.support_direction === 'Supported Decrease') bCls = 'badge-decrease';
        dirTd.innerHTML = `<span class="badge-evidence ${bCls}">${iRow.support_direction}</span>`;
      } else {
        dirTd.innerHTML = `<span class="badge-evidence badge-not-tested">Not Tested</span>`;
      }

      const qTd = document.createElement('td');
      qTd.textContent = (iRow && iRow.bh_q_value !== null) ? iRow.bh_q_value.toFixed(4) : '—';

      const ciTd = document.createElement('td');
      ciTd.textContent = (iRow && iRow.ci_lower !== null && iRow.ci_upper !== null) 
        ? `[${iRow.ci_lower.toFixed(2)}, ${iRow.ci_upper.toFixed(2)}]` 
        : '—';

      tr.appendChild(varTd);
      tr.appendChild(dzTd);
      tr.appendChild(magTd);
      tr.appendChild(testedTd);
      tr.appendChild(dirTd);
      tr.appendChild(qTd);
      tr.appendChild(ciTd);

      stationInferenceTbody.appendChild(tr);
    });
  }
};
