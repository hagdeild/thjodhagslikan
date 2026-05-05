# Pipeline entry point for car registrations.
# Reads the combined parquet produced by _03_combine.R (and kept current by _04_update.R).
# Exposes car_reg_tbl (one row per month, columns: period, registrations, source).

library(tidyverse)
library(arrow)

parquet_path <- "data/car_registrations.parquet"

if (!file.exists(parquet_path)) {
  stop(
    "data/car_registrations.parquet not found. ",
    "Run R/data/03_real_activity/car_registrations_03_combine.R first."
  )
}

car_reg_tbl <- read_parquet(parquet_path) |>
  arrange(period)

message(sprintf(
  "car_reg_tbl: %d months loaded (%s to %s)",
  nrow(car_reg_tbl),
  format(min(car_reg_tbl$period), "%Y-%m"),
  format(max(car_reg_tbl$period), "%Y-%m")
))
