# ── 03_real_activity.R ────────────────────────────────────────────────────────
# Orchestrates all real-activity sub-modules.
# Each sub-file appends its series to the environment; 10_assemble.R joins them.
# ──────────────────────────────────────────────────────────────────────────────

src <- function(f) source(file.path(dirname(sys.frame(1)$ofile), "03_real_activity", f))

src("gdp_components.R")
src("card_turnover.R")
src("electricity.R")
src("tourism.R")
src("marine_exports.R")
src("aluminium.R")
src("car_registrations.R")
