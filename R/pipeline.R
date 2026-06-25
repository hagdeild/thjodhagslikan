# pipeline.R — assembly entry point (STEP 1)
#
# Reads data/raw/*.parquet (the per-source raw outputs; this script does NOT
# re-fetch — fetching is the separate, network-bound R/data/*.R step), aligns
# everything to one monthly grid, fills internal gaps, applies the central
# transforms from macro-data-for-favar.md, and writes data/processed/.
#
# Outputs (per the spec's raw->processed contract):
#   data/processed/panel_monthly_levels.parquet — aligned monthly LEVELS
#       (quarterly sources interpolated to monthly, internal gaps filled, but NO
#        Δln/level transforms applied). For inspection, plotting, and any model
#        that wants levels.
#   data/processed/panel_monthly.parquet — MODEL-READY: Δln for quantities &
#       price indices (×100), levels for rates/ratios/expectations.
#   data/processed/column_dictionary.csv — one row per series: source file,
#       native frequency, transform applied, and panel role.
#
# Conventions:
#   • Panel starts 2003-01 (the spec sample floor). Series that start later keep
#     leading NAs (no fabricated pre-history — the estimators tolerate ragged
#     left edges; see PROJECT_SPEC.md). car_registrations starts 2004-01, so it
#     carries 12 leading NAs by design (a backcast may fill these later).
#   • Internal gaps (holes inside a series' active span) ARE filled before
#     transforms — type-aware: index/quantity series by spline, rate/step-function
#     series by last-observation-carried-forward. Leading NAs are left untouched.
#   • Headline inflation outcome is CPI EXCLUDING HOUSING (cpi_less_housing).
#   • Interpolated monthly GDP is produced (Denton-Cholette) but flagged
#     panel_role = "bvar_only": it must stay OUT of the FAVAR indicator panel
#     (fabricated within-quarter variation loads spuriously onto factors); use
#     actual quarterly GDP in the VAR/BVAR block instead.


# 1.0.0 SETUP ----
library(tidyverse)
library(arrow)
library(zoo)
library(tempdisagg)

source("R/data/01_helpers.R")

RAW <- "data/raw"
OUT <- "data/processed"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

PANEL_START <- as.Date("2003-01-01")


# 1.1.0 Helpers ----

rd <- function(name) {
  df <- read_parquet(file.path(RAW, paste0(name, ".parquet")))
  dcol <- intersect(c("date", "period"), names(df))[1]
  df |>
    rename(date = all_of(dcol)) |>
    mutate(date = floor_date(date, "month")) |>
    arrange(date)
}

# Fill INTERNAL gaps only (between first and last non-NA); leave leading/trailing
# NAs as-is. method "spline" for index/quantity series, "locf" for step rates.
fill_internal <- function(x, method = c("spline", "locf")) {
  method <- match.arg(method)
  nn <- which(!is.na(x))
  if (length(nn) < 2) return(x)
  lo <- min(nn); hi <- max(nn)
  seg <- x[lo:hi]
  seg <- if (method == "spline") {
    na.spline(seg, na.rm = FALSE)
  } else {
    na.locf(seg, na.rm = FALSE)
  }
  x[lo:hi] <- seg
  x
}

# Spline-interpolate a quarterly (date, <cols>) tibble to monthly, per column,
# over each column's own non-NA span. Returns monthly (date, <cols>).
quarterly_cols_to_monthly <- function(df, cols) {
  grid <- tibble(date = seq(min(df$date), floor_date(max(df$date), "month"), by = "month"))
  out <- grid
  for (nm in cols) {
    q <- df |> filter(!is.na(.data[[nm]])) |> select(date, value = all_of(nm))
    if (nrow(q) < 2) { out[[nm]] <- NA_real_; next }
    span <- grid |> filter(date >= min(q$date), date <= max(q$date))
    vals <- spline(as.numeric(q$date), q$value, xout = as.numeric(span$date),
                   method = "natural")$y
    out <- out |> left_join(tibble(date = span$date, !!nm := vals), by = "date")
  }
  out
}


# 2.0.0 LOAD RAW ----

