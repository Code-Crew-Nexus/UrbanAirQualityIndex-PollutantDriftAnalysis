/**
 * explore.js
 * Interactive time-series explorer for 11,970 scheduled station-day observations across 21 CAAQMS stations.
 * Project: UrbanAirQualityIndex-PollutantDriftAnalysis
 * Baseline: v0.6-svm-freeze (FROZEN — READ ONLY)
 */

let exploreState = 'uninitialized';
window.initExploreSection = async function(force = false) {
  if (!force && (exploreState === 'initializing' || exploreState === 'ready')) return;
  exploreState = 'initializing';
  
  const loadingEl = document.getElementById('explore-loading');
  const errorEl = document.getElementById('explore-error');
  const dashEl = document.getElementById('explore-dashboard');
  
  if (loadingEl) loadingEl.style.display = 'block';
  if (errorEl) errorEl.style.display = 'none';
  if (dashEl) dashEl.style.display = 'none';


  'use strict';

  // DOM Elements
  const dataModeSelect = document.getElementById('filter-data-mode');
  const dataModeCalloutTitle = document.getElementById('data-mode-callout-title');
  const dataModeCalloutText = document.getElementById('data-mode-callout-text');
  const scopeSelect = document.getElementById('filter-scope');
  const stationSelect = document.getElementById('filter-station');
  const variableSelect = document.getElementById('filter-variable');
  const startDateInput = document.getElementById('filter-start-date');
  const endDateInput = document.getElementById('filter-end-date');
  const preset90DaysBtn = document.getElementById('btn-preset-90d');
  const presetFullBtn = document.getElementById('btn-preset-full');

  const chartCard = document.getElementById('explore-chart-card');
  const emptyStateCard = document.getElementById('explore-empty-state');
  const loadErrorCard = document.getElementById('explore-load-error');
  const chartCanvas = document.getElementById('exploreChart');
  const chartTitle = document.getElementById('chart-title');
  const chartSubtitle = document.getElementById('chart-subtitle');

  // Summary Metrics Elements
  const metricValidObs = document.getElementById('metric-valid-obs');
  const metricMean = document.getElementById('metric-mean');
  const metricMedian = document.getElementById('metric-median');
  const metricMin = document.getElementById('metric-min');
  const metricMax = document.getElementById('metric-max');
  const metricLatestVal = document.getElementById('metric-latest-val');
  const metricLatestDate = document.getElementById('metric-latest-date');
  const metricLatestLabel = document.getElementById('metric-latest-label');

  // Dataset Inspector Elements (Add-On A)
  const datasetInspectorCard = document.getElementById('dataset-inspector-card');
  const datasetInspectorSubtitle = document.getElementById('dataset-inspector-subtitle');
  const datasetTableWrapper = document.querySelector('.dataset-table-wrapper');
  const datasetTable = document.getElementById('dataset-inspector-table');
  const datasetTableBody = document.getElementById('dataset-table-body');
  const datasetEmptyState = document.getElementById('dataset-empty-state');
  const statusScheduledCount = document.getElementById('status-scheduled-count');
  const statusValidCount = document.getElementById('status-valid-count');
  const statusStationInfo = document.getElementById('status-station-info');
  const btnDownloadCsv = document.getElementById('btn-download-csv');

  // Chart instance
  let exploreChart = null;

  // In-memory data
  let stationsData = [];
  let dailyObservations = [];
  let frozenObservations = [];
  let liveObservations = [];
  let liveLoaded = false;
  let latestLiveDate = '2026-09-26';
  let currentDataMode = 'frozen';

  // Default Study Boundaries
  const STUDY_MIN_DATE = '2025-03-01';
  const STUDY_MAX_DATE = '2026-09-21';
  const DEFAULT_START_DATE = '2026-06-24'; // Exactly 90 calendar days prior to max date

  function showLoadError(isProtocolError) {
    if (chartCard) chartCard.style.display = 'none';
    if (emptyStateCard) emptyStateCard.style.display = 'none';
    if (datasetInspectorCard) datasetInspectorCard.style.display = 'none';
    const metricGrid = document.querySelector('.metric-card-grid');
    if (metricGrid) metricGrid.style.display = 'none';

    if (!loadErrorCard) return;

    if (isProtocolError || window.location.protocol === 'file:') {
      loadErrorCard.innerHTML = `
        <div class="load-error-card local-preview-card">
          <div class="load-error-header">
            <span class="load-error-badge">LOCAL PREVIEW REQUIRED</span>
            <h3 class="load-error-title">Interactive Datasets Require Local HTTP Server</h3>
          </div>
          <p class="load-error-desc">
            Interactive datasets cannot be loaded when this page is opened directly from disk (<code>file://</code>) because modern browser security policies restrict <code>fetch()</code> requests from reading local JSON files.
          </p>
          <div class="load-error-action-box">
            <p class="action-box-label">Start the project's local web server from your terminal:</p>
            <div class="command-copy-wrapper">
              <code id="cmd-local-server">py scripts/serve_website_local.py</code>
              <button type="button" class="btn btn-copy-cmd" id="btn-copy-preview-cmd" aria-label="Copy server command to clipboard">Copy</button>
            </div>
            <p class="action-box-alt">Or using standard Python: <code>py -m http.server 8000 --directory docs</code></p>
            <p class="action-box-sub">Then reopen the page at: <a href="http://localhost:8000/explore.html" class="preview-direct-link">http://localhost:8000/explore.html</a></p>
          </div>
        </div>
      `;
      loadErrorCard.style.display = 'block';

      const copyBtn = document.getElementById('btn-copy-preview-cmd');
      if (copyBtn) {
        copyBtn.addEventListener('click', () => {
          const cmd = document.getElementById('cmd-local-server')?.innerText || 'py scripts/serve_website_local.py';
          navigator.clipboard.writeText(cmd).then(() => {
            copyBtn.textContent = 'Copied!';
            copyBtn.classList.add('copied');
            setTimeout(() => {
              copyBtn.textContent = 'Copy';
              copyBtn.classList.remove('copied');
            }, 2000);
          }).catch(() => {
            copyBtn.textContent = 'Copied!';
          });
        });
      }
    } else {
      loadErrorCard.innerHTML = `
        <div class="load-error-card network-error-card">
          <div class="load-error-header">
            <span class="load-error-badge badge-danger">DATA LOAD ERROR</span>
            <h3 class="load-error-title">Unable to Load the Frozen Scientific Dataset</h3>
          </div>
          <p class="load-error-desc">
            A network or resource error occurred while loading scientific data assets. Please refresh the page or verify network connectivity.
          </p>
        </div>
      `;
      loadErrorCard.style.display = 'block';
    }
  }

  // Pre-flight file:// protocol check
  if (window.location.protocol === 'file:') {
    showLoadError(true);
    return;
  }

  try {
    // 1. Fetch JSON datasets concurrently (cached in page memory)
    const [stations, observations] = await Promise.all([
      DataUtils.fetchJSON('web-data/stations.json'),
      DataUtils.fetchJSON('web-data/daily_observations.json')
    ]);

    stationsData = stations;
    frozenObservations = observations;
    dailyObservations = frozenObservations;

    // 2. Initialize Filter Controls
    await initFilters();

    // 3. Render Initial State

    exploreState = 'ready';
    if (loadingEl) loadingEl.style.display = 'none';
    if (dashEl) dashEl.style.display = 'block';
    updateView();

  

  } catch (err) {
    console.error('Error loading Explore Data assets:', err);
    showLoadError(window.location.protocol === 'file:');
  
    exploreState = 'failed';
    if (loadingEl) loadingEl.style.display = 'none';
    if (errorEl) errorEl.style.display = 'block';
  }

  async function ensureLiveObservationsLoaded() {
    if (liveLoaded) return;
    try {
      const liveData = await DataUtils.fetchJSON('web-data/live_daily_observations.json');
      if (Array.isArray(liveData) && liveData.length > 0) {
        liveObservations = liveData;
        latestLiveDate = liveData.reduce((max, r) => r.date > max ? r.date : max, '2026-09-26');
        liveLoaded = true;
      }
    } catch (e) {
      console.warn('Could not load live_daily_observations.json:', e);
    }
  }

  async function applyDataMode(mode) {
    currentDataMode = mode;
    if (dataModeSelect && dataModeSelect.value !== mode) {
      dataModeSelect.value = mode;
    }

    if (mode === 'live') {
      await ensureLiveObservationsLoaded();
      dailyObservations = liveObservations;
      startDateInput.min = '2026-09-22';
      startDateInput.max = latestLiveDate;
      endDateInput.min = '2026-09-22';
      endDateInput.max = latestLiveDate;
      startDateInput.value = '2026-09-22';
      endDateInput.value = latestLiveDate;

      if (dataModeCalloutTitle) dataModeCalloutTitle.textContent = 'Extended / Live Mode (Operational Extension)';
      if (dataModeCalloutText) {
        dataModeCalloutText.innerHTML = `Displaying operational observations from September 22, 2026 through <strong>${latestLiveDate}</strong> refreshed periodically from OpenAQ v3 and Open-Meteo. These records extend the monitoring timeline but do not alter the frozen v0.6 baseline.`;
      }
      if (preset90DaysBtn) preset90DaysBtn.textContent = 'Full Live Window';
      if (presetFullBtn) presetFullBtn.textContent = 'Full Live Window';
    } else if (mode === 'combined') {
      await ensureLiveObservationsLoaded();
      dailyObservations = [...frozenObservations, ...liveObservations];
      startDateInput.min = STUDY_MIN_DATE;
      startDateInput.max = latestLiveDate;
      endDateInput.min = STUDY_MIN_DATE;
      endDateInput.max = latestLiveDate;
      startDateInput.value = DEFAULT_START_DATE;
      endDateInput.value = latestLiveDate;

      if (dataModeCalloutTitle) dataModeCalloutTitle.textContent = 'Complete Continuity Mode (Frozen Study + Live Extension)';
      if (dataModeCalloutText) {
        dataModeCalloutText.innerHTML = `Displaying the continuous combination of the frozen academic baseline (through September 21, 2026) and operational extension observations (September 22, 2026 onward through <strong>${latestLiveDate}</strong>).`;
      }
      if (preset90DaysBtn) preset90DaysBtn.textContent = 'Latest 90 Days';
      if (presetFullBtn) presetFullBtn.textContent = 'Complete Period';
    } else {
      // 'frozen'
      dailyObservations = frozenObservations;
      startDateInput.min = STUDY_MIN_DATE;
      startDateInput.max = STUDY_MAX_DATE;
      endDateInput.min = STUDY_MIN_DATE;
      endDateInput.max = STUDY_MAX_DATE;
      startDateInput.value = DEFAULT_START_DATE;
      endDateInput.value = STUDY_MAX_DATE;

      if (dataModeCalloutTitle) dataModeCalloutTitle.textContent = 'Academic Review Mode (v0.6-svm-freeze)';
      if (dataModeCalloutText) {
        dataModeCalloutText.innerHTML = `Displaying the frozen scientific evaluation baseline spanning 570 calendar days (March 1, 2025 to September 21, 2026). All values, KPIs, and distributions strictly match the submitted PBL report. Switch to <em>Extended / Live</em> to inspect operational observations from September 22, 2026 onward.`;
      }
      if (preset90DaysBtn) preset90DaysBtn.textContent = 'Latest 90 Days';
      if (presetFullBtn) presetFullBtn.textContent = 'Full Study Period';
    }

    const modeNotice = document.getElementById('mode-aware-methodological-notice');
    if (modeNotice) {
      if (mode === 'frozen') {
        modeNotice.textContent = "Metrics shown for this mode use the frozen academic study baseline.";
      } else if (mode === 'live') {
        modeNotice.textContent = "Metrics shown for this mode use periodically refreshed operational extension observations; this is not continuous real-time streaming.";
      } else if (mode === 'combined') {
        modeNotice.textContent = "Metrics shown combine the frozen academic baseline with periodically refreshed operational-extension observations.";
      }
    }

    preset90DaysBtn.classList.add('active');
    presetFullBtn.classList.remove('active');
  }

  function normalizeScope(scopeStr) {
    if (!scopeStr) return null;
    const s = decodeURIComponent(scopeStr).trim().toLowerCase();
    if (s === 'hyderabad') return 'Hyderabad';
    if (s === 'india' || s === 'india representative panel') return 'India';
    return null;
  }

  function normalizeVariable(varStr) {
    if (!varStr) return null;
    const clean = decodeURIComponent(varStr).trim().toLowerCase().replace(/[-_\s.]/g, '');
    if (clean === 'aqi' || clean === 'aqiverified') return 'AQI';
    if (clean === 'pm25' || clean === 'pm25aqiinput') return 'PM2.5';
    if (clean === 'pm10' || clean === 'pm10aqiinput') return 'PM10';
    if (clean === 'o3' || clean === 'ozone' || clean === 'o38hmax') return 'O3';
    if (clean === 'temperature' || clean === 'temp') return 'Temperature';
    if (clean === 'humidity' || clean === 'rh') return 'Humidity';
    if (clean === 'windspeed' || clean === 'wind') return 'Wind Speed';
    return null;
  }

  async function initFilters() {
    // Set date defaults
    startDateInput.min = STUDY_MIN_DATE;
    startDateInput.max = STUDY_MAX_DATE;
    endDateInput.min = STUDY_MIN_DATE;
    endDateInput.max = STUDY_MAX_DATE;

    startDateInput.value = DEFAULT_START_DATE;
    endDateInput.value = STUDY_MAX_DATE;

    // Populate stations according to initial Scope (Hyderabad)
    populateStations('Hyderabad');

    // Event listeners
    if (dataModeSelect) {
      dataModeSelect.addEventListener('change', async () => {
        await applyDataMode(dataModeSelect.value);
        updateView();
      });
    }

    scopeSelect.addEventListener('change', () => {
      populateStations(scopeSelect.value);
      updateView();
    });

    stationSelect.addEventListener('change', updateView);
    variableSelect.addEventListener('change', updateView);
    startDateInput.addEventListener('change', () => {
      clearPresetHighlight();
      updateView();
    });
    endDateInput.addEventListener('change', () => {
      clearPresetHighlight();
      updateView();
    });

    // Preset Buttons
    preset90DaysBtn.addEventListener('click', () => {
      if (currentDataMode === 'live') {
        startDateInput.value = '2026-09-22';
        endDateInput.value = latestLiveDate;
      } else if (currentDataMode === 'combined') {
        startDateInput.value = DEFAULT_START_DATE;
        endDateInput.value = latestLiveDate;
      } else {
        startDateInput.value = DEFAULT_START_DATE;
        endDateInput.value = STUDY_MAX_DATE;
      }
      preset90DaysBtn.classList.add('active');
      presetFullBtn.classList.remove('active');
      updateView();
    });

    presetFullBtn.addEventListener('click', () => {
      if (currentDataMode === 'live') {
        startDateInput.value = '2026-09-22';
        endDateInput.value = latestLiveDate;
      } else if (currentDataMode === 'combined') {
        startDateInput.value = STUDY_MIN_DATE;
        endDateInput.value = latestLiveDate;
      } else {
        startDateInput.value = STUDY_MIN_DATE;
        endDateInput.value = STUDY_MAX_DATE;
      }
      presetFullBtn.classList.add('active');
      preset90DaysBtn.classList.remove('active');
      updateView();
    });

    // URL parameters for deep-linking
    const urlParams = new URLSearchParams(window.location.search);
    if (urlParams.has('mode')) {
      const m = urlParams.get('mode').toLowerCase();
      if (m === 'live' || m === 'combined' || m === 'frozen') {
        await applyDataMode(m);
      }
    }
    if (urlParams.has('scope')) {
      const s = normalizeScope(urlParams.get('scope'));
      if (s) {
        scopeSelect.value = s;
        populateStations(s);
      }
    }
    if (urlParams.has('station')) {
      const stParam = urlParams.get('station');
      const optExists = Array.from(stationSelect.options).some(o => o.value === stParam);
      if (optExists) {
        stationSelect.value = stParam;
      }
    }
    if (urlParams.has('variable')) {
      const v = normalizeVariable(urlParams.get('variable'));
      if (v) {
        variableSelect.value = v;
      }
    }
    if (urlParams.has('start')) {
      startDateInput.value = urlParams.get('start');
      clearPresetHighlight();
    }
    if (urlParams.has('end')) {
      endDateInput.value = urlParams.get('end');
      clearPresetHighlight();
    }
  }

  function clearPresetHighlight() {
    preset90DaysBtn.classList.remove('active');
    presetFullBtn.classList.remove('active');
  }

  function populateStations(selectedScope) {
    const prevStation = stationSelect.value;
    stationSelect.innerHTML = '';

    const isHyd = selectedScope === 'Hyderabad';
    const filteredStations = stationsData.filter(st => {
      if (isHyd) return st.use_hyderabad === true;
      return st.use_india === true;
    });

    filteredStations.forEach((st, idx) => {
      const opt = document.createElement('option');
      opt.value = st.project_station_id;
      opt.textContent = `${st.project_station_id}: ${st.station_name} (${st.city})`;
      stationSelect.appendChild(opt);
    });

    // Retain previous station if valid in new scope (e.g. Zoo Park PROJ_007), otherwise select first
    const exists = Array.from(stationSelect.options).some(o => o.value === prevStation);
    if (exists && prevStation) {
      stationSelect.value = prevStation;
    } else if (stationSelect.options.length > 0) {
      stationSelect.selectedIndex = 0;
    }
  }

  function updateView() {
    const stationId = stationSelect.value;
    const varKey = variableSelect.value;
    const startDate = startDateInput.value;
    const endDate = endDateInput.value;

    const varConfig = DataUtils.VARIABLE_MAP[varKey] || DataUtils.VARIABLE_MAP['AQI'];
    const stationObj = stationsData.find(s => s.project_station_id === stationId);
    const stationName = stationObj ? stationObj.station_name : stationId;

    // Filter observations for selected station and date range
    const filtered = dailyObservations.filter(row => {
      return row.project_station_id === stationId &&
             row.date >= startDate &&
             row.date <= endDate;
    }).sort((a, b) => (a.date > b.date ? 1 : -1));

    // Extract valid variable values
    const rawValues = filtered.map(r => r[varConfig.key]);
    const validValues = rawValues.filter(v => v !== null && v !== undefined && !isNaN(v));

    // Update Header
    chartTitle.textContent = `${varConfig.fullLabel} — ${stationName}`;
    
    // Missingness logic
    const totalDays = filtered.length;
    const validDays = filtered.filter(r => r[varConfig.key] !== null && r[varConfig.key] !== undefined && !isNaN(r[varConfig.key])).length;
    
    if (validDays < totalDays && varConfig.key === 'aqi_verified') {
        chartSubtitle.innerHTML = `${stationObj.station_name} | ${startDate} to ${endDate}<br><span style="color:#d9534f; font-weight:bold;">Valid AQI available for ${validDays} of ${totalDays} scheduled station-days. Missing AQI dates are intentionally not interpolated because required verified-pollutant coverage was insufficient.</span>`;
    } else {
        chartSubtitle.textContent = `${stationObj.station_name} | ${startDate} to ${endDate}`;
    }


    // Update Latest Label (Strict wording: "Latest Valid AQI" vs "Latest Valid Value", never "Current AQI")
    if (varConfig.isAQI) {
      metricLatestLabel.textContent = 'Latest Valid AQI';
    } else {
      metricLatestLabel.textContent = 'Latest Valid Value';
    }

    // Check empty state for chart
    if (validValues.length === 0) {
      chartCard.style.display = 'none';
      emptyStateCard.style.display = 'block';
      renderEmptyMetrics(varConfig);
    } else {
      // Show Chart, Hide Empty State
      emptyStateCard.style.display = 'none';
      chartCard.style.display = 'block';

      // Compute Client-Side Summary Metrics
      const meanVal = DataUtils.calculateMean(validValues);
      const medianVal = DataUtils.calculateMedian(validValues);
      const minVal = DataUtils.calculateMin(validValues);
      const maxVal = DataUtils.calculateMax(validValues);

      // Latest valid observation
      let latestVal = null;
      let latestDate = null;
      for (let i = filtered.length - 1; i >= 0; i--) {
        const v = filtered[i][varConfig.key];
        if (v !== null && v !== undefined && !isNaN(v)) {
          latestVal = v;
          latestDate = filtered[i].date;
          break;
        }
      }

      // Render Metrics
      metricValidObs.textContent = `${validValues.length} / ${filtered.length} days`;
      metricMean.textContent = `${DataUtils.formatNumber(meanVal, varConfig.decimals)} ${varConfig.unit}`;
      metricMedian.textContent = `${DataUtils.formatNumber(medianVal, varConfig.decimals)} ${varConfig.unit}`;
      metricMin.textContent = `${DataUtils.formatNumber(minVal, varConfig.decimals)} ${varConfig.unit}`;
      metricMax.textContent = `${DataUtils.formatNumber(maxVal, varConfig.decimals)} ${varConfig.unit}`;
      
      if (latestVal !== null) {
        metricLatestVal.textContent = `${DataUtils.formatNumber(latestVal, varConfig.decimals)} ${varConfig.unit}`;
        metricLatestDate.textContent = `Observed on ${latestDate}`;
      } else {
        metricLatestVal.textContent = '—';
        metricLatestDate.textContent = 'No valid observation';
      }

      // Render Chart
      renderChart(filtered, varConfig);
    }

    // Always update Dataset Inspector for the current filtered observations
    renderDatasetInspector(filtered, stationObj, varConfig, startDate, endDate);
  }

  function renderEmptyMetrics(varConfig) {
    metricValidObs.textContent = '0 days';
    metricMean.textContent = '—';
    metricMedian.textContent = '—';
    metricMin.textContent = '—';
    metricMax.textContent = '—';
    metricLatestVal.textContent = '—';
    metricLatestDate.textContent = 'No valid observation';
  }

  function renderChart(dataRows, varConfig) {
    const labels = dataRows.map(r => r.date);
    const dataPoints = dataRows.map(r => {
      const v = r[varConfig.key];
      return (v === null || v === undefined) ? null : Number(v);
    });

    // Semantic point coloring for AQI
    let pointColors = DataUtils.THEME.jadeDeep;
    if (varConfig.isAQI) {
      pointColors = dataPoints.map(val => {
        if (val === null) return 'transparent';
        return DataUtils.getAQICategory(val).color;
      });
    }

    if (exploreChart) {
      exploreChart.destroy();
    }

    const ctx = chartCanvas.getContext('2d');
    exploreChart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [{
          label: `${varConfig.label} (${varConfig.unit})`,
          data: dataPoints,
          borderColor: DataUtils.THEME.jadeDeep,
          backgroundColor: 'rgba(40, 95, 73, 0.08)',
          borderWidth: 2,
          pointRadius: labels.length > 180 ? 1.5 : 3,
          pointHoverRadius: 6,
          pointBackgroundColor: pointColors,
          pointBorderColor: pointColors,
          fill: true,
          tension: 0.15,
          spanGaps: false // strictly omit missing values without drawing connecting line
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: 'index',
          intersect: false
        },
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            backgroundColor: 'rgba(31, 36, 33, 0.92)',
            titleFont: { family: 'inherit', size: 12 },
            bodyFont: { family: 'inherit', size: 12 },
            padding: 10,
            cornerRadius: 6,
            callbacks: {
              label: function (context) {
                const val = context.parsed.y;
                if (val === null || isNaN(val)) return 'Missing / Invalid observation';
                if (varConfig.isAQI) {
                  const cat = DataUtils.getAQICategory(val);
                  return `AQI: ${val.toFixed(1)} (${cat.category})`;
                }
                return `${varConfig.label}: ${val.toFixed(varConfig.decimals)} ${varConfig.unit}`;
              }
            }
          }
        },
        scales: {
          x: {
            grid: {
              color: 'rgba(0, 0, 0, 0.04)'
            },
            ticks: {
              maxTicksLimit: 12,
              font: { family: 'inherit', size: 11 },
              color: DataUtils.THEME.graphiteLight
            }
          },
          y: {
            beginAtZero: false,
            grid: {
              color: 'rgba(0, 0, 0, 0.06)'
            },
            ticks: {
              font: { family: 'inherit', size: 11 },
              color: DataUtils.THEME.graphiteLight,
              callback: function (val) {
                return `${val} ${varConfig.unit}`;
              }
            },
            title: {
              display: true,
              text: `${varConfig.label} (${varConfig.unit})`,
              color: DataUtils.THEME.graphiteDark,
              font: { family: 'inherit', size: 12, weight: 600 }
            }
          }
        }
      }
    });
  }

  // =========================================================================
  // G5 Add-On A: Dataset Inspector Implementation
  // =========================================================================

  function escapeHtml(str) {
    if (str === null || str === undefined) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  function formatVal(val, decimals) {
    if (val === null || val === undefined || isNaN(val) || val === '') {
      return '<span class="val-missing" title="Missing / unavailable" aria-label="Missing / unavailable">—</span>';
    }
    return Number(val).toFixed(decimals);
  }

  function formatValRaw(val, decimals, unit) {
    if (val === null || val === undefined || isNaN(val) || val === '') {
      return '<span class="val-missing" title="Missing / unavailable" aria-label="Missing / unavailable">—</span>';
    }
    const numStr = Number(val).toFixed(decimals);
    return unit ? `${numStr} ${unit}` : numStr;
  }

  function getCategoryBadge(category) {
    if (!category) {
      return '<span class="val-missing" title="Missing / unavailable" aria-label="Missing / unavailable">—</span>';
    }
    const catLower = String(category).toLowerCase().replace(/[^a-z]/g, '-');
    let badgeClass = 'aqi-badge--moderate';
    if (catLower.includes('good')) badgeClass = 'aqi-badge--good';
    else if (catLower.includes('satisfactory')) badgeClass = 'aqi-badge--satisfactory';
    else if (catLower.includes('very-poor')) badgeClass = 'aqi-badge--very-poor';
    else if (catLower.includes('poor')) badgeClass = 'aqi-badge--poor';
    else if (catLower.includes('severe')) badgeClass = 'aqi-badge--severe';

    return `<span class="aqi-badge ${badgeClass}">${escapeHtml(category)}</span>`;
  }

  function formatDateLabel(dateStr) {
    if (!dateStr) return '';
    const parts = dateStr.split('-');
    if (parts.length !== 3) return dateStr;
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    const m = parseInt(parts[1], 10) - 1;
    return `${parseInt(parts[2], 10)} ${months[m] || parts[1]} ${parts[0]}`;
  }

  function renderDatasetInspector(filteredRows, stationObj, varConfig, startDate, endDate) {
    if (datasetInspectorSubtitle) {
      if (currentDataMode === 'frozen') {
        datasetInspectorSubtitle.textContent = 'Filtered frozen study observations used by the visualization above.';
      } else if (currentDataMode === 'live') {
        datasetInspectorSubtitle.textContent = 'Filtered operational-extension observations used by the visualization above.';
      } else {
        datasetInspectorSubtitle.textContent = 'Filtered frozen + operational-extension observations used by the visualization above.';
      }
    }

    if (!datasetTableBody || !datasetTable) return;

    if (!filteredRows || filteredRows.length === 0) {
      if (datasetEmptyState) datasetEmptyState.style.display = 'block';
      datasetTable.style.display = 'none';
      if (statusScheduledCount) statusScheduledCount.textContent = '0 scheduled records';
      if (statusValidCount) statusValidCount.textContent = '0 valid observations';
      if (statusStationInfo) statusStationInfo.textContent = stationObj ? `${stationObj.station_name} (${stationObj.project_station_id})` : 'Selected station';
      if (btnDownloadCsv) btnDownloadCsv.disabled = true;
      datasetTableBody.innerHTML = '';
      return;
    }

    if (datasetEmptyState) datasetEmptyState.style.display = 'none';
    datasetTable.style.display = '';
    if (btnDownloadCsv) btnDownloadCsv.disabled = false;

    // Count valid observations
    const validVarCount = filteredRows.filter(r => r[varConfig.key] !== null && r[varConfig.key] !== undefined && !isNaN(r[varConfig.key])).length;
    const validAqiCount = filteredRows.filter(r => r.aqi_verified !== null && r.aqi_verified !== undefined && !isNaN(r.aqi_verified)).length;

    if (statusScheduledCount) statusScheduledCount.textContent = `${filteredRows.length} scheduled station-days`;
    if (statusValidCount) {
      statusValidCount.textContent = varConfig.isAQI 
        ? `${validAqiCount} valid AQI observations` 
        : `${validVarCount} valid ${varConfig.label} observations`;
    }
    if (statusStationInfo) statusStationInfo.textContent = `${stationObj.station_name} (${stationObj.project_station_id})`;

    // Efficient DOM rendering with DocumentFragment
    const fragment = document.createDocumentFragment();

    filteredRows.forEach((r) => {
      const rowId = `dataset-detail-${r.project_station_id}-${r.date}`;
      const dateLabel = formatDateLabel(r.date);
      const isFrozen = r.date <= '2026-09-21';
      const streamBadge = isFrozen
        ? '<span class="stream-badge stream-badge--frozen">Frozen Study</span>'
        : '<span class="stream-badge stream-badge--live">Live Extension</span>';

      // Main observation row
      const tr = document.createElement('tr');
      tr.className = 'dataset-row';
      tr.id = `dataset-row-${r.date}`;

      tr.innerHTML = `
        <td class="sticky-col">
          <button type="button" class="row-expand-btn" aria-expanded="false" aria-controls="${rowId}" aria-label="View complete record for ${dateLabel}">
            <span class="expand-icon" aria-hidden="true">▸</span>
          </button>
          <span class="row-date">${r.date}</span>
        </td>
        <td>${streamBadge}</td>
        <td>${formatVal(r.aqi_verified, 1)}</td>
        <td>${getCategoryBadge(r.aqi_category)}</td>
        <td>${r.dominant_pollutant ? `<code style="font-size:0.78rem; text-transform:uppercase;">${escapeHtml(r.dominant_pollutant)}</code>` : '<span class="val-missing" title="Missing / unavailable" aria-label="Missing / unavailable">—</span>'}</td>
        <td>${formatVal(r.pm2_5_aqi_input, 1)}</td>
        <td>${formatVal(r.pm10_aqi_input, 1)}</td>
        <td>${formatVal(r.o3_8h_max, 1)}</td>
        <td>${formatVal(r.temperature, 1)}</td>
        <td>${formatVal(r.humidity, 1)}</td>
        <td>${formatVal(r.wind_speed, 2)}</td>
      `;

      // Expandable detail row
      const detailTr = document.createElement('tr');
      detailTr.id = rowId;
      detailTr.className = 'dataset-detail-row';
      detailTr.style.display = 'none';
      detailTr.hidden = true;

      detailTr.innerHTML = `
        <td colspan="11" class="dataset-detail-cell">
          <div class="record-detail-card" role="region" aria-label="Observation details for ${dateLabel}">
            <div class="record-detail-grid">
              <!-- Identification -->
              <div class="detail-section">
                <div class="detail-section-title">Identification</div>
                <div class="detail-item"><span class="detail-label">Station ID:</span><span class="detail-value">${escapeHtml(stationObj.project_station_id)}</span></div>
                <div class="detail-item"><span class="detail-label">Station:</span><span class="detail-value" style="font-family:inherit; font-size:0.75rem;">${escapeHtml(stationObj.station_name)}</span></div>
                <div class="detail-item"><span class="detail-label">City, State:</span><span class="detail-value" style="font-family:inherit;">${escapeHtml(stationObj.city)}, ${escapeHtml(stationObj.state)}</span></div>
                <div class="detail-item"><span class="detail-label">Date:</span><span class="detail-value">${escapeHtml(r.date)}</span></div>
                <div class="detail-item"><span class="detail-label">Data Stream:</span><span class="detail-value" style="font-family:inherit; font-size:0.75rem;">${isFrozen ? 'Frozen Academic Baseline (v0.6-svm-freeze)' : 'Live Extension (Operational Update)'}</span></div>
                <div class="detail-item"><span class="detail-label">Panel Role:</span><span class="detail-value" style="font-family:inherit; font-size:0.72rem;">${escapeHtml(stationObj.panel_role || (stationObj.use_hyderabad ? 'Hyderabad Panel' : 'India Panel'))}</span></div>
              </div>

              <!-- AQI Composite -->
              <div class="detail-section">
                <div class="detail-section-title">AQI Composite</div>
                <div class="detail-item"><span class="detail-label">Verified-Subset AQI:</span><span class="detail-value">${formatValRaw(r.aqi_verified, 1, 'Index units')}</span></div>
                <div class="detail-item"><span class="detail-label">CPCB Category:</span><span class="detail-value">${r.aqi_category ? escapeHtml(r.aqi_category) : '<span class="val-missing">—</span>'}</span></div>
                <div class="detail-item"><span class="detail-label">Dominant Pollutant:</span><span class="detail-value">${r.dominant_pollutant ? escapeHtml(r.dominant_pollutant.toUpperCase()) : '<span class="val-missing">—</span>'}</span></div>
                <div class="detail-item"><span class="detail-label">Sufficiency Status:</span><span class="detail-value" style="font-family:inherit; font-size:0.75rem;">${r.aqi_verified !== null ? 'Validated (3 pollutants)' : 'Incomplete coverage'}</span></div>
              </div>

              <!-- Pollutant Inputs -->
              <div class="detail-section">
                <div class="detail-section-title">Pollutant Inputs</div>
                <div class="detail-item"><span class="detail-label">PM2.5 (24-hr avg):</span><span class="detail-value">${formatValRaw(r.pm2_5_aqi_input, 1, 'µg/m³')}</span></div>
                <div class="detail-item"><span class="detail-label">PM10 (24-hr avg):</span><span class="detail-value">${formatValRaw(r.pm10_aqi_input, 1, 'µg/m³')}</span></div>
                <div class="detail-item"><span class="detail-label">O3 (8h daily max):</span><span class="detail-value">${formatValRaw(r.o3_8h_max, 1, 'µg/m³')}</span></div>
              </div>

              <!-- Meteorology -->
              <div class="detail-section">
                <div class="detail-section-title">Meteorology</div>
                <div class="detail-item"><span class="detail-label">Temperature:</span><span class="detail-value">${formatValRaw(r.temperature, 1, '°C')}</span></div>
                <div class="detail-item"><span class="detail-label">Relative Humidity:</span><span class="detail-value">${formatValRaw(r.humidity, 1, '%')}</span></div>
                <div class="detail-item"><span class="detail-label">Wind Speed:</span><span class="detail-value">${formatValRaw(r.wind_speed, 2, 'm/s')}</span></div>
              </div>
            </div>
          </div>
        </td>
      `;

      fragment.appendChild(tr);
      fragment.appendChild(detailTr);
    });

    datasetTableBody.innerHTML = '';
    datasetTableBody.appendChild(fragment);

    // Setup CSV Download handler with current filtered observations
    setupCsvDownload(filteredRows, stationObj, startDate, endDate);
  }

  function setupCsvDownload(filteredRows, stationObj, startDate, endDate) {
    if (!btnDownloadCsv) return;

    btnDownloadCsv.onclick = function() {
      if (!filteredRows || filteredRows.length === 0) return;

      const headers = [
        'project_station_id',
        'station_name',
        'city',
        'state',
        'date',
        'data_stream',
        'aqi_verified',
        'aqi_category',
        'dominant_pollutant',
        'pm2_5_aqi_input',
        'pm10_aqi_input',
        'o3_8h_max',
        'temperature',
        'humidity',
        'wind_speed'
      ];

      const escapeCsvCell = (val) => {
        if (val === null || val === undefined) return '';
        const str = String(val);
        if (str.includes(',') || str.includes('"') || str.includes('\n')) {
          return '"' + str.replace(/"/g, '""') + '"';
        }
        return str;
      };

      const lines = [headers.join(',')];

      filteredRows.forEach(row => {
        const isFrozen = row.date <= '2026-09-21';
        const cells = [
          escapeCsvCell(stationObj.project_station_id),
          escapeCsvCell(stationObj.station_name),
          escapeCsvCell(stationObj.city),
          escapeCsvCell(stationObj.state),
          escapeCsvCell(row.date),
          escapeCsvCell(isFrozen ? 'Frozen Study' : 'Live Extension'),
          escapeCsvCell(row.aqi_verified),
          escapeCsvCell(row.aqi_category),
          escapeCsvCell(row.dominant_pollutant),
          escapeCsvCell(row.pm2_5_aqi_input),
          escapeCsvCell(row.pm10_aqi_input),
          escapeCsvCell(row.o3_8h_max),
          escapeCsvCell(row.temperature),
          escapeCsvCell(row.humidity),
          escapeCsvCell(row.wind_speed)
        ];
        lines.push(cells.join(','));
      });

      const csvContent = '\uFEFF' + lines.join('\r\n');
      const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      const filename = `UAQI_${stationObj.project_station_id}_${startDate}_${endDate}.csv`;
      link.setAttribute('href', url);
      link.setAttribute('download', filename);
      link.style.display = 'none';
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      URL.revokeObjectURL(url);
    };
  }

  // Row expansion delegation
  if (datasetTableBody) {
    datasetTableBody.addEventListener('click', (e) => {
      const btn = e.target.closest('.row-expand-btn');
      if (!btn) return;
      const targetId = btn.getAttribute('aria-controls');
      const detailRow = document.getElementById(targetId);
      const parentRow = btn.closest('tr');
      const icon = btn.querySelector('.expand-icon');
      if (!detailRow) return;

      const isExpanded = btn.getAttribute('aria-expanded') === 'true';
      if (isExpanded) {
        btn.setAttribute('aria-expanded', 'false');
        if (icon) icon.textContent = '▸';
        detailRow.style.display = 'none';
        detailRow.hidden = true;
        if (parentRow) parentRow.classList.remove('expanded');
      } else {
        btn.setAttribute('aria-expanded', 'true');
        if (icon) icon.textContent = '▾';
        detailRow.style.display = '';
        detailRow.hidden = false;
        if (parentRow) parentRow.classList.add('expanded');
      }
    });
  }
};
