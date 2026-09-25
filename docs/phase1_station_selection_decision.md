# Phase 1.6 Scientific Station Selection & Human Decision Pack

## A. Phase 1 Verified Foundation
The project now sits upon a robust, verified foundation built entirely on authentic OpenAQ data:
* **Integrity:** 330 total immutable raw API responses verified against a strict SHA-256 manifest.
* **Accuracy:** City matching accurately handles exact matches and `metro_adjacent` (e.g. Navi Mumbai).
* **Provenance:** Zero synthetic observations. All metadata and coverage tests execute against actual sensor lineage configurations and proper 30-day API intervals.

## B. Why Station Choice Matters
Recent coverage informs whether a station can feed current conditions and future predictions. Historical sensor lineage tells us if a model can be trained on past data. A scientifically sound study must avoid confusing a long location-level bounding date (e.g., 2016-2026) with a continuous, gap-free sensor lineage.

## C. Hyderabad Candidate Review
After targeted coverage audits, Hyderabad possesses several distinct active candidate stations. A few have complete core pollutant coverage (PM2.5, PM10, NO2, SO2, CO, O3), while others lack key gases. Station selection must balance geographical spread, pollutant depth, and historical continuity.

## D. Hyderabad Strategies H1 / H2 / H3
* **H1 — CORE HYDERABAD:** Strict focus on dense urban stations inside the core municipal boundary. Maximizes city-center relevance but may cluster spatially.
* **H2 — CORE + METROPOLITAN HYDERABAD:** Includes high-quality metropolitan/suburban stations (e.g., ICRISAT Patancheru, if available/active). Provides a broader urban footprint.
* **H3 — BALANCED URBAN + PERIPHERAL:** Combines core stations with explicitly industrial or peripheral stations to maximize variance in air quality measurements across zones.

## E. Hyderabad Configurations
* **H-COMPACT (approx. 5 stations):** The strongest, most reliable sensors with all core pollutants and near-continuous histories.
* **H-BALANCED (approx. 7 stations):** A scientifically representative mix covering distinct city zones.
* **H-EXTENDED (approx. 8+ stations):** Inclusion of legacy-heavy or missing-gas sensors for maximal spatial density, accepting some missing data blocks.

## F. India City Review
The national shortlist covers 15 distinct cities. Each has 1 to 3 verified candidates. Due to OpenAQ's strict free-tier rate limits, processing all 15 cities with rich histories may challenge practical constraints, warranting consideration of a balanced selection.

## G. India Configurations I1 / I2 / I3
* **I1 — COMPACT / HIGH RELIABILITY (approx. 10 cities):** Selects only cities with robust, multi-pollutant, continuous history stations (e.g., Delhi, Mumbai, Bengaluru).
* **I2 — BALANCED NATIONAL (approx. 12 cities):** Ensures broad geographic representation (North, South, East, West, Central) while dropping 3 marginally performing cities.
* **I3 — BROAD NATIONAL (15 cities):** Maximizes geographic scale but accepts stations with significant missing historical blocks or fewer pollutants.

## H. Sensor-Lineage Continuity Findings
Analysis of sensor `datetime_first` and `datetime_last` reveals that many OpenAQ locations have structural generation gaps (e.g., a legacy sensor ending in 2022, and a new sensor beginning in 2024). Multi-year periods of silence frequently exist.

## I. Historical Source Strategies S1 / S2 / S3
* **S1 — OPENAQ CONTINUOUS-RECENT ONLY:** Limit the training history to the most recent, unbroken block (e.g., 2024/2025–2026). Simpler, homogeneous, but shorter duration.
* **S2 — OPENAQ SEPARATE BLOCKS:** Treat the legacy period and the recent period as distinct, unbridged historical blocks in the dataset.
* **S3 — VERIFIED GAP BACKFILL LATER:** Rely on OpenAQ for recent/future data, but integrate static verified CPCB historical files (in Phase 2 or later) to bridge the multi-year gaps.

## J. Historical Windows A / B / C
* **WINDOW A — CONSERVATIVE CONTINUOUS:** Uses only the verified continuous block from early 2025 to 2026. Highly reliable for next-day forecasting.
* **WINDOW B — BALANCED:** Reaches back to 2023, accepting that some stations may have minor gaps that require modeling as separate analytical periods.
* **WINDOW C — EXTENDED / MULTI-BLOCK:** Reaches back to 2018, explicitly managing legacy periods and relying heavily on S3 (backfill) for continuity.

## K. Pollutant Policies P-A / P-B / P-C
* **P-A — SIX-POLLUTANT STRICT:** Demand all 6 core pollutants. (Reduces candidate pool significantly).
* **P-B — PRACTICAL:** Require strong PM2.5 + PM10, plus any available gases, allowing NA values for missing gases.
* **P-C — AQI-METHODOLOGY-DRIVEN:** Final pollutant sufficiency rules will be implemented only after verifying official CPCB AQI methodology in the AQI phase.

## L. Past -> Current -> Future Prediction Design
The eventual methodology logically separates timeframes:
* **Past (Training):** The verified historical block trains the algorithm.
* **Recent (Validation/Testing):** The recent 30-day block validates the model.
* **Future (Inference):** The live pipeline executes next-day predictions.
* **Primary Target:** Multiple Linear Regression predicting next-day continuous AQI.
* **Secondary Target:** Logistic Regression predicting next-day binary "Poor" AQI probability.

## M. Estimated Phase 2 Acquisition Size
* **Stations:** ~7 Hyderabad + ~20 National (~27 total)
* **History:** ~2 years (approx. 730 days)
* **Data Volume:** 27 * 730 * 24 = ~473,000 hourly observation rows.
* **API Constraints:** At 60 req/min, retrieving detailed daily/hourly histories will take multiple hours of background execution. (Note: The number of data rows is NOT the number of API requests; requests are paginated or bundled by day).

## N. Exact Human Decisions Still Required
Before Phase 2 can begin, the human lead must decide:
1. Which Hyderabad Geographic Strategy (H1, H2, H3)?
2. Which National City Configuration (I1, I2, I3)?
3. Which Historical Source Strategy (S1, S2, S3)?
4. Which Historical Window (A, B, C)?
5. Which Pollutant Policy (P-A, P-B, P-C)?

Please review the generated decision pack CSVs in `data/metadata/` and provide your final choices.
