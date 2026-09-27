/**
 * common.js
 * Shared utility functions, responsive navigation toggle, and common metadata helpers.
 * G5: Added keyboard tablist navigation (roving tabindex, ArrowLeft/Right/Home/End),
 *     mobile nav Escape-to-close, close-on-link-activate, aria-controls on nav toggle.
 *
 * Project: UrbanAirQualityIndex-PollutantDriftAnalysis
 * Path Safety: Relative paths only (GitHub Pages project site safe).
 */

(function (window) {
  "use strict";

  const AppCommon = {
    /**
     * Initializes responsive navigation toggling with full a11y support.
     */
    initNavigation: function () {
      const navToggle = document.querySelector(".nav-toggle");
      const mainNav = document.querySelector(".main-nav");

      // Add stable id for aria-controls
      if (mainNav && !mainNav.id) {
        mainNav.id = "primary-navigation";
      }

      if (navToggle && mainNav) {
        // Wire aria-controls to nav
        navToggle.setAttribute("aria-controls", "primary-navigation");

        navToggle.addEventListener("click", function () {
          const isOpen = mainNav.classList.toggle("open");
          navToggle.setAttribute("aria-expanded", isOpen ? "true" : "false");
          if (isOpen) {
            // Move focus into first nav link for keyboard users
            const firstLink = mainNav.querySelector(".nav-link");
            if (firstLink) firstLink.focus();
          }
        });

        // Escape key closes nav and returns focus to toggle
        document.addEventListener("keydown", function (e) {
          if (e.key === "Escape" && mainNav.classList.contains("open")) {
            mainNav.classList.remove("open");
            navToggle.setAttribute("aria-expanded", "false");
            navToggle.focus();
          }
        });

        // Close nav when any nav link is activated (mobile)
        mainNav.querySelectorAll(".nav-link").forEach(function (link) {
          link.addEventListener("click", function () {
            mainNav.classList.remove("open");
            navToggle.setAttribute("aria-expanded", "false");
          });
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

      // Initialize keyboard roving tabindex for all tablist elements
      AppCommon.initTablists();
    },

    /**
     * Keyboard roving tabindex for role="tablist" elements.
     * Supports ArrowRight, ArrowLeft, Home, End per ARIA Authoring Practices.
     */
    initTablists: function () {
      document.querySelectorAll('[role="tablist"]').forEach(function (tablist) {
        const tabs = Array.from(tablist.querySelectorAll('[role="tab"]'));
        if (tabs.length === 0) return;

        tablist.addEventListener("keydown", function (e) {
          const currentIdx = tabs.indexOf(document.activeElement);
          if (currentIdx === -1) return;

          let nextIdx = currentIdx;

          if (e.key === "ArrowRight") {
            nextIdx = (currentIdx + 1) % tabs.length;
          } else if (e.key === "ArrowLeft") {
            nextIdx = (currentIdx - 1 + tabs.length) % tabs.length;
          } else if (e.key === "Home") {
            nextIdx = 0;
          } else if (e.key === "End") {
            nextIdx = tabs.length - 1;
          } else {
            return; // Not a navigation key
          }

          e.preventDefault();

          // Update roving tabindex
          tabs.forEach(function (t, i) {
            t.setAttribute("tabindex", i === nextIdx ? "0" : "-1");
          });
          tabs[nextIdx].focus();
          tabs[nextIdx].click(); // Activate the tab
        });
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
