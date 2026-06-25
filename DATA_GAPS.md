# DATA_GAPS.md — what we have NOT pulled (and why)

Authoritative list of `macro-data-for-favar.md` series (A–I, 1–81) that are **not**
in the assembled panel, with the reason and status for each. Generated 2026-06-25
from the fetcher "Gaps" blocks, `R/data/00_explore.R`, and STEP 0.

**81 series total → 53 wired, 28 not wired.** Of the 28, over half are deliberate
(no free source, derived at assembly, or covered by a proxy); 15 are "could wire, haven't yet."

Status legend:
- 🔴 **UNAVAILABLE** — no free, machine-readable, deep-history source found (audited, not just unsearched).
- 🟡 **DEFERRED** — a source plausibly exists; not yet built. Candidate for future work.
- 🟢 **DERIVED** — intentionally computed at the modelling step, not fetched. Not a gap.
- ⚪ **PROXY/COVERED** — covered by another series we do pull; deliberately not duplicated.

---

## A. Prices (18) — 15 wired, 2 derived, 1 covered

| # | Series | Status | Notes |
|---|--------|--------|-------|
| 13 | CPI services | 🟢 DERIVED | Clean goods/services aggregate only exists 2024M12+ (VIS01101); the deep-history table (VIS01102, 1997-) has a different 1-12 scheme with no single services aggregate. Services is derivable at assembly from the 10 COICOP divisions already in `prices.parquet` (≈ divisions 05,06,08,10,11,12). |
| 14 | CPI goods | 🟢 DERIVED | As #13 — derivable from the COICOP divisions already pulled (≈ 01-04,07,09). |
| 15 | Producer Price Index (PPI) | 🟢 WIRED | Headline PPI + domestic was ALREADY in `prices.parquet` (02_prices.R §2.6). `02_prices_ppi.R` → `ppi.parquet` adds the **export** producer-price index (Hagstofa VIS08000, monthly 2006-): `ppi`, `ppi_domestic`, `ppi_export`. |
| 17 | Import price index | ⚪ COVERED | Deliberately dropped: embeds FX, redundant with the endogenous EER (per spec/README). `import` (CPI imported component) is pulled instead. |

Wired: 1–12, 16, 18 (headline + ex-housing + 10 COICOP divisions + construction cost + house prices).

## B. Real activity (12) — all key ones wired

