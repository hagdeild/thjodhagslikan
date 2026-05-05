# ONE-TIME: Combines the historical PDF-sourced series (2004–2019) with the Power BI series
# (2020–present) into a single monthly total. Writes data/car_registrations.parquet + .csv.
# Run once after car_registrations_02_scrape_powerbi.R has populated its outputs.

library(tidyverse)
library(arrow)

# ── Historical series (2004-01 – 2019-12) ─────────────────────────────────────
historical_raw <- read_csv(
  "samgongustofa_pdf/nyskraning_nyrra.csv",
  col_types = cols(year_month = col_character(), .default = col_integer())
)

historical <- historical_raw |>
  mutate(
    period = as.Date(paste0(year_month, "-01")),
    registrations = alls,
    source = "historical_pdf"
  ) |>
  select(period, registrations, source) |>
  # 2020-01 row exists in historical (866 total) but Power BI is authoritative from 2020 onward
  filter(period < as.Date("2020-01-01")) |>
  distinct()

# ── Present series (2020-01 – present) ────────────────────────────────────────
present_raw <- readRDS("data/car_registrations_present.rds") |>
  filter(period < floor_date(today(), "month"))

present <- present_raw |>
  filter(
    vehicle_class %in%
      c(
        "Fólksbifreið (M1)",
        "Sendibifreið (N1)",
        "Hópbifreið I (M2)",
        "Hópbifreið II (M3)",
        "Vörubifreið I (N2)",
        "Vörubifreið II (N3)"
      )
  ) |>
  summarise(registrations = sum(registrations), .by = period) |>
  mutate(source = "powerbi") |>
  select(period, registrations, source) |>
  arrange(period)

# ── Sanity check at boundary ───────────────────────────────────────────────────
hist_jan2020 <- historical_raw |>
  filter(year_month == "2020-01") |>
  pull(alls)

pbi_jan2020 <- present |>
  filter(period == as.Date("2020-01-01")) |>
  pull(registrations)

if (length(hist_jan2020) > 0 && length(pbi_jan2020) > 0) {
  message(sprintf(
    "Boundary check Jan 2020 — historical: %d, Power BI: %d (diff: %d)",
    hist_jan2020,
    pbi_jan2020,
    pbi_jan2020 - hist_jan2020
  ))
}

# ── Combine ────────────────────────────────────────────────────────────────────
car_reg <- bind_rows(historical, present) |>
  arrange(period)

stopifnot(!anyDuplicated(car_reg$period))

message(sprintf(
  "Combined series: %d months (%s to %s)",
  nrow(car_reg),
  format(min(car_reg$period), "%Y-%m"),
  format(max(car_reg$period), "%Y-%m")
))

# ── Write ──────────────────────────────────────────────────────────────────────
dir.create("data", showWarnings = FALSE, recursive = TRUE)
write_parquet(car_reg, "data/car_registrations.parquet")
write_csv(car_reg, "data/car_registrations.csv")

message(
  "Done. Written to data/car_registrations.parquet and data/car_registrations.csv"
)
