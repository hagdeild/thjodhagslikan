# run_all.R — daily refresh orchestrator
#
# Runs every network-bound raw fetcher, then assembles the panel via pipeline.R.
# Intended to be invoked unattended (Windows Task Scheduler) once per day; see
# tools/schedule_daily_refresh.ps1 for registration and tools/run_daily.ps1 for
# the wrapper that captures logs.
#
# DESIGN (decided with the maintainer):
#   • Each fetcher is sourced in its OWN environment. Fetchers redefine helpers
#     like fix_date()/splice_series() differently, so isolating them avoids one
#     script's helper leaking into the next. 01_helpers.R is the only shared one
#     and pipeline.R sources it itself.
#   • On a fetcher error we LOG and CONTINUE (a flaky source must not block the
#     rest). pipeline.R then runs over whatever raw parquet exists — a failed
#     source simply keeps its previous (stale) parquet. A non-empty failure list
#     is printed at the end and the process exits non-zero so the scheduler /
#     logs flag it, but the panel is still rebuilt.
#   • car_registrations is refreshed by the INCREMENTAL updater (_04_update.R),
#     not the full PDF-scrape chain. The PowerBI scrape and the one-time 2003
#     reversed-ARIMA backcast (_05_backcast.R) are deliberately NOT in the daily
#     run — they are bootstrap/one-off steps.
#
# Run from the repo root:  Rscript R/run_all.R

# Force working dir to the repo root regardless of how we were invoked, because
# every fetcher uses paths relative to it (e.g. "data/raw/foo.parquet").
.args <- commandArgs(trailingOnly = FALSE)
.file_arg <- sub("^--file=", "", .args[grep("^--file=", .args)])
if (length(.file_arg) == 1 && nzchar(.file_arg)) {
  setwd(normalizePath(file.path(dirname(.file_arg), "..")))
}
REPO <- getwd()
message("run_all.R working directory: ", REPO)
stopifnot(dir.exists("data/raw"), file.exists("R/pipeline.R"))

# Ordered list of fetchers (paths relative to repo root). Order is mostly
# independent — each writes its own data/raw/*.parquet — but kept in the numeric
# convention order for readability. car_registrations_04_update.R must come
# after the rest of real activity only by convention; it self-contains.
fetchers <- c(
  "R/data/02_prices.R",
  "R/data/02_prices_ppi.R",
  "R/data/03_real_activity.R",          # gdp, card, tourism, alu/marine, retail, resinv (+ reads car_reg)
  "R/data/03_real_activity/car_registrations_04_update.R",  # incremental car-reg refresh
  "R/data/04_labour.R",
  "R/data/04_labour_extras.R",          # vacancies + employment_count
  "R/data/05_financial.R",
  "R/data/05_retail_rates.R",
  "R/data/06_money_credit.R",
  "R/data/07_exchange.R",
  "R/data/08_external.R",
  "R/data/08_fiscal.R",
  "R/data/09_expectations.R",
  "R/data/09_gallup_confidence.R"
)

failures <- character(0)

run_fetcher <- function(path) {
  message("\n", strrep("=", 72))
  message("FETCH  ", path, "   [", format(Sys.time(), "%H:%M:%S"), "]")
  message(strrep("=", 72))
  t0 <- Sys.time()
  ok <- tryCatch({
    # Fresh child env per fetcher so helper redefinitions don't leak.
    env <- new.env(parent = globalenv())
    sys.source(path, envir = env, chdir = FALSE)  # chdir=FALSE: stay at repo root
    TRUE
  }, error = function(e) {
    message("  !! FAILED: ", conditionMessage(e))
    FALSE
  })
  dt <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1)
  if (ok) {
    message("  ok (", dt, "s)")
  } else {
    failures <<- c(failures, path)
    message("  failed (", dt, "s) — continuing")
  }
  invisible(ok)
}

message("\n### Daily refresh started ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
for (f in fetchers) run_fetcher(f)

# Assemble the panel over whatever raw parquet now exists.
message("\n", strrep("=", 72))
message("PIPELINE  R/pipeline.R   [", format(Sys.time(), "%H:%M:%S"), "]")
message(strrep("=", 72))
pipeline_ok <- tryCatch({
  sys.source("R/pipeline.R", envir = new.env(parent = globalenv()), chdir = FALSE)
  TRUE
}, error = function(e) {
  message("  !! PIPELINE FAILED: ", conditionMessage(e))
  FALSE
})

# Summary.
message("\n", strrep("#", 72))
message("### Daily refresh finished ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
message("    fetchers ok: ", length(fetchers) - length(failures), "/", length(fetchers))
if (length(failures)) {
  message("    FAILED fetchers:")
  for (f in failures) message("      - ", f)
}
message("    pipeline: ", if (pipeline_ok) "ok" else "FAILED")
message(strrep("#", 72))

# Non-zero exit if anything failed, so the scheduler/log flags it.
if (length(failures) > 0 || !pipeline_ok) quit(status = 1, save = "no")
