# Vinnumarkaðstengd gögn

# C. Labour market
#
# Monthly registered unemployment + quarterly wage index, hours, and participation
# (macro-data-for-favar.md §C, series 31-36). Sources: Vinnumálastofnun (monthly
# unemployment) and Hagstofa PxWeb (quarterly launavísitala / vinnumarkaður).
# Values stored RAW; the §C transform/interpolation is applied centrally in
# pipeline.R. Unemployment is monthly; the wage/hours/participation series are
# native quarterly (first-of-period dates) — kept ragged, not interpolated here.

# 1.0.0 SETUP ----
library(tidyverse)
library(readxl)
library(arrow)


# 2.0.0 DATA ----

# 2.1.0 Vinnumálastofnun ----

vmst_url <- "https://island.is/s/vinnumalastofnun/maelabord-og-toelulegar-upplysingar"

# Source: Vinnumálastofnun, "Talnagögn um atvinnuleysi" (Talnagogn_atvinnuleysi.xlsm).
# The file is published on vmst_url via a hashed CDN asset URL that changes on every
# update, so we scrape the current link from the page rather than hard-coding it.
# Sheet "G2": row 7 holds Excel date serials, row 9 ("Landið allt") holds the monthly
# unemployment RATE for the whole country, and row 43 ("Landið allt", under the
# "Atvinnulausir, meðalfjöldi á mánuði" header) holds the monthly registered
# unemployment COUNT (DATA_GAPS #31). Both run from column C onward; the sheet
# expands one column to the right each month; data begin in February 2000.

atvinnuleysi_tbl <-
  local({
    # Find the .xlsm download link on the Vinnumálastofnun page
    page <- as.character(rvest::read_html(vmst_url))
    pattern <- 'https?://[^"\'[:space:]]*Talnagogn_atvinnuleysi\\.xlsm'
    file_url <- regmatches(page, regexpr(pattern, page, perl = TRUE))
    if (length(file_url) == 0) {
      stop("Could not find Talnagogn_atvinnuleysi.xlsm link on ", vmst_url)
    }

    tmp <- tempfile(fileext = ".xlsm")
    download.file(file_url, tmp, mode = "wb", quiet = TRUE)

    raw <- suppressWarnings(suppressMessages(
      readxl::read_excel(tmp, sheet = "G2", col_names = FALSE)
    ))

    row_vals <- function(r) {
      v <- suppressWarnings(as.numeric(unlist(raw[r, -(1:2)], use.names = FALSE)))
      v[!is.na(v)]
    }

    # Row 9: unemployment rate (fraction). Row 43: average unemployed count.
    rate  <- row_vals(9)
    count <- row_vals(43)

    # Monthly axis from February 2000 (matches the date serials in row 7)
    date <- seq(as.Date("2000-02-01"), by = "month", length.out = length(rate))

    # Count may trail the rate by a month; pad to common length on the date axis.
    length(count) <- length(rate)

    tibble(
      date = date,
      unemployment_rate  = rate,
      unemployment_count = count
    )
  })

# 2.2.0 Launavísitala ----

laun_tbl <-
  read_csv2(
    "https://px.hagstofa.is:443/pxis/sq/bb157166-cce9-4e4e-b355-937e8bb292ce"
  ) |>
  set_names("date", "launavisitala") |>
  mutate(
    date = make_date(str_sub(date, 1, 4), str_sub(date, 6, 7)),
    launavisitala = launavisitala / 10
  )

# 2.3.0 Unnar klukkustundir, atvinnuþátttaka og hlutfall starfandi ----

vmk_tbl <-
  read_csv2(
    "https://px.hagstofa.is:443/pxis/sq/09dd952e-fa93-47d7-83b4-f82f53e93290"
  ) |>
  set_names(
    "date",
    "atvinnuthatttaka",
    "hlutfall_starfandi",
    "unnar_stundir"
  ) |>
  mutate(
    date = make_date(str_sub(date, 1, 4), str_sub(date, 6, 7)),
    atvinnuthatttaka = atvinnuthatttaka / 10,
    hlutfall_starfandi = hlutfall_starfandi / 10,
    unnar_stundir = unnar_stundir / 10
  )


# 3.0.0 SAVE ----

list(atvinnuleysi_tbl, laun_tbl, vmk_tbl) |>
  reduce(full_join, by = "date") |>
  arrange(date) |>
  write_parquet("data/raw/labour.parquet")
