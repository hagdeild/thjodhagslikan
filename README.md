# Iceland Macro Modelling Suite — VR

Independent macroeconomic modelling for Verkalýðsfélag Reykjavíkur (VR). Two goals,
one shared data layer:

1. **Bargaining (kjarasamningar) support** — credible macro forecasts and wage-scenario
   analysis for collective-bargaining preparation.
2. **Research** — a paper arguing that the Seðlabanki policy rate is not the right tool
   for fighting Icelandic inflation. The thesis is about *transmission*, not stance: the
   conclusion is explicitly **not** "raise rates more."

Core institutional mechanism behind the research: Iceland's inflation-linked (verðtryggð)
mortgage market. When nominal rates rise, households refinance from nominal to indexed
loans, lowering monthly payments and sustaining demand — potentially muting monetary
transmission. Supporting channels: cost-push through construction, asymmetric exchange-rate
pass-through to food prices.

---

## How this repo is organised

```
R/
  data/                     <- SHARED data layer (used by all three models)
    03_real_activity.R         orchestrator for real-activity sub-modules
    03_real_activity/          gdp, card_turnover, tourism, exports, car_registrations
    05_financial.R             Seðlabanki XML: policy rate, REIBOR, par-yield curve, breakeven
    06_money_credit.R          gagnabanki (chromote): M3, credit, IL-mortgage share
    ...                        other section files (prices, labour, external, expectations)
  data/02_prices.R          Hagstofa CPI / byggingarvísitala / import / domestic prices
data/
  raw/                      one parquet per source (NOT model-ready)
  processed/                assembled panels (model-ready)
macro-data-for-favar.md     the 81-series variable spec (sections A–I)
pipeline.R                  <- assembly entry point (currently EMPTY — see "Next")
```

**Conventions** (follow these; they are already established in the existing scripts):
- One R script per data source. Raw outputs as individual parquet files under `data/raw/`.
- Bespoke-parsing sources (PDF scrape, PowerBI, gagnabanki Blob) fully isolated in their
  own files.
- JS-rendered pages: `chromote` to render, then `rvest`/`readxl` to extract.
- Transforms (Δln etc.) applied centrally at the assembly step, NOT in the source scripts.
  Source scripts store RAW values.
- Stack: R + tidyverse only where possible; `arrow` for parquet. Modelling engines use
  only `tidyverse` + `MASS`.

---

## The three models (shared data layer, separate engines)

### 1. Monetary-policy-effectiveness suite  *(research headline)*
Three models estimating whether/how much the policy rate moves inflation, with **no prior
on sign or magnitude**:
- **Model 1** — sign-restricted SVAR, agnostic on the CPI response (theory cross-check).
- **Model 2** (headline) — local projections on a high-frequency MP surprise series: daily
  5-year nominal bond yield change around MPC announcement dates, with Jarociński–Karadi
  information-shock decomposition using same-day OMXI equity returns.
- **Model 3** — state-dependent local projections interacting the MP surprise with the
  monthly IL-mortgage share (direct test of the refinancing-channel hypothesis).

Locked design decisions:
- Headline inflation outcome = **CPI excluding housing** (avoids the mechanical rate→CPI
  link from the pre-June-2024 user-cost housing imputation and the June-2024 methodology break).
- Brent crude in **USD only**. Euro-area HICP raw and unadjusted. Trade-weighted ISK as the
  sole exchange-rate carrier.
- Clean housing-channel outcomes: paid rent + house-price index. Placebo: public-services CPI.
  Activity proxy: nominal card turnover.
- 5-year breakeven via Nelson-Siegel fitting from RIKB/RIKS wide-format yields, self-starting
  when ≥4 bonds per side (~2011). Optional / robustness only.
- Sample: 2009-onward, monthly.
- A `PROJECT_SPEC.md` exists for this suite with a mandatory **STEP 0 data-contract
  exploration** before any model code.

### 2. MF-BVAR-FAVAR  *(workhorse forecasting model)*
81-variable mixed-frequency Bayesian FAVAR, built from scratch in R (`mfbvar` package
abandoned). Engine `mf_bvar_favar.R` (~900 lines) is **complete**: PCA factor extraction
(Bai-Ng), Minnesota prior, mixed-frequency Durbin-Koopman simulation smoother for quarterly
GDP, Gibbs sampler, sign-restriction IRFs, historical decomposition, Waggoner-Zha conditional
forecasting. Dependencies: `tidyverse` + `MASS` only.

Locked decisions: real chain-weighted GDP for the VAR block; aluminium export *value in ISK*
(not volume) for the indicator panel; variables organised into sections A–I per
`macro-data-for-favar.md`. The 8 univariate + 5 neural models (Python/neuralforecast) are
retained as Tier-2 benchmarks.

### 3. Structural BVAR  *(kjarasamningar scenario analysis)*
6-variable BVAR: log wage index, output gap, log CPI, 5-year breakeven, policy rate,
log trade-weighted EER. Wage scenarios conditioned via Waggoner-Zha.

