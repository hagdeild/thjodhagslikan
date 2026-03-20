# FAVAR Variable List: Monetary Policy Transmission in Iceland

## Overview

This document lists recommended monthly time series for a Factor-Augmented VAR (FAVAR)
model examining the effectiveness of monetary policy transmission in Iceland. Variables are
organised by category. The policy rate enters the VAR block as an observable; remaining
series enter the factor estimation panel unless noted otherwise.

**Target panel size:** 60–80 series  
**Frequency:** Monthly (quarterly series noted — interpolate or use mixed-frequency Bayesian estimation)  
**Sample:** 2003m1–2025m12 (post-inflation-targeting, avoids capital controls regime break issues pre-2003 can be discussed)  
**Transformations:** Log-levels → first differences (Δln) for most real/nominal quantities and prices; levels for rates and ratios. All series stationarity-tested (ADF/KPSS) before inclusion.

---

## A. PRICES (18 series)

Core to identifying whether the policy rate genuinely moves consumer prices or whether
disinflation is driven by other factors.

| # | Series | Source | Freq | Transform | Notes |
|---|--------|--------|------|-----------|-------|
| 1 | CPI – All items | Hagstofa (VÍS01000) | M | Δln | Headline inflation |
| 2 | CPI – Food & non-alc beverages | Hagstofa | M | Δln | COICOP 01 |
| 3 | CPI – Alcoholic beverages & tobacco | Hagstofa | M | Δln | COICOP 02, tax-driven |
| 4 | CPI – Clothing & footwear | Hagstofa | M | Δln | COICOP 03, import-heavy |
| 5 | CPI – Housing, water, elec, gas | Hagstofa | M | Δln | COICOP 04, key for IL mortgages |
| 6 | CPI – Furnishings & household equip | Hagstofa | M | Δln | COICOP 05 |
| 7 | CPI – Transport | Hagstofa | M | Δln | COICOP 07, oil-sensitive |
| 8 | CPI – Restaurants & hotels | Hagstofa | M | Δln | COICOP 11, tourism/wage sensitive |
| 9 | CPI – Miscellaneous goods & services | Hagstofa | M | Δln | COICOP 12 |
| 10 | CPI – Domestic goods component | Hagstofa | M | Δln | Domestically produced, wage-sensitive |
| 11 | CPI – Imported goods component | Hagstofa | M | Δln | Exchange rate sensitive |
| 12 | CPI – Excluding housing | Hagstofa | M | Δln | Core measure |
| 13 | CPI – Services | Hagstofa | M | Δln | Labour-cost driven |
| 14 | CPI – Goods | Hagstofa | M | Δln | Import/commodity driven |
| 15 | Producer Price Index (PPI) | Hagstofa | M | Δln | Upstream price pressure |
| 16 | Construction Cost Index (byggingarvisitala) | Hagstofa | M | Δln | Housing supply costs |
| 17 | Import Price Index | Hagstofa | M/Q | Δln | May need interpolation |
| 18 | House prices (capital area) | Þjóðskrá / Registers Iceland | M | Δln | Critical for housing channel |

---

## B. REAL ACTIVITY (12 series)

Capturing the real effects of monetary policy — does tightening actually reduce demand?

| # | Series | Source | Freq | Transform | Notes |
|---|--------|--------|------|-----------|-------|
| 19 | Payment card turnover (real, domestic) | Seðlabanki / RB | M | Δln | Best monthly consumption proxy |
| 20 | Payment card turnover (real, foreign cards in Iceland) | Seðlabanki / RB | M | Δln | Tourism demand |
| 21 | New vehicle registrations | Samgöngustofa | M | Δln | Durable goods demand, credit-sensitive |
| 22 | Retail sales index / turnover | Hagstofa | M | Δln | If available monthly |
| 23 | Industrial production index | Hagstofa | M/Q | Δln | May need interpolation |
| 24 | Building permits (number / m²) | Hagstofa | M | Δln | Forward-looking housing supply |
| 25 | Housing starts / completions | Hagstofa | M/Q | Δln | Housing supply pipeline |
| 26 | Electricity consumption (total) | Orkustofnun / Landsnet | M | Δln | Activity proxy |
| 27 | Tourist arrivals (foreign visitors) | Ferðamálastofa | M | Δln | External demand, major sector |
| 28 | Marine product export volume | Hagstofa | M | Δln | Traditional export sector |
| 29 | Aluminium production/exports | Hagstofa | M | Δln | Energy-intensive sector |
| 30 | GDP (interpolated) | Hagstofa | Q→M | Δln | Chow-Lin or Denton interpolation using card turnover |

---

## C. LABOUR MARKET (6 series)

