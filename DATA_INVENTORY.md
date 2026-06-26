# DATA_INVENTORY.md — what data we have, proxies, and what's unavailable

Companion to [DATA_GAPS.md](DATA_GAPS.md) and the 81-series spec
[macro-data-for-favar.md](macro-data-for-favar.md). DATA_GAPS lists what is *not*
in the panel; this file is the positive inventory — **what we successfully pull,
which series are proxies (and for what), and what is genuinely unavailable.**

Generated 2026-06-25. Series numbers (#) refer to the A–I, 1–81 spec.

---

## 1. Successfully pulled — direct (the series the spec asked for)

Each row is a `data/raw/*.parquet` written by an `R/data/*.R` fetcher. Frequency
is the *native* frequency (the monthly panel is assembled in `pipeline.R`).

### A. Prices — `prices.parquet`, `ppi.parquet`
| # | Series | Source | Freq | History |
|---|--------|--------|------|---------|
| 1–12, 16, 18 | CPI headline, CPI ex-housing, 10 COICOP divisions, construction-cost index, house prices | Hagstofa PxWeb (saved queries) | M | deep |
| 15 | **PPI** — headline + domestic + **export** producer-price index | Hagstofa VIS08000 (`02_prices_ppi.R`) | M | 2006– |

### B. Real activity — `card_turnover`, `tourism`, `car_registrations`, `aluminium_and_marine_exports`, `gdp`, `retail_turnover` parquets
| # | Series | Source | Freq | History |
|---|--------|--------|------|---------|
| 19, 20 | Card turnover, domestic + abroad | Seðlabanki | M | deep |
| 21 | Vehicle registrations | Samgöngustofa (PDF scrape) | M | 2004– |
| 22 | **Retail + hospitality turnover** (VAT returns, ÍSAT G47/I55/I56) | Hagstofa FYR04101 (`retail_turnover.R`) | bi-monthly | 2008– |
| 27 | Tourist arrivals (Keflavík) | Hagstofa | M | deep |
| 28 | Marine export volume | Hagstofa | M | 2002– |
| 29 | Aluminium production | Hagstofa | M | 2002– |
| 30 | GDP (Denton-Cholette monthly + actual quarterly) | Hagstofa NA | Q→M | deep |

### C. Labour — `labour.parquet`, `vacancies.parquet`, `employment_count.parquet`
| # | Series | Source | Freq | History |
|---|--------|--------|------|---------|
| 31 | **Registered unemployment count** | Vinnumálastofnun xlsm, sheet G2 row 43 (`04_labour.R`) | M | 2000– |
| 32 | Unemployment rate | Vinnumálastofnun | M | 2000– |
| 33 | **Job vacancies** (count + rate) | Hagstofa JVS00001 (`04_labour_extras.R`) | Q | 2019– |
| 34 | Wage index (launavísitala) | Hagstofa | M | deep |
| 35 | Hours worked | Hagstofa | Q | deep |
| 36 | Participation rate | Hagstofa | Q | deep |
| — | Employment count (register-based, *bonus*) | Hagstofa VIN10001 (`04_labour_extras.R`) | M | 2005– |

### D. Interest rates — `financial.parquet`, `retail_rates.parquet`
| # | Series | Source | Freq |
|---|--------|--------|------|
| 37 | Policy rate | Seðlabanki XML | M/daily |
| 38, 39 | REIBOR 3m / 6m | Seðlabanki XML | M |
| 40, 41 | **Non-indexed + indexed mortgage rate** (lowest bond-loan rate) | Seðlabanki "Bankavextir" table (`05_retail_rates.R`) | M, 2003- |
| 43, 44, 45 | Govt nominal yield, indexed yield, breakeven | Seðlabanki XML | M |
| 46 | **Household deposit rate** (almennir sparireikningar) | Seðlabanki "Bankavextir" table | M, 2003- |
| — | Rate-corridor extras (current-account, overnight, collateral lending) | Seðlabanki XML | M |

### E. Money & credit — `money_credit.parquet`
| # | Series | Source | Freq |
|---|--------|--------|------|
| 47 | M3 | gagnabanki (chromote Blob) | M |
| 48, 49 | Household credit, business credit | gagnabanki | M |
| 50 | **IL-mortgage share** (from stock — the key thesis variable) | gagnabanki LOANS IV | M |
| 51 | New mortgage lending | gagnabanki | M |

### F. Exchange rates — `exchange.parquet`
| # | Series | Source |
|---|--------|--------|
| 55, 56 | ISK/EUR, ISK/USD (+ ISK/GBP bonus) | Seðlabanki |
| 57 | Trade-weighted index (narrow) | Seðlabanki |
| 58 | REER | BIS EER API |

### G. External / global — `external.parquet`
| # | Series | Source |
|---|--------|--------|
| 59 | Brent crude (USD) | FRED |
| 61 | FAO food price index | FAO |
| 62 | Aluminium price (USD) | FRED/LME |
| 63, 64 | Euro-area HICP, euro-area IP | Eurostat/ECB |
| 65, 66 | ECB MRO, Fed funds | ECB/FRED |
| 67 | US CPI | FRED |
| 68 | GSCPI (supply-chain pressure) | NY Fed |
| 70 | VIX | FRED |
| — | SE/NO/DK policy rates | respective CBs |

### H. Expectations — `expectations.parquet`, `gallup_confidence.parquet`
| # | Series | Source | Freq |
|---|--------|--------|------|
| 73, 74 | Household + business inflation expectations | Seðlabanki MEASURES xlsx (chromote) | Q |
| 75 | Market-participants expectations (+ 5-horizon policy-rate path, bond breakevens) | Seðlabanki MARKET xlsx | Q |
| 76 | **Consumer confidence** (Gallup Væntingavísitala, VVG) | Gallup public Looker embed (`09_gallup_confidence.R`, chromote) | M, 2001- |

### I. Fiscal — `fiscal.parquet`
| # | Series | Source | Freq | History |
|---|--------|--------|------|---------|
| 79 | **Government revenue** | Hagstofa THJ05211 (`08_fiscal.R`) | annual | 1980– |
| 80 | **Government expenditure** | Hagstofa THJ05211 | annual | 1980– |
| 81 | **Net fiscal balance** | Hagstofa THJ05211 (pulled directly) | annual | 1980– |

---

## 2. Proxies — pulled something *adjacent* to what the spec named

| Spec # | Spec asked for | What we pull instead | Why the proxy | Where |
|--------|----------------|----------------------|---------------|-------|
| 23 | Industrial production **index** | Aluminium production (#29) + marine export volume (#28) | No Icelandic IP index exists; the only Hagstofa IP table (IDN01000) is annual and ends 2018. Aluminium + marine *are* Iceland's monthly tradable-industry output. | `aluminium_and_marine_exports.parquet` |
| 24 | Building **permits** | Residential gross fixed capital formation ("Íbúðarhús") | No free machine-readable permits series; HMS dwelling counts are biannual PDF only. Residential investment is the clean fetchable construction-activity signal. | `residential_investment.parquet` (Hagstofa THJ03111, Q, 1995–) |
| 25 | Housing **starts/completions** | Same residential-investment proxy as #24 | Same reason. | `residential_investment.parquet` |
| 17 | Import **price index** | CPI imported-goods component (`import`) | Deliberate — import price embeds FX and is redundant with the endogenous EER (per spec/README). | `prices.parquet` |
| 71 | Fish **price index** | Marine export **price** index | The actual Icelandic seafood export price; FRED `PFISHUSDM` is fish *meal* (feed), a poor proxy. | (external/marine) |
| 22 | Retail sales **index** | Retail VAT-return **turnover** (nominal, bi-monthly) | Iceland publishes no fixed-base monthly retail index. Turnover is the real series; rebase at modelling step. *(Listed here as a method caveat — the series itself is wired, §1.B.)* | `retail_turnover.parquet` |

**Derived-at-assembly (not gaps, computed in `pipeline.R`, not fetched):**
- #13 CPI services, #14 CPI goods — from the 10 COICOP divisions in `prices.parquet`.
- #60 Brent-in-ISK = #59 × #56. #72 Nordic avg policy rate = weighted SE/NO/DK.

---

## 3. Genuinely unavailable (audited — not merely unsearched)

| # | Series | Verdict |
|---|--------|---------|
| 26 | Electricity consumption | No free machine-readable monthly/deep-history series. Hagstofa (IDN021xx) + Orkustofnun .xlsx are **annual** and lag to ~2020–22; Landsnet `amper.landsnet.is/generation/api/Values` is a **live snapshot** (no history); Iceland is outside ENTSO-E/Nord Pool. Monthly only via paywalled CEIC. |
| 42 | Corporate lending rate | Not in the Seðlabanki "Bankavextir" table (households/general only), XML feed, or gagnabanki (which has loan *volumes*, not the corporate *rate*). PDF only. (NB #40/41/46 were *also* thought PDF-only but turned out to be in the Bankavextir library Excel — see §1.D.) |
| 52 | OMXI stock index | No clean free deep-history feed (Yahoo `^OMXIPI` starts 2013 w/ gaps; Nasdaq OMX scrape fragile). |
| 53 | Sovereign CDS spread | Bloomberg/Refinitiv only (spec said "if avail"). |
| 54 | Financial conditions index | CB publishes no clean monthly FCI (spec said "if CB publishes"). |
| 69 | Baltic Dry Index | Bloomberg/Refinitiv; Yahoo `^BDIY` gone. Shipping channel partly via GSCPI (#68). |
| 78 | PMI | **No Icelandic PMI exists** — S&P Global/Markit doesn't run one; aggregator pages are empty stubs. |

---

## 4. Deferred — exists, but behind a hard interface (realistic remaining backlog)

| # | Series | Where it lives | Blocker |
|---|--------|----------------|---------|
| 77 | Business sentiment (400-largest-firms survey, quarterly) | CB **Hagvísar Chapter II** ("Framleiðsla og eftirspurn") Power BI embed | Power BI export is undocumented/version-fragile; SA publishes per-round PDF press releases only. (Gallup's own Looker dashboard — used for #76 — is consumer-only.) |

If #77 becomes a priority: either scrape the CB Hagvísar Power BI embed (the same
*class* of headless scrape as #76, but Power BI's data export is harder than
Looker's), or check whether Gallup publishes a separate business-sentiment Looker
dashboard like the consumer VVG one.

*(#76 consumer confidence was on this list last session; it is now WIRED — see §1.H
and §5. Gallup exposes the VVG via a public Looker embed whose tile query CSV
(`/explore/<slug>.csv`) is fetchable from inside the embed iframe session — no Power
BI scrape needed after all.)*

---

## 5. New fetchers added this session (2026-06-25)

| File | Writes | Covers |
|------|--------|--------|
| `R/data/03_real_activity/retail_turnover.R` | `retail_turnover.parquet` | #22 |
| `R/data/03_real_activity/residential_investment.R` | `residential_investment.parquet` | #24/#25 proxy |
| `R/data/02_prices_ppi.R` | `ppi.parquet` | #15 (adds export PPI) |
| `R/data/04_labour_extras.R` | `vacancies.parquet`, `employment_count.parquet` | #33, #31-adjacent |
| `R/data/08_fiscal.R` | `fiscal.parquet` | #79/#80/#81 |
| `R/data/05_retail_rates.R` | `retail_rates.parquet` | #40/#41/#46 |
| `R/data/09_gallup_confidence.R` | `gallup_confidence.parquet` | #76 |
| `R/data/04_labour.R` (edited) | adds `unemployment_count` to `labour.parquet` | #31 |

All pulled from the Hagstofa PxWeb JSON API (POST query → CSV) except the
unemployment count (existing Vinnumálastofnun xlsm). The two new real-activity
sub-modules are wired into `R/data/03_real_activity.R`.

**Frequency note for the panel:** #22 is bi-monthly, #33/#24/#25 are quarterly,
and #79/#80/#81 are annual — all enter the **mixed-frequency** handling in
`pipeline.R`, not the native monthly block.
