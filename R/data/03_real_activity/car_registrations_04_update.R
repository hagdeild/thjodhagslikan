# MONTHLY: Appends the latest month(s) of new vehicle registrations to the combined parquet.
# Reads data/car_registrations.parquet, fetches only months not yet covered from the
# Samgöngustofa Power BI report, updates both the long-format archive
# (data/car_registrations_present.{csv,rds}) and the combined series
# (data/car_registrations.{parquet,csv}). Assumes _03_combine.R has been run at least once.

library(tidyverse)
library(arrow)

# Resolve script directory whether run via source() or interactively (RStudio).
.this_dir <- tryCatch(
  dirname(sys.frame(1)$ofile),
  error = function(e) {
    if (
      requireNamespace("rstudioapi", quietly = TRUE) &&
        rstudioapi::isAvailable()
    ) {
      dirname(rstudioapi::getActiveDocumentContext()$path)
    } else {
      file.path(getwd(), "R", "data", "03_real_activity")
    }
  }
)

source(file.path(.this_dir, "car_registrations_powerbi_helpers.R"))

# Vehicle classes that match the historical "alls" total (folks + hop + sendi + voru).
# Keep in sync with car_registrations_03_combine.R.
included_classes <- c(
  "Fólksbifreið (M1)",
  "Sendibifreið (N1)",
  "Hópbifreið I (M2)",
  "Hópbifreið II (M3)",
  "Vörubifreið I (N2)",
  "Vörubifreið II (N3)"
)

# ── Determine which months are missing ────────────────────────────────────────
existing <- read_parquet("data/car_registrations.parquet")
last_period <- max(existing$period)
current_period <- floor_date(Sys.Date(), "month")

# Only fetch fully-completed months (skip the in-progress current month).
last_complete <- current_period - months(1)
first_to_fetch <- last_period + months(1)

if (first_to_fetch > last_complete) {
  message(sprintf(
    "Already up to date (last period: %s).",
    format(last_period, "%Y-%m")
  ))
} else {
  months_to_fetch <- seq(first_to_fetch, last_complete, by = "month")

  message(sprintf(
    "Fetching %d month(s): %s to %s",
    length(months_to_fetch),
    format(min(months_to_fetch), "%Y-%m"),
    format(max(months_to_fetch), "%Y-%m")
  ))

  # ── Fetch new months from Power BI ────────────────────────────────────────────
  metadata <- fetch_report_metadata()
  table_visual <- find_vehicle_class_table(metadata)

  new_rows_long <- map(months_to_fetch, function(period) {
    yr <- year(period)
    mo <- month(period)
    message(sprintf("  Fetching %d-%02d ...", yr, mo))
    out <- query_vehicle_class_table(metadata, table_visual, yr, mo, period)
    Sys.sleep(0.15)
    out
  }) |>
    bind_rows() |>
    arrange(period, desc(registrations), vehicle_class)

  # ── Update the long-format archive ──────────────────────────────────────────
  present_archive <- readRDS("data/car_registrations_present.rds")
  present_updated <- bind_rows(present_archive, new_rows_long) |>
    distinct() |>
    arrange(period, desc(registrations), vehicle_class)

  write_csv(present_updated, "data/car_registrations_present.csv")
  saveRDS(present_updated, "data/car_registrations_present.rds")

  # ── Aggregate new months to the combined-series schema ──────────────────────
  new_rows <- new_rows_long |>
    filter(vehicle_class %in% included_classes) |>
    summarise(registrations = sum(registrations), .by = period) |>
    mutate(source = "powerbi") |>
    select(period, registrations, source) |>
    arrange(period)

  message(sprintf("Fetched %d new month(s).", nrow(new_rows)))

  # ── Append and write the combined series ───────────────────────────────────
  updated <- bind_rows(existing, new_rows) |>
    arrange(period)

  stopifnot(!anyDuplicated(updated$period))

  write_parquet(updated, "data/car_registrations.parquet")
  write_csv(updated, "data/car_registrations.csv")

  message(sprintf(
    "Done. Series now covers %s to %s (%d months).",
    format(min(updated$period), "%Y-%m"),
    format(max(updated$period), "%Y-%m"),
    nrow(updated)
  ))
}
