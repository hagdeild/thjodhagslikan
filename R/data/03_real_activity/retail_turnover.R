# Retail (and hospitality) turnover from VAT returns — DATA_GAPS #22.
# Hagstofa table FYR04101: "Velta eftir atvinnugreinum og vsk-tímabilum 2008-".
# This is NOMINAL turnover from VAT returns, reported per bi-monthly VAT period
# (6 periods/year), by ÍSAT2008 sector. It is NOT a fixed-base index — to use it
# as a "retail sales index" rebase it yourself downstream. Bi-monthly frequency,
# so it belongs in the mixed-frequency block, not the monthly panel.

# 1.0.0 SETUP ----
library(tidyverse)
library(arrow)
library(httr2)

source("R/data/01_helpers.R")


# 2.0.0 DATA ----
# Pull straight from the PxWeb JSON API (no saved query needed).
# Sectors:  G47 = retail (smásöluverslun), I55 = accommodation, I56 = food service.

.url <- paste0(
  "https://px.hagstofa.is/pxis/api/v1/is/Atvinnuvegir/",
  "fyrirtaeki/veltutolur/velta/FYR04101.px"
)

.query <- list(
  query = list(
    list(
      code = "Atvinnugrein (ÍSAT2008)",
      selection = list(filter = "item", values = list("G47", "I55", "I56"))
    ),
    list(
      code = "vsk-þrep",
      selection = list(filter = "item", values = list("Alls"))
    )
  ),
  response = list(format = "csv")
)

.raw <- request(.url) |>
  req_body_json(.query) |>
  req_perform() |>
  resp_body_string(encoding = "UTF-8")

raw_tbl <- read_csv(I(.raw), show_col_types = FALSE)


# 3.0.0 RESHAPE ----
# Columns come as wide "YYYY <period>" (e.g. "2008 Jan.-feb."). Map each VAT
# period to the first calendar month of the period and pivot long.

period_month <- c(
  "Jan.-feb."    = 1,
  "Mars-apríl"   = 3,
  "Maí-júní"     = 5,
  "Júlí-ágúst"   = 7,
  "Sept.-okt."   = 9,
  "Nóv.-des."    = 11
)

# The CSV returns the long ÍSAT text, not the code, so match on the leading number.
relabel_sector <- function(x) {
  case_when(
    str_starts(x, "47") ~ "retail",
    str_starts(x, "55") ~ "accommodation",
    str_starts(x, "56") ~ "food_service",
    TRUE                ~ x
  )
}

retail_turnover_tbl <-
  raw_tbl |>
  rename(sector = `Atvinnugrein (ÍSAT2008)`) |>
  select(-`vsk-þrep`) |>
  pivot_longer(
    cols = -sector,
    names_to = "period",
    values_to = "value",
    values_transform = as.character   # latest periods arrive as ".." (not yet filed)
  ) |>
  mutate(
    value     = parse_number(na_if(na_if(str_trim(value), "."), "..")),
    year      = as.integer(str_sub(period, 1, 4)),
    period_lab = str_trim(str_sub(period, 6)),
    month     = period_month[period_lab],
    date      = make_date(year, month, 1),
    sector    = relabel_sector(sector)
  ) |>
  filter(!is.na(value)) |>
  select(date, sector, value) |>
  arrange(sector, date) |>
  pivot_wider(names_from = sector, values_from = value)


retail_turnover_tbl |>
  write_parquet("data/raw/retail_turnover.parquet")
