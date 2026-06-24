# H. Expectations & surveys
#
# Quarterly inflation- and policy-rate-expectation series for the FAVAR panel
# (macro-data-for-favar.md §H, series 73-76). Source: Seðlabanki Íslands,
# "Verðbólguvæntingar á mismunandi mælikvarða":
#   https://sedlabanki.is/peningastefna/verdbolguvaentingar-a-mismunandi-maelikvarda/
#
# That page publishes TWO Excel workbooks:
#   (1) "Verðbólguvæntingar á mismunandi mælikvarða.xlsx"  (the MEASURES file) —
#       household & business survey inflation expectations + bond-market breakeven
#       inflation, quarterly from 2003Q1.
#   (2) "Væntingar markaðsaðila <YYYYqQ>.xlsx"             (the MARKET file) —
#       the market-participants survey: inflation- and policy-rate-path
#       expectations, quarterly from 2012Q1.
# The MARKET file name carries the latest quarter (e.g. ..._2026Q2.xlsx) and
# changes every quarter, so neither URL is hard-coded: the page is a Blazor SPA
# whose anchors render client-side, so we drive it headless with chromote (same
# mechanism as 06_money_credit.R) and pick the two .xlsx links off the live DOM.
#
# Frequency: QUARTERLY. Per the repo convention these are stored RAW (levels, in
# %), dated to the first of the quarter; the §H quarterly->monthly interpolation
# (quarterly_to_monthly in 01_helpers.R) and any transform happen at the
# modelling step (pipeline.R), not here.
#
# NB on row positions: the workbook captions are 1 row higher than they appear in
# a frozen-pane viewer. Verified positions (2026-06) used below:
#   MEASURES Households/Businesses: date header row 9, data col B(2);
#     row 10 = Meðaltal/average, row 11 = Miðgildi/median.
#   MEASURES Breakeven: date header row 4, data col B(2);
#     rows 5/6/7/8 = breakeven inflation at 1/2/5/10 years.
#   MARKET sheets I and II: a 2-D grid — each COLUMN is a survey quarter (date
#     header in row 11, from col B), and rows 12-16 are forecast HORIZONS
#     relative to that survey quarter: row 12 = current quarter ("núverandi"),
#     rows 13-16 = +1Q..+4Q. We keep all five horizons (h0..h4) and date each
#     observation by its SURVEY quarter (the column). Only the Meðaltal/average
#     block (rows 12-16) is taken, not the median block below it.
#   Sheet I = 12-month inflation expectation per quarter (Question 1).
#   Sheet II = expected CBI policy rate at end of each quarter (Question 2). The
#     current 7-day-deposit-rate survey lives in sheet "II" but only as the LATEST
#     column; the full 2012Q1-onward history (asked of the older collateralized-
#     lending rate) lives in "II eldri". We splice them: full history from
#     "II eldri", with "II" taking precedence where the latest quarter overlaps.


# 1.0.0 SETUP ----
library(tidyverse)
library(arrow)
library(readxl)

source("R/data/01_helpers.R")  # fix_date()


# 1.1.0 Find + download the two published workbooks ----

page_url <-
  "https://sedlabanki.is/peningastefna/verdbolguvaentingar-a-mismunandi-maelikvarda/"

# Render the (Blazor SPA) page headless and return the two .xlsx hrefs it lists.
# The anchors render client-side some unpredictable time after the load event, so
# we POLL the DOM (every 0.5s up to `timeout`s) until both workbooks appear rather
# than guessing a fixed sleep. Requires chromote + headless Chrome (find_chrome()).
expectations_xlsx_urls <- function(url = page_url, timeout = 45) {
  abs_url <- function(h) if (str_starts(h, "http")) h else str_c("https://sedlabanki.is", h)

  scrape_hrefs <- function(b) {
    raw <- b$Runtime$evaluate(str_c(
      "JSON.stringify(Array.from(document.querySelectorAll('a[href]'))",
      ".map(function(a){return a.getAttribute('href');})",
      ".filter(function(h){return h && h.toLowerCase().indexOf('.xlsx')>-1;}))"
    ), returnByValue = TRUE)$result$value
    if (is.null(raw)) character(0) else jsonlite::fromJSON(raw)
  }

  b <- chromote::ChromoteSession$new(wait_ = TRUE)
  on.exit(b$close(), add = TRUE)
  b$default_timeout <- 60
  b$Page$navigate(url)
  b$Page$loadEventFired(wait_ = TRUE)

  hrefs <- character(0)
  for (i in seq_len(ceiling(timeout / 0.5))) {
    hrefs <- scrape_hrefs(b)
    has_measures <- any(str_detect(hrefs, regex("mismunandi", ignore_case = TRUE)))
    has_market   <- any(str_detect(hrefs, regex("markadsadila", ignore_case = TRUE)))
    if (has_measures && has_market) break
    Sys.sleep(0.5)
  }

  measures <- hrefs[str_detect(hrefs, regex("mismunandi", ignore_case = TRUE))]
  market   <- hrefs[str_detect(hrefs, regex("markadsadila", ignore_case = TRUE))]
  if (length(measures) == 0 || length(market) == 0) {
    stop("Could not find both expectation workbooks on ", url, " within ", timeout,
         "s (found: ", str_c(hrefs, collapse = ", "), ")")
  }
  list(measures = abs_url(measures[1]), market = abs_url(market[1]))
}

download_xlsx <- function(url) {
  tmp <- tempfile(fileext = ".xlsx")
  download.file(url, tmp, mode = "wb", quiet = TRUE)
  tmp
}

urls          <- expectations_xlsx_urls()
measures_xlsx <- download_xlsx(urls$measures)
market_xlsx   <- download_xlsx(urls$market)


# 1.2.0 Workbook readers ----

