# PROJECT_SPEC.md — `thjodhagslikan`

Authoritative instruction file for any agent (Claude Code) working in `thjodhagslikan`.
Read it before writing code.

## What this repo is

`thjodhagslikan` is the **forecasting + wage-scenario** repo of VR's macro work. Its two
deliverables:

1. **Best-possible forecast** of the Icelandic economy (CPI, policy rate, exchange rate,
   unemployment, activity, …) via BVAR / FAVAR / a blend. Accuracy (low forecast error)
   is the sole criterion for the forecasting engine — whatever specification forecasts
   best wins.
2. **Scenario analysis** for kjarasamningar: IRFs *and* conditional "what-if" scenarios
   (e.g. "wages +X% → what happens to policy rate, inflation, EER, unemployment"),
   reported as **differences between scenarios**.

There is **no policy-rate research thesis in this repo.** Do not describe the project as
arguing that the Seðlabanki policy rate is the wrong tool, and do not treat the
inflation-linked (verðtryggð) mortgage channel as a thesis. The IL-mortgage share is used
here only as one predictor among many.

## Scope of THIS repo

`thjodhagslikan` owns:

1. **The shared data layer** — all ingestion scripts under `R/data/`, producing raw
   per-source parquet files and one assembled monthly panel.
2. **Two modelling engines** that consume that panel:
   - **MF-BVAR-FAVAR** — the 81-variable workhorse forecasting model.
   - **Structural BVAR** — the 6-variable kjarasamningar wage-scenario model.

## Working agreement

- **Language**: R + tidyverse. `arrow` for parquet. Modelling engines depend on
  `tidyverse` + `MASS` only.
- **The agent may run R itself** — including the fetchers and the assembly pipeline —
  to produce parquets, verify outputs, and report results. (Earlier the rule was
  write-and-stop; lifted 2026-06-24.) Network fetchers hit live APIs and need
  credentials (`FRED_API_KEY` in `.Renviron`) and, for some sources, headless Chrome
  / the ACE ODBC driver; if a credential or driver is missing, report that rather
  than fake the data.
- One R script per data source. Bespoke-parsing sources (PDF, PowerBI, gagnabanki Blob)
  stay fully isolated in their own files.
- Source scripts store **raw** values. All transforms (Δln / levels / interpolation)
  happen centrally at the assembly step, never in the fetchers.
- Comments minimal, only where they add what the code doesn't already say.

---

## Data layer

### Layout

```
R/data/
  01_helpers.R        fix_date, splice_series, monthly_to_quarterly, quarterly_to_monthly
  02_prices.R         A. Prices        -> data/raw/prices.parquet
  03_real_activity.R  B. Real activity (orchestrator for the sub-modules below)
  03_real_activity/
    gdp_components.R
    card_turnover.R
    tourism.R
    aluminium_and_marine_exports.R     -> data/raw/aluminium_and_marine_exports.parquet
    car_registrations*.R               -> data/raw/car_registrations.parquet
  05_financial.R      D. Interest rates -> data/raw/financial.parquet
  06_money_credit.R   E. Money & credit -> data/raw/money_credit.parquet  (incl. IL share)
  07_exchange.R       F. Exchange rates -> data/raw/exchange.parquet
  08_external.R       G. External/global (FRED, Eurostat, BIS, FAO, NY Fed)   [status: check]
  09_expectations.R   H. Expectations & surveys                               [status: check]
  08_fiscal.R         I. Fiscal (annual only — mixed-frequency block)
pipeline.R            ASSEMBLY ENTRY POINT
macro-data-for-favar.md   the 81-series variable spec (sections A–I), authoritative for
                          which series exist, their Freq, and their Transform
```

Section numbering follows `macro-data-for-favar.md` sections A–I. The historical
`R/favar_data.R` is an earlier standalone version of the price block; `R/data/02_prices.R`
is canonical. (FLAG: confirm `favar_data.R` can be retired, and that the `splice_series`
in `02_prices.R` — which differs in signature from the one in `01_helpers.R` — is the one
the pipeline should use.)

### Raw-output contract

Every source script writes one parquet to `data/raw/`, in this shape:
- a `date` column = first day of the period (`fix_date` / `floor_date(_, "month")`),
- one numeric column per series, named in snake_case,
- **raw units, no transforms** (M.kr., index points, %, ISK per FX unit, etc.),
- monthly frequency where the source is monthly; native quarterly frequency where the
  source is quarterly (do NOT interpolate inside the fetcher).

Ragged left edges are expected and allowed (e.g. par-yield curve starts 2020, BIS REER
from 1994). The assembly step tolerates NA-leading columns.

### Key construction rules (locked — do not re-derive)

- **IL-mortgage share** (series 50): computed from the **stock** of indexed vs total
  mortgages, not new-lending flow. Flow nets pre-/over-payments and is unstable. Already
  wired in `06_money_credit.R`. (Used here as an ordinary predictor — not a thesis variable.)
- **Brent crude**: keep in **USD only**. Do not multiply by ISK/USD — that conflates oil
  and FX shocks.
- **Policy rate**: 7-day term-deposit rate (Meginvextir, Seðlabanki TimeSeriesID 17923).
- **Exchange rate**: trade-weighted index (narrow, "Viðskiptavog þröng") as the sole
  FX carrier. ISK/EUR and ISK/USD kept for reference.
- Drop import-price indices that already embed FX (redundant with an endogenous EER).

---

## STEP 0 — Data-contract exploration

