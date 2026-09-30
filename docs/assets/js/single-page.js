/**
 * single-page.js
 * Handles scrollspy, lazy section initialization, KaTeX rendering, and deep linking
 * for the single-page faculty presentation redesign.
 */

document.addEventListener('DOMContentLoaded', async () => {
  'use strict';

  // 1. Navigation & Scrollspy
  const sections = document.querySelectorAll('.presentation-section');
  const navLinks = document.querySelectorAll('.main-nav .nav-link');
  
  const updateNav = (id) => {
    navLinks.forEach(link => {
      link.classList.remove('active');
      link.removeAttribute('aria-current');
      if (link.getAttribute('href').endsWith(`#${id}`)) {
        link.classList.add('active');
        link.setAttribute('aria-current', 'location');
      }
    });
  };

  const observerOptions = {
    root: null,
    rootMargin: '-20% 0px -60% 0px',
    threshold: 0
  };

  const sectionObserver = new IntersectionObserver((entries) => {
    let intersecting = entries.filter(e => e.isIntersecting);
    if (intersecting.length > 0) {
      intersecting.sort((a, b) => Math.abs(a.boundingClientRect.top) - Math.abs(b.boundingClientRect.top));
      updateNav(intersecting[0].target.id);
      intersecting.forEach(e => initSection(e.target.id));
    }
  }, observerOptions);

  sections.forEach(sec => sectionObserver.observe(sec));

  // 2. Lazy Initialization Handlers
  const initSection = (id) => {
    if (id === 'explore' && window.initExploreSection) {
      window.initExploreSection();
    } else if (id === 'statistics' && window.initStatisticsSection) {
      window.initStatisticsSection();
    } else if (id === 'machine-learning' && window.initMachineLearningSection) {
      window.initMachineLearningSection();
    }
  };

  // 3. Deep Link on Load
  const hash = window.location.hash;
  if (hash) {
    const target = document.querySelector(hash);
    if (target) {
      setTimeout(() => {
        target.scrollIntoView({ behavior: 'smooth' });
        initSection(hash.substring(1));
        updateNav(hash.substring(1));
      }, 100);
    }
  } else {
    // Initial load without hash
    const firstSection = sections.length > 0 ? sections[0].id : null;
    if(firstSection) {
        updateNav(firstSection);
        initSection(firstSection);
    }
  }

  // Handle nav clicks
  navLinks.forEach(link => {
    link.addEventListener('click', (e) => {
      const href = link.getAttribute('href');
      if (href.startsWith('#') || href.includes('.html#')) {
        const targetId = href.substring(href.indexOf('#'));
        const target = document.querySelector(targetId);
        if (target) {
          e.preventDefault();
          target.scrollIntoView({ behavior: 'smooth' });
          history.pushState(null, '', targetId);
          initSection(targetId.substring(1));
          updateNav(targetId.substring(1));
        }
      }
    });
  });

  // 4. Render KaTeX
  if (typeof katex !== 'undefined') {
    const eqns = [
      { id: 'katex-aqi-subindex', tex: 'I_p = \\frac{I_{HI} - I_{LO}}{B_{HI} - B_{LO}} (C_p - B_{LO}) + I_{LO}', display: true },
      { id: 'katex-ip', tex: 'I_p', display: false },
      { id: 'katex-cp', tex: 'C_p', display: false },
      { id: 'katex-bhi', tex: 'B_{HI}', display: false },
      { id: 'katex-blo', tex: 'B_{LO}', display: false },
      { id: 'katex-ihi', tex: 'I_{HI}', display: false },
      { id: 'katex-ilo', tex: 'I_{LO}', display: false },
      { id: 'katex-aqi-max', tex: 'AQI_{verified} = \\max(I_{PM2.5}, I_{PM10}, I_{O3})', display: true },
      { id: 'katex-mean', tex: '\\bar{x} = \\frac{1}{n} \\sum_{i=1}^{n} x_i', display: true },
      { id: 'katex-sd', tex: 's = \\sqrt{\\frac{\\sum_{i=1}^{n}(x_i - \\bar{x})^2}{n - 1}}', display: true },
      { id: 'katex-drift', tex: 'D_z = \\frac{\\bar{x}_{recent} - \\bar{x}_{baseline}}{s_{baseline}}', display: true },
      { id: 'katex-mlr', tex: '\\hat{y} = \\beta_0 + \\beta_1x_1 + ... + \\beta_px_p', display: true },
      { id: 'katex-lr', tex: 'P(Y = 1 | x) = \\frac{1}{1 + \\exp(-(\\beta_0 + \\beta^T x))}', display: true },
      { id: 'katex-rbf', tex: 'K(x, x\') = \\exp(-\\gamma \\|x - x\'\\|^2)', display: true },
      { id: 'katex-kmeans', tex: '\\min \\sum_{k} \\sum_{x_i \\in C_k} \\|x_i - \\mu_k\\|^2', display: true }
    ];
    
    eqns.forEach(eq => {
      const el = document.getElementById(eq.id);
      if (el) {
        katex.render(eq.tex, el, {
          throwOnError: false,
          displayMode: eq.display
        });
      }
    });
  }

  // 5. Load Live Extension Dates dynamically
  try {
    const res = await fetch('web-data/live_pipeline_status.json');
    if (res.ok) {
      const data = await res.json();
      const liveDatesEl = document.getElementById('dynamic-live-dates');
      if (liveDatesEl && data.data_through) {
        liveDatesEl.textContent = `Sep 22, 2026 \u2192 ${data.data_through}`;
      }
    }
  } catch (err) {
    console.warn('Could not load live pipeline status for homepage dates.', err);
  }

});