| # | Series | Status | Notes |
|---|--------|--------|-------|
| 22 | Retail sales index | 🟢 WIRED | `retail_turnover.R` → `data/raw/retail_turnover.parquet`. Hagstofa FYR04101 VAT-return turnover (nominal, bi-monthly, ÍSAT G47 retail + I55/I56 hospitality), 2008→present. Not a fixed-base index — rebase downstream; bi-monthly → mixed-frequency block. |
| 23 | Industrial production index | ⚪ PROXY/COVERED | No live Icelandic IP index exists — the only Hagstofa table (IDN01000) is *annual* and ends 2018. Monthly industrial output is already covered by aluminium production + marine export volume (#28/#29). Not interpolating a stale annual series. |
| 24 | Building permits | ⚪ PROXY/COVERED | No free machine-readable permits series (Hagstofa building tables are stale-annual to 2021; HMS dwelling counts are PDF/biannual only). Proxied by `residential_investment.R` → `residential_investment.parquet` (Hagstofa THJ03111, residential GFCF "Íbúðarhús", quarterly 1995-, chain-vol SA + current prices). |
| 25 | Housing starts / completions | ⚪ PROXY/COVERED | Same proxy as #24 (residential investment). The physical unit count (HMS "íbúðir í byggingu") is biannual PDF only — not machine-readable. |
| 26 | Electricity consumption | 🔴 UNAVAILABLE | **Audited.** No free machine-readable monthly/deep-history series. Hagstofa (IDN021xx) + Orkustofnun (gogn.orkustofnun.is .xlsx) are **annual** and lag to ~2020-22; Landsnet `amper.landsnet.is/generation/api/Values` is a **live snapshot** with no history; Iceland is outside ENTSO-E/Nord Pool. CEIC sells a monthly series (paywalled). Real-industry activity is covered by aluminium (#29) + marine vol (#28). |

Wired: 19, 20 (card turnover dom/foreign), 21 (vehicle regs), 27 (tourist arrivals),
28 (marine export vol), 29 (aluminium), 30 (GDP, Denton-Cholette).

## C. Labour (6) — all 6 wired

| # | Series | Status | Notes |
|---|--------|--------|-------|
| 31 | Registered unemployment (level/count) | 🟢 WIRED | Added `unemployment_count` to `labour.parquet` (04_labour.R) — VMST workbook sheet G2 row 43 "Atvinnulausir, meðalfjöldi á mánuði / Landið allt", monthly from 2000. (Bonus: `employment_count.parquet` from Hagstofa VIN10001, register-based number EMPLOYED, monthly 2005-.) |
| 33 | Job vacancies | 🟢 WIRED | `04_labour_extras.R` → `vacancies.parquet` (Hagstofa JVS00001, total economy, **quarterly** 2019Q1-): `vacancies` count + `vacancy_rate`. |

Wired: 32 (unemployment rate), 34 (wage index/launavísitala), 35 (hours/unnar stundir),
36 (participation/atvinnuþátttaka). All in `labour.parquet`.

## D. Interest rates (10) — 6 wired, 4 not

| # | Series | Status | Notes |
|---|--------|--------|-------|
| 40 | Non-indexed mortgage rate (new loans) | 🔴 UNAVAILABLE | **Audited both Seðlabanki services** — not in xmltimeseries feed (groups 1/4/20 only) nor gagnabanki (`/api/config` "interests" = key rate + REIBOR + govt curve only). Exists only in FS/FME **PDF tables**. |
| 41 | Indexed mortgage rate (new loans) | 🔴 UNAVAILABLE | Same as 40. |
| 42 | Corporate lending rate (non-indexed) | 🔴 UNAVAILABLE | Same as 40. gagnabanki has loan *volumes* but not the corresponding *rates*. |
| 46 | Deposit rate (household, avg) | 🔴 UNAVAILABLE | Same as 40. |

Wired: 37 (policy rate), 38/39 (REIBOR 3m/6m), 43 (govt nominal yield), 44 (govt indexed
yield), 45 (breakeven). Plus extra rate-corridor series (current-account, overnight,
collateral lending) carried as bonus levels.

## E. Money, credit & financial conditions (8) — 5 wired, 3 not

| # | Series | Status | Notes |
|---|--------|--------|-------|
| 52 | OMXI stock market index | 🔴 UNAVAILABLE | No clean free deep-history feed. Yahoo `^OMXIPI` starts only 2013 with gaps; Nasdaq OMX Nordic site is a fragile scrape that may not reach 2003. |
| 53 | CDS spread (Iceland sovereign) | 🔴 UNAVAILABLE | Bloomberg/Refinitiv only (spec said "if avail"). |
| 54 | Financial conditions index | 🔴 UNAVAILABLE | CB publishes no clean monthly FCI series (spec said "if CB publishes"). |

Wired: 47 (M3), 48 (HH credit), 49 (business credit), 50 (**IL-mortgage share** — the key
variable, from stock), 51 (new mortgage lending).

## F. Exchange rates (4) — all wired

Wired: 55 (ISK/EUR), 56 (ISK/USD), 57 (TWI narrow), 58 (REER). Plus ISK/GBP as bonus.

## G. External / global (14) — 11 wired, 3 not

| # | Series | Status | Notes |
|---|--------|--------|-------|
| 60 | Brent crude in ISK | 🟢 DERIVED | = 59 (Brent USD) × 56 (ISK/USD), computed at assembly. **NB:** README/spec lean toward keeping Brent in USD only to avoid conflating oil & FX shocks — so this may stay unused. |
| 69 | Baltic Dry Index | 🔴 UNAVAILABLE | Index is Bloomberg/Refinitiv; Yahoo `^BDIY` gone, `BDRY` is a 2018+ ETF proxy. Shipping/supply channel partly captured by GSCPI (68). |
| 71 | Fish price index | ⚪ COVERED | Covered by the marine export price index (§B) — the actual Icelandic seafood export price. FRED `PFISHUSDM` is fish *meal* (animal feed), a poor proxy. |
| 72 | Nordic avg policy rate (weighted) | 🟢 DERIVED | We pull SE/NO/DK separately (`policy_rate_se/no/dk`); the GDP/trade-weighted average is derived at assembly (weights not yet applied). |

Wired: 59 (Brent USD), 61 (FAO food), 62 (aluminium USD), 63 (euro HICP), 64 (euro IP),
65 (ECB MRO), 66 (Fed funds), 67 (US CPI), 68 (GSCPI), 70 (VIX), + SE/NO/DK rates.

## H. Expectations & surveys (6) — 3 wired, 2 deferred (Power BI), 1 unavailable

| # | Series | Status | Notes |
|---|--------|--------|-------|
| 76 | Consumer confidence index | 🟡 DEFERRED | **Gallup Væntingavísitala** lives only in CB **Hagvísar Chapter II** ("Framleiðsla og eftirspurn"), which is an **embedded Power BI report** (`app.powerbi.com/view?r=…`). Audited: not in OECD SDMX (Iceland absent), not in Hagstofa PxWeb, not in gagnabanki `/api/config`, not in the XML feed. The `/library/…/HV_…II….xlsx` path serves only the Veva SPA shell to non-interactive fetches. Extracting needs a fragile Power BI query-API scrape. Gallup itself = PDF only. |
| 77 | Business sentiment / confidence | 🟡 DEFERRED | Same Hagvísar Chapter II Power BI embed (400-largest-firms survey, quarterly). SA publishes per-round PDF press releases only. |
| 78 | PMI or equivalent | 🔴 UNAVAILABLE | **No Icelandic PMI exists** — S&P Global/Markit does not run one for Iceland; aggregator "Iceland PMI" pages are empty stubs. The Hagvísar demand/business-survey series are the only output-tendency proxy (and are Power-BI-locked, see #77). |

Wired: 73 (household inflation expectations), 74 (business inflation expectations),
75 (market participants' expectations — plus the 5-horizon policy-rate path and bond
breakevens). All in `expectations.parquet`.

## I. Fiscal (3) — all 3 wired (annual)

| # | Series | Status | Notes |
|---|--------|--------|-------|
| 79 | Government total revenue | 🟢 WIRED | `08_fiscal.R` → `fiscal.parquet`, `gov_revenue` (Hagstofa THJ05211, central govt, ISK m). **ANNUAL** 1980-2025 (no current monthly fiscal exists — the monthly table THJ95200 ends 2014) → mixed-frequency block. |
| 80 | Government total expenditure | 🟢 WIRED | Same table/file, `gov_expenditure`. Annual 1980-2025. |
| 81 | Net fiscal balance | 🟢 WIRED | Pulled directly as `gov_balance` (Tekjuafgangur/-halli) in the same table — no longer needs deriving, though = 79 − 80 holds. |

---

## Summary by status (updated 2026-06-25 — see DATA_INVENTORY.md)

This session wired/resolved 13 of the former backlog items (#15, 22, 31, 33, 79, 80, 81
wired; #24, 25 proxied; #13, 14 derived; #26, 78 audited to unavailable). Remaining
not-wired:

- 🔴 **UNAVAILABLE (10)**: 40, 41, 42, 46 (retail bank rates — PDF only); 52 (OMXI), 53 (CDS), 54 (FCI); 69 (Baltic Dry); **26 (electricity — annual/snapshot only)**; **78 (no Icelandic PMI exists)**. *No action unless a paid/manual source is accepted.*
- 🟡 **DEFERRED — wireable but hard (2)**: 76, 77 (Gallup consumer/business confidence — locked in a CB Hagvísar **Power BI embed**; needs a fragile PBI query-API scrape). *The realistic remaining backlog.*
- 🟢 **DERIVED (5)**: 13, 14 (CPI goods/services from COICOP), 60 (Brent-ISK), 72 (Nordic avg), 81 (now also pulled directly). *Computed at assembly, not gaps.*
- ⚪ **PROXY/COVERED (5)**: 17 (import price → EER), 23 (IP → aluminium+marine), 24, 25 (building → residential investment), 71 (fish → marine export price).

**Remaining highest-value gap**: 76 consumer confidence (Gallup) — only the Power BI
embed stands between us and it. The 🔴 retail bank rates (40–42, 46) remain the other
material gap for the §D pass-through story (CB PDF tables only).