`R/data/00_explore.R` is the read-only contract report: for each `data/raw/*.parquet` it
prints path, row count, `date` min/max, every column name + type + NA-leading run length,
inferred frequency, columns that don't map to a `macro-data-for-favar.md` series, spec
series with no column anywhere, and the common monthly window. It produces a printed report
only — no assembly, no transforms. Run/refresh it whenever the raw parquets may have drifted
(fetchers hit live APIs and column sets/coverage move).

---

## STEP 1 — `pipeline.R` assembly

**STATUS: built (2026-06-24).** `R/pipeline.R` produces a 282-month panel (2003-01 → 2026-06,
81 series) and writes `data/processed/panel_monthly_levels.parquet`,
`panel_monthly.parquet`, and `column_dictionary.csv`. Decisions baked in: panel start
2003-01 with leading NAs for late-starting series (car registrations 2004-01 — backcast TBD);
internal gaps filled type-aware (spline for index/quantity, LOCF for step-function rates such
as `ecb_mro`) while leading pre-history NAs are left untouched; 40 series Δln (×100), 41 level;
`new_mortgage_lending` kept as level (flow hits ≤0); interpolated `gdp` flagged
`panel_role = "bvar_only"`. The survey breakeven family is prefixed `be_survey_*` to avoid
colliding with the financial bond-spread `breakeven_5y`.

`pipeline.R` reads `data/raw/*.parquet` (it does **not** re-source the fetchers — assembly
is offline and deterministic; fetching is a separate, manual, network-bound step), and:

1. **Interpolate quarterly → monthly** where the spec marks Q→M:
   - GDP via Denton-Cholette (`tempdisagg`), `conversion = "average"`, per
     `research/tempdisagg.R`. Use actual quarterly GDP only in the VAR/BVAR block; keep
     interpolated GDP **out** of the FAVAR indicator panel (fabricated within-quarter
     variation loads spuriously onto factors).
   - Other Q→M series (wage index, hours, participation, expectations) via
     `quarterly_to_monthly` (natural spline) from `01_helpers.R`, unless an indicator
     series is available for proper disaggregation.
2. **Apply central transforms** per the `Transform` column of `macro-data-for-favar.md`:
   Δln for real/nominal quantities and prices; levels for rates and ratios. **CPI excluding
   housing** is the preferred headline inflation outcome (avoids the mechanical rate→CPI link
   from the pre-June-2024 user-cost housing imputation and the June-2024 methodology break).
3. **Join** all sources on `date` (full join) into one wide monthly panel.
4. **Write** `data/processed/panel_monthly.parquet` (model-ready), a levels companion, and a
   column dictionary.

Output two things downstream models rely on: the FAVAR indicator panel (sections A–I minus
the VAR-block observables and minus interpolated GDP) and the VAR/BVAR core block (policy
rate, CPI ex-housing, activity, EER, IL share, wage index).

---

## Engine specs (consume `data/processed/`)

### MF-BVAR-FAVAR — forecasting (accuracy is the objective)
Engine `mf_bvar_favar.R` is complete: PCA factor extraction (Bai-Ng), Minnesota prior,
mixed-frequency Durbin-Koopman simulation smoother for quarterly GDP, Gibbs sampler, IRFs,
historical decomposition, Waggoner-Zha conditional forecasting. `tidyverse` + `MASS` only.
Real chain-weighted GDP in the VAR block; aluminium export **value in ISK** (not volume) in
the indicator panel. The 8 univariate + 5 neural models (Python) are Tier-2 benchmarks to
beat. Selection criterion: out-of-sample forecast error.

### Structural BVAR — kjarasamningar scenarios
6 variables: log wage index, output gap, log CPI, 5-year breakeven, policy rate, log
trade-weighted EER. Condition wage scenarios on the **continuous VR wage index** (never
discrete negotiated wages — January-only spikes create large negative Waggoner-Zha shocks
in flat quarters). Impose the Daníelsson (2021, CBI WP 87) cointegrating vector
(log CPI ≈ 0.65·log ULC + 0.35·log pf), forced rank r=1. Exogenous: log EU HICP, log Brent
(USD), centered seasonal dummies, 2008-crisis and capital-controls dummies. Minnesota prior
with unit-root settings on log wage, log CPI, log EER. Report scenarios as **differences
between scenarios** (marginal inflation and policy-rate cost of extra wage growth).

Open issues: ~67% sign-restriction rejection rate; conditioning shocks too large; near-zero
output-gap response; candidate fix = add current account as a 7th variable
(wages → demand → ISK depreciation → import prices → CPI).

---

## Principles (do not re-litigate)

Modelling lessons only — no policy thesis attached.
- **Scenario identification**: the wages → demand → current account → ISK depreciation →
  import prices → CPI channel is blocked by construction under a Cholesky ordering with
  wages first and EER last. Any scheme must account for this.
- **Wage–CPI**: no significant short-run link; only a long-run cointegrating relationship.
  Impose the vector and loading externally (Daníelsson); freely estimated loadings on wages
  in the CPI equation come out near zero.
- **Levels BVAR instability**: ~100 obs and 5+ variables → explosive posteriors. Minnesota
  prior alone is insufficient; add a companion-matrix spectral-radius filter (~1.005).
  QoQ-differenced specs are more tractable for forecasting.
- **CPI housing break (June 2024)**: user-cost imputation discontinued. Use CPI ex-housing
  or model the break.
- **COICOP break (Jan 2026)**: ISLCOICOP → COICOP 2018, only 12 months back-calculated.
  Divisions 01–05, 10, 11 stable; 07–09 need splicing or Eurostat HICP back-series.
  Headline CPI and indexation indices unaffected.
- **Model-suite philosophy**: narrative consistency > numerical agreement. Keep core
  observables identical across the two engines so the economic stories stay compatible.