| # | Series | Source | Freq | Transform | Notes |
|---|--------|--------|------|-----------|-------|
| 31 | Registered unemployment (level) | Vinnumálastofnun | M | Level or Δ | Key slack measure |
| 32 | Registered unemployment rate | Vinnumálastofnun | M | Level | |
| 33 | Job vacancies | Vinnumálastofnun | M | Δln | Demand-side labour indicator |
| 34 | Wage index – IWPI (Törnqvist) | Hagstofa | Q→M | Δln | Official wage measure (used by CB) |
| 35 | Total hours worked | Hagstofa | Q→M | Δln | Better than employment for productivity |
| 36 | Labour force participation rate | Hagstofa | Q→M | Level | Supply-side |

---

## D. FINANCIAL VARIABLES — INTEREST RATES (10 series)

Critical for tracing the pass-through from policy rate to market rates.

| # | Series | Source | Freq | Transform | Notes |
|---|--------|--------|------|-----------|-------|
| 37 | **Policy rate (7-day term deposit)** | Seðlabanki | M | Level | **VAR BLOCK OBSERVABLE** |
| 38 | REIBOR 3-month | Seðlabanki | M | Level | Money market transmission |
| 39 | REIBOR 6-month | Seðlabanki | M | Level | |
| 40 | Non-indexed mortgage rate (new loans, avg) | Seðlabanki / FSA | M | Level | Nominal mortgage channel |
| 41 | Indexed mortgage rate (new loans, avg) | Seðlabanki / FSA | M | Level | Real rate on IL mortgages |
| 42 | Corporate lending rate (non-indexed) | Seðlabanki | M | Level | Business cost channel |
| 43 | Nominal government bond yield (5yr or 10yr) | Seðlabanki / Nasdaq Iceland | M | Level | Term structure |
| 44 | Indexed government bond yield (10yr, HFF/ríkisskuldabréf) | Seðlabanki | M | Level | Real long-term rate |
| 45 | Breakeven inflation (nominal – indexed bond spread) | Calculated | M | Level | Market inflation expectations |
| 46 | Deposit rate (household, avg) | Seðlabanki | M | Level | Savings channel |

---

## E. MONEY, CREDIT & FINANCIAL CONDITIONS (8 series)

| # | Series | Source | Freq | Transform | Notes |
|---|--------|--------|------|-----------|-------|
| 47 | M3 money supply | Seðlabanki | M | Δln | Broad money |
| 48 | Total credit to households | Seðlabanki | M | Δln | Household leverage |
| 49 | Total credit to businesses | Seðlabanki | M | Δln | Business leverage |
| 50 | **Share of inflation-linked mortgages (%)** | Seðlabanki / FSA | M/Q | Level | **KEY VARIABLE — consider VAR block** |
| 51 | New mortgage lending (volume) | Seðlabanki | M | Δln | Flow measure |
| 52 | OMXI stock market index | Nasdaq Iceland | M | Δln | Wealth channel |
| 53 | CDS spread on Iceland sovereign (if avail) | Bloomberg / Refinitiv | M | Level | Country risk |
| 54 | Financial conditions index (if CB publishes) | Seðlabanki | M | Level | Composite |

---

## F. EXCHANGE RATES (4 series)

Essential for the small open economy transmission channel.

| # | Series | Source | Freq | Transform | Notes |
|---|--------|--------|------|-----------|-------|
| 55 | ISK/EUR exchange rate | Seðlabanki | M | Δln | Main trading partner rate |
| 56 | ISK/USD exchange rate | Seðlabanki | M | Δln | Commodity pricing currency |
| 57 | Trade-weighted exchange rate index (narrow) | Seðlabanki | M | Δln | Effective rate |
| 58 | Real effective exchange rate (REER) | Seðlabanki / BIS | M | Δln | Competitiveness |

---

## G. EXTERNAL / GLOBAL VARIABLES (14 series)

These capture global shocks that drive Icelandic inflation independently of domestic
monetary policy — essential for the identification strategy.

| # | Series | Source | Freq | Transform | Notes |
|---|--------|--------|------|-----------|-------|
| 59 | Brent crude oil price (USD) | FRED (DCOILBRENTEU) | M | Δln | Key commodity |
| 60 | Brent crude oil price (ISK) | Calculated (59 × 56) | M | Δln | Domestic fuel cost |
| 61 | Global food price index | FAO | M | Δln | Imported food inflation |
| 62 | Aluminium price (LME, USD) | FRED / LME | M | Δln | Iceland's main commodity export |
| 63 | Euro area HICP | Eurostat (prc_hicp_minr) | M | Δln | Trading partner inflation |
| 64 | Euro area industrial production | Eurostat | M | Δln | External demand |
| 65 | ECB main refinancing rate | ECB SDW | M | Level | Foreign monetary policy |
| 66 | US Federal Funds rate | FRED (FEDFUNDS) | M | Level | Global monetary conditions |
| 67 | US CPI | FRED (CPIAUCSL) | M | Δln | Global inflation benchmark |
| 68 | Global Supply Chain Pressure Index (GSCPI) | NY Fed | M | Level | Supply-side shocks |
| 69 | Baltic Dry Index | FRED / Bloomberg | M | Δln | Shipping costs |
| 70 | VIX (CBOE volatility index) | FRED (VIXCLS) | M | Level | Global risk appetite |
| 71 | Fish price index (if available) | Hagstofa / industry | M | Δln | Key export revenue |
| 72 | Nordic avg policy rate (weighted SE/NO/DK) | Riksbank/Norges/Nationalbanken | M | Level | Regional monetary stance |

