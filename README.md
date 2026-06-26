# thjodhagslikan — Iceland macro forecasting & scenario model (VR)

Macroeconomic modelling for Verkalýðsfélag Reykjavíkur (VR). This repo does **two**
things and nothing else:

1. **Forecasting** — produce the most accurate possible forecast of the Icelandic
   economy (CPI, policy rate, exchange rate, unemployment, activity, …) using BVAR /
   FAVAR or a blend. Low forecast error is the only objective. Whatever specification
   forecasts best wins.
2. **Scenario analysis** — answer counterfactual "what if" questions for collective
   bargaining (kjarasamningar) prep. Not only IRFs, but conditional scenarios such as
   *"if wages rise by X%, what happens to the policy rate, inflation, the exchange rate
   and unemployment?"* — reported as **differences between scenarios**.

That is the whole project. This repo has **no research thesis** about whether the
Seðlabanki policy rate is the right or wrong tool, and no monetary-policy-transmission
argument to defend. Do not describe the project that way, and do not treat the
inflation-linked (verðtryggð) mortgage channel as a thesis. The IL-mortgage share series
*is* used here — but only as one ordinary predictor in the forecasting panel.

---

## Repo layout

```
R/
  data/                     <- shared data layer feeding both engines
    01_helpers.R               fix_date, splice_series, monthly_to_quarterly, quarterly_to_monthly
    02_prices.R                Hagstofa CPI / byggingarvísitala / import / domestic prices
    03_real_activity.R         orchestrator for real-activity sub-modules
    03_real_activity/          gdp, card_turnover, tourism, exports, car_registrations
    05_financial.R             Seðlabanki XML: policy rate, REIBOR, par-yield curve, breakeven
    06_money_credit.R          gagnabanki (chromote): M3, credit, IL-mortgage share
    07_exchange.R              exchange rates
    08_external.R / 08_fiscal.R, 09_expectations.R   external, fiscal, expectations
    00_explore.R               STEP 0 read-only data-contract report
  pipeline.R                assembly entry point (reads data/raw/ -> data/processed/)
  mf_bvar_favar.R           forecasting engine
  <structural BVAR engine>  scenario engine
data/
  raw/                      one parquet per source (raw units, NOT model-ready)
  processed/                assembled panels (model-ready)
macro-data-for-favar.md     the 81-series variable spec (sections A–I)
```

**Conventions** (already established in the scripts; keep them):
- One R script per data source. Raw outputs as individual parquet files under `data/raw/`.
- Bespoke-parsing sources (PDF scrape, PowerBI, gagnabanki Blob) fully isolated in their
  own files.
- JS-rendered pages: `chromote` to render, then `rvest`/`readxl` to extract.
- Transforms (Δln etc.) applied centrally at the assembly step, NOT in the source scripts.
  Source scripts store RAW values.
- Stack: R + tidyverse; `arrow` for parquet. Modelling engines use `tidyverse` + `MASS` only.

---

## The two engines (shared data layer, separate engines)


### 1. MF-BVAR-FAVAR — forecasting workhorse
81-variable mixed-frequency Bayesian FAVAR, built from scratch in R (`mfbvar` package
abandoned). Engine `mf_bvar_favar.R` (~900 lines) is **complete**: PCA factor extraction
(Bai-Ng), Minnesota prior, mixed-frequency Durbin-Koopman simulation smoother for quarterly
GDP, Gibbs sampler, IRFs, historical decomposition, Waggoner-Zha conditional forecasting.
Dependencies: `tidyverse` + `MASS` only.

This is the engine whose job is accuracy. The 8 univariate + 5 neural models
(Python/neuralforecast) are retained as Tier-2 benchmarks to beat.

Locked decisions: real chain-weighted GDP for the VAR block; aluminium export *value in ISK*
(not volume) for the indicator panel; variables organised into sections A–I per
`macro-data-for-favar.md`.

### 2. Structural BVAR — kjarasamningar scenario analysis
6-variable BVAR: log wage index, output gap, log CPI, 5-year breakeven, policy rate,
log trade-weighted EER. Wage scenarios conditioned via Waggoner-Zha.

This is the engine that answers "what if wages rise by X%". Output is always framed as
**differences between scenarios** (the marginal inflation and policy-rate cost of an extra
percentage point of wage growth), never a single absolute conditional forecast.

Locked decisions: condition on the **continuous VR wage index** (not discrete negotiated
wages — January-only spikes create large negative Waggoner-Zha shocks in flat quarters).
Impose the Daníelsson (2021, CBI WP 87) cointegrating vector (log CPI ≈ 0.65·log ULC +
0.35·log pf), forced rank r=1. Exogenous: log EU HICP, log Brent (USD), centered seasonal
dummies, 2008-crisis and capital-controls dummies. Minnesota prior with unit-root settings
on log wage, log CPI, log EER.

