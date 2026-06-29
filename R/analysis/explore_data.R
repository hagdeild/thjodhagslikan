library(tidyverse)
library(arrow)

raw <- map(
  list.files("data/raw", "\\.parquet$", full.names = TRUE),
  read_parquet
) |>
  set_names(tools::file_path_sans_ext(list.files("data/raw", "\\.parquet$")))

panel <- read_parquet("data/processed/panel_monthly_levels.parquet")


panel |>
  filter(date == "2026-04-01") |>
  glimpse()
