# GDP components

# 1.0.0 SETUP ----
library(tidyverse)
library(arrow)


# 2.0.0 DATA ----

data_tbl <-
  read_csv2(
    "https://px.hagstofa.is:443/pxis/sq/706d8efd-9108-4ae6-8e1f-e6bb632995b6"
  ) |>
  select(-2) |>
  set_names(
    "date",
    "einkaneysla",
    "samneysla",
    "fjarmunamyndun",
    "utflutningur",
    "innflutningur",
    "gdp"
  ) |>
  mutate(
    date = str_replace(date, "Á", "Q"),
    date = zoo::as.yearqtr(date),
    date = date(date)
  )


data_tbl |>
  write_parquet("data/raw/gdp.parquet")