---

## Status

| Component | State |
|---|---|
| Data: real activity (03) | wired (GDP, card turnover, tourism, exports, car regs) |
| Data: financial (05) | wired (policy rate, REIBOR, par-yield curve, breakeven) |
| Data: money/credit (06) | wired (M3, credit, IL-mortgage share) |
| Data: prices (02_prices) | wired (CPI, byggingarvísitala, import, domestic) |
| Data: labour / external / expectations | wired (04/08/09 → labour, external, expectations parquets) |
| Data: fiscal (I) | annual only; enters via mixed-frequency block |
| `data/raw/` parquets | populated for wired sources |
| `data/processed/` panel | wired — `panel_monthly{,_levels}.parquet` + `column_dictionary.csv` (282 mo, 100 series) |
| `pipeline.R` | wired — reads `data/raw/`, interpolates Q→M, applies transforms, writes `data/processed/` |
| MF-BVAR-FAVAR engine | complete |
| Structural BVAR | running, open issues (below) |

---

## Open issues (structural BVAR / scenario engine)
- High rejection rate (~67%) in sign-restriction sampling.
- Conditioning shocks too large.
- Near-zero output-gap response across scenarios.
- Candidate fix on the table: add current account as a 7th variable to capture
  wages → demand → ISK depreciation → import prices → CPI.

---

## Next actions
1. **Feed the panel to the engines** — wire `mf_bvar_favar.R` (FAVAR indicator panel =
   sections A–I minus core-block minus interpolated GDP) and the structural BVAR
   (core block + breakeven) to `data/processed/panel_monthly.parquet`.
2. ✅ **Backcast car registrations** to 2003 — done (reversed-ARIMA,
   `car_registrations_05_backcast.R`; 2003 rows tagged `source="backcast_arima"`).
3. **Finish the data layer** — fiscal section (I) handling; optionally add deferred series.
4. Resolve the structural-BVAR open issues; test the 7th-variable (current account) addition.
5. Forecast evaluation: out-of-sample RMSE/MAE of MF-BVAR-FAVAR vs the Tier-2 benchmarks
   across horizons; pick the specification that minimises error.

---

## Principles / learnings (do not re-litigate)
These are modelling lessons, stated without reference to any policy thesis.
- **Wage–CPI**: no significant *short-run* link in Icelandic data — only a long-run
  cointegrating relationship. Freely estimated BVECM loadings on wages in the CPI equation
  come out near zero; impose the cointegrating vector and loading externally (Daníelsson).
- **Identification for scenarios**: under a Cholesky ordering with wages first and exchange
  rate last, the wages → demand → current account → ISK depreciation → import prices → CPI
  channel is blocked by construction. Any identification scheme for the scenario engine must
  account for this (hence the current-account candidate fix).
- **Levels BVAR instability**: log-level BVAR with ~100 obs and 5+ variables → explosive
  posteriors. Minnesota prior alone is insufficient; add a companion-matrix spectral-radius
  filter (~1.005). QoQ-differenced specs are more tractable for forecasting.
- **Interpolated GDP**: Denton-Cholette without an indicator fabricates within-quarter
  variation that loads spuriously onto FAVAR factors. Drop interpolated GDP from the
  indicator panel; use actual quarterly GDP only in the BVAR/VAR step.
- **CPI housing break (June 2024)**: user-cost housing imputation discontinued. Analysis
  across the break uses CPI ex-housing or models the break explicitly.
- **Variable construction**: keep Brent in USD (not ISK) to avoid conflating oil and FX
  shocks. Drop import-price indices that already embed FX (redundant with an endogenous EER).
- **COICOP break (Jan 2026)**: Hagstofa switched ISLCOICOP → COICOP 2018, only 12 months
  back-calculated. Divisions 01–05, 10, 11 stable; 07–09 need splicing or Eurostat HICP
  back-series. Headline CPI and indexation indices unaffected.
- **Conditioning on wage paths**: always use the continuous VR wage index. Discrete
  January-only spikes create large negative Waggoner-Zha shocks in flat quarters.
- **Model-suite philosophy**: narrative consistency across the two engines > numerical
  agreement. Keep core observables (CPI, policy rate, wage index, EER, inflation
  expectations) identical across both so the economic stories stay compatible — mirroring
  the Seðlabanki's own multi-model approach (QMM, VAR, DSGE).