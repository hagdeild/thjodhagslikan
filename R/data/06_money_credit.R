# E. Money, credit & financial conditions
#
# Monthly money/credit series for the FAVAR panel (macro-data-for-favar.md §E,
# series 47-54). Source: Seðlabanki Íslands, via the gagnabanki.is data portal
# (https://gagnabanki.is). Five of the eight series are wired here; the other
# three have no clean free deep-history source and are documented at the bottom.
#
# gagnabanki serves each report as an Angular SPA whose "Excel" button builds the
# .xlsx CLIENT-SIDE as a Blob — there is no stable download URL to GET. We render
# the report headless (chromote), hook URL.createObjectURL to keep a reference to
# the Blob the app builds, click Excel, then read the Blob back as base64 and
# write the bytes to a tempfile. Approach ported from the macro_iceland reference
# repo (github.com/Vidaringa/macro_iceland, R/ingest/sedlabanki.R).
#
# All five wired series come from one report family — "monetary" (Innlánsstofnanir
# / deposit-taking corporations) — across three of its export pages:
#   FINSTATS.MONETARY.BROADMONEY.TABLE  -> M3 (47)
#   FINSTATS.MONETARY.LOANS.TABLE       -> household (48) & business (49) credit
#                                          stock + indexed-mortgage share (50)
#   FINSTATS.MONETARY.NEWCREDIT.TABLE   -> new HH mortgage flow (51)
# Row/sheet positions below were read from each workbook's own captions (verified
# 2026-06; the NEWCREDIT rows match the reference repo's mapping).
#
# Values are stored RAW: M.kr. for the money/credit levels (47, 48, 49, 51) and a
# percent for the indexed-mortgage share (50). The §E Δln transform for the level
# series is applied centrally at the modelling step (pipeline.R), not here.


# 1.0.0 SETUP ----
library(tidyverse)
library(arrow)


# 1.1.0 gagnabanki Excel-report download (chromote Blob capture) ----

# Download a gagnabanki report workbook to a tempfile (.xlsx), returning its path.
# `slug` is the /report/<slug> path; `report` is the page= export code (the value
# under a page's `table` in /api/config). The wide date window asks for full
# history. Requires chromote + a headless Chrome (chromote::find_chrome()).
gagnabanki_report_xlsx <- function(slug, report = NULL,
                                   from = "1990-01-01", to = Sys.Date()) {
  url <- str_c(
    "https://gagnabanki.is/report/", slug,
    "?from=", from, "&to=", to,
    if (!is.null(report)) str_c("&page=", report) else ""
  )

  b <- chromote::ChromoteSession$new(wait_ = TRUE)
  on.exit(b$close(), add = TRUE)
  b$default_timeout <- 60
  b$Page$navigate(url)
  b$Page$loadEventFired(wait_ = TRUE)
  Sys.sleep(8)  # Angular: report grid + Excel button render after load

  # Retain the Blob the app hands to URL.createObjectURL when Excel is clicked.
  b$Runtime$evaluate(str_c(
    "window.__capturedBlob=null;(function(){var o=URL.createObjectURL;",
    "URL.createObjectURL=function(b){try{if(b instanceof Blob)",
    "window.__capturedBlob=b;}catch(e){}return o.apply(this,arguments);};})();'ok'"
  ))
  # Click the Excel export button (mat-button whose label span reads 'Excel').
  b$Runtime$evaluate(str_c(
    "(function(){var s=Array.from(document.querySelectorAll",
    "('span.mdc-button__label')).find(s=>s.textContent.trim()==='Excel');",
    "if(!s)return'no-btn';(s.closest('button')||s).click();return'ok';})()"
  ))
  Sys.sleep(6)  # let the app fetch + build the workbook Blob

  # Read the captured Blob back as base64 (async -> awaitPromise).
  b64 <- b$Runtime$evaluate(str_c(
    "new Promise(function(res){var bl=window.__capturedBlob;",
    "if(!bl){res('NO_BLOB');return;}var fr=new FileReader();",
    "fr.onload=function(){res(fr.result.split(',')[1]);};fr.readAsDataURL(bl);})"
  ), awaitPromise = TRUE)$result$value
  if (identical(b64, "NO_BLOB") || is.null(b64)) {
    stop("gagnabanki Excel export produced no Blob for report '", slug,
         if (!is.null(report)) str_c("/", report) else "", "'")
  }

  tmp <- tempfile(fileext = ".xlsx")
  writeBin(jsonlite::base64_dec(b64), tmp)
  tmp
}

