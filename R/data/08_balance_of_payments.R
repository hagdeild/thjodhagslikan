# Balance of payments / current account — the external-balance block.
#
# This is the linchpin variable for the kjarasamningar scenario engine: the
# wages/credit -> imports -> current-account-deficit -> ISK-depreciation -> CPI
# channel. Without it the external channel is only visible indirectly through the
# exchange rate, which is exactly how a wage shock gets "hidden" in Icelandic data.
#
# Source: Seðlabanki "Greiðslujöfnuður við útlönd" (balance of payments).
#   Landing page: https://sedlabanki.is/gagnatorg/greidslujofnudur-vid-utlond/
#   The page is an Angular SPA shell; the quarterly workbook is a static
#   `library/?itemid=<uuid>` Excel whose uuid CHANGES every release (it embeds the
#   latest quarter, e.g. "...Q12026.xlsx"). So we render the page headless with
#   chromote to discover the current itemid, then download the file directly with
#   httr2 (the library item itself serves the real .xlsx to a plain GET — no SPA).
#
# Workbook layout (sheet "Lóðrétt" = vertical):
#   • Row 6 is the header row; col A label "m.kr.", then one column per BoP item.
#   • Data from row 7 down, one row per quarter, col A = "YYYY Q#", 1995Q1-present.
#   • Col 2  = Viðskiptajöfnuður            (current account, headline)
#   • Col 3  = Vöruskiptajöfnuður           (goods-trade balance)
#   • Col 14 = Þjónusta                     (services balance)
#   • Col 223= Viðskiptajöfnuður án áhrifa gömlu bankanna (CA excl. failed banks)
#
# The "án áhrifa gömlu bankanna" series strips the distortion from the 2008 failed
# banks' winding-up (slitameðferð): their accrued-but-unpaid foreign primary income
# made the measured CA wildly misleading 2008Q4-2015Q4 (swings of 50-90 bn.kr). It
# is BLANK before 2008Q4 (no banks failed yet) and exactly 0 from 2016Q1 (the
# old banks finished winding up after the 2015 stability settlement, so there is no
# adjustment and headline == underlying). We therefore build ONE clean continuous
# series, `current_account` = the underlying balance:
#   use ex-banks where it is non-zero & non-NA (2008Q4-2015Q4), headline otherwise.
# `current_account_headline` is also kept raw for reference. Values m.kr., nominal.

# 1.0.0 SETUP ----
library(tidyverse)
library(arrow)
library(httr2)
library(readxl)
library(chromote)

source("R/data/01_helpers.R")


# 2.0.0 DISCOVER + DOWNLOAD WORKBOOK ----
.landing <- "https://sedlabanki.is/gagnatorg/greidslujofnudur-vid-utlond/"

# 2.1.0 Render the SPA and read out the xlsx download link's itemid. The anchor is
# `<a class="... file-type-xlsx ..." href="/library/?itemid=<uuid>">`.
discover_itemid <- function(url) {
  b <- ChromoteSession$new()
  on.exit(b$close(), add = TRUE)
  b$Page$navigate(url)
  b$Page$loadEventFired(wait_ = TRUE)
  Sys.sleep(6)  # let Angular render the data-tab download links
  js <- paste0(
    "(function(){var a=document.querySelector('a.file-type-xlsx[href*=\"itemid=\"]');",
    "return a ? a.getAttribute('href') : '';})()"
  )
  href <- b$Runtime$evaluate(js)$result$value
  if (is.null(href) || !nzchar(href))
    stop("balance_of_payments: could not find the xlsx download link on the SPA page")
  sub(".*itemid=", "", href)
}

itemid <- discover_itemid(.landing)
message("BoP workbook itemid: ", itemid)

.xlsx <- tempfile(fileext = ".xlsx")
request(paste0("https://sedlabanki.is/library/?itemid=", itemid)) |>
  req_perform(path = .xlsx)


# 3.0.0 PARSE ----
# Read the vertical sheet with row 6 as the header (skip the 5-row title block).
.lod <- read_excel(.xlsx, sheet = "Lóðrétt", skip = 5, .name_repair = "unique_quiet")

bop_tbl <-
  tibble(
    quarter            = .lod[[1]],
    current_account_hl = suppressWarnings(as.numeric(.lod[[2]])),    # headline
    trade_balance      = suppressWarnings(as.numeric(.lod[[3]])),    # goods
    services_balance   = suppressWarnings(as.numeric(.lod[[14]])),   # Þjónusta
    ca_ex_old_banks    = suppressWarnings(as.numeric(.lod[[223]]))   # excl. failed banks
  ) |>
  filter(!is.na(quarter), str_detect(quarter, "Q")) |>
  mutate(
    # fix_date() is scalar (uses if()); map over the "YYYY Q#" labels.
    date = as.Date(map_dbl(str_replace(quarter, " ", ""), \(x) as.numeric(fix_date(x))),
                   origin = "1970-01-01"),                           # "1995 Q1" -> 1995-01-01
    # One clean underlying CA: ex-banks adjustment only where it is materially
    # present (2008Q4-2015Q4, non-zero & non-NA); headline everywhere else.
    current_account = if_else(
      !is.na(ca_ex_old_banks) & ca_ex_old_banks != 0,
      ca_ex_old_banks,
      current_account_hl
    )
  ) |>
  transmute(
    date,
    current_account,                       # underlying (model-ready level)
    current_account_headline = current_account_hl,
    trade_balance,
    services_balance,
    ca_ex_old_banks
  ) |>
  arrange(date) |>
  assert_unique_dates()

stopifnot(nrow(bop_tbl) > 100, min(bop_tbl$date) <= as.Date("1995-01-01"))

bop_tbl |>
  write_parquet("data/raw/balance_of_payments.parquet")

message("balance_of_payments.parquet written: ", nrow(bop_tbl), " quarters, ",
        format(min(bop_tbl$date)), " -> ", format(max(bop_tbl$date)))
