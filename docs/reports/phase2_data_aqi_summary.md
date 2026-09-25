# Phase 2: Data Engineering and AQI Calculation

## 1. Station Selection and Data Sources
The study focuses on real-world air quality data from the **OpenAQ** platform and meteorological parameters from **Open-Meteo**.
- **Hyderabad Representative Panel**: 7 physical monitoring stations.
- **India Representative Panel**: 15 distinct physical stations broadly distributed across the country.
- Total unique physical stations processed: 21 (due to overlap).

## 2. Historical Acquisition Window
Data was acquired on a normalized hourly basis spanning:
- **March 1, 2025** through **September 21, 2026**.
This captured seasonal variations essential for robust baseline modeling.

## 3. Daily Aggregation & Data Quality
Hourly sensor data was rigorously aggregated to a daily resolution (24-hour means or 8-hour maximums). A minimum 70% temporal coverage threshold within a valid day was enforced to prevent sparse sensor reporting from severely skewing diurnal averages.

## 4. Verified AQI Policy (`VERIFIED_SUBSET_PM25_PM10_O3`)
The daily composite Air Quality Index (AQI) was calculated in strict alignment with CPCB (Central Pollution Control Board) piecewise linear sub-index logic.

**Included in the Composite AQI:**
- **PM2.5** (24-hour mean)
- **PM10** (24-hour mean)
- **O3** (8-hour maximum)

**Retained but Excluded from the AQI:**
- **CO** (Source-scale mean)
- **NO2** (Source-scale mean)
- **SO2** (Source-scale mean)

**Reasoning:**
The current physical units reported in the OpenAQ source data for CO, NO2, and SO2 (predominantly ppm/ppb) could not be authoritatively reconciled and converted to the necessary CPCB operational units (µg/m³ or mg/m³) for the exact historical study period. Rather than applying unsupported generic conversion factors, these three gases were rigorously excluded from the composite AQI calculation to guarantee the mathematical integrity of the target variable. They are retained strictly as unadjusted source-scale features.

Consequently, the target label is formally defined as the **CPCB-methodology-aligned verified-subset AQI**, ensuring no unverified units corrupt the classification boundary.
