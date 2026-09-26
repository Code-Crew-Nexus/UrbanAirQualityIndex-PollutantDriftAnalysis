/**
 * data-utils.js
 * Reusable scientific data manipulation, statistical helpers, and brand chart configurations.
 * Project: UrbanAirQualityIndex-PollutantDriftAnalysis
 * Baseline: v0.6-svm-freeze (FROZEN — READ ONLY)
 */

(function (root, factory) {
  if (typeof define === 'function' && define.amd) {
    define([], factory);
  } else if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.DataUtils = factory();
  }
}(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  // In-memory JSON cache to prevent redundant network fetches
  const jsonCache = new Map();

  /**
   * Fetches JSON data once and caches in page memory.
   * @param {string} url 
   * @returns {Promise<any>}
   */
  async function fetchJSON(url) {
    if (jsonCache.has(url)) {
      return jsonCache.get(url);
    }
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to load ${url}: ${response.status} ${response.statusText}`);
    }
    const data = await response.json();
    jsonCache.set(url, data);
    return data;
  }

  /**
   * Formats a numeric value safely. Returns "—" for null/undefined/NaN.
   */
  function formatNumber(val, decimals = 2) {
    if (val === null || val === undefined || isNaN(val)) {
      return '—';
    }
    return Number(val).toLocaleString(undefined, {
      minimumFractionDigits: decimals,
      maximumFractionDigits: decimals
    });
  }

  /**
   * Calculates the arithmetic mean of an array of numbers, ignoring null/NaN.
   */
  function calculateMean(arr) {
    const valid = arr.filter(v => v !== null && v !== undefined && !isNaN(v));
    if (valid.length === 0) return null;
    const sum = valid.reduce((acc, v) => acc + Number(v), 0);
    return sum / valid.length;
  }

  /**
   * Calculates the median of an array of numbers, ignoring null/NaN.
   */
  function calculateMedian(arr) {
    const valid = arr
      .filter(v => v !== null && v !== undefined && !isNaN(v))
      .map(v => Number(v))
      .sort((a, b) => a - b);
    if (valid.length === 0) return null;
    const mid = Math.floor(valid.length / 2);
    if (valid.length % 2 !== 0) {
      return valid[mid];
    }
    return (valid[mid - 1] + valid[mid]) / 2;
  }

  /**
   * Calculates minimum of valid values.
   */
  function calculateMin(arr) {
    const valid = arr.filter(v => v !== null && v !== undefined && !isNaN(v)).map(v => Number(v));
    if (valid.length === 0) return null;
    return Math.min(...valid);
  }

  /**
   * Calculates maximum of valid values.
   */
  function calculateMax(arr) {
    const valid = arr.filter(v => v !== null && v !== undefined && !isNaN(v)).map(v => Number(v));
    if (valid.length === 0) return null;
    return Math.max(...valid);
  }

  /**
   * Official CPCB Breakpoints and semantic category descriptors.
   */
  function getAQICategory(aqi) {
    if (aqi === null || aqi === undefined || isNaN(aqi)) {
      return { category: 'Invalid / Incomplete', color: '#9CA3AF', textClass: 'text-muted' };
    }
    const val = Number(aqi);
    if (val <= 50) {
      return { category: 'Good', color: '#2E7D32', textClass: 'aqi-good' };
    } else if (val <= 100) {
      return { category: 'Satisfactory', color: '#689F38', textClass: 'aqi-satisfactory' };
    } else if (val <= 200) {
      return { category: 'Moderate', color: '#FBC02D', textClass: 'aqi-moderate' };
    } else if (val <= 300) {
      return { category: 'Poor', color: '#F57C00', textClass: 'aqi-poor' };
    } else if (val <= 400) {
      return { category: 'Very Poor', color: '#D32F2F', textClass: 'aqi-very-poor' };
    } else {
      return { category: 'Severe', color: '#7B1FA2', textClass: 'aqi-severe' };
    }
  }

  /**
   * Approved variable definitions for Explore Data and Statistical Analysis.
   */
  const VARIABLE_MAP = {
    'AQI': {
      key: 'aqi_verified',
      label: 'AQI',
      fullLabel: 'Verified CPCB AQI (PM2.5, PM10, O3)',
      unit: 'Index units',
      decimals: 1,
      isAQI: true
    },
    'PM2.5': {
      key: 'pm2_5_aqi_input',
      label: 'PM2.5',
      fullLabel: 'Fine Particulate Matter (PM2.5, 24-hr avg)',
      unit: 'µg/m³',
      decimals: 2,
      isAQI: false
    },
    'PM10': {
      key: 'pm10_aqi_input',
      label: 'PM10',
      fullLabel: 'Coarse Particulate Matter (PM10, 24-hr avg)',
      unit: 'µg/m³',
      decimals: 2,
      isAQI: false
    },
    'O3': {
      key: 'o3_8h_max',
      label: 'O3',
      fullLabel: 'daily maximum rolling 8-hour ozone (o3_8h_max)',
      unit: 'µg/m³',
      decimals: 2,
      isAQI: false
    },
    'Temperature': {
      key: 'temperature',
      label: 'Temperature',
      fullLabel: 'Surface Temperature (2m mean)',
      unit: '°C',
      decimals: 1,
      isAQI: false
    },
    'Humidity': {
      key: 'humidity',
      label: 'Humidity',
      fullLabel: 'Relative Humidity (2m mean)',
      unit: '%',
      decimals: 1,
      isAQI: false
    },
    'Wind Speed': {
      key: 'wind_speed',
      label: 'Wind Speed',
      fullLabel: 'Wind Speed (10m max)',
      unit: 'm/s',
      decimals: 2,
      isAQI: false
    }
  };

  /**
   * Standard Graphite × Jade × Champagne visual theme colors.
   */
  const THEME = {
    jadeDeep: '#285F49',
    jadeMedium: '#3D7A60',
    jadeLight: '#5C9A7D',
    jadeSoft: '#EBF4F0',
    champagne: '#C49A58',
    champagneDark: '#A67F42',
    champagneLight: '#FAF5EE',
    graphiteDark: '#1F2421',
    graphiteMedium: '#3A423D',
    graphiteLight: '#6B7280',
    borderLight: '#E5E7EB',
    cardBg: '#FFFFFF',
    bodyBg: '#F8FAF9'
  };

  return {
    fetchJSON,
    formatNumber,
    calculateMean,
    calculateMedian,
    calculateMin,
    calculateMax,
    getAQICategory,
    VARIABLE_MAP,
    THEME
  };
}));
