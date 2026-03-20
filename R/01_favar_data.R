# Fetch data for FAVAR model

# 1.0.0 SETUP ----
library(tidyverse)

# 1.1.0 Helper functions ----
fix_date <- function(x) {
  make_date(str_sub(x, 1, 4), str_sub(x, 6, 7))
}

# 2.0.0 VERÐLAG ----

# 2.1.0 Cpi with and without housing cost ----
cpi_tbl <-
  read_csv2(
    "https://px.hagstofa.is:443/pxis/sq/da043a19-5834-458d-99c0-b07b2b474e59"
  ) |>
  set_names("date", "cpi", "cpi_less_housing") |>
  mutate(
    date = fix_date(date),
    cpi = cpi / 10,
    cpi_less_housing = cpi_less_housing / 10,
    cpi = log(cpi),
    cpi_less_housing = log(cpi_less_housing)
  )


# 2.2.0 coicop ----
coicop_new_tbl <-
  read_csv2(
    "https://px.hagstofa.is:443/pxis/sq/ea21be69-1127-4a81-9393-4932925dd49b"
  ) |>
  janitor::clean_names() |>
  rename("date" = "manudur") |>
  mutate(date = fix_date(date))

coicop_old_tbl <-
  read_csv2(
    "https://px.hagstofa.is:443/pxis/sq/9eda51c8-d943-481b-adc1-6bc4d6f84c4f"
  ) |>
  janitor::clean_names() |>
  rename("date" = "manudur") |>
  mutate(date = fix_date(date))
