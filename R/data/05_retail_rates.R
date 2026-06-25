# Retail bank rates — DATA_GAPS #40 (non-indexed mortgage), #41 (indexed
# mortgage), #46 (household deposit rate).
#
# Source: Seðlabanki Íslands, "Bankavextir og dráttarvextir" — reached from
# https://sedlabanki.is/gagnatorg/vextir/ ("Banka- og dráttavextir" tab). The
# workbook itself is a static library item that downloads directly (no SPA /
# chromote needed):
#   https://sedlabanki.is/library/?itemid=9a60725a-7bf5-429a-8552-bf33a5eb5878
#
# These are the retail lending/deposit rates that are NOT in the xmltimeseries
# feed or gagnabanki — they live only in this published table.
#
# Workbook layout (sheet "mmyyvxban", legacy .xls):
#   col A  year marker ("2003".."2026"), present only on each year's January row
#          (carried down); footnotes begin once the year run ends.
#   col B  month name (Janúar..Desember)
#   col C  deposit rate — "Almennir sparireikningar"            -> #46
#   col E  non-indexed bond loan, LOWEST rate ("Óverðtryggð, lægstu vextir") -> #40
#   col H  indexed bond loan, LOWEST rate     ("Verðtryggð,  lægstu vextir") -> #41
#   (cols F/I are the corresponding HIGHEST rates; D/G are blank spacers.)
#   Monthly, 2003-01 onward.
#
# Methodology note (Seðlabanki footnote 1/2): up to 2020-03 these are the posted
# rates that took effect on/around the month shown; from 2020-04 onward they are
# weighted-average bank rates. Stored RAW (levels, %); kept as LEVEL at assembly.

# 1.0.0 SETUP ----
library(tidyverse)
library(arrow)
library(readxl)

source("R/data/01_helpers.R")


# 2.0.0 DOWNLOAD ----

.url <- "https://sedlabanki.is/library/?itemid=9a60725a-7bf5-429a-8552-bf33a5eb5878"
.tmp <- tempfile(fileext = ".xls")
download.file(.url, .tmp, mode = "wb", quiet = TRUE)

raw <- suppressWarnings(suppressMessages(
  read_excel(.tmp, sheet = 1, col_names = FALSE)
))


# 3.0.0 PARSE ----
# Keep only rows whose col B is a recognised Icelandic month; carry the year
# (col A) down so each month gets its year.

months_is <- c(
  "Janúar" = 1, "Febrúar" = 2, "Mars" = 3, "Apríl" = 4, "Maí" = 5, "Júní" = 6,
  "Júlí" = 7, "Ágúst" = 8, "September" = 9, "Október" = 10, "Nóvember" = 11,
  "Desember" = 12
)

retail_rates_tbl <-
  tibble(
    year_marker = as.character(raw[[1]]),
    month_name  = str_trim(as.character(raw[[2]])),
    deposit_rate          = suppressWarnings(as.numeric(raw[[3]])),
    mortgage_rate_nonidx  = suppressWarnings(as.numeric(raw[[5]])),
    mortgage_rate_indexed = suppressWarnings(as.numeric(raw[[8]]))
  ) |>
  mutate(
    year = if_else(str_detect(year_marker %||% "", "^\\d{4}$"),
                   suppressWarnings(as.integer(year_marker)), NA_integer_)
  ) |>
  fill(year, .direction = "down") |>
  filter(month_name %in% names(months_is), !is.na(year)) |>
  mutate(
    month = months_is[month_name],
    date  = make_date(year, month, 1L)
  ) |>
  select(date, mortgage_rate_nonidx, mortgage_rate_indexed, deposit_rate) |>
  arrange(date) |>
  filter(if_any(c(mortgage_rate_nonidx, mortgage_rate_indexed, deposit_rate),
                ~ !is.na(.))) |>
  assert_unique_dates()


retail_rates_tbl |>
  write_parquet("data/raw/retail_rates.parquet")
