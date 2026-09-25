# Target Dataset Schema Specification

**Project:** UrbanAirQualityIndex-PollutantDriftAnalysis  
**Academic Context:** B.Tech CSE (AI & ML) III Year / I Sem — Statistics for Machine Learning (PBL)  
**Target Analytical Datasets:**
1. `UAQI_Hyderabad_Daily.csv` (Dedicated multi-station dataset for Hyderabad)
2. `UAQI_India_Daily.csv` (Curated national multi-city comparative dataset, including Hyderabad)

---

## Canonical Pipeline Principle
Both final datasets originate from the **exact same canonical processing pipeline**. They strictly share:
- Identical column names
- Identical data types
- Identical measurement units
- Identical column ordering
- Identical Indian Air Quality Index (AQI) calculation methodology
- Identical weather-variable definitions and reanalysis sourcing

The only difference between the two datasets is **geographical scope**.

---

## Detailed Column Specifications

| # | Column Name | R Data Type | Canonical Unit | Required | Description |
|---|---|---|---|---|---|
| 1 | `date` | `Date` | `YYYY-MM-DD` | Yes | Standardized calendar date in Indian Standard Time (`Asia/Kolkata`). |
| 2 | `state` | `character` | — | Yes | Name of the Indian State or Union Territory (e.g., "Telangana", "Delhi"). |
| 3 | `city` | `character` | — | Yes | Standardized urban municipality/city name (e.g., "Hyderabad", "Bengaluru"). |
| 4 | `station_id` | `character` | — | Yes | Unique CAAQMS or source monitoring station identifier (e.g., "TG001", "DL001"). |
| 5 | `station_name` | `character` | — | Yes | Official descriptive name of the monitoring station (e.g., "Sanathnagar, Hyderabad - TSPCB"). |
| 6 | `latitude` | `numeric` | decimal degrees | Yes | Geographic latitude in WGS84 coordinate system (e.g., 17.4589). |
| 7 | `longitude` | `numeric` | decimal degrees | Yes | Geographic longitude in WGS84 coordinate system (e.g., 78.4419). |
| 8 | `pm2_5` | `numeric` | µg/m³ | Yes | 24-hour mean concentration of fine particulate matter ($\le 2.5\ \mu\text{m}$). |
| 9 | `pm10` | `numeric` | µg/m³ | Yes | 24-hour mean concentration of coarse particulate matter ($\le 10\ \mu\text{m}$). |
| 10 | `no2` | `numeric` | µg/m³ | Yes | 24-hour mean concentration of Nitrogen Dioxide. |
| 11 | `so2` | `numeric` | µg/m³ | Yes | 24-hour mean concentration of Sulphur Dioxide. |
| 12 | `co` | `numeric` | mg/m³ | Yes | Daily Carbon Monoxide concentration (canonical CPCB unit is $\text{mg/m}^3$). |
| 13 | `o3` | `numeric` | µg/m³ | Yes | Daily Ground-Level Ozone concentration (8-hr or 24-hr standard). |
| 14 | `nh3` | `numeric` | µg/m³ | No | 24-hour mean concentration of Ammonia (optional criterion pollutant). |
| 15 | `temperature` | `numeric` | °C | Yes | Daily mean ambient 2-meter air temperature from Open-Meteo ERA5 archive. |
| 16 | `humidity` | `numeric` | % | Yes | Daily mean relative humidity at 2 meters from Open-Meteo ERA5 archive. |
| 17 | `wind_speed` | `numeric` | m/s | Yes | Daily mean wind speed at 10 meters from Open-Meteo ERA5 archive. |
| 18 | `wind_direction` | `numeric` | degrees (0–360) | Yes | Daily mean / resultant wind direction at 10 meters from Open-Meteo ERA5. |
| 19 | `pm25_subindex` | `numeric` | 0–500 index | No | Individual subindex for $\text{PM}_{2.5}$ calculated via CPCB linear interpolation. |
| 20 | `pm10_subindex` | `numeric` | 0–500 index | No | Individual subindex for $\text{PM}_{10}$ calculated via CPCB linear interpolation. |
| 21 | `no2_subindex` | `numeric` | 0–500 index | No | Individual subindex for $\text{NO}_2$ calculated via CPCB linear interpolation. |
| 22 | `so2_subindex` | `numeric` | 0–500 index | No | Individual subindex for $\text{SO}_2$ calculated via CPCB linear interpolation. |
| 23 | `co_subindex` | `numeric` | 0–500 index | No | Individual subindex for $\text{CO}$ calculated via CPCB linear interpolation. |
| 24 | `o3_subindex` | `numeric` | 0–500 index | No | Individual subindex for $\text{O}_3$ calculated via CPCB linear interpolation. |
| 25 | `aqi` | `numeric` | 0–500 index | Yes | Composite Indian Air Quality Index ($\max$ of valid subindices meeting CPCB criteria). |
| 26 | `aqi_category` | `character` | — | Yes | CPCB Category: Good, Satisfactory, Moderate, Poor, Very Poor, Severe. |
| 27 | `dominant_pollutant` | `character` | — | Yes | Name of the pollutant whose subindex determines the overall composite AQI. |
| 28 | `day_of_week` | `character` | — | Yes | Day of the week in Indian Standard Time (e.g., "Monday", "Tuesday"). |
| 29 | `month` | `character` | — | Yes | Calendar month name (e.g., "January", "February"). |
| 30 | `season` | `character` | — | Yes | Indian climatological season: Winter, Summer/Pre-monsoon, Monsoon, Post-monsoon. |
| 31 | `air_data_source` | `character` | — | Yes | Primary provenance source of air measurements (e.g., `openaq`, `cpcb`). |
| 32 | `weather_source` | `character` | — | Yes | Provenance source of meteorological data (e.g., `openmeteo_era5`). |
| 33 | `data_quality_flag` | `character` | — | Yes | QC validation flag (e.g., `valid`, `missing_optional_nh3`, `imputed_weather`). |

