# Project Presentation Walkthrough

A concise visual walkthrough of the Urban Air Quality Index & Pollutant Drift Analysis project, covering the research problem, data engineering, statistical methodology, machine learning, deployment, conclusions and supporting references.

---

## Presentation Overview

- **Slide Deck:** 12 authoritative presentation slides
- **Course Framework:** Statistics for Machine Learning — Project Based Learning
- **Institution:** Geethanjali College of Engineering and Technology &bull; B.Tech CSE (AIML)
- **Baseline Invariant:** Scientific evaluation frozen at `v0.6-svm-freeze` (March 1, 2025 to September 21, 2026)
- **Operational Status:** Live data extension enabled separately via GitHub Actions (`v0.7.3-live-extension`)
- **Review Audience:** Faculty review, external evaluation, and technical project defense

> [!NOTE]
> **Faculty Reviewer Note:** This presentation summarizes the frozen academic analysis while demonstrating the separately maintained operational data extension. All statistical inferences, distribution tests, hypothesis evaluations, and machine-learning models remain strictly tied to the frozen scientific baseline (`v0.6-svm-freeze`). Periodic operational updates do not alter or retrain the published academic metrics.

---

## Presentation Contents

<nav class="presentation-index" aria-label="Presentation Slide Index">
  <div class="presentation-index__title">📑 Quick-Jump Slide Index</div>
  <ul class="presentation-index__grid">
    <li class="presentation-index__item">
      <a href="#slide-1" class="presentation-index__link">
        <span class="presentation-index__num">01.</span>
        <span>Urban Air Quality Index &amp; Pollutant Drift Analysis</span>
      </a>
    </li>
    <li class="presentation-index__item">
      <a href="#slide-2" class="presentation-index__link">
        <span class="presentation-index__num">02.</span>
        <span>Problem Statement &amp; Motivation</span>
      </a>
    </li>
    <li class="presentation-index__item">
      <a href="#slide-3" class="presentation-index__link">
        <span class="presentation-index__num">03.</span>
        <span>Objectives &amp; Scope</span>
      </a>
    </li>
    <li class="presentation-index__item">
      <a href="#slide-4" class="presentation-index__link">
        <span class="presentation-index__num">04.</span>
        <span>Data Sources &amp; Study Design</span>
      </a>
    </li>
    <li class="presentation-index__item">
      <a href="#slide-5" class="presentation-index__link">
        <span class="presentation-index__num">05.</span>
        <span>Data Pipeline &amp; Preprocessing</span>
      </a>
    </li>
    <li class="presentation-index__item">
      <a href="#slide-6" class="presentation-index__link">
        <span class="presentation-index__num">06.</span>
        <span>AQI Methodology &amp; Statistical Foundation</span>
      </a>
    </li>
    <li class="presentation-index__item">
      <a href="#slide-7" class="presentation-index__link">
        <span class="presentation-index__num">07.</span>
        <span>Exploratory Results / Key Observations</span>
      </a>
    </li>
    <li class="presentation-index__item">
      <a href="#slide-8" class="presentation-index__link">
        <span class="presentation-index__num">08.</span>
        <span>Machine Learning Approach</span>
      </a>
    </li>
    <li class="presentation-index__item">
      <a href="#slide-9" class="presentation-index__link">
        <span class="presentation-index__num">09.</span>
        <span>Model Results &amp; Interpretation</span>
      </a>
    </li>
    <li class="presentation-index__item">
      <a href="#slide-10" class="presentation-index__link">
        <span class="presentation-index__num">10.</span>
        <span>Website Features &amp; System Demonstration</span>
      </a>
    </li>
    <li class="presentation-index__item">
      <a href="#slide-11" class="presentation-index__link">
        <span class="presentation-index__num">11.</span>
        <span>References / Terminology</span>
      </a>
    </li>
    <li class="presentation-index__item">
      <a href="#slide-12" class="presentation-index__link">
        <span class="presentation-index__num">12.</span>
        <span>Thank You</span>
      </a>
    </li>
  </ul>
</nav>

---

## Slides &amp; Analytical Walkthrough

