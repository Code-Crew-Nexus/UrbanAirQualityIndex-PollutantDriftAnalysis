/**
 * documentation-manifest.js
 * Central registry mapping faculty walkthrough sections and reference topics
 * to canonical repository-tracked Markdown source documents.
 * 
 * Project: UrbanAirQualityIndex-PollutantDriftAnalysis
 * Baseline: v0.6-svm-freeze
 */

const DOCUMENTATION_MANIFEST = {
  defaultSection: "prerequisites",
  
  // Exactly the 5 Primary Documentation Sections
  primarySections: [
    {
      id: "prerequisites",
      title: "1. Prerequisites",
      description: "Computational environment, verified R 4.6.1 runtime, required packages, and API access modes.",
      source: "guide/prerequisites.md",
      badge: "Environment",
      subItems: [
        { id: "prereq-guide", title: "System Prerequisites", source: "guide/prerequisites.md" },
        { id: "prereq-env", title: "Authoritative R Environment", source: "ENVIRONMENT.md" }
      ]
    },
    {
      id: "setup",
      title: "2. Setup Guide",
      description: "Dual execution pathways: Mode A (frozen review & offline site preview) and Mode B (full data re-harvest).",
      source: "guide/setup.md",
      badge: "Quickstart",
      subItems: [
        { id: "setup-guide", title: "Setup & Execution Modes", source: "guide/setup.md" }
      ]
    },
    {
      id: "theory",
      title: "3. Theoretical Concepts",
      description: "Mathematical definitions, CPCB interpolation formulas, standardized drift, MLR, Logistic, PCA, K-Means, and RBF SVM.",
      source: "guide/theoretical_concepts.md",
      badge: "Mathematics",
      subItems: [
        { id: "theory-core", title: "Theoretical Foundations & Cautions", source: "guide/theoretical_concepts.md" },
        { id: "theory-cpcb", title: "Verified-Subset AQI Methodology", source: "cpcb_aqi_methodology_verified.md" },
        { id: "theory-sources", title: "Data Sources & Provenance", source: "data_sources.md" },
        { id: "theory-schema", title: "Canonical Dataset Schema", source: "dataset_schema.md" }
      ]
    },
    {
      id: "execution",
      title: "4. Detailed Execution",
      description: "Chronological phase-by-phase execution guide covering Phases 1 through 6 with standardized fields.",
      source: "guide/execution_guide.md",
      badge: "Walkthrough",
      subItems: [
        { id: "exec-walkthrough", title: "Phase 1-6 Execution Guide", source: "guide/execution_guide.md" },
        { id: "exec-phase1", title: "Phase 1: Station Selection Decision", source: "phase1_station_selection_decision.md" },
        { id: "exec-phase2", title: "Phase 2: Data Engineering & AQI Summary", source: "reports/phase2_data_aqi_summary.md" },
        { id: "exec-phase3", title: "Phase 3: Statistical Analysis & Drift", source: "reports/phase3_statistical_analysis_summary.md" },
        { id: "exec-phase4", title: "Phase 4: Supervised Learning Summary", source: "reports/phase4_supervised_learning_summary.md" },
        { id: "exec-phase5a", title: "Phase 5A: PCA & K-Means Summary", source: "reports/phase5_pca_kmeans_summary.md" },
        { id: "exec-phase5b", title: "Phase 5B: RBF SVM Classification Summary", source: "reports/phase5b_svm_summary.md" },
        { id: "exec-freeze", title: "Modeling Freeze Summary", source: "MODELING_FREEZE_SUMMARY.md" },
        { id: "exec-checkpoints", title: "Project Milestones & Checkpoints", source: "PROJECT_CHECKPOINTS.md" }
      ]
    },
    {
      id: "screenshots",
      title: "5. Screenshots & Samples",
      description: "Curated gallery of diagnostic residual plots, PR curves, PCA projections, and cluster biplots.",
      source: "guide/screenshots_and_samples.md",
      badge: "Gallery",
      subItems: [
        { id: "gallery-curated", title: "Curated Scientific Figures", source: "guide/screenshots_and_samples.md" }
      ]
    }
  ]
};

// Global export for vanilla browser environment
if (typeof window !== "undefined") {
  window.DOCUMENTATION_MANIFEST = DOCUMENTATION_MANIFEST;
}
if (typeof module !== "undefined" && module.exports) {
  module.exports = DOCUMENTATION_MANIFEST;
}
