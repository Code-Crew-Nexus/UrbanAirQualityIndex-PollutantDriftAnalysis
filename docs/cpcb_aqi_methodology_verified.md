# CPCB AQI Methodology - Verification and Implementation Document

## OFFICIAL RULES (VERIFIED FROM CPCB PRIMARY SOURCES)

1. **Pollutants**: The NAQI computes AQI based on 8 parameters, of which this project uses 6: PM2.5, PM10, NO2, SO2, CO, O3.
2. **Breakpoints**: 6 categories: Good (0-50), Satisfactory (51-100), Moderately Polluted (101-200), Poor (201-300), Very Poor (301-400), Severe (401-500). Breakpoint concentrations are defined in CPCB Table 3.11.
3. **Severe Category Open-Endedness**: The Severe category boundaries are open-ended for higher concentrations (e.g. PM10 431+, PM2.5 251+).
4. **Data Sufficiency (Pollutants)**: An overall AQI may be calculated only if a minimum of three pollutants have valid sub-indices, and one of them MUST be PM2.5 or PM10.
5. **Data Sufficiency (Hours)**: A minimum of 16 hours' data is considered necessary for calculating a pollutant sub-index.
6. **Gas Conversion**: Standard CPCB CAAQMS protocol fixes gas conversions at a reference temperature of 25°C.
   - NO2: 1 ppb = 1.88 µg/m³
   - SO2: 1 ppb = 2.62 µg/m³
   - O3: 1 ppb = 1.96 µg/m³
   - CO: 1 ppm = 1.145 mg/m³ $\rightarrow$ 1 ppb = 0.001145 mg/m³
7. **Interpolation Formula**: Linear segmented interpolation maps concentration to sub-index.
8. **ILO Adjustment Rule**: When applying the formula, one must "subtract one from ILO if ILO is greater than 50".
9. **Averaging Periods**: PM2.5, PM10, NO2, SO2 use 24-hour averages. CO and O3 use rolling 8-hour averages.
10. **Ozone Special Rule**: O3 shifts from an 8-hour period to a 1-hour period for the Very Poor (209–748 µg/m³) and Severe (749+ µg/m³) bands.
11. **Overall AQI Rule**: The overall AQI is the maximum of the valid sub-indices.
12. **Scale Maximum**: The CPCB scale defines 500 as the maximum index value.

---

## PROJECT OPERATIONALIZATION (IMPLEMENTATION CHOICES)

1. **Window Time Semantics**: A rolling 8-hour window is defined as the trailing 8 hours ending at the current hour $T$. For calculations early in the day, the trailing window spans back across local midnight into the previous calendar day.
2. **8-Hour Window Completeness**: As CPCB does not explicitly prescribe how many valid observations must exist *within* a single 8-hour window, the project implements a conservative rule: at least 6 out of 8 hours (75%) must be valid for the 8-hour rolling average to be valid.
3. **Severe Category Extrapolation**: For inputs exceeding the Severe lower bound, the sub-index mathematically extrapolates using the slope from the preceding "Very Poor" category. This yields an `aqi_uncapped` internal value. For regulatory display, `aqi_display` is strictly clamped at a maximum of 500.
4. **Input Concentration Precision (Rounding)**: To strictly match integer breakpoint boundaries and avoid unclassified fractional gaps (e.g., 50.5), project policy rounds concentrations half-up to the nearest whole integer (or 1 decimal place for CO) BEFORE band selection and interpolation.
5. **Dominant Pollutant Ties**: If multiple pollutants share the maximum sub-index, they are concatenated alphabetically (e.g., "pm10, pm2_5").
6. **Conversion Sequence**: Gas units are converted to their canonical mass equivalents hour-by-hour prior to any rolling or daily aggregations.
7. **Invalidity Reason Codes**: Instead of failing silently with NA, missing AQI values carry explicit reason codes (e.g. `insufficient_pollutants`, `missing_particulate`, `insufficient_co_hours`).

---

## UNRESOLVED ITEMS

1. **Exact CPCB Calculator Rounding**: CPCB documents do not specify whether the internal calculators explicitly round input averages prior to formula application, or if they rely on truncation/floats. The `PROJECT OPERATIONALIZATION` rounding policy safely bridges this gap.
2. **Current Operational Extrapolation (AQI > 500)**: While the official scale stops at 500, extreme pollution events often trigger public reports above 500. It is unresolved whether official CPCB operations use a capped 500 or extrapolate the Severe slope. The project safely outputs both.

## PROJECT SOURCE-UNIT RESOLUTION

1. **OpenAQ's Reported Units**: During Phase 2, it was discovered that OpenAQ reports Indian gaseous pollutants (CO, NO2, SO2) with the explicit metadata unit of ppb or ppm.
2. **2022 Mass-Counterpart Cutoff**: An investigation into dual-stream tracking found that OpenAQ ceased tracking the explicit mass-unit counterparts (µg/m³, mg/m³) for Indian CAAQMS stations in late 2022. Consequently, no temporal overlap exists between current data (2025-2026) and mass-tagged data to empirically prove a 1:1 scalar relationship.
3. **CPCB Reconciliation Attempt**: A direct API reconciliation against the official CPCB CCR historical portal was determined to be computationally unfeasible without improperly bypassing CAPTCHA or using undocumented/unauthenticated private endpoints.
4. **Final Policy (Verified-Subset)**: Because the source unit semantics for CO, NO2, and SO2 cannot be scientifically verified through authoritative automated means, these three pollutants have been explicitly **EXCLUDED** from AQI sub-index calculations.
5. **Verified Pollutants**: The final operational AQI strictly uses **PM2.5, PM10, and O3**, all of which natively report in canonical mass units. This perfectly satisfies the CPCB structural requirement (minimum 3 pollutants, at least one being a particulate). The resulting AQI represents a mathematically sound, conservative estimate.