<div class="presentation-walkthrough">

  <!-- Slide 01 -->
  <article class="presentation-slide" id="slide-1">
    <div class="presentation-slide__header">
      <span class="presentation-slide__number">Slide 01</span>
      <h3 class="presentation-slide__title">Urban Air Quality Index &amp; Pollutant Drift Analysis</h3>
    </div>
    <figure class="presentation-slide__figure">
      <picture>
        <source srcset="../slides/web/slide01.webp" type="image/webp">
        <img src="../slides/slide1.png" alt="Slide 1 — Urban Air Quality Index &amp; Pollutant Drift Analysis" class="presentation-slide__image" width="1672" height="941" decoding="async">
      </picture>
      <figcaption class="presentation-slide__caption">
        <p><strong>Purpose:</strong> Formal title and metadata slide identifying the investigation as a semester-long project for Statistics for Machine Learning &mdash; Project Based Learning at Geethanjali College of Engineering and Technology.</p>
        <p><strong>Key Idea:</strong> Unifies physical sensor data engineering, statistical drift diagnostics, supervised regression/classification, nonlinear support vector machines, and live web deployment under a single reproducible architecture.</p>
      </figcaption>
    </figure>
    <div class="presentation-slide__meta">
      <a href="../slides/slide1.png" target="_blank" rel="noopener noreferrer" class="presentation-slide__full-link" title="Open master resolution PNG in new tab">🔍 Open Full-Size Slide (Original Master PNG)</a>
    </div>
  </article>

  <!-- Slide 02 -->
  <article class="presentation-slide" id="slide-2">
    <div class="presentation-slide__header">
      <span class="presentation-slide__number">Slide 02</span>
      <h3 class="presentation-slide__title">Problem Statement &amp; Motivation</h3>
    </div>
    <figure class="presentation-slide__figure">
      <picture>
        <source srcset="../slides/web/slide02.webp" type="image/webp">
        <img src="../slides/slide2.png" alt="Slide 2 — Problem Statement &amp; Motivation" class="presentation-slide__image" width="1672" height="941" loading="lazy" decoding="async">
      </picture>
      <figcaption class="presentation-slide__caption">
        <p><strong>Purpose:</strong> Formulates the core motivation: while regulatory AQI communicates general health severity, the complex physical mass concentrations and meteorological interactions behind it require deeper statistical explanation.</p>
        <p><strong>Key Idea:</strong> Introduces the project's analytical doctrine &mdash; <em>Observe &rarr; Explain &rarr; Predict &rarr; Communicate</em> &mdash; transforming fragmented sensor streams into an end-to-end evidence pipeline.</p>
      </figcaption>
    </figure>
    <div class="presentation-slide__meta">
      <a href="../slides/slide2.png" target="_blank" rel="noopener noreferrer" class="presentation-slide__full-link" title="Open master resolution PNG in new tab">🔍 Open Full-Size Slide (Original Master PNG)</a>
    </div>
  </article>

  <!-- Slide 03 -->
  <article class="presentation-slide" id="slide-3">
    <div class="presentation-slide__header">
      <span class="presentation-slide__number">Slide 03</span>
      <h3 class="presentation-slide__title">Objectives &amp; Scope</h3>
    </div>
    <figure class="presentation-slide__figure">
      <picture>
        <source srcset="../slides/web/slide03.webp" type="image/webp">
        <img src="../slides/slide3.png" alt="Slide 3 — Objectives &amp; Scope" class="presentation-slide__image" width="1672" height="941" loading="lazy" decoding="async">
      </picture>
      <figcaption class="presentation-slide__caption">
        <p><strong>Purpose:</strong> Defines the scientific boundaries and deliverables: rigorous study design, AQI calculation, statistical inference, and machine learning models presented through a production web application.</p>
        <p><strong>Key Idea:</strong> Clearly demarcates the 570-day frozen scientific baseline from the optional operational live extension, guaranteeing that academic evaluation remains fixed and reproducible.</p>
      </figcaption>
    </figure>
    <div class="presentation-slide__meta">
      <a href="../slides/slide3.png" target="_blank" rel="noopener noreferrer" class="presentation-slide__full-link" title="Open master resolution PNG in new tab">🔍 Open Full-Size Slide (Original Master PNG)</a>
    </div>
  </article>

  <!-- Slide 04 -->
  <article class="presentation-slide" id="slide-4">
    <div class="presentation-slide__header">
      <span class="presentation-slide__number">Slide 04</span>
      <h3 class="presentation-slide__title">Data Sources &amp; Study Design</h3>
    </div>
    <figure class="presentation-slide__figure">
      <picture>
        <source srcset="../slides/web/slide04.webp" type="image/webp">
        <img src="../slides/slide4.png" alt="Slide 4 — Data Sources &amp; Study Design" class="presentation-slide__image" width="1672" height="941" loading="lazy" decoding="async">
      </picture>
      <figcaption class="presentation-slide__caption">
        <p><strong>Purpose:</strong> Details data acquisition sources (OpenAQ v3 physical CAAQMS stations and Open-Meteo hourly meteorology) across 21 selected stations spanning Hyderabad and the India Representative Panel.</p>
        <p><strong>Key Idea:</strong> Establishes the verified-subset methodology (computing AQI only from verified pollutant observations) and formalizes the separation between frozen academic datasets and operational streaming data.</p>
      </figcaption>
    </figure>
    <div class="presentation-slide__meta">
      <a href="../slides/slide4.png" target="_blank" rel="noopener noreferrer" class="presentation-slide__full-link" title="Open master resolution PNG in new tab">🔍 Open Full-Size Slide (Original Master PNG)</a>
    </div>
  </article>

  <!-- Slide 05 -->
  <article class="presentation-slide" id="slide-5">
    <div class="presentation-slide__header">
      <span class="presentation-slide__number">Slide 05</span>
      <h3 class="presentation-slide__title">Data Pipeline &amp; Preprocessing</h3>
    </div>
    <figure class="presentation-slide__figure">
      <picture>
        <source srcset="../slides/web/slide05.webp" type="image/webp">
        <img src="../slides/slide5.png" alt="Slide 5 — Data Pipeline &amp; Preprocessing" class="presentation-slide__image" width="1672" height="941" loading="lazy" decoding="async">
      </picture>
      <figcaption class="presentation-slide__caption">
        <p><strong>Purpose:</strong> Traces the sequential data engineering lifecycle: Ingestion &rarr; Harmonization &rarr; Validation &rarr; Daily Aggregation &rarr; AQI Calculation &rarr; Quality Checks &rarr; Web Export.</p>
        <p><strong>Key Idea:</strong> Emphasizes honest missingness handling &mdash; missing observations are recorded, audited, and preserved rather than artificially fabricated or imputed.</p>
      </figcaption>
    </figure>
    <div class="presentation-slide__meta">
      <a href="../slides/slide5.png" target="_blank" rel="noopener noreferrer" class="presentation-slide__full-link" title="Open master resolution PNG in new tab">🔍 Open Full-Size Slide (Original Master PNG)</a>
    </div>
  </article>

  <!-- Slide 06 -->
  <article class="presentation-slide" id="slide-6">
    <div class="presentation-slide__header">
      <span class="presentation-slide__number">Slide 06</span>
      <h3 class="presentation-slide__title">AQI Methodology &amp; Statistical Foundation</h3>
    </div>
    <figure class="presentation-slide__figure">
      <picture>
        <source srcset="../slides/web/slide06.webp" type="image/webp">
        <img src="../slides/slide6.png" alt="Slide 6 — AQI Methodology &amp; Statistical Foundation" class="presentation-slide__image" width="1672" height="941" loading="lazy" decoding="async">
      </picture>
      <figcaption class="presentation-slide__caption">
        <p><strong>Purpose:</strong> Presents the regulatory subindex interpolation rules (CPCB linear breakpoints) and core statistical summary measures (Mean, Median, Min/Max, and trend analysis).</p>
        <p><strong>Key Idea:</strong> Implements the CPCB 16-hour completion rule and data sufficiency constraints to ensure all computed subindices and composite AQI values satisfy strict regulatory standards.</p>
      </figcaption>
    </figure>
    <div class="presentation-slide__meta">
      <a href="../slides/slide6.png" target="_blank" rel="noopener noreferrer" class="presentation-slide__full-link" title="Open master resolution PNG in new tab">🔍 Open Full-Size Slide (Original Master PNG)</a>
    </div>
  </article>

  <!-- Slide 07 -->
  <article class="presentation-slide" id="slide-7">
    <div class="presentation-slide__header">
      <span class="presentation-slide__number">Slide 07</span>
      <h3 class="presentation-slide__title">Exploratory Results / Key Observations</h3>
    </div>
    <figure class="presentation-slide__figure">
      <picture>
        <source srcset="../slides/web/slide07.webp" type="image/webp">
        <img src="../slides/slide7.png" alt="Slide 7 — Exploratory Results / Key Observations" class="presentation-slide__image" width="1672" height="941" loading="lazy" decoding="async">
      </picture>
      <figcaption class="presentation-slide__caption">
        <p><strong>Purpose:</strong> Highlights descriptive patterns, multi-station temporal trajectories, and episodic spikes across Hyderabad monitoring stations (Balanagar, Sanathnagar, Zoo Park).</p>
        <p><strong>Key Idea:</strong> Shows that fine particulate matter (PM2.5 and PM10) acts as the dominant exploratory driver of AQI variance, displaying strong seasonal winter elevation and uneven station-level pressure.</p>
      </figcaption>
    </figure>
    <div class="presentation-slide__meta">
      <a href="../slides/slide7.png" target="_blank" rel="noopener noreferrer" class="presentation-slide__full-link" title="Open master resolution PNG in new tab">🔍 Open Full-Size Slide (Original Master PNG)</a>
    </div>
  </article>

  <!-- Slide 08 -->
  <article class="presentation-slide" id="slide-8">
    <div class="presentation-slide__header">
      <span class="presentation-slide__number">Slide 08</span>
      <h3 class="presentation-slide__title">Machine Learning Approach</h3>
    </div>
    <figure class="presentation-slide__figure">
      <picture>
        <source srcset="../slides/web/slide08.webp" type="image/webp">
        <img src="../slides/slide8.png" alt="Slide 8 — Machine Learning Approach" class="presentation-slide__image" width="1672" height="941" loading="lazy" decoding="async">
      </picture>
      <figcaption class="presentation-slide__caption">
        <p><strong>Purpose:</strong> Explains target variables, feature design (pollutants, calendar lag features, meteorology), and the complementary model suite: Multiple Linear Regression, Logistic Regression, and Support Vector Machines.</p>
        <p><strong>Key Idea:</strong> Clarifies that operational scoring reuses frozen model weights for deterministic inference rather than executing uncontrolled daily retraining.</p>
      </figcaption>
    </figure>
    <div class="presentation-slide__meta">
      <a href="../slides/slide8.png" target="_blank" rel="noopener noreferrer" class="presentation-slide__full-link" title="Open master resolution PNG in new tab">🔍 Open Full-Size Slide (Original Master PNG)</a>
    </div>
  </article>

  <!-- Slide 09 -->
  <article class="presentation-slide" id="slide-9">
    <div class="presentation-slide__header">
      <span class="presentation-slide__number">Slide 09</span>
      <h3 class="presentation-slide__title">Model Results &amp; Interpretation</h3>
    </div>
    <figure class="presentation-slide__figure">
      <picture>
        <source srcset="../slides/web/slide09.webp" type="image/webp">
        <img src="../slides/slide9.png" alt="Slide 9 — Model Results &amp; Interpretation" class="presentation-slide__image" width="1672" height="941" loading="lazy" decoding="async">
      </picture>
      <figcaption class="presentation-slide__caption">
        <p><strong>Purpose:</strong> Evaluates out-of-sample performance: Multiple Linear Regression for continuous trend fitting, Logistic Regression for adverse event probability ranking, and RBF SVM for nonlinear decision boundary separation.</p>
        <p><strong>Key Idea:</strong> Emphasizes <em>insight first &rarr; numbers second</em> &mdash; models serve to illuminate the atmospheric physics and persistence dynamics rather than acting as uninterpretable black boxes.</p>
      </figcaption>
    </figure>
    <div class="presentation-slide__meta">
      <a href="../slides/slide9.png" target="_blank" rel="noopener noreferrer" class="presentation-slide__full-link" title="Open master resolution PNG in new tab">🔍 Open Full-Size Slide (Original Master PNG)</a>
    </div>
  </article>

  <!-- Slide 10 -->
  <article class="presentation-slide" id="slide-10">
    <div class="presentation-slide__header">
      <span class="presentation-slide__number">Slide 10</span>
      <h3 class="presentation-slide__title">Website Features &amp; System Demonstration</h3>
    </div>
    <figure class="presentation-slide__figure">
      <picture>
        <source srcset="../slides/web/slide10.webp" type="image/webp">
        <img src="../slides/slide10.png" alt="Slide 10 — Website Features &amp; System Demonstration" class="presentation-slide__image" width="1672" height="941" loading="lazy" decoding="async">
      </picture>
      <figcaption class="presentation-slide__caption">
        <p><strong>Purpose:</strong> Demonstrates the publicly deployed web application: Explore Data, Dataset Inspector, Statistical Analysis, Machine Learning, and Documentation.</p>
        <p><strong>Key Idea:</strong> Highlights key architectural features: zero-runtime frontend, live vs. frozen data mode switching, WCAG AA accessibility, and fully responsive layouts across mobile and desktop devices.</p>
      </figcaption>
    </figure>
    <div class="presentation-slide__meta">
      <a href="../slides/slide10.png" target="_blank" rel="noopener noreferrer" class="presentation-slide__full-link" title="Open master resolution PNG in new tab">🔍 Open Full-Size Slide (Original Master PNG)</a>
    </div>
  </article>

  <!-- Slide 11 -->
  <article class="presentation-slide" id="slide-11">
    <div class="presentation-slide__header">
      <span class="presentation-slide__number">Slide 11</span>
      <h3 class="presentation-slide__title">References / Terminology</h3>
    </div>
    <figure class="presentation-slide__figure">
      <picture>
        <source srcset="../slides/web/slide11.webp" type="image/webp">
        <img src="../slides/slide11.png" alt="Slide 11 — References / Terminology" class="presentation-slide__image" width="1672" height="941" loading="lazy" decoding="async">
      </picture>
      <figcaption class="presentation-slide__caption">
        <p><strong>Purpose:</strong> Consolidates core regulatory terminology (AQI, PM2.5, PM10, O3, CPCB, Frozen Baseline) alongside primary data sources (OpenAQ, Open-Meteo) and technical references.</p>
        <p><strong>Key Idea:</strong> Ensures conceptual precision and complete provenance across all environmental metrics, regulatory standards, and scientific citations.</p>
      </figcaption>
    </figure>
    <div class="presentation-slide__meta">
      <a href="../slides/slide11.png" target="_blank" rel="noopener noreferrer" class="presentation-slide__full-link" title="Open master resolution PNG in new tab">🔍 Open Full-Size Slide (Original Master PNG)</a>
    </div>
  </article>

  <!-- Slide 12 -->
  <article class="presentation-slide" id="slide-12">
    <div class="presentation-slide__header">
      <span class="presentation-slide__number">Slide 12</span>
      <h3 class="presentation-slide__title">Thank You</h3>
    </div>
    <figure class="presentation-slide__figure">
      <picture>
        <source srcset="../slides/web/slide12.webp" type="image/webp">
        <img src="../slides/slide12.png" alt="Slide 12 — Thank You" class="presentation-slide__image" width="1672" height="941" loading="lazy" decoding="async">
      </picture>
      <figcaption class="presentation-slide__caption">
        <p><strong>Purpose:</strong> Formal closing slide acknowledging faculty mentors, peers, and evaluators, and inviting questions and technical discussion.</p>
        <p><strong>Key Idea:</strong> Concludes the presentation walkthrough and directs evaluators to the public repository, live website, and interactive data explorer for real-time demonstration.</p>
      </figcaption>
    </figure>
    <div class="presentation-slide__meta">
      <a href="../slides/slide12.png" target="_blank" rel="noopener noreferrer" class="presentation-slide__full-link" title="Open master resolution PNG in new tab">🔍 Open Full-Size Slide (Original Master PNG)</a>
    </div>
  </article>

</div>
