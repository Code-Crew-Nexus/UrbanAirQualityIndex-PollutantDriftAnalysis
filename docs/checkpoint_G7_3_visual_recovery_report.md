# G7.3 Visual Recovery Report

## Controlled UI Recovery

The G7.2 release included an overly aggressive regex-based refactor of inline styles that accidentally destroyed the core single-page HTML layout structures (cards, pill shapes, flexbox layouts).

To fix this, we performed a controlled recovery based on the known-good **v0.8.1-single-page-polish** release and surgically applied targeted fixes instead of brute-force replacing all inline styles.

## Outstanding Fixes Completed

1.  **Factual Error in Metrics Card:**
    *   **Regression:** The Hero section incorrectly labeled "7 + 15" as "Pollutants & Meteorological Features".
    *   **Correction:** Fixed back to **"Panel Memberships"** and added supporting copy: "7 Hyderabad + 15 India memberships &middot; 1 overlap &middot; 21 unique stations".
2.  **Mode-Aware Scientific Notice:**
    *   **Improvement:** The "All metrics reflect frozen historical study data; no real-time or live monitoring is implied." notice inside the Explore section now reacts to the user's data-mode selection (Frozen, Live, Combined) dynamically.
3.  **Invalid CSS Custom Properties:**
    *   **Bug:** Several tokens generated in G7.2 were technically undefined in the canonical `:root` (e.g. `--jade`, `--graphite`, `--pearl`, `--pearl-dark`, `--heading-color`, `--text-color`).
    *   **Correction:** Replaced inline undefined tokens with their valid equivalents (`--jade-deep`, `--text-graphite`, `--bg-warm-pearl`, `--jade-tint`). This restored proper visibility for End-to-End journey pills and the Operational Extension panels.
4.  **Navigation Observer Overlap Fix:**
    *   **Bug:** When rapidly scrolling, multiple navigation links would incorrectly light up simultaneously in `single-page.js` scrollspy.
    *   **Correction:** Modified the `IntersectionObserver` callback to filter only intersecting entries, calculate the one closest to the top of the viewport (`Math.abs(entry.boundingClientRect.top)`), and explicitly apply the `.active` and `aria-current="location"` state to that single section.
5.  **Mobile Horizontal Overflow:**
    *   **Bug:** On mobile devices (390px viewport), hardcoded `grid-template-columns` inline grids pushed the `.journey-flow` and metric cards off the screen.
    *   **Correction:** Added a targeted `@media (max-width: 768px)` override block that forces these specific grid containers into `1fr` and allows the `.journey-flow` items to flex wrap cleanly.
6.  **Footer Cleanup:**
    *   **Update:** Altered footer to read "Statistics for Machine Learning &middot; Project Based Learning" and updated website release tag to `v0.8.1-single-page-polish` during dev (which will be tagged to `v0.8.3` on final merge).

## Validation

All Playwright tests pass successfully:
- `test_g7_1_playwright.py`: Single-page JS functionality is fully restored.
- `test_g7_2_nav.py`: Scrollspy active link handling behaves perfectly without multiple concurrent selections.
- `test_g7_2_visual_qa.py`: No horizontal overflow on 390px mobile screens.
- `test_g7_2_css_tokens.py`: All references are mapped to valid defined `:root` tokens.
