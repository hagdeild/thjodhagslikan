# F. Exchange rates
#
# Monthly exchange-rate series for the FAVAR panel (macro-data-for-favar.md §F,
# series 55-58). The small-open-economy transmission channel.
#
#   55 ISK/EUR, 56 ISK/USD, 57 trade-weighted index (narrow)  — Seðlabanki XML feed
#   58 real effective exchange rate (REER)                     — BIS
#
# The three nominal series come from the Seðlabanki XML time-series feed
# (sedlabanki.is/xmltimeseries), addressed by TimeSeriesID — the same feed used
# in 05_financial.R. IDs were located from the feed's group catalogues:
#   Group 9  "Opinbert viðmiðunargengi SÍ" — official ISK mid-rates (one ID per
#            currency; only the mid is populated): USD 4055, EUR 4064 (GBP 4103).
#   Group 10 "Gengisvísitölur SÍ" — effective-rate indices: 4117 = Viðskiptavog
#            þröng (narrow trade weight), the narrow trade-weighted index.
# The feed is DAILY; each series is aggregated to the calendar-month MEAN, dated
# to the first of the month. Values are stored RAW (levels): ISK per unit of
# foreign currency, and the index for the TWI/REER. The §F Δln transform is
# applied centrally at the modelling step (pipeline.R), not here.
#
# The REER is not on the XML feed (groups 9/10 carry only nominal indices, and
# the NSDP exchange-rate code is nominal + a rolling 12-month window). It is taken
# from the BIS effective-exchange-rate dataset (the spec's named alternative,
# "Seðlabanki / BIS") via the BIS SDMX REST API — a clean monthly CSV from 1994.


# 1.0.0 SETUP ----
library(tidyverse)
library(arrow)


# 1.1.0 Helper functions ----

# Pull one Seðlabanki series by TimeSeriesID into a tidy daily (date, value)
# tibble. Feed dates are "m/d/yyyy h:m:s"; values numeric. NA points dropped.
cbi_series <- function(time_series_id, from = "2000-01-01", to = Sys.Date()) {
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
cbi_monthly <- function(ids, from = "2000-01-01", to = Sys.Date()) {
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

# 2.1.0 Nominal ISK rates + trade-weighted index (Seðlabanki XML feed) ----
# 55, 56, 57. ISK per unit of foreign currency (higher = weaker króna); the TWI
# is an index. GBP is pulled alongside as a bonus major. Raw levels.
fx_tbl <-
  cbi_monthly(c(
    isk_eur = 4064,  # EUR mid-rate
    isk_usd = 4055,  # USD mid-rate
    isk_gbp = 4103,  # GBP mid-rate
    twi     = 4117   # Viðskiptavog þröng (narrow trade-weighted index)
  ))


# 2.2.0 Real effective exchange rate (BIS) ----
# 58. BIS effective-exchange-rate dataflow WS_EER, series M.R.B.IS = Monthly,
# Real, Broad basket (64 economies), Iceland. CPI-deflated; higher = real
# appreciation (less competitive). Monthly from 1994. Raw index level.
reer_tbl <-
  read_csv(
    "https://stats.bis.org/api/v2/data/dataflow/BIS/WS_EER/1.0/M.R.B.IS?format=csv",
    show_col_types = FALSE
  ) |>
  transmute(
    date = ym(TIME_PERIOD),
    reer = as.numeric(OBS_VALUE)
  ) |>
  filter(!is.na(reer)) |>
  arrange(date)


# 3.0.0 SAVE ----

fx_tbl |>
  full_join(reer_tbl, by = "date") |>
  arrange(date) |>
  write_parquet("data/raw/exchange.parquet")
