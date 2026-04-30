# A. Prices

# 1.0.0 SETUP ----
library(tidyverse)

# 1.1.0 Helper functions ----
fix_date <- function(x) {
  make_date(str_sub(x, 1, 4), str_sub(x, 6, 7))
}

# Splice two overlapping series onto a common base.
# `old` and `new` share identical column names; `date` must be one of them.
# In the overlap window the ratio new/old is averaged per column, then the
# old (pre-overlap) observations are rescaled by that ratio and prepended.
splice_series <- function(old, new, date_col = "date") {
  overlap <- inner_join(
    old |> rename_with(\(x) if_else(x == date_col, x, paste0(x, "_old"))),
    new |> rename_with(\(x) if_else(x == date_col, x, paste0(x, "_new"))),
    by = date_col
  )

  value_cols <- setdiff(names(old), date_col)

  ratios <- map_dbl(value_cols, \(col) {
    mean(
      overlap[[paste0(col, "_new")]] / overlap[[paste0(col, "_old")]],
      na.rm = TRUE
    )
  }) |>
    set_names(value_cols)

  old_only <- old |> filter(.data[[date_col]] < min(new[[date_col]]))

  old_rescaled <- old_only |>
    mutate(across(all_of(value_cols), \(x) x * ratios[cur_column()]))

  bind_rows(old_rescaled, new) |> arrange(.data[[date_col]])
}

# 2.0.0 DATA ----

# 2.1.0 Cpi with and without housing cost ----
cpi_tbl <-
  read_csv2(
    "https://px.hagstofa.is:443/pxis/sq/24f7baf4-3571-43cb-9f81-be3c8a5a33cc"
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
# coicop_new_tbl <-
#   read_csv2(
#     "https://px.hagstofa.is:443/pxis/sq/ea21be69-1127-4a81-9393-4932925dd49b"
#   ) |>
#   janitor::clean_names() |>
#   rename("date" = "manudur") |>
#   mutate(date = fix_date(date))

# coicop_old_tbl <-
#   read_csv2(
#     "https://px.hagstofa.is:443/pxis/sq/9eda51c8-d943-481b-adc1-6bc4d6f84c4f"
#   ) |>
#   janitor::clean_names() |>
#   rename("date" = "manudur") |>
#   mutate(date = fix_date(date))

coicop_tbl <-
  read_csv2(
    "https://px.hagstofa.is:443/pxis/sq/b25509f7-bdb9-47b7-93ba-6f9e441db74a"
  ) |>
  set_names("date", "coicop", "gildi") |>
  mutate(
    date = fix_date(date),
    coicop = str_remove(coicop, "^\\d+\\s+"),
    gildi = gildi / 10,
    gildi = log(gildi)
  ) |>
  pivot_wider(names_from = coicop, values_from = gildi) |>
  janitor::clean_names()


# 2.3.0 Byggingavísitala ----
byggingarvisitala_tbl <-
  read_csv2(
    "https://px.hagstofa.is:443/pxis/sq/3d76eac9-8219-4639-8e25-8c63a57e406d"
  ) |>
  set_names("date", "byggingarvisitala") |>
  mutate(
    date = fix_date(date),
    byggingarvisitala = byggingarvisitala / 10,
    byggingarvisitala = log(byggingarvisitala)
  )


# 2.4.0 Innflutningsverð ----
import_price_old_tbl <-
  read_csv2(
    "https://px.hagstofa.is:443/pxis/sq/65e25ed1-ae61-4e6d-a5c4-00fb1198f604"
  ) |>
  set_names("date", "import") |>
  mutate(
    date = fix_date(date)
  )


import_price_new_tbl <-
  read_csv2(
    "https://px.hagstofa.is:443/pxis/sq/90bfc34b-12a6-4714-b6d3-715abefdb398"
  ) |>
  set_names("date", "import") |>
  mutate(
    date = fix_date(date)
  )

import_price_tbl <- splice_series(import_price_old_tbl, import_price_new_tbl)

import_price_tbl <- import_price_tbl |>
  mutate(
    import = log(import)
  )


# 2.5.0 Innlendar vörur ----
domestic_old_tbl <-
  read_csv2(
    "https://px.hagstofa.is:443/pxis/sq/430c11da-3ff2-4e35-925c-a611f493f9fe"
  ) |>
  set_names("date", "domestic") |>
  mutate(date = fix_date(date))

domestic_new_tbl <-
  read_csv2(
    "https://px.hagstofa.is:443/pxis/sq/7e37632c-a8fc-4498-9157-53477394cc09"
  ) |>
  set_names("date", "domestic") |>
  mutate(date = fix_date(date))


domestic_tbl <- splice_series(domestic_old_tbl, domestic_new_tbl)


# 2.5.0 Markaðsverð húsnæðis ---
# Hagstofa, ekki HMS

husnaedi_tbl <-
  read_csv2(
    "https://px.hagstofa.is:443/pxis/sq/8dce57db-b8db-4b8f-abdc-924217b2b874"
  ) |>
  set_names("date", "husnaedisverd") |>
  mutate(
    date = fix_date(date),
    husnaedisverd = log(husnaedisverd)
  )
