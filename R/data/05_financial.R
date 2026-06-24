# D. Financial variables — interest rates
#
# Monthly interest-rate levels for the FAVAR panel (macro-data-for-favar.md §D,
# series 37-46). Source: Seðlabanki Íslands XML time-series feed
#
#   https://sedlabanki.is/xmltimeseries/Default.aspx
#
# addressed by TimeSeriesID with a DagsFra/DagsTil date window and Type=xml.
# The feed serves DAILY observations; for the monthly panel each series is
# aggregated to the calendar-month MEAN and dated to the first of the month
# (matching the first-of-month `date` convention used by the other data files).
# All section-D series enter the model as LEVELS (no log/diff here).
#
# TimeSeriesIDs were located from the feed's own group catalogues (GroupID=...,
# reading each <TimeSeries> ID + Name + Description) rather than guessed:
#   Group 1  "Vextir Seðlabankans"               -> policy rate + corridor
#   Group 4  "Vextir á millibankamarkaði"         -> REIBOR fixings
#   Group 20 "Fastir lánstímavextir"              -> estimated govt par-yield curve
#
# NOT on the XML feed (see "Gaps" at the bottom): the bank-level retail rates
# — non-indexed/indexed new-mortgage rates (40, 41), corporate lending rate
# (42) and household deposit rate (46). Those are published by Seðlabanki / FME
# only as Excel / dashboard releases and need a separate readxl pull once a
# stable download URL is confirmed; they are deliberately left out here rather
# than filled with a wrong-looking proxy.


# 1.0.0 SETUP ----
library(tidyverse)
library(arrow)


# 1.1.0 Helper functions ----

# Pull one Seðlabanki series by TimeSeriesID into a tidy daily (date, value)
# tibble. Feed dates are "m/d/yyyy h:m:s"; values are numeric. NA-valued points
# (non-publication days) are dropped. libxml2 follows the www -> apex redirect,
# so the bare host is used directly.
cbi_series <- function(time_series_id, from = "2003-01-01", to = Sys.Date()) {
  url <- str_glue(
    "https://sedlabanki.is/xmltimeseries/Default.aspx",
    "?TimeSeriesID={time_series_id}&DagsFra={from}&DagsTil={to}&Type=xml"
  )

  x <- xml2::read_xml(url)
  entries <- xml2::xml_find_all(x, ".//Entry")

  tibble(
    date = xml2::xml_text(xml2::xml_find_first(entries, ".//Date")) |>
      mdy_hms() |>
      as_date(),
    value = xml2::xml_text(xml2::xml_find_first(entries, ".//Value")) |>
      as.numeric()
  ) |>
    filter(!is.na(value)) |>
    arrange(date)
}

# Pull a named vector of TimeSeriesIDs and collapse each to monthly means,
# returned wide: one `date` column (first of month) + one column per series.
cbi_monthly <- function(ids, from = "2003-01-01", to = Sys.Date()) {
  imap(ids, \(id, name) {
    cbi_series(id, from = from, to = to) |>
      mutate(date = floor_date(date, "month")) |>
      summarise(value = mean(value, na.rm = TRUE), .by = date) |>
      rename(!!name := value)
  }) |>
    reduce(full_join, by = "date") |>
    arrange(date)
}


# 2.0.0 DATA ----

# 2.1.0 Policy rate + corridor (Seðlabanki group 1) ----
# 37: policy_rate is the headline 7-day term-deposit rate (Meginvextir, 17923) —
# the VAR-block observable. The three corridor rates (current-account, overnight
# lending, 7-day collateralised lending) are pulled alongside as context; they
# bracket the policy rate and are useful for the rate-pass-through block.
policy_tbl <-
  cbi_monthly(c(
    policy_rate              = 17923,  # Meginvextir, 7-day term deposit (headline)
    current_account_rate     = 28,     # Vextir á viðskiptareikningum
    overnight_lending_rate   = 24,     # Vextir á daglánum
    collateral_lending_rate  = 55      # Vextir á 7 daga veðlánum
  ))


# 2.2.0 REIBOR interbank fixings (Seðlabanki group 4) ----
# 38, 39: REIBOR (offer side) 3M and 6M. NB the feed also carries REIBID (bid
# side, IDs 3-11) and other tenors; the offer-side 3M/6M the spec asks for are
# IDs 15 and 16, verified from the <Name> captions ("REIBOR, 3 M" / "REIBOR, 6 M").
reibor_tbl <-
  cbi_monthly(c(
    reibor_3m = 15,
    reibor_6m = 16
  ))


# 2.3.0 Government bond yields — estimated par curve (Seðlabanki group 20) ----
# 43, 44: nominal (óverðtryggt) and indexed (verðtryggt) government yields. The
# feed's "Fastir lánstímavextir" group publishes Seðlabanki's estimated par-yield
# curve at fixed 3/5/10-year points, which is the model-ready monthly equivalent
# of the on-the-run RIKB/RIKS yields. The 5-year point matches the spec's "5yr or
# 10yr"; the 10-year point is kept too for the long end of the term structure.
# NB this curve series begins 2020 on the feed (the daily fixings before then are
# not published here), so these columns are NA before 2020 — a ragged left edge
# the panel assembly / factor estimation must tolerate.
bond_yield_tbl <-
  cbi_monthly(c(
    govt_yield_nominal_5y = 30102,  # Par-vextir óverðtryggt, 5 ára
    govt_yield_nominal_10y = 30103, # Par-vextir óverðtryggt, 10 ára
    govt_yield_indexed_5y = 30105,  # Par-vextir verðtryggt, 5 ára
    govt_yield_indexed_10y = 30106  # Par-vextir verðtryggt, 10 ára
  ))


# 3.0.0 DERIVED ----

# 45: breakeven inflation = nominal yield − indexed yield (5-year point, to match
# the headline nominal/indexed pair above). A market-implied inflation-expectations
# measure; NA wherever either leg is missing (i.e. pre-2020).
financial_tbl <-
  policy_tbl |>
  full_join(reibor_tbl, by = "date") |>
  full_join(bond_yield_tbl, by = "date") |>
  arrange(date) |>
  mutate(
    breakeven_5y = govt_yield_nominal_5y - govt_yield_indexed_5y
  )


# 4.0.0 SAVE ----

financial_tbl |>
  write_parquet("data/raw/financial.parquet")


# ── Gaps: section-D series with NO machine-readable Seðlabanki source ───────────
# The following four bank-level retail rates (macro-data-for-favar.md §D) are
# NOT available from either Seðlabanki data service:
#   40  Non-indexed mortgage rate (new loans, avg)
#   41  Indexed mortgage rate (new loans, avg)
#   42  Corporate lending rate (non-indexed)
#   46  Deposit rate (household, avg)
#
# Confirmed by auditing BOTH services (not just by failing to find them):
#   - xmltimeseries feed: rate groups are 1 (CBI rates), 4 (REIBOR) and 20
#     (govt par-curve) — none carries retail bank rates.
#   - gagnabanki.is portal: its full report registry (GET gagnabanki.is/api/config)
#     has an "interests" category with exactly three reports — key rate, market
#     rate (REIBOR) and constant-maturity govt curve — all backed by the same
#     TimeSeriesIDs already pulled above. gagnabanki publishes mortgage/business
#     loan VOLUMES (the "monetary" reports, used in 06_money_credit.R) but not the
#     corresponding interest RATES.
# These rates exist only inside Seðlabanki Financial Stability / FME publications
# (PDF tables); wiring them needs a manual source and is deliberately deferred
# rather than filled with a wrong-looking proxy.