prices      <- rd("prices")
gdp_raw     <- rd("gdp")
card        <- rd("card_turnover")
tourism     <- rd("tourism")
alu_marine  <- rd("aluminium_and_marine_exports")
car_reg     <- rd("car_registrations") |> select(date, registrations)  # drop `source` label
financial   <- rd("financial")
money       <- rd("money_credit")
exchange    <- rd("exchange")
external    <- rd("external")
labour      <- rd("labour")
# `breakeven_5y` also exists in financial.parquet (the bond-spread breakeven,
# spec §45). The expectations-file breakevens are a separate survey family; prefix
# them be_survey_* so the two don't collide on the join.
expect      <- rd("expectations") |>
  rename_with(\(x) str_replace(x, "^breakeven_", "be_survey_"))


# 3.0.0 FREQUENCY: quarterly -> monthly ----

# 3.1.0 GDP via Denton-Cholette (conversion = average), no indicator.
#       Produced for completeness/BVAR; flagged bvar_only downstream.
gdp_monthly <-
  local({
    g <- gdp_raw |> filter(!is.na(gdp)) |> arrange(date)
    start_q <- c(year(min(g$date)), quarter(min(g$date)))
    gdp_ts <- ts(g$gdp, start = start_q, frequency = 4)
    fit <- td(gdp_ts ~ 1, to = "monthly", method = "denton-cholette",
              conversion = "average")
    tibble(
      date = seq(min(g$date), by = "month", length.out = length(predict(fit))),
      gdp  = as.numeric(predict(fit))
    )
  })

# 3.2.0 Labour: unemployment is monthly; wage/hours/participation are quarterly
#       columns inside the (ragged) monthly parquet -> interpolate those three.
labour_q_cols <- c("launavisitala", "unnar_stundir", "atvinnuthatttaka", "hlutfall_starfandi")
labour_monthly <-
  labour |>
  select(date, unemployment_rate) |>
  full_join(
    quarterly_cols_to_monthly(
      labour |> select(date, all_of(labour_q_cols)) |>
        filter(if_any(all_of(labour_q_cols), \(x) !is.na(x))),
      labour_q_cols
    ),
    by = "date"
  ) |>
  arrange(date)

# 3.3.0 Expectations: all columns quarterly -> monthly (spline within each span).
expect_cols <- setdiff(names(expect), "date")
expect_monthly <- quarterly_cols_to_monthly(
  expect |> filter(if_any(all_of(expect_cols), \(x) !is.na(x))),
  expect_cols
)


# 4.0.0 ALIGN to one monthly grid ----

sources <- list(
  prices, card, tourism, alu_marine, car_reg, financial, money, exchange,
  external, labour_monthly, gdp_monthly, expect_monthly
)

panel_raw <-
  reduce(sources, full_join, by = "date") |>
  arrange(date) |>
  filter(date >= PANEL_START) |>
  assert_unique_dates()


# 5.0.0 FILL internal gaps (type-aware) ----

# Step-function / rate series: carry forward. Everything else numeric: spline.
locf_cols <- c(
  "policy_rate", "current_account_rate", "overnight_lending_rate",
  "collateral_lending_rate", "reibor_3m", "reibor_6m",
  "govt_yield_nominal_5y", "govt_yield_nominal_10y",
  "govt_yield_indexed_5y", "govt_yield_indexed_10y", "breakeven_5y",
  "fed_funds", "ecb_mro", "policy_rate_se", "policy_rate_no", "policy_rate_dk"
)

panel_levels <-
  panel_raw |>
  mutate(across(any_of(locf_cols), \(x) fill_internal(x, "locf"))) |>
  mutate(across(
    where(is.numeric) & !any_of(c(locf_cols)),
    \(x) fill_internal(x, "spline")
  ))


# 6.0.0 TRANSFORM map ----
#
# Δln (log_diff, ×100): real/nominal quantities and price indices.
# Level: rates, ratios, %-expectations, breakeven, diffusion/index-around-zero,
#        and new_mortgage_lending (a flow that legitimately hits ≤0, so Δln is
#        ill-defined — kept as level by decision).

