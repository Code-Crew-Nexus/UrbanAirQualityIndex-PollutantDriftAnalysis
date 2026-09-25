# Environmental Data Sources Documentation

**Project:** UrbanAirQualityIndex-PollutantDriftAnalysis  
**Academic Context:** B.Tech CSE (AI & ML) III Year / I Sem — Statistics for Machine Learning (PBL)  
**Investigation Date:** September 2026

---

## 1. Overview of Data Ingestion Architecture
To build an authentic, verifiable, and student-defensible environmental dataset, candidate data sources were evaluated according to their official standing, historical depth, temporal granularity, API stability, and unit transparency.

| Source Identifier | Official / Secondary | Access Method | Auth Required | Historical Range | Primary Use Case |
|---|---|---|---|---|---|
| `openaq` | Secondary Aggregator | REST API (`api.openaq.org/v3`) | `X-API-Key` (Mandatory) | Multi-year historical | Station discovery & time-series sensor ingestion |
| `cpcb_datagov` | Official Government | REST API (`api.data.gov.in`) | `api-key` query param | Real-time bulletin only | Live cross-validation & station provenance |
| `openmeteo` | Secondary Reanalysis | REST API (`archive-api.open-meteo.com`) | None (Free open tier) | 1940 to present | Hourly meteorological matching |
| `kaggle_reference` | Secondary Reference | Static CSV repository | Optional | 2015–2020 / 2024 | Benchmark cross-checking & historical backfill |

---