---

## H. EXPECTATIONS & SURVEYS (4-6 series)

| # | Series | Source | Freq | Transform | Notes |
|---|--------|--------|------|-----------|-------|
| 73 | Household inflation expectations (1yr) | Seðlabanki (Gallup survey) | Q→M | Level | Expectations channel |
| 74 | Household inflation expectations (2yr) | Seðlabanki (Gallup survey) | Q→M | Level | |
| 75 | Market participants' inflation expect (1yr) | Seðlabanki survey | Q→M | Level | |
| 76 | Consumer confidence index | Gallup / Capacent | M | Level | Demand expectations |
| 77 | Business sentiment / confidence | Gallup / SA | Q→M | Level | Investment intentions |
| 78 | PMI or equivalent (if available) | SA / Capacent | M | Level | |

---

## I. FISCAL (2-3 series, if available monthly)

| # | Series | Source | Freq | Transform | Notes |
|---|--------|--------|------|-----------|-------|
| 79 | Government total revenue | Fjársýsla ríkisins | M | Δln | Fiscal impulse |
| 80 | Government total expenditure | Fjársýsla ríkisins | M | Δln | Fiscal impulse |
| 81 | Net fiscal balance | Calculated | M | Level | Fiscal stance |

---

## Total: ~81 series (exact count depends on data availability)

---

## Key Design Decisions

### VAR block (observed variables in the transition equation)
Minimum: **Policy rate** + **CPI** + **GDP/activity measure**  
Recommended: Add **ISK/EUR**, **IL mortgage share**, **wage index**  
This gives a 5-6 variable VAR block with 3-5 latent factors extracted from the remaining panel.

### Variables to definitely keep in the factor panel (not VAR block)
- All CPI subcomponents (except headline CPI)
- All global/external variables
- All financial market rates except policy rate
- Credit aggregates
- Labour market indicators

### Identification of monetary policy shock
**Option 1 (baseline):** Recursive/Cholesky — policy rate ordered last among domestic
variables. Global variables ordered first (block exogenous to Iceland).

**Option 2 (preferred):** Sign restrictions — policy rate shock: rate ↑, activity ↓,
exchange rate appreciates. **Agnostic on CPI response** — this is the key: don't assume
the answer you're trying to find.

**Option 3 (robustness):** Narrative sign restrictions using known Seðlabanki decisions
that were clearly exogenous (e.g., surprise moves documented in MPC minutes).

### Block exogeneity
Global variables (59-72) should be treated as block exogenous — Iceland is a small
open economy and cannot influence Brent oil prices, euro area inflation, or the Fed
funds rate. This reduces parameters and improves identification.

### Time-varying extension
After establishing baseline results, re-estimate as TVP-FAVAR (Korobilis 2013) or
split sample (pre-2015 vs post-2015, reflecting changing IL mortgage shares) to test
whether transmission has weakened over time.

---

## Data Sources Summary

| Source | URL / Access | Variables |
|--------|-------------|-----------|
| Hagstofa (Statistics Iceland) | hagstofa.is / PxWeb API | CPI, PPI, labour, activity |
| Seðlabanki (Central Bank) | sedlabanki.is / XML API | Rates, credit, money, exchange rates |
| Þjóðskrá (Registers Iceland) | skra.is | House prices |
| FRED (St. Louis Fed) | fred.stlouisfed.org / API | Oil, US rates, VIX, aluminium |
| Eurostat | ec.europa.eu/eurostat / REST API | Euro area HICP, IP |
| ECB SDW | sdw.ecb.europa.eu | ECB rates |
| NY Fed | newyorkfed.org | GSCPI |
| FAO | fao.org/worldfoodsituation | Food price index |
| Nasdaq Iceland | nasdaqomxnordic.com | OMXI, bond yields |
| Vinnumálastofnun | vinnumalastofnun.is | Unemployment, vacancies |
| Ferðamálastofa | ferdamalastofa.is | Tourist arrivals |

---

## Notes on the IL Mortgage Share Variable

This is the single most important institutional variable for your thesis. Sources:

1. **Seðlabanki Financial Stability reports** — usually contain charts/tables on
   mortgage composition (indexed vs non-indexed share of outstanding stock)
2. **FME/FSA data** (now part of Seðlabanki) — supervised entity reports
3. **Íbúðalánasjóður (Housing Financing Fund)** reports — historically the main
   provider of indexed mortgages before the commercial banks entered
4. **Seðlabanki statistical database** — check under "Credit" tables

If only available at low frequency (annual/semi-annual from FS reports), construct a
monthly series using Chow-Lin interpolation with total indexed credit as the related
high-frequency indicator, or model it as a slow-moving state variable in the BVAR.