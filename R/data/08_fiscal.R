# Government finances — DATA_GAPS #79 (revenue), #80 (expenditure), #81 (balance).
# Hagstofa THJ05211: "Helstu hagstærðir ríkissjóðs 1980-2025".
#
# ANNUAL ONLY. Iceland publishes no current monthly central-government accounts
# (the monthly table THJ95200 ends 2014). So this series enters the panel as an
# annual block to be interpolated / handled in the mixed-frequency step, not the
# monthly panel. Values are central government (ríkissjóður), ISK million,
# nominal current prices.

# 1.0.0 SETUP ----
library(tidyverse)
library(arrow)
library(httr2)

source("R/data/01_helpers.R")


# 2.0.0 DATA ----
# Skipting: 0 = Tekjur (revenue), 1 = Gjöld (expenditure), 2 = balance.

.url <- paste0(
  "https://px.hagstofa.is/pxis/api/v1/is/Efnahagur/fjaropinber/",
  "fjarmal_rikissjods/THJ05211.px"
)

.query <- list(
  query = list(
    list(code = "Skipting", selection = list(filter = "item", values = list("0", "1", "2")))
  ),
  response = list(format = "csv")
)

.raw <- request(.url) |>
  req_body_json(.query) |>
  req_perform() |>
  resp_body_string(encoding = "UTF-8")

raw_tbl <- read_csv(I(.raw), show_col_types = FALSE)


# 3.0.0 RESHAPE ----
# Layout: "Skipting" rows (3 of them), one column per year. Pivot long, then wide.

fiscal_tbl <-
  raw_tbl |>
  mutate(series = case_when(
    str_detect(Skipting, "Tekjur ríkissjóðs") ~ "gov_revenue",
    str_detect(Skipting, "Gjöld ríkissjóðs")  ~ "gov_expenditure",
    str_detect(Skipting, "halli")             ~ "gov_balance",
    TRUE                                       ~ NA_character_
  )) |>
  filter(!is.na(series)) |>
  select(-Skipting) |>
  pivot_longer(-series, names_to = "year", values_to = "value") |>
  mutate(date = make_date(as.integer(year), 1L, 1L)) |>
  select(date, series, value) |>
  pivot_wider(names_from = series, values_from = value) |>
  arrange(date) |>
  filter(if_any(c(gov_revenue, gov_expenditure), ~ !is.na(.)))


fiscal_tbl |>
  write_parquet("data/raw/fiscal.parquet")