## 2. Source A: OpenAQ Platform API v3
- **Base Endpoint:** `https://api.openaq.org/v3`
- **Official Documentation:** [https://docs.openaq.org](https://docs.openaq.org)
- **Authentication:** **Mandatory API Key** passed via HTTP header:
  ```http
  X-API-Key: YOUR_OPENAQ_API_KEY
  ```
  *(Confirmed via live test: unauthenticated requests return `HTTP 401 Unauthorized`).*
- **Version Status:** Versions 1 and 2 were permanently retired on January 31, 2025. All queries must use v3 endpoints.
- **Key v3 Endpoints:**
  - `GET /v3/locations`: Returns station coordinates, sensor lists, and metadata. Filterable by `iso=IN`, `coordinates`, `radius`, `bbox`.
  - `GET /v3/locations/{id}/sensors`: Lists active and historical sensors at a specific station.
  - `GET /v3/sensors/{id}/hours`: Hourly averaged measurements.
  - `GET /v3/sensors/{id}/measurements`: Raw reported observations.
- **Supported Pollutants:** $\text{PM}_{2.5}$, $\text{PM}_{10}$, $\text{NO}_2$, $\text{SO}_2$, $\text{CO}$, $\text{O}_3$, $\text{NH}_3$.
- **Strengths:** Global harmonization, ISO timestamps, standard units ($\mu\text{g/m}^3$, $\text{mg/m}^3$), historical queries.
- **Limitations:** Free tier rate limits (60 requests per minute and 2,000 requests per hour); requires API key configuration.

---

## 3. Source B: CPCB / National Data Portal (data.gov.in)
- **Base Endpoint:** `https://api.data.gov.in/resource/3b01bcb8-0b14-4abf-b6f2-c1bfd384ba69`
- **Resource Title:** "Real-Time Air Quality Index from Various Locations"
- **Authoritative Publisher:** Central Pollution Control Board (CPCB), Ministry of Environment, Forest and Climate Change (MoEFCC), Govt. of India.
- **Authentication:** Mandatory API Key (`&api-key=YOUR_KEY`) passed as a query parameter.
- **Granularity & Architecture:**
  - Output formats: `json`, `csv`, `xml`.
  - Supported filters: `filters[city]`, `filters[state]`, `filters[pollutant_id]`.
- **Critical Limitation for Historical PBL:**
  - This API endpoint exposes **current real-time bulletins only**.
  - It does **not natively store or serve arbitrary historical time-series queries** (e.g., retrieving January 2023 or 2024 historical data is unsupported).
  - Attempting to force this endpoint for multi-year historical analysis is technically invalid unless a continuous polling pipeline had been active.
- **Pipeline Role:** Used for station provenance verification, geographic naming validation, and live cross-checks.

---

## 4. Source C: Open-Meteo Historical Weather API
- **Base Endpoint:** `https://archive-api.open-meteo.com/v1/archive`
- **Official Documentation:** [https://open-meteo.com/en/docs/historical-weather-api](https://open-meteo.com/en/docs/historical-weather-api)
- **Authentication:** None required for standard non-commercial educational use.
- **Underlying Meteorological Models:** ECMWF ERA5 reanalysis and ERA5-Land.
- **Target Meteorological Variables & Canonical Mapping:**
  - `temperature_2m` (°C) $\rightarrow$ `temperature`
  - `relative_humidity_2m` (%) $\rightarrow$ `humidity`
  - `wind_speed_10m` (km/h) $\rightarrow$ `wind_speed`
  - `wind_direction_10m` (degrees) $\rightarrow$ `wind_direction`
- **Query Format:**
  ```text
  GET /v1/archive?latitude=17.385&longitude=78.4867&start_date=2024-01-01&end_date=2024-01-07&hourly=temperature_2m,relative_humidity_2m,wind_speed_10m,wind_direction_10m&timezone=Asia%2FKolkata
  ```
- **Strengths:** Direct coordinate lookup, native `Asia/Kolkata` timezone alignment, no API key barriers, verified live.

---

## 5. Source D: Kaggle Reference Data Review
Kaggle datasets are **not** the primary authoritative foundation of this project. However, they serve as critical reference benchmarks for historical data validation.

### Candidate 1: "Air Quality Data in India (2015 - 2020)"
- **Publisher:** Rohan Rao
- **Stated Original Source:** Central Pollution Control Board (CPCB) official portal.
- **Date Range:** 2015-01-01 to 2020-07-01.
- **Geographical Scope:** 26 Indian cities; station-level files for major metropolitan stations.
- **Files Included:** `city_day.csv`, `city_hour.csv`, `station_day.csv`, `station_hour.csv`, `stations.csv`.
- **Target Pollutants:** $\text{PM}_{2.5}$, $\text{PM}_{10}$, $\text{NO}$, $\text{NO}_2$, $\text{NO}_x$, $\text{NH}_3$, $\text{CO}$, $\text{SO}_2$, $\text{O}_3$, Benzene, Toluene, Xylene.
- **Granularity:** Hourly and daily.
- **Units:** Pollutants in $\mu\text{g/m}^3$, except $\text{CO}$ in $\text{mg/m}^3$.
- **AQI Presence:** Includes pre-computed AQI and AQI bucket based on CPCB rules.
- **Compatibility Review:**
  - High station metadata compatibility (`stations.csv` contains official CPCB station names).
  - Does not cover 2021–2026.
  - Can serve as a robust reference baseline to validate our pipeline's future CPCB AQI implementation.

### Candidate 2: "Hyderabad CAAQMS Historical Air Quality" (OpenCity.in / Kaggle)
- **Publisher:** OpenCity.in / TSPCB
- **Stated Original Source:** Telangana State Pollution Control Board (TSPCB) & CPCB.
- **Date Range:** 2017 to 2023 / 2024.
- **Geographical Scope:** 14 CAAQMS stations across Hyderabad and peri-urban industrial belts (Sanathnagar, Zoo Park, Central University, ICRISAT, IDA Pashamylaram, etc.).
- **Granularity:** Hourly and 15-minute reports.
- **Units:** Standard CPCB units.
- **Compatibility Review:** Excellent for verifying Hyderabad station coverage and providing fallback historical depth if API queries have rate limitations.

### Candidate 3: "Air Quality Dataset: Indian Cities (2022 - 2025)"
- **Stated Original Source:** Aggregated CPCB and Open-Meteo.
- **Date Range:** 2022 to 2025.
- **Geographical Scope:** 29 Indian cities including Hyderabad.
- **Compatibility Review:** High temporal relevance; requires careful verification of sensor vs reanalysis fields to ensure no unverified mixing occurred.

---

## 6. Synthesis: Ingestion Strategy for the PBL Project
1. **Primary Ingestion:** Direct, reproducible API calls to OpenAQ v3 (pollutants) and Open-Meteo (meteorology).
2. **Metadata & Provenance:** CPCB station directories and CAAQMS station coordinates.
3. **Reference Verification:** Kaggle/OpenCity CPCB datasets strictly for cross-validation and pre-2021 historical benchmarking.
