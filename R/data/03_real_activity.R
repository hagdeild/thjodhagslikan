# ── 03_real_activity.R ────────────────────────────────────────────────────────
# Orchestrates all real-activity sub-modules.
# Each sub-file appends its series to the environment; pipeline.R joins them.
# ──────────────────────────────────────────────────────────────────────────────

.real_activity_dir <- (function() {
  this_file <- tryCatch(
    sys.frame(1)$ofile,
    error = function(e) NULL
  )
  base <- if (!is.null(this_file)) {
    dirname(this_file)
  } else {
    here::here("R", "data")
  }
  file.path(base, "03_real_activity")
})()

src <- function(f) source(file.path(.real_activity_dir, f))

src("gdp_components.R")
src("card_turnover.R")
src("tourism.R")
src("aluminium_and_marine_exports.R")
src("car_registrations.R")
