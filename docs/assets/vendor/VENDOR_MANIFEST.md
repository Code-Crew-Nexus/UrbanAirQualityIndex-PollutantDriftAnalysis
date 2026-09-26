# Third-Party Vendor Library Manifest

**Project:** `UrbanAirQualityIndex-PollutantDriftAnalysis`  
**Directory:** `docs/assets/vendor/`  
**Policy:** Local offline vendoring with fixed immutable versions. Zero runtime CDN dependencies, zero npm, zero build-step requirement.

---

## Vendored Dependencies

| Library | Version | Purpose | Official Source / Distribution | License |
| :--- | :--- | :--- | :--- | :--- |
| **Marked.js** | `12.0.2` | Fast Markdown parser and compiler for dynamically rendering project guides, reports, and methodology documentation. | Official GitHub: [markedjs/marked](https://github.com/markedjs/marked)<br>Distribution: `marked.min.js` | MIT License |
| **marked-katex-extension** | `5.0.1` | Marked extension facilitating inline (`$...$`) and block (`$$...$$`) mathematical syntax parsing for KaTeX. | Official GitHub: [UziTech/marked-katex-extension](https://github.com/UziTech/marked-katex-extension)<br>Distribution: `marked-katex-extension.min.js` | MIT License |
| **KaTeX JavaScript** | `0.16.11` | High-performance, accessible mathematical typesetting engine producing HTML and MathML. | Official GitHub: [KaTeX/KaTeX](https://github.com/KaTeX/KaTeX)<br>Distribution: `katex/katex.min.js` | MIT License |
| **KaTeX CSS** | `0.16.11` | Stylesheet defining equation layout, delimiter glyph alignment, and responsive rendering rules. | Official GitHub: [KaTeX/KaTeX](https://github.com/KaTeX/KaTeX)<br>Distribution: `katex/katex.min.css` | MIT License |
| **KaTeX Auto-Render Extension** | `0.16.11` | Traverses DOM elements to render mathematical expressions delimited by `$` and `$$`. | Official GitHub: [KaTeX/KaTeX](https://github.com/KaTeX/KaTeX)<br>Distribution: `katex/contrib/auto-render.min.js` | MIT License |
| **KaTeX Web Fonts** | `0.16.11` | Mathematical font glyphs (AMS, Caligraphic, Fraktur, Main, Math, SansSerif, Script, Size1-4, Typewriter) in `.woff2`, `.woff`, and `.ttf` formats. | Official GitHub: [KaTeX/KaTeX](https://github.com/KaTeX/KaTeX)<br>Distribution: `katex/fonts/*` (60 font files) | SIL Open Font License 1.1 |
| **Chart.js** | `4.4.3` | Responsive canvas-based scientific charting library (vendored for Phase 6B interactive visualization layer). | Official GitHub: [chartjs/Chart.js](https://github.com/chartjs/Chart.js)<br>Distribution: `chart.umd.min.js` | MIT License |

---

## Verification & Integrity

All vendor files are tracked in version control under `docs/assets/vendor/` to ensure that GitHub Pages deployments and local offline reviews execute reliably without external network requests or CDN dependencies.
