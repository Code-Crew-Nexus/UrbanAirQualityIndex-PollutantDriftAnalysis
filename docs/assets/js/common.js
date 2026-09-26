/**
 * common.js
 * Shared utility functions, responsive navigation toggle, and common metadata helpers.
 * 
 * Project: UrbanAirQualityIndex-PollutantDriftAnalysis
 * Path Safety: Relative paths only (GitHub Pages project site safe).
 */

(function (window) {
  "use strict";

  const AppCommon = {
    /**
     * Initializes responsive navigation toggling.
     */
    initNavigation: function () {
      const navToggle = document.querySelector(".nav-toggle");
      const mainNav = document.querySelector(".main-nav");

      if (navToggle && mainNav) {
        navToggle.addEventListener("click", function () {
          const isOpen = mainNav.classList.toggle("open");
          navToggle.setAttribute("aria-expanded", isOpen ? "true" : "false");
        });
      }

      // Highlight active nav item based on current page URL
      const currentPath = window.location.pathname;
      const navLinks = document.querySelectorAll(".nav-link");
      
      navLinks.forEach(function (link) {
        const href = link.getAttribute("href");
        if (!href) return;

        // Extract filename
        const page = href.split("/").pop().split("#")[0] || "index.html";
        const currentFilename = currentPath.split("/").pop() || "index.html";

        if (page === currentFilename) {
          link.classList.add("active");
          link.setAttribute("aria-current", "page");
        } else {
          link.classList.remove("active");
          link.removeAttribute("aria-current");
        }
      });
    },

    /**
     * Helper to fetch JSON data with robust error reporting.
     */
    fetchJson: function (relativePath) {
      return fetch(relativePath)
        .then(function (response) {
          if (!response.ok) {
            throw new Error(`Failed to load ${relativePath}: ${response.status} ${response.statusText}`);
          }
          return response.json();
        });
    }
  };

  // Export to window
  window.AppCommon = AppCommon;

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", AppCommon.initNavigation);
  } else {
    AppCommon.initNavigation();
  }
})(typeof window !== "undefined" ? window : this);
