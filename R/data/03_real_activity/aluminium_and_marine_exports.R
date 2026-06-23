# Aluminum and marine exports.

# 1.0.0 SETUP ----
library(tidyverse)
library(arrow)


# 2.0.0 DATA ----

data_old_tbl <-
  read_csv2(
    "https://px.hagstofa.is:443/pxis/sq/7d063f88-9258-44e5-895a-eec7d485d3db"
  ) |>
  set_names("date", "marine", "aluminum")


data_new_tbl <-
  read_csv2(
    "https://px.hagstofa.is:443/pxis/sq/459c6bae-1738-438f-8a9f-c85ff0eb6e9f",
    locale = locale(encoding = "latin1")
  ) |>
  set_names("date", "marine", "aluminum") |>
  mutate(
    date = make_date(str_sub(date, 1, 4), str_sub(date, 6, 7))
  )


# 3.0.0 BACK-EXTEND TO 2002 ----
# Use seasonal shares from data_new_tbl (2011 onward) to disaggregate
# yearly totals from data_old_tbl (2002–2010) into monthly values.

seasonal_shares_tbl <-
  data_new_tbl |>
  mutate(
    year = year(date),
    month = month(date)
  ) |>
  filter(year >= 2011, year <= 2024) |>
  group_by(year) |>
  mutate(
    marine_share = marine / sum(marine),
    aluminum_share = aluminum / sum(aluminum)
  ) |>
  group_by(month) |>
  summarise(
    marine_share = mean(marine_share),
    aluminum_share = mean(aluminum_share),
    .groups = "drop"
  ) |>
  mutate(
    marine_share = marine_share / sum(marine_share),
    aluminum_share = aluminum_share / sum(aluminum_share)
  )

data_backfill_tbl <-
  data_old_tbl |>
  filter(date < 2011) |>
  rename(year = date) |>
  tidyr::crossing(month = 1:12) |>
  left_join(seasonal_shares_tbl, by = "month") |>
  mutate(
    date = make_date(year, month, 1),
    marine = marine * marine_share,
    aluminum = aluminum * aluminum_share
  ) |>
  select(date, marine, aluminum)

data_new_tbl <-
  bind_rows(data_backfill_tbl, data_new_tbl) |>
  arrange(date)


data_new_tbl |>
  write_parquet("data/aluminium_and_marine_exports.parquet")