---

## Important Architectural Rule: Pollutant Drift Calculation
**A static column named `pollutant_drift_score` is deliberately excluded from the base canonical datasets.**

### Scientific Rationale
1. **Dynamic Temporal Windows:** Pollutant drift is inherently relative and depends on comparison between sliding analytical timeframes (e.g., comparing a recent 30-day or 90-day moving window against a multi-year historical or pre-intervention baseline).
2. **Statistical Rigor:** Hardcoding an arbitrary static drift score in the base table conflates physical measurements with a specific analytical model.
3. **Downstream Implementation:** In subsequent analytical phases, drift will be computed dynamically using statistical rolling metrics (such as Welch's $t$-test or percentage shift in mean $\mu_{\text{recent}} - \mu_{\text{baseline}}$) without corrupting base observations.

---

## Units and Missing Data Integrity
- **Physical Zero vs Missing:** A missing sensor value (`NA`) and a true physical zero ($0.0$) are fundamentally different. Under no circumstances are missing values filled with zero.
- **Unit Conversions:** Conversions (such as converting CO from $\mu\text{g/m}^3$ to $\text{mg/m}^3$) are strictly executed only when original units are explicitly verified ($\text{mg/m}^3 = \mu\text{g/m}^3 / 1000$).

## Missing Value Imputation and Final Fields
Currently, the datasets produced in Phase 2C represent the **PRE-AQI** layer.
In the PRE-AQI layer, gas source means (NO2, SO2, CO) remain in source units (ppb) and AQI fields (`aqi`, `aqi_category`, `dominant_pollutant`, `no2`, `so2`, `co`) do NOT yet exist.
The schema above details the **TARGET FINAL FIELDS** that will be populated using the Phase 2D verified methodologies.

*CPCB sufficiency rules (e.g. minimum 3 pollutants including one particulate) have been OFFICIALLY VERIFIED against the 2014 CPCB National AQI report.*


## Phase 2E Update: Verified-Subset AQI Implementation
As of Phase 2E, the qi column (now correctly titled qi_verified in output datasets) is computed using the **VERIFIED_SUBSET_PM25_PM10_O3** policy. CO, NO2, and SO2 lack verifiable source-semantics mapping against historical OpenAQ records and have been permanently excluded from AQI interpolation. They are preserved securely in their original unresolved unit states (e.g., co_source_mean, co_source_unit). This firmly respects the "No Fabrication" rule.
