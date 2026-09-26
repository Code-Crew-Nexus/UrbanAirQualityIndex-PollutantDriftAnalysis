/**
 * explore.js
 * Interactive time-series explorer for 11,970 scheduled station-day observations across 21 CAAQMS stations.
 * Project: UrbanAirQualityIndex-PollutantDriftAnalysis
 * Baseline: v0.6-svm-freeze (FROZEN — READ ONLY)
 */

document.addEventListener('DOMContentLoaded', async () => {
  'use strict';

  // DOM Elements
  const scopeSelect = document.getElementById('filter-scope');
  const stationSelect = document.getElementById('filter-station');
  const variableSelect = document.getElementById('filter-variable');
  const startDateInput = document.getElementById('filter-start-date');
  const endDateInput = document.getElementById('filter-end-date');
  const preset90DaysBtn = document.getElementById('btn-preset-90d');
  const presetFullBtn = document.getElementById('btn-preset-full');

  const chartCard = document.getElementById('explore-chart-card');
  const emptyStateCard = document.getElementById('explore-empty-state');
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

  // Chart instance
  let exploreChart = null;

  // In-memory data
  let stationsData = [];
  let dailyObservations = [];

  // Default Study Boundaries
  const STUDY_MIN_DATE = '2025-03-01';
  const STUDY_MAX_DATE = '2026-09-21';
  const DEFAULT_START_DATE = '2026-06-24'; // Exactly 90 calendar days prior to max date

  try {
    // 1. Fetch JSON datasets concurrently (cached in page memory)
    const [stations, observations] = await Promise.all([
      DataUtils.fetchJSON('web-data/stations.json'),
      DataUtils.fetchJSON('web-data/daily_observations.json')
    ]);

    stationsData = stations;
    dailyObservations = observations;

    // 2. Initialize Filter Controls
    initFilters();

    // 3. Render Initial State
    updateView();

  } catch (err) {
    console.error('Error loading Explore Data assets:', err);
    if (chartCard) chartCard.style.display = 'none';
    if (emptyStateCard) {
      emptyStateCard.style.display = 'block';
      const textElem = emptyStateCard.querySelector('.empty-state-text');
      if (textElem) textElem.textContent = 'Failed to load scientific observations dataset.';
    }
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

  function initFilters() {
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
      startDateInput.value = DEFAULT_START_DATE;
      endDateInput.value = STUDY_MAX_DATE;
      preset90DaysBtn.classList.add('active');
      presetFullBtn.classList.remove('active');
      updateView();
    });

    // URL parameters for deep-linking
    const urlParams = new URLSearchParams(window.location.search);
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
    chartSubtitle.textContent = `Date Range: ${startDate} to ${endDate} (${validValues.length} valid / ${filtered.length} scheduled days)`;

    // Update Latest Label (Strict wording: "Latest Valid AQI" vs "Latest Valid Value", never "Current AQI")
    if (varConfig.isAQI) {
      metricLatestLabel.textContent = 'Latest Valid AQI';
    } else {
      metricLatestLabel.textContent = 'Latest Valid Value';
    }

    // Check empty state
    if (validValues.length === 0) {
      chartCard.style.display = 'none';
      emptyStateCard.style.display = 'block';
      renderEmptyMetrics(varConfig);
      return;
    }

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
});
