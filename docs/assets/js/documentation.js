/**
 * documentation.js
 * Controls navigation, URL hash routing, and Markdown rendering
 * within the single-source Documentation framework.
 * 
 * Project: UrbanAirQualityIndex-PollutantDriftAnalysis
 * Primary Sections:
 *   1. Prerequisites
 *   2. Setup Guide
 *   3. Theoretical Concepts
 *   4. Detailed Execution
 *   5. Screenshots & Samples
 */

(function (window) {
  "use strict";

  document.addEventListener("DOMContentLoaded", function () {
    const manifest = window.DOCUMENTATION_MANIFEST;
    if (!manifest) {
      console.error("DOCUMENTATION_MANIFEST not found.");
      return;
    }

    const navContainer = document.getElementById("doc-nav-tree");
    const contentPane = document.getElementById("doc-render-target");
    if (!navContainer || !contentPane) return;

    // 1. Build Navigation DOM from manifest
    buildNavigationTree(manifest, navContainer);

    // 2. Hash Change Listener
    window.addEventListener("hashchange", function () {
      routeHash(manifest, contentPane);
    });

    // 3. Initial Route
    routeHash(manifest, contentPane);
  });

  /**
   * Renders the sidebar navigation tree.
   */
  function buildNavigationTree(manifest, container) {
    const ul = document.createElement("ul");
    ul.className = "doc-nav-list";

    manifest.primarySections.forEach(function (sec) {
      const li = document.createElement("li");
      li.className = "doc-nav-item";
      li.setAttribute("data-section-id", sec.id);

      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "doc-section-btn";
      btn.innerHTML = `<span>${sec.title}</span>`;
      btn.addEventListener("click", function () {
        window.location.hash = sec.id;
      });

      li.appendChild(btn);

      // Sub-items if present
      if (sec.subItems && sec.subItems.length > 1) {
        const subUl = document.createElement("ul");
        subUl.className = "doc-sub-list";

        sec.subItems.forEach(function (sub) {
          const subLi = document.createElement("li");
          subLi.className = "doc-sub-item";

          const subA = document.createElement("a");
          subA.className = "doc-sub-link";
          subA.href = "#" + sub.id;
          subA.setAttribute("data-sub-id", sub.id);
          subA.innerText = sub.title;

          subLi.appendChild(subA);
          subUl.appendChild(subLi);
        });

        li.appendChild(subUl);
      }

      ul.appendChild(li);
    });

    container.innerHTML = "";
    container.appendChild(ul);
  }

  /**
   * Routes the URL hash to the appropriate Markdown document.
   */
  function routeHash(manifest, contentPane) {
    const urlParams = new URLSearchParams(window.location.search);
    let hash = window.location.hash.replace(/^#/, "") || urlParams.get("section") || urlParams.get("doc");
    if (!hash) {
      hash = manifest.defaultSection;
    }

    // If hash matches an element already in the rendered content pane (e.g. #slide-3), scroll to it
    const existingTarget = document.getElementById(hash);
    if (existingTarget && contentPane.contains(existingTarget)) {
      existingTarget.scrollIntoView({ behavior: "smooth" });
      return;
    }

    // Direct slide deep-link when not yet loaded: #slide-1 through #slide-12
    if (hash.startsWith("slide-")) {
      loadDocument("guide/presentation_walkthrough.md", contentPane, function () {
        const el = document.getElementById(hash);
        if (el) el.scrollIntoView({ behavior: "smooth" });
      });
      highlightActiveNav("exec-presentation", "guide/presentation_walkthrough.md");
      return;
    }

    // Direct doc parameter: #doc=path/to/doc.md
    if (hash.startsWith("doc=")) {
      const docPath = decodeURIComponent(hash.substring(4));
      loadDocument(docPath, contentPane);
      highlightActiveNav(null, docPath);
      return;
    }

    // Special alias or direct anchor for theory
    if (hash === "theory-eq") {
      loadDocument("guide/theoretical_concepts.md", contentPane);
      highlightActiveNav("theory", "guide/theoretical_concepts.md");
      return;
    }

    // Historical sub-item aliases to maintain backward-compatibility
    const HISTORICAL_ALIASES = {
      "exec-phase1": "phase1_station_selection_decision.md",
      "exec-phase2": "reports/phase2_data_aqi_summary.md",
      "exec-phase3": "reports/phase3_statistical_analysis_summary.md",
      "exec-phase4": "reports/phase4_supervised_learning_summary.md",
      "exec-phase5a": "reports/phase5_pca_kmeans_summary.md",
      "exec-phase5b": "reports/phase5b_svm_summary.md",
      "exec-freeze": "MODELING_FREEZE_SUMMARY.md",
      "exec-checkpoints": "PROJECT_CHECKPOINTS.md"
    };
    if (HISTORICAL_ALIASES[hash]) {
      loadDocument(HISTORICAL_ALIASES[hash], contentPane);
      highlightActiveNav("execution", HISTORICAL_ALIASES[hash]);
      return;
    }

    // Check primary section matches
    const primaryMatch = manifest.primarySections.find(function (s) { return s.id === hash; });
    if (primaryMatch) {
      loadDocument(primaryMatch.source, contentPane);
      highlightActiveNav(primaryMatch.id, primaryMatch.source);
      return;
    }

    // Check sub-item matches
    for (let i = 0; i < manifest.primarySections.length; i++) {
      const sec = manifest.primarySections[i];
      if (sec.subItems) {
        const subMatch = sec.subItems.find(function (sub) { return sub.id === hash; });
        if (subMatch) {
          loadDocument(subMatch.source, contentPane);
          highlightActiveNav(subMatch.id, subMatch.source);
          return;
        }
      }
    }

    // Fallback to default
    const defSec = manifest.primarySections[0];
    loadDocument(defSec.source, contentPane);
    highlightActiveNav(defSec.id, defSec.source);
  }

  /**
   * Calls MarkdownRenderer to load and typeset the file.
   */
  function loadDocument(sourcePath, contentPane, onDone) {
    if (window.MarkdownRenderer && window.MarkdownRenderer.loadDocument) {
      window.MarkdownRenderer.loadDocument(sourcePath, contentPane, function () {
        // Intercept internal markdown links rendered within the document
        const internalLinks = contentPane.querySelectorAll(".doc-internal-link");
        internalLinks.forEach(function (link) {
          link.addEventListener("click", function (e) {
            e.preventDefault();
            const targetDoc = link.getAttribute("data-doc-source");
            if (targetDoc) {
              window.location.hash = "doc=" + encodeURIComponent(targetDoc);
            }
          });
        });

        // Intercept in-page anchor links (e.g. #slide-3) for smooth scrolling
        const inPageAnchors = contentPane.querySelectorAll('a[href^="#"]');
        inPageAnchors.forEach(function (anchor) {
          const targetId = anchor.getAttribute("href").replace(/^#/, "");
          if (targetId && !targetId.startsWith("doc=")) {
            anchor.addEventListener("click", function (e) {
              const targetEl = document.getElementById(targetId);
              if (targetEl && contentPane.contains(targetEl)) {
                e.preventDefault();
                targetEl.scrollIntoView({ behavior: "smooth" });
                history.replaceState(null, "", window.location.pathname + window.location.search + "#" + targetId);
              }
            });
          }
        });

        if (typeof onDone === "function") {
          onDone();
        }
      });
    }
  }

  /**
   * Synchronizes visual active states on sidebar buttons and sub-links.
   */
  function highlightActiveNav(activeId, activeSource) {
    const sectionBtns = document.querySelectorAll(".doc-section-btn");
    sectionBtns.forEach(function (btn) {
      btn.classList.remove("active");
    });

    const navItems = document.querySelectorAll(".doc-nav-item");
    navItems.forEach(function (item) {
      item.classList.remove("active");
    });

    const subLinks = document.querySelectorAll(".doc-sub-link");
    subLinks.forEach(function (link) {
      link.classList.remove("active");
    });

    if (activeId) {
      const targetBtn = document.querySelector(`.doc-nav-item[data-section-id="${activeId}"] .doc-section-btn`);
      if (targetBtn) {
        targetBtn.classList.add("active");
        const parentItem = targetBtn.closest(".doc-nav-item");
        if (parentItem) parentItem.classList.add("active");
      }

      const targetSub = document.querySelector(`.doc-sub-link[data-sub-id="${activeId}"]`);
      if (targetSub) {
        targetSub.classList.add("active");
        // Also highlight parent section button and expand parent item
        const parentItem = targetSub.closest(".doc-nav-item");
        if (parentItem) {
          parentItem.classList.add("active");
          const parentBtn = parentItem.querySelector(".doc-section-btn");
          if (parentBtn) parentBtn.classList.add("active");
        }
      }
    }
  }
})(typeof window !== "undefined" ? window : this);