# Read selected rows from a gagnabanki FAME-export workbook into a wide tibble.
# These workbooks carry the date header as a row of EXCEL SERIALS (month-end),
# with the header row and first data column varying by report. `groups` is a
# named list: each name becomes an output column, each value is the source row
# number(s) to SUM column-wise (a vector combines rows, e.g. floating + fixed).
# Serials are floored to first-of-month to match the other data files' `date`.
gagnabanki_rows <- function(xlsx, sheet, header_row, first_col, groups) {
  raw <- readxl::read_excel(xlsx, sheet = sheet, col_names = FALSE,
                            .name_repair = "minimal")

  serials   <- suppressWarnings(as.numeric(unlist(raw[header_row, ])))
  date_cols <- which(!is.na(serials) & seq_along(serials) >= first_col)
  dates     <- floor_date(as.Date(serials[date_cols], origin = "1899-12-30"), "month")

  imap(groups, \(row_nums, col_name) {
    vals <- map_dbl(date_cols, \(cc) {
      sum(as.numeric(unlist(raw[as.integer(row_nums), cc])), na.rm = TRUE)
    })
    tibble(date = dates, !!col_name := vals)
  }) |>
    reduce(full_join, by = "date") |>
    arrange(date)
}


# 2.0.0 DATA ----

# 2.1.0 Broad money M3 (gagnabanki: monetary / BROADMONEY) ----
# 47: M3. Sheet "I", serial date header in row 8, data from col B (2).
# Row 12 = "Peningamagn og sparifé (M3) / Broad money (M3)". Raw M.kr.
m3_tbl <-
  local({
    xlsx <- gagnabanki_report_xlsx("monetary", "FINSTATS.MONETARY.BROADMONEY.TABLE")
    gagnabanki_rows(xlsx, sheet = "I", header_row = 8, first_col = 2,
                    groups = list(m3 = 12L))
  })


# 2.2.0 Credit stock by sector + indexed-mortgage share (monetary / LOANS) ----
# 48, 49, 50: outstanding loans of deposit-taking corporations (banks), M.kr.
#   Sheet "IV" (Lending to households), serial header row 9, data col C (3):
#     row 10 = "Útlán heimila / Loans to households"            -> household credit
#     Household residential-mortgage STOCK, split by indexation:
#       row 15 = indexed (verðtryggð) mortgages "Með veð í íbúð"
#       row 18 = non-indexed ISK mortgages       "Með veð í íbúð"
#       row 21 = FX mortgages                    "Með veð í íbúð" (≈0, included)
#   Sheet "I"  (Lending by sector),  serial header row 9, data col C (3):
#     row 12 = "Atvinnufyrirtæki / Non financial companies"     -> business credit
#
# 50 (the KEY variable) is computed from the STOCK of indexed vs total mortgages,
# NOT from new-lending flow: flow is net of pre-/over-payments so individual
# months go negative and a flow ratio is unstable (blows past 100% / below 0).
# The stock share is a clean, slow-moving 0-100% series — what the spec wants.
credit_tbl <-
  local({
    xlsx <- gagnabanki_report_xlsx("monetary", "FINSTATS.MONETARY.LOANS.TABLE")
    households <- gagnabanki_rows(
      xlsx, sheet = "IV", header_row = 9, first_col = 3,
      groups = list(
        credit_households  = 10L,
        mortgage_indexed   = 15L,
        mortgage_nonidx    = 18L,
        mortgage_fx        = 21L
      ))
    businesses <- gagnabanki_rows(xlsx, sheet = "I", header_row = 9, first_col = 3,
                                  groups = list(credit_businesses = 12L))
    full_join(households, businesses, by = "date") |> arrange(date)
  }) |>
  mutate(
    mortgage_total    = mortgage_indexed + mortgage_nonidx + mortgage_fx,
    il_mortgage_share = if_else(mortgage_total > 0,
                                mortgage_indexed / mortgage_total * 100, NA_real_)
  ) |>
  select(date, credit_households, credit_businesses, il_mortgage_share)


# 2.3.0 New mortgage lending (gagnabanki: monetary / NEWCREDIT) ----
# 51: new household residential-mortgage credit, net of pre-/over-payments, M.kr.
# Sheet "I", serial date header in row 10, data from col B (2). The household
# residential-mortgage rows (floating + fixed) under the "Ný útlán" block:
#   43 + 44 -> total new HH mortgages. A flow measure, stored raw (M.kr.).
new_mortgage_tbl <-
  local({
    xlsx <- gagnabanki_report_xlsx("monetary", "FINSTATS.MONETARY.NEWCREDIT.TABLE")
    gagnabanki_rows(xlsx, sheet = "I", header_row = 10, first_col = 2,
                    groups = list(new_mortgage_lending = c(43L, 44L)))
  })


# 3.0.0 SAVE ----

m3_tbl |>
  full_join(credit_tbl, by = "date") |>
  full_join(new_mortgage_tbl, by = "date") |>
  arrange(date) |>
  write_parquet("data/raw/money_credit.parquet")


# ── Gaps: section-E series not wired ───────────────────────────────────────────
# 52  OMXI stock market index — Nasdaq Iceland. No clean free deep-history feed:
#     Yahoo ^OMXIPI starts only 2013 and has gaps/NAs; the Nasdaq OMX Nordic site
#     is a fragile scrape and still may not reach 2003m1. Deferred pending a
#     reliable source (e.g. a Nasdaq data export or a paid feed).
# 53  CDS spread on Iceland sovereign — Bloomberg/Refinitiv only (spec: "if avail").
#     No free source; deferred.
# 54  Financial conditions index — the central bank does not publish a clean
#     monthly FCI series (spec: "if CB publishes"); deferred.
