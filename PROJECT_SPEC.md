# PROJECT_SPEC.md — `thjodhagslikan`

Spec for the **data + forecasting** repo of the VR Iceland macro suite. This is the
authoritative instruction file for any agent (Claude Code) working in `thjodhagslikan`.
Read it before writing code.

## Scope of THIS repo

`thjodhagslikan` owns two things:

1. **The shared data layer** — all ingestion scripts under `R/data/`, producing raw
   per-source parquet files and one assembled monthly panel.
2. **Two modelling engines** that consume that panel:
   - **MF-BVAR-FAVAR** — the 81-variable workhorse forecasting model.
   - **Structural BVAR** — the 6-variable kjarasamningar wage-scenario model.

It does **not** own the monetary-policy-effectiveness suite. That is a separate repo,
`virkni_styrivaxta` (sign-restricted SVAR + local projections + state-dependent LP, with
Jarociński–Karadi decomposition). It has its own `PROJECT_SPEC.md` and its own
`data/` inputs (`main-data.xlsx`, `mpc_announcement.csv`, `breakeven_5y_monthly.csv`).
Do not look for those files here; do not treat that spec's STEP 0 as a gate on this repo.
The two repos are kept narratively consistent (shared core observables) but are
physically independent.

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
  (fiscal)            I. Fiscal                                               [status: check]
pipeline.R            ASSEMBLY ENTRY POINT — currently empty (see below)
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

- **IL-mortgage share** (the thesis's key variable, series 50): computed from the
  **stock** of indexed vs total mortgages, not new-lending flow. Flow nets pre-/over-
  payments and is unstable. Already wired in `06_money_credit.R`.
- **Brent crude**: keep in **USD only**. Do not multiply by ISK/USD — that conflates oil
  and FX shocks.
- **Policy rate**: 7-day term-deposit rate (Meginvextir, Seðlabanki TimeSeriesID 17923).
- **Exchange rate**: trade-weighted index (narrow, "Viðskiptavog þröng") as the sole
  FX carrier. ISK/EUR and ISK/USD kept for reference.
- Drop import-price indices that already embed FX (redundant with an endogenous EER).

---

## STEP 0 — Data-contract exploration (MANDATORY before `pipeline.R` or any model code)

This is the gate for this repo. `pipeline.R` is the assembly step the source scripts
already reference (as `10_assemble.R` in their comments). Before writing or modifying it,
the agent must first produce a **read-only exploration script** that reports the contract
of every `data/raw/*.parquet` and stops. No assembly logic, no modelling, no transforms
in STEP 0 — just discover and report what is actually on disk, because the fetchers hit
live APIs and column sets/coverage drift.

STEP 0 script must, for each parquet in `data/raw/`:
1. Print path, row count, and `date` min/max.
2. Print every column name, its type, and its NA-leading run length (ragged left edge).
3. Print the inferred frequency (monthly vs quarterly) from the `date` spacing.
4. Flag any column whose name does not map to a series in `macro-data-for-favar.md`.
5. Flag any spec series (A–I) with **no** corresponding column anywhere (coverage gaps).
6. Report the common date window across all monthly sources (the panel's usable span).

Output is a printed report only. The agent then **stops and waits** for Vidar to confirm
the contract before STEP 1.

---

## STEP 1 — `pipeline.R` assembly (only after STEP 0 is confirmed)

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
   Δln for real/nominal quantities and prices; levels for rates and ratios. Use
   **CPI excluding housing** as the headline inflation outcome (avoids the mechanical
   rate→CPI link from the pre-June-2024 user-cost housing imputation and the June-2024
   methodology break).
3. **Join** all sources on `date` (full join) into one wide monthly panel.
4. **Write** `data/processed/panel_monthly.parquet` (model-ready) and, if useful, a
   levels-vs-transformed companion plus a column dictionary.

Output two things downstream models can rely on: the FAVAR indicator panel (sections
A–I minus the VAR-block observables and minus interpolated GDP) and the VAR/BVAR core
block (policy rate, CPI ex-housing, activity, EER, IL share, wage index).

---

## Engine specs (consume `data/processed/`)

### MF-BVAR-FAVAR
Engine `mf_bvar_favar.R` is complete: PCA factor extraction (Bai-Ng), Minnesota prior,
mixed-frequency Durbin-Koopman simulation smoother for quarterly GDP, Gibbs sampler,
sign-restriction IRFs, historical decomposition, Waggoner-Zha conditional forecasting.
`tidyverse` + `MASS` only. Real chain-weighted GDP in the VAR block; aluminium export
**value in ISK** (not volume) in the indicator panel. The 8 univariate + 5 neural models
(Python) are Tier-2 benchmarks.

### Structural BVAR (kjarasamningar)
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

- **Transmission identification**: the dominant Icelandic channel (wages → demand/current
  account → ISK depreciation → import prices → CPI) is blocked by construction under a
  Cholesky ordering with wages first and EER last. Any scheme must account for this.
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
  observables identical across models so the economic stories stay compatible.