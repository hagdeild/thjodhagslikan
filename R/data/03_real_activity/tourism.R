# Fjöldi farþega um keflavíkurflugvöll

# 1.0.0 SETUP ----
library(tidyverse)
library(arrow)

source("R/data/01_helpers.R")

# 2.0.0 DATA ----

old_tbl <-
  read_csv2(
    "https://px.hagstofa.is:443/pxis/sq/645269a1-2c21-4aed-9bc1-54c546e44420",
    locale = locale(encoding = "latin1")
  ) |>
  set_names("date", "value") |>
  mutate(
    date = make_date(str_sub(date, 1, 4), str_sub(date, 6, 7))
  )


new_tbl <-
  read_csv2(
    "https://px.hagstofa.is:443/pxis/sq/d6f4ce6a-8881-4488-b150-d456d2cd3e6c"
  ) |>
  set_names("date", "value") |>
  mutate(
    date = make_date(str_sub(date, 1, 4), str_sub(date, 6, 7))
  )

tourism_tbl <- splice_series(new_tbl, old_tbl) |>
  rename(farthegar = value)


tourism_tbl |>
  write_parquet("data/raw/tourism.parquet")
