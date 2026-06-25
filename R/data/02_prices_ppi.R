# Producer Price Index (PPI) — DATA_GAPS #15.
# Hagstofa VIS08000: "Vísitala framleiðsluverðs", base 2005Q4=100, monthly 2006-.
#
# NB: headline PPI + domestic is ALREADY in prices.parquet (02_prices.R §2.6).
# This file is the richer cut — it adds the EXPORT producer-price index
# (Prod_exp), which the tradable-price channel wants and the original omits.
# Headline + domestic + export, index level only (Liður = index).

# 1.0.0 SETUP ----
library(tidyverse)
library(arrow)
library(httr2)

source("R/data/01_helpers.R")


# 2.0.0 DATA ----

.url <- paste0(
  "https://px.hagstofa.is/pxis/api/v1/is/Efnahagur/visitolur/",
  "5_visitalaframleidslu/framleidsluverd/VIS08000.px"
)

.query <- list(
  query = list(
    list(code = "Liður",   selection = list(filter = "item", values = list("index"))),
    list(code = "Flokkur", selection = list(filter = "item",
         values = list("PPI", "Prod_dom", "Prod_exp")))
  ),
  response = list(format = "csv")
)

.raw <- request(.url) |>
  req_body_json(.query) |>
  req_perform() |>
  resp_body_string(encoding = "UTF-8")

raw_tbl <- read_csv(I(.raw), show_col_types = FALSE)


# 3.0.0 RESHAPE ----
# Wide: one column per "<Flokkur text> Vísitala". Months are rows already
# because "Mánuður" is the row variable when not in the query selection.

ppi_tbl <-
  raw_tbl |>
  rename(month = Mánuður) |>
  rename_with(~ case_when(
    str_detect(.x, "framleiðsluverðs") ~ "ppi",
    str_detect(.x, "innanlands")       ~ "ppi_domestic",
    str_detect(.x, "Útfluttar")        ~ "ppi_export",
    TRUE                               ~ .x
  )) |>
  mutate(date = make_date(str_sub(month, 1, 4), str_sub(month, 6, 7))) |>
  select(date, ppi, ppi_domestic, ppi_export) |>
  arrange(date) |>
  filter(if_any(c(ppi, ppi_domestic, ppi_export), ~ !is.na(.)))


ppi_tbl |>
  write_parquet("data/raw/ppi.parquet")
