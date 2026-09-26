/**
 * home.js
 * Drives dynamic metric loading for the Home presentation page.
 * 
 * Project: UrbanAirQualityIndex-PollutantDriftAnalysis
 * Baseline: v0.6-svm-freeze
 */

(function (window) {
  "use strict";

  document.addEventListener("DOMContentLoaded", function () {
    const summaryPath = "web-data/project_summary.json";

    if (window.AppCommon && window.AppCommon.fetchJson) {
      window.AppCommon.fetchJson(summaryPath)
        .then(function (data) {
          // Populate summary cards
          const elStations = document.getElementById("stat-stations");
          const elDays = document.getElementById("stat-days");
          const elPanels = document.getElementById("stat-panels");
          const elBaseline = document.getElementById("stat-baseline");

          if (elStations && data.study_scope) {
            elStations.innerText = data.study_scope.total_physical_stations;
          }
          if (elDays && data.study_period) {
            elDays.innerText = data.study_period.total_study_days;
          }
          if (elPanels && data.study_scope) {
            elPanels.innerText = `${data.study_scope.hyderabad_stations} + ${data.study_scope.india_representative_stations}`;
          }
          if (elBaseline && data.modeling_baseline) {
            elBaseline.innerText = data.modeling_baseline.latest_tag.split("-")[0];
          }

          // Populate study dates
          const elDateRange = document.getElementById("study-date-range");
          if (elDateRange && data.study_period) {
            elDateRange.innerText = `${data.study_period.start_date} to ${data.study_period.end_date}`;
          }
        })
        .catch(function (err) {
          console.warn("Could not load dynamic project summary, retaining static defaults:", err);
        });
    }
  });
})(typeof window !== "undefined" ? window : this);