dln_cols <- c(
  # A. prices (all index levels)
  "cpi", "cpi_less_housing",
  "matur_og_oafengir_drykkir", "afengir_drykkir_tobak_og_fikniefni",
  "fatnadur_og_skofatnadur", "husnaedi_vatn_rafmagn_gas_og_adrir_orkugjafar",
  "husbunadur_heimilistaeki_og_thjonusta_tengd_venjubundnu_vidhaldi_heimila",
  "kaup_a_okutaekjum", "rekstur_farartaekja_til_einkanota",
  "farthegaflutningar_thjonusta", "adrar_vorur_til_afthreyingar",
  "veitingahus_og_gistithjonusta", "tryggingar",
  "byggingarvisitala", "import", "domestic", "husnaedisverd",
  # B. real activity
  "domestic_card_turnover", "foreign_card_turnover", "registrations",
  "farthegar", "marine", "aluminum", "gdp",
  # C. labour (quantities)
  "launavisitala", "unnar_stundir",
  # E. money & credit (levels in M.kr.)
  "m3", "credit_households", "credit_businesses",
  # F. exchange rates
  "isk_eur", "isk_usd", "isk_gbp", "twi", "reer",
  # G. external quantities/prices
  "brent_usd", "aluminium", "us_cpi", "ea_hicp", "ea_ip", "fao_food"
)

all_value_cols <- setdiff(names(panel_levels), "date")
level_cols     <- setdiff(all_value_cols, dln_cols)

panel_model <-
  panel_levels |>
  mutate(across(all_of(dln_cols), \(x) log_diff(x)))
# level_cols pass through unchanged.


# 7.0.0 COLUMN DICTIONARY ----

# native frequency: which columns came from a quarterly source
quarterly_native <- c("gdp", labour_q_cols, expect_cols)
# panel role
bvar_only  <- c("gdp")  # interpolated GDP: keep out of the FAVAR indicator panel
core_block <- c("policy_rate", "cpi_less_housing", "twi", "il_mortgage_share",
                "launavisitala")  # VAR/BVAR core observables (activity = gdp via Q)

source_of <- c(
  setNames("gdp", "gdp"),
  setNames(rep("prices", ncol(prices) - 1), setdiff(names(prices), "date")),
  setNames(rep("card_turnover", 2), setdiff(names(card), "date")),
  setNames("tourism", "farthegar"),
  setNames(rep("aluminium_and_marine_exports", 2), setdiff(names(alu_marine), "date")),
  setNames("car_registrations", "registrations"),
  setNames(rep("financial", ncol(financial) - 1), setdiff(names(financial), "date")),
  setNames(rep("money_credit", ncol(money) - 1), setdiff(names(money), "date")),
  setNames(rep("exchange", ncol(exchange) - 1), setdiff(names(exchange), "date")),
  setNames(rep("external", ncol(external) - 1), setdiff(names(external), "date")),
  setNames(rep("labour", 5), c("unemployment_rate", labour_q_cols)),
  setNames(rep("expectations", length(expect_cols)), expect_cols)
)

column_dictionary <-
  tibble(series = all_value_cols) |>
  mutate(
    source     = source_of[series],
    native_freq = if_else(series %in% quarterly_native, "quarterly", "monthly"),
    transform  = if_else(series %in% dln_cols, "dln_x100", "level"),
    panel_role = case_when(
      series %in% bvar_only  ~ "bvar_only",
      series %in% core_block ~ "core_block",
      TRUE                   ~ "factor_panel"
    ),
    first_obs = map_chr(series, \(s) {
      d <- panel_levels$date[!is.na(panel_levels[[s]])]
      if (length(d)) as.character(min(d)) else NA_character_
    })
  ) |>
  arrange(source, series)


# 8.0.0 SAVE ----

write_parquet(panel_levels, file.path(OUT, "panel_monthly_levels.parquet"))
write_parquet(panel_model,  file.path(OUT, "panel_monthly.parquet"))
write_csv(column_dictionary, file.path(OUT, "column_dictionary.csv"))

cat(sprintf(
  "Wrote panel: %d months (%s -> %s), %d series.\n",
  nrow(panel_model), as.character(min(panel_model$date)),
  as.character(max(panel_model$date)), length(all_value_cols)
))
cat(sprintf("  Δln series: %d | level series: %d\n",
            length(dln_cols), length(level_cols)))
cat(sprintf("  -> %s/{panel_monthly_levels,panel_monthly}.parquet + column_dictionary.csv\n", OUT))
