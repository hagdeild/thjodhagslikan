# G. External / global variables
#
# Monthly global series for the FAVAR panel (macro-data-for-favar.md §G, series
# 59-72). These capture global shocks that drive Icelandic inflation independently
# of domestic policy — the block-exogenous part of the identification strategy.
#
# Sources (all public APIs; daily/business series are aggregated to month means,
# dated to the first of the month). Values stored RAW; the §G Δln/level transform
# is applied at the modelling step (pipeline.R), not here.
#   FRED (fredr, needs FRED_API_KEY in .Renviron):
#     59 Brent USD (DCOILBRENTEU), 62 aluminium USD (PALUMUSDM),
#     66 Fed funds (FEDFUNDS), 67 US CPI (CPIAUCSL), 70 VIX (VIXCLS)
#   Eurostat (public SDMX REST): 63 euro-area HICP, 64 euro-area industrial production
#   ECB Data Portal SDMX REST: 65 ECB main refinancing rate
#   NY Fed: 68 Global Supply Chain Pressure Index (GSCPI) xlsx
#   FAO: 61 global food price index (CSV)
#   BIS SDMX REST: 72 Nordic policy rates (SE/NO/DK)
#
# Not wired (documented at the bottom): 60 Brent-in-ISK and the 72 weighted
# average are DERIVED; 69 Baltic Dry has no free source; 71 fish price is covered
# by the marine export price index in section B (03_real_activity).

# 1.0.0 SETUP ----
library(tidyverse)
library(arrow)
library(fredr)
library(callr)
# NB: DBI/odbc are loaded only inside the GSCPI subprocess (2.4.0), not here — the
# ACE Excel ODBC driver corrupts the heap and segfaults R when it shares a session
# with arrow under memory load, so that one read is isolated via callr::r().

fredr_set_key(Sys.getenv("FRED_API_KEY"))


# 1.1.0 Helper functions ----

# Collapse a daily/business (date, value) tibble to monthly means, first-of-month.
to_monthly <- function(df) {
  df |>
    mutate(date = floor_date(date, "month")) |>
    summarise(value = mean(value, na.rm = TRUE), .by = date) |>
    arrange(date)
}

# Pull a named vector of FRED series to monthly means, returned wide.
fred_monthly <- function(ids, from = as.Date("2000-01-01")) {
  imap(ids, \(id, name) {
    fredr(series_id = id, observation_start = from) |>
      transmute(date, value) |>
      filter(!is.na(value)) |>
      to_monthly() |>
      rename(!!name := value)
  }) |>
    reduce(full_join, by = "date") |>
    arrange(date)
}

# Fetch one Eurostat SDMX series via the public REST API (SDMX-CSV), returning a
# tidy monthly (date, value) tibble. `filters` is the dot-separated series key.
eurostat_series <- function(dataflow, filters, from = "2000-01") {
  url <- str_glue(
    "https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/data/",
    "{dataflow}/{filters}?startPeriod={from}&format=SDMX-CSV"
  )
  read_csv(url, show_col_types = FALSE) |>
    transmute(date = ym(TIME_PERIOD), value = as.numeric(OBS_VALUE)) |>
    filter(!is.na(value)) |>
    arrange(date)
}

# Fetch one ECB Data Portal series (SDMX REST, csvdata) to a tidy (date, value).
ecb_series <- function(flow, key, from = "2000-01-01") {
  url <- str_glue(
    "https://data-api.ecb.europa.eu/service/data/",
    "{flow}/{key}?startPeriod={from}&format=csvdata"
  )
  read_csv(url, show_col_types = FALSE) |>
    transmute(date = as.Date(TIME_PERIOD), value = as.numeric(OBS_VALUE)) |>
    filter(!is.na(value)) |>
    arrange(date)
}

# Fetch one BIS SDMX series (REST, CSV) to a tidy (date, value). Monthly keys.
bis_series <- function(flow, key, from = "2000-01-01") {
  url <- str_glue(
    "https://stats.bis.org/api/v2/data/dataflow/BIS/",
    "{flow}/1.0/{key}?format=csv"
  )
  read_csv(url, show_col_types = FALSE) |>
    transmute(date = ym(TIME_PERIOD), value = as.numeric(OBS_VALUE)) |>
    filter(date >= as.Date(from), !is.na(value)) |>
    arrange(date)
}


# 2.0.0 DATA ----

# 2.1.0 FRED — commodities, US rates, risk (59, 62, 66, 67, 70) ----
# Brent (USD/bbl), aluminium (USD/tonne, IMF/World Bank monthly), Fed funds (%),
# US CPI (index), VIX (index). DCOILBRENTEU and VIXCLS are daily → monthly mean.
fred_tbl <-
  fred_monthly(c(
    brent_usd = "DCOILBRENTEU", # 59 Brent crude, USD
    aluminium = "PALUMUSDM", # 62 global aluminium price, USD/tonne
    fed_funds = "FEDFUNDS", # 66 effective federal funds rate, %
    us_cpi = "CPIAUCSL", # 67 US CPI, index
    vix = "VIXCLS" # 70 CBOE VIX, index
  ))


# 2.2.0 Eurostat — euro-area HICP & industrial production (63, 64) ----
# 63 HICP: monthly index 2015=100, all-items (CP00), euro area (EA).
# 64 IP: monthly index 2021=100, industry ex-construction (B-D), seasonally &
#        calendar adjusted (SCA), euro area 20 (EA20).
euro_tbl <-
  full_join(
    eurostat_series("prc_hicp_midx", "M.I15.CP00.EA") |>
      rename(ea_hicp = value),
    eurostat_series("sts_inpr_m", "M.PRD.B-D.SCA.I21.EA20") |>
      rename(ea_ip = value),
    by = "date"
  ) |>
  arrange(date)


