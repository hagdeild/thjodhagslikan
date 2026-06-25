# Residential construction activity — DATA_GAPS #24/#25 PROXY.
#
# Iceland publishes no free machine-readable physical building-permits or
# housing-starts series (Hagstofa's permit/completion tables are stale-annual;
# HMS's current dwelling counts are PDF/biannual only). The cleanest fetchable
# construction-activity proxy is residential gross fixed capital formation
# (fjármunamyndun, "Íbúðarhús") from the quarterly national accounts.
#
# Hagstofa THJ03111, QUARTERLY 1995Q1-, current. We take:
#   resinv_volume_sa  Mælikvarði=3  chain-volume, seasonally adjusted (the signal)
#   resinv_current    Mælikvarði=0  current prices (nominal level)

# 1.0.0 SETUP ----
library(tidyverse)
library(arrow)
library(httr2)

source("R/data/01_helpers.R")


# 2.0.0 DATA ----

.url <- paste0(
  "https://px.hagstofa.is/pxis/api/v1/is/Efnahagur/thjodhagsreikningar/",
  "fjarmunamyndun_fjarmunaeign/fjarmunamyndun_arsfj/THJ03111.px"
)

.query <- list(
  query = list(
    list(code = "Mælikvarði", selection = list(filter = "item", values = list("0", "3"))),
    list(code = "Skipting",   selection = list(filter = "item", values = list("2")))  # Íbúðarhús
  ),
  response = list(format = "csv")
)

.raw <- request(.url) |>
  req_body_json(.query) |>
  req_perform() |>
  resp_body_string(encoding = "UTF-8")

raw_tbl <- read_csv(I(.raw), show_col_types = FALSE)


# 3.0.0 RESHAPE ----
# Layout: 2 Mælikvarði rows, one column per quarter ("1995Á1"). Pivot long, wide.

residential_investment_tbl <-
  raw_tbl |>
  mutate(series = case_when(
    str_detect(Mælikvarði, "árstíðaleiðrétt") ~ "resinv_volume_sa",
    str_detect(Mælikvarði, "Verðlag hvers")   ~ "resinv_current",
    TRUE                                       ~ NA_character_
  )) |>
  filter(!is.na(series)) |>
  select(-Mælikvarði, -any_of("Skipting")) |>
  pivot_longer(-series, names_to = "quarter", values_to = "value") |>
  mutate(
    year = as.integer(str_sub(quarter, 1, 4)),
    qtr  = as.integer(str_sub(quarter, 6, 6)),
    date = make_date(year, (qtr - 1L) * 3L + 1L, 1L)
  ) |>
  select(date, series, value) |>
  pivot_wider(names_from = series, values_from = value) |>
  arrange(date) |>
  filter(if_any(c(resinv_current, resinv_volume_sa), ~ !is.na(.)))


residential_investment_tbl |>
  write_parquet("data/raw/residential_investment.parquet")
