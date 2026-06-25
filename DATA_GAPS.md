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

## A. Prices (18) — 14 wired, 4 not

| # | Series | Status | Notes |
|---|--------|--------|-------|
| 13 | CPI services | 🟡 DEFERRED | Subcomponent not separately fetched; COICOP divisions we pull don't isolate it. Could derive from Hagstofa services aggregate. |
| 14 | CPI goods | 🟡 DEFERRED | As above (goods aggregate). |
| 15 | Producer Price Index (PPI) | 🟡 DEFERRED | Not wired. Hagstofa publishes PPI (framleiðsluverðsvísitala) — wireable from PxWeb. |
| 17 | Import price index | ⚪ COVERED | Deliberately dropped: embeds FX, redundant with the endogenous EER (per spec/README). `import` (CPI imported component) is pulled instead. |

Wired: 1–12, 16, 18 (headline + ex-housing + 10 COICOP divisions + construction cost + house prices).

## B. Real activity (12) — all key ones wired

| # | Series | Status | Notes |
|---|--------|--------|-------|
| 22 | Retail sales index | 🟡 DEFERRED | Not wired. Hagstofa has a retail turnover index (smávörusala) — wireable. |
| 23 | Industrial production index | 🟡 DEFERRED | Not wired; Hagstofa/quarterly only, would need interpolation. |
| 24 | Building permits | 🟡 DEFERRED | Not wired. |
| 25 | Housing starts / completions | 🟡 DEFERRED | Not wired. |
| 26 | Electricity consumption | 🟡 DEFERRED | Not wired (Orkustofnun/Landsnet). |

Wired: 19, 20 (card turnover dom/foreign), 21 (vehicle regs), 27 (tourist arrivals),
28 (marine export vol), 29 (aluminium), 30 (GDP, Denton-Cholette).

## C. Labour (6) — 4 wired

| # | Series | Status | Notes |
|---|--------|--------|-------|
| 31 | Registered unemployment (level/count) | 🟡 DEFERRED | We emit only the **rate** (32), not the headcount. The Vinnumálastofnun source has the count; could add. |
| 33 | Job vacancies | 🟡 DEFERRED | Not wired (Vinnumálastofnun). |

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

## H. Expectations & surveys (6) — 3 wired, 3 not  ⬅ ACTIVE WORK

| # | Series | Status | Notes |
|---|--------|--------|-------|
| 76 | Consumer confidence index | 🟡 DEFERRED | **Gallup Væntingavísitala** — Vidar is supplying source info (in progress). Not in the two Seðlabanki workbooks already pulled. |
| 77 | Business sentiment / confidence | 🟡 DEFERRED | Gallup/SA source, not wired. |
| 78 | PMI or equivalent | 🟡 DEFERRED | SA/Capacent source; an Icelandic PMI may not have deep history. |

Wired: 73 (household inflation expectations), 74 (business inflation expectations),
75 (market participants' expectations — plus the 5-horizon policy-rate path and bond
breakevens). All in `expectations.parquet`.

## I. Fiscal (3) — none wired

| # | Series | Status | Notes |
|---|--------|--------|-------|
| 79 | Government total revenue | 🟡 DEFERRED | Fiscal block not wired. Source: Fjársýsla ríkisins. |
| 80 | Government total expenditure | 🟡 DEFERRED | As above. |
| 81 | Net fiscal balance | 🟢 DERIVED | = 79 − 80, once those are wired. |

---

## Summary by status (28 not-wired = 8 + 15 + 3 + 2)

- 🔴 **UNAVAILABLE (8)**: 40, 41, 42, 46 (retail bank rates — PDF only); 52 (OMXI), 53 (CDS), 54 (FCI); 69 (Baltic Dry). *No action unless a paid/manual source is accepted.*
- 🟡 **DEFERRED — wireable (15)**: 13, 14, 15 (price aggregates/PPI); 22, 23, 24, 25, 26 (real-activity indices); 31, 33 (labour count/vacancies); 76, 77, 78 (Gallup/PMI surveys); 79, 80 (fiscal). *These are the realistic backlog.*
- 🟢 **DERIVED (3)**: 60 (Brent-ISK), 72 (Nordic avg), 81 (net fiscal). *Computed at assembly, not gaps.*
- ⚪ **PROXY/COVERED (2)**: 17 (import price → EER), 71 (fish → marine export price).

**Highest-value backlog** (drives the thesis / VAR blocks): 76 consumer confidence
(Gallup, in progress), 15 PPI, 22 retail sales, 79/80 fiscal. The 🔴 retail bank rates
(40–42, 46) would materially help the §D pass-through story but appear genuinely
unavailable without scraping CB PDFs.