Locked decisions: condition on the **continuous VR wage index** (not discrete negotiated
wages — those create spike-and-zero conditioning artifacts). Impose the Daníelsson (2021,
CBI WP 87) cointegrating vector (log CPI ≈ 0.65·log ULC + 0.35·log pf), forced rank r=1.
Exogenous: log EU HICP, log Brent (USD), centered seasonal dummies, 2008-crisis and
capital-controls dummies. Minnesota prior with unit-root settings on log wage, log CPI,
log EER. Scenario results framed as **differences between scenarios** (marginal inflation
and policy-rate cost of extra wage growth), not absolute conditional forecasts.

---

## Status

| Component | State |
|---|---|
| Data: real activity (03) | wired (GDP, card turnover, tourism, exports, car regs) |
| Data: financial (05) | wired (policy rate, REIBOR, par-yield curve, breakeven) |
| Data: money/credit (06) | wired (M3, credit, **IL-mortgage share** — the key variable) |
| Data: prices (02_prices) | wired (CPI, byggingarvísitala, import, domestic) |
| Data: labour / external / expectations | wired (04/08/09 → labour, external, expectations parquets) |
| Data: fiscal (I) | not wired — no source yet |
| `data/raw/` parquets | populated for wired sources |
| `data/processed/` assembled panel | wired — `panel_monthly{,_levels}.parquet` + `column_dictionary.csv` (282 mo, 81 series) |
| `pipeline.R` | wired — reads `data/raw/`, interpolates Q→M, applies transforms, writes `data/processed/` |
| MF-BVAR-FAVAR engine | complete |
| Monetary-effectiveness suite | spec written; STEP 0 not yet run |
| Structural BVAR | running, but open issues (below) |

---

## Open issues (structural BVAR)
- High rejection rate (~67%) in sign-restriction sampling.
- Conditioning shocks too large.
- Near-zero output-gap response across scenarios.
- Candidate fix on the table: add current account as a 7th variable to capture
  wages → demand → ISK depreciation → import prices → CPI.

---

## Next actions
1. ✅ **`pipeline.R` assembly** — done. Reads `data/raw/`, interpolates Q→M (GDP via
   Denton-Cholette; wage/hours/participation/expectations via spline), applies central
   transforms, writes `data/processed/panel_monthly{,_levels}.parquet` + `column_dictionary.csv`
   (282 months, 81 series). STEP 0 contract is in `R/data/00_explore.R`.
2. **Feed the panel to the engines** — wire `mf_bvar_favar.R` (FAVAR indicator panel = sections
   A–I minus core-block minus interpolated GDP) and the structural BVAR (core block + breakeven)
   to `data/processed/panel_monthly.parquet`.
3. **Backcast car registrations** to 2003 (reversed-ARIMA or regression on other monthly series)
   to remove the 12 leading NAs that currently gate the fully-populated window at 2004-01.
4. **Finish the data layer** — fiscal section (I) still unwired; optionally add deferred series.
5. Resolve the structural-BVAR open issues; test the 7th-variable (current account) addition.
6. Research deliverables: historical decomposition of monetary policy's contribution to
   2022–2025 disinflation; counterfactual holding the policy rate constant.

---

## Principles / learnings (do not re-litigate)
- **Transmission identification**: the dominant Icelandic channel (wages → demand/current
  account → ISK depreciation → import prices → CPI) is *blocked by construction* under a
  Cholesky ordering with wages first and exchange rate last. Any identification scheme must
  account for this.
- **Wage–CPI**: no significant *short-run* link in Icelandic data — only a long-run
  cointegrating relationship. Freely estimated BVECM loadings on wages in the CPI equation
  come out near zero; impose the cointegrating vector and loading externally (Daníelsson).
- **Levels BVAR instability**: log-level BVAR with ~100 obs and 5+ variables → explosive
  posteriors. Minnesota prior alone is insufficient; add a companion-matrix spectral-radius
  filter (~1.005). QoQ-differenced specs are more tractable for forecasting.
- **CPI housing break (June 2024)**: user-cost housing imputation discontinued. Any analysis
  across the break uses CPI ex-housing or models the break explicitly.
- **Interpolated GDP**: Denton-Cholette without an indicator fabricates within-quarter
  variation that loads spuriously onto FAVAR factors. Drop interpolated GDP from the
  indicator panel; use actual quarterly GDP only in the BVAR/VAR step.
- **Variable construction**: keep Brent in USD (not ISK) to avoid conflating oil and FX
  shocks. Drop import-price indices that already embed FX (redundant with an endogenous EER).
- **COICOP break (Jan 2026)**: Hagstofa switched ISLCOICOP → COICOP 2018, only 12 months
  back-calculated. Divisions 01–05, 10, 11 stable; 07–09 need splicing or Eurostat HICP
  back-series. Headline CPI and indexation indices unaffected.
- **Conditioning on wage paths**: always use the continuous VR wage index. Discrete
  January-only spikes create large negative Waggoner-Zha shocks in flat quarters.
- **Model-suite philosophy**: narrative consistency across models > numerical agreement.
  Keep core observables (CPI, policy rate, wage index, ISK/EUR, inflation expectations)
  identical across models so the economic stories stay compatible — the Seðlabanki's own
  multi-model approach (QMM, VAR, DSGE).