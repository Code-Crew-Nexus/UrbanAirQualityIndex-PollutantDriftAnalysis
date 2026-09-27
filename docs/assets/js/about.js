/**
 * about.js
 * Hydrates team roster and project provenance data on the About page.
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
          const rosterTableBody = document.getElementById("team-roster-body");
          if (rosterTableBody && data.team) {
            rosterTableBody.innerHTML = "";
            data.team.forEach(function (member) {
              const tr = document.createElement("tr");
              const memberName = member.name === "RISHIT GHOSH" ? "Rishit Ghosh" : member.name;
              tr.innerHTML = `
                <td><strong>${memberName}</strong></td>
                <td><code>${member.roll_number}</code></td>
                <td><a href="https://github.com/${member.github.replace('@', '')}" target="_blank" rel="noopener noreferrer">${member.github}</a></td>
              `;
              rosterTableBody.appendChild(tr);
            });
          }

          // Hydrate milestone tag badges if container exists
          const tagContainer = document.getElementById("frozen-tags-container");
          if (tagContainer && data.modeling_baseline) {
            const allTags = [data.modeling_baseline.latest_tag].concat(data.modeling_baseline.previous_tags || []);
            tagContainer.innerHTML = allTags.map(function (tag) {
              return `<span class="intro-badge" style="margin-right: 0.5rem;">${tag}</span>`;
            }).join("");
          }
        })
        .catch(function (err) {
          console.warn("Could not load dynamic summary on about page, retaining static markup:", err);
        });
    }
  });
})(typeof window !== "undefined" ? window : this);
