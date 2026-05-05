# ONE-TIME (then monthly via _04_update.R): Scrapes new vehicle registrations (2020–present)
# from the Samgöngustofa Power BI report. Writes long-format data to
# data/car_registrations_present.{csv,rds}. The _03_combine.R and _04_update.R
# scripts depend on this output.

# Resolve script directory whether run via source() or interactively (RStudio).
.this_dir <- tryCatch(
  dirname(sys.frame(1)$ofile),
  error = function(e) {
    if (requireNamespace("rstudioapi", quietly = TRUE) &&
        rstudioapi::isAvailable()) {
      dirname(rstudioapi::getActiveDocumentContext()$path)
    } else {
      file.path(getwd(), "R", "data", "03_real_activity")
    }
  }
)

source(file.path(.this_dir, "car_registrations_powerbi_helpers.R"))

# ── Build the full month grid (2020-01 to current month) ──────────────────────
years <- 2020:year(Sys.Date())
current_period <- floor_date(Sys.Date(), "month")

periods <- tidyr::expand_grid(year = years, month = seq_along(months_is)) |>
  mutate(period = make_date(year, month, 1)) |>
  filter(period <= current_period)

# ── Scrape every month ────────────────────────────────────────────────────────
metadata <- fetch_report_metadata()
table_visual <- find_vehicle_class_table(metadata)

results <- pmap(
  periods,
  function(year, month, period) {
    message(sprintf("Scraping %d-%02d ...", year, month))
    out <- query_vehicle_class_table(metadata, table_visual, year, month, period)
    message(sprintf("  -> %d rows", nrow(out)))
    Sys.sleep(0.15)
    out
  }
)

car_reg <- bind_rows(results) |>
  arrange(period, desc(registrations), vehicle_class)

out_dir <- "data"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

write_csv(car_reg, file.path(out_dir, "car_registrations_present.csv"))
saveRDS(car_reg, file.path(out_dir, "car_registrations_present.rds"))

message(sprintf(
  "Done. %d rows saved to data/car_registrations_present.csv",
  nrow(car_reg)
))