# 2.3.0 ECB — main refinancing rate (65) ----
# Main refinancing operations, fixed rate, level (%). Business-daily (changes only
# on policy decisions) → monthly mean.
ecb_tbl <-
  ecb_series("FM", "B.U2.EUR.4F.KR.MRR_FR.LEV") |>
  to_monthly() |>
  rename(ecb_mro = value)


# 2.4.0 NY Fed — Global Supply Chain Pressure Index (68) ----
# GSCPI, monthly index (standard deviations from mean), level. The download is
# named .xlsx but is actually a legacy BIFF8 .xls (OLE2 container) that libxls /
# readxl cannot parse ("Unable to parse file"). We read it through the Microsoft
# ACE Excel ODBC driver instead. The "GSCPI Monthly Data" sheet has a Date
# (e.g. "31-May-2026") + GSCPI column pair, plus trailing branding columns and a
# few header rows that drop out when we coerce the date/value.
#
# The whole read runs in a throwaway R subprocess (callr::r): the ACE ODBC driver
# corrupts the heap and segfaults when it coexists with arrow under memory load,
# so we keep DBI/odbc out of this session entirely and return only the small
# (date, gscpi) tibble.
gscpi_tbl <-
  callr::r(function() {
    suppressMessages({
      library(DBI); library(odbc); library(dplyr)
      library(stringr); library(lubridate); library(tibble)
    })
    tmp <- tempfile(fileext = ".xls")
    download.file(
      "https://www.newyorkfed.org/medialibrary/research/interactives/gscpi/downloads/gscpi_data.xlsx",
      tmp,
      mode = "wb",
      quiet = TRUE
    )
    con <- dbConnect(
      odbc::odbc(),
      .connection_string = sprintf(
        "Driver={Microsoft Excel Driver (*.xls, *.xlsx, *.xlsm, *.xlsb)};DBQ=%s;ReadOnly=1;",
        tmp
      )
    )
    on.exit(dbDisconnect(con), add = TRUE)
    sheet <- dbListTables(con) |>
      str_subset(regex("monthly", ignore_case = TRUE)) |>
      head(1)
    raw <- dbGetQuery(
      con,
      sprintf("SELECT Date, GSCPI FROM [%s]", str_remove_all(sheet, "'"))
    )
    raw |>
      transmute(
        date = floor_date(dmy(Date), "month"),
        gscpi = as.numeric(GSCPI)
      ) |>
      filter(!is.na(date), !is.na(gscpi)) |>
      arrange(date) |>
      as_tibble()
  })


# 2.5.0 FAO — global food price index (61) ----
# FAO Food Price Index, monthly, 2014-2016=100. The CSV has a 3-row preamble
# (title, base, header), then "Date" as "YYYY-MM" + the index columns. We keep
# the headline Food Price Index (first value column).
fao_tbl <-
  read_csv(
    "https://www.fao.org/media/docs/worldfoodsituationlibraries/default-document-library/food_price_indices_data.csv",
    skip = 3,
    col_names = c("date", "fao_food"),
    col_types = cols_only(date = col_character(), fao_food = col_double())
  ) |>
  transmute(
    date = ym(date),
    fao_food = as.numeric(fao_food)
  ) |>
  filter(!is.na(date), !is.na(fao_food)) |>
  arrange(date)


# 2.6.0 BIS — Nordic policy rates (72) ----
# Central-bank policy rates for Sweden, Norway, Denmark from the BIS WS_CBPOL
# dataset (monthly), level (%). Kept as three separate series; the GDP/trade-
# weighted average is derived at the modelling step (weights not applied here).
nordic_tbl <-
  list(
    policy_rate_se = "M.SE",
    policy_rate_no = "M.NO",
    policy_rate_dk = "M.DK"
  ) |>
  imap(\(key, name) bis_series("WS_CBPOL", key) |> rename(!!name := value)) |>
  reduce(full_join, by = "date") |>
  arrange(date)


# 3.0.0 SAVE ----

fred_tbl |>
  full_join(euro_tbl, by = "date") |>
  full_join(ecb_tbl, by = "date") |>
  full_join(gscpi_tbl, by = "date") |>
  full_join(fao_tbl, by = "date") |>
  full_join(nordic_tbl, by = "date") |>
  arrange(date) |>
  write_parquet("data/raw/external.parquet")

# ── Derived downstream (pipeline.R), not pulled here ────────────────────────
# 60 Brent-in-ISK = brent_usd × ISK/USD (isk_usd from 07_exchange.R).
# 72 Nordic average = GDP/trade-weighted mean of policy_rate_se/no/dk.
#
# ── Gaps: section-G series not wired ───────────────────────────────────────────
# 69 Baltic Dry Index — no free deep-history source (the index itself is
#    Bloomberg/Refinitiv; Yahoo ^BDIY is gone and BDRY is a 2018+ ETF proxy, not
#    the index). The supply-chain/shipping channel is partly captured by GSCPI (68).
# 71 Fish price index — covered by the marine export price index in section B
#    (03_real_activity), which is the actual Icelandic seafood export price; FRED
#    PFISHUSDM is fish *meal* (animal feed), a poor proxy, so not used.