# Read selected rows from one of these workbooks into a wide tibble. The date
# header lives on `header_row` (quarter labels like "2003Q1") from `first_col`
# onward; `groups` is a named list mapping each output column to its source row.
# Quarter labels are parsed to first-of-quarter via fix_date().
read_expect_rows <- function(xlsx, sheet, header_row, first_col, groups) {
  raw <- suppressMessages(read_excel(
    xlsx, sheet = sheet, col_names = FALSE, .name_repair = "minimal"
  ))

  hdr       <- as.character(unlist(raw[header_row, ]))
  date_cols <- which(!is.na(hdr) & seq_along(hdr) >= first_col &
                       str_detect(hdr, "^\\d{4}Q[1-4]$"))
  dates     <- as.Date(vapply(hdr[date_cols], fix_date, as.Date(NA)),
                       origin = "1970-01-01")

  imap(groups, \(row_num, col_name) {
    vals <- suppressWarnings(as.numeric(unlist(raw[row_num, date_cols])))
    tibble(date = dates, !!col_name := vals)
  }) |>
    reduce(full_join, by = "date") |>
    arrange(date)
}


# 2.0.0 DATA ----

# 2.1.0 MEASURES file — household & business survey expectations (73-74) ----
# Sheet 1 = households, sheet 2 = businesses; mean + median of the 1-year-ahead
# inflation expectation, quarterly from 2003Q1. (Sheets are named, not indexed,
# to be robust to ordering.)
measures_sheets <- excel_sheets(measures_xlsx)
sheet_households <- str_subset(measures_sheets, regex("heimili|household", ignore_case = TRUE))[1]
sheet_businesses <- str_subset(measures_sheets, regex("fyrirt|business", ignore_case = TRUE))[1]
sheet_breakeven  <- str_subset(measures_sheets, regex("breakeven|álag", ignore_case = TRUE))[1]

households_tbl <- read_expect_rows(
  measures_xlsx, sheet = sheet_households, header_row = 9, first_col = 2,
  groups = list(hh_infl_exp_mean = 10L, hh_infl_exp_median = 11L)
)

businesses_tbl <- read_expect_rows(
  measures_xlsx, sheet = sheet_businesses, header_row = 9, first_col = 2,
  groups = list(biz_infl_exp_mean = 10L, biz_infl_exp_median = 11L)
)

# 2.2.0 MEASURES file — bond-market breakeven inflation (≈75) ----
# Breakeven (nominal − indexed bond) inflation at 1/2/5/10-year horizons.
breakeven_tbl <- read_expect_rows(
  measures_xlsx, sheet = sheet_breakeven, header_row = 4, first_col = 2,
  groups = list(
    breakeven_1y  = 5L,
    breakeven_2y  = 6L,
    breakeven_5y  = 7L,
    breakeven_10y = 8L
  )
)


# 2.3.0 MARKET file — market-participants inflation path (75) ----
# Sheet "I": expected 12-month inflation, by survey quarter, at 5 horizons
# (h0 = current quarter .. h4 = +4Q). Mean block only (rows 12-16).
market_infl_tbl <- read_expect_rows(
  market_xlsx, sheet = "I", header_row = 11, first_col = 2,
  groups = list(
    mkt_infl_exp_h0 = 12L,
    mkt_infl_exp_h1 = 13L,
    mkt_infl_exp_h2 = 14L,
    mkt_infl_exp_h3 = 15L,
    mkt_infl_exp_h4 = 16L
  )
)

# 2.4.0 MARKET file — market-participants policy-rate path ----
# Expected CBI policy rate at end of each quarter, 5 horizons (h0..h4). Full
# 2012Q1-onward history is in "II eldri"; the latest quarter is in "II". Splice:
# history from eldri, current sheet wins on overlapping dates.
pol_groups <- list(
  mkt_polrate_exp_h0 = 12L,
  mkt_polrate_exp_h1 = 13L,
  mkt_polrate_exp_h2 = 14L,
  mkt_polrate_exp_h3 = 15L,
  mkt_polrate_exp_h4 = 16L
)
market_pol_old <- read_expect_rows(
  market_xlsx, sheet = "II eldri", header_row = 11, first_col = 2,
  groups = pol_groups
)
market_pol_new <- read_expect_rows(
  market_xlsx, sheet = "II", header_row = 11, first_col = 2,
  groups = pol_groups
)
market_pol_tbl <-
  bind_rows(market_pol_new, market_pol_old |> filter(!date %in% market_pol_new$date)) |>
  arrange(date)


# 3.0.0 SAVE ----

list(
  households_tbl,
  businesses_tbl,
  breakeven_tbl,
  market_infl_tbl,
  market_pol_tbl
) |>
  reduce(full_join, by = "date") |>
  arrange(date) |>
  assert_unique_dates() |>
  write_parquet("data/raw/expectations.parquet")


# ── Notes ──────────────────────────────────────────────────────────────────────
# • Frequency is quarterly (first-of-quarter dates). The §H Q→M interpolation and
#   any transform are applied in pipeline.R, not here (raw-storage convention).
# • The MARKET grid is kept in "wide-by-horizon" form (h0..h4) dated by SURVEY
#   quarter; the target quarter of horizon hN is (survey quarter + N). Pick the
#   horizon(s) you need at the modelling step (e.g. h4 = the classic 1-year-ahead).
# • "II eldri" surveys the older collateralized-lending rate and "II" the current
#   7-day term-deposit rate; they are spliced as one continuous expectations path
#   (the way the bank presents them) — a minor instrument change around 2014.
# ── Section-H series not wired here ─────────────────────────────────────────────
# 76 Consumer confidence (Gallup), 77 business sentiment, 78 PMI — different
#    sources (Gallup/SA), not in these two workbooks; deferred.
