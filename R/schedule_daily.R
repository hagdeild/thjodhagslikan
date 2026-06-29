# schedule_daily.R — register the daily data refresh as a Windows Scheduled Task
# using the taskscheduleR package. Replaces tools/schedule_daily_refresh.ps1 and
# tools/run_daily.ps1.
#
# Run ONCE, from R / RStudio (run as Administrator is recommended so the task can
# be created cleanly):
#     source("R/schedule_daily.R")
# or from a shell:
#     Rscript R/schedule_daily.R
#
# The task runs R/run_all.R every day at 02:00. taskscheduleR captures the
# console output of each run to a log next to run_all.R automatically.
#
# To remove the task later:
#     taskscheduleR::taskscheduler_delete("Thjodhagslikan_daily_refresh")

if (!requireNamespace("taskscheduleR", quietly = TRUE)) {
  install.packages("taskscheduleR")
}

# Repo root = parent of this script's directory (R/). Resolve it whether sourced
# interactively or run via Rscript.
.args <- commandArgs(trailingOnly = FALSE)
.file_arg <- sub("^--file=", "", .args[grep("^--file=", .args)])
if (length(.file_arg) == 1 && nzchar(.file_arg)) {
  repo <- normalizePath(file.path(dirname(.file_arg), ".."))
} else if (requireNamespace("rstudioapi", quietly = TRUE) &&
           rstudioapi::isAvailable()) {
  repo <- normalizePath(file.path(dirname(rstudioapi::getActiveDocumentContext()$path), ".."))
} else {
  repo <- normalizePath(getwd())  # assume you're at the repo root
}

run_all <- file.path(repo, "R", "run_all.R")
stopifnot(file.exists(run_all))

task_name <- "Thjodhagslikan_daily_refresh"

# Drop any existing task of the same name so re-running is idempotent.
existing <- tryCatch(taskscheduleR::taskscheduler_ls(), error = function(e) NULL)
if (!is.null(existing) && task_name %in% existing$TaskName) {
  taskscheduleR::taskscheduler_delete(task_name)
  message("Removed existing task '", task_name, "'.")
}

# taskscheduleR builds a .bat that runs `Rscript <run_all> ...` and tees the
# output to <run_all>.log (same dir as the script). run_all.R already forces its
# own working dir to the repo root via the --file= path, so the fetchers'
# relative paths ("data/raw/...") resolve correctly regardless of where the task
# runs from.
taskscheduleR::taskscheduler_create(
  taskname  = task_name,
  rscript   = run_all,
  schedule  = "DAILY",
  starttime = "02:00",
  startdate = format(Sys.Date(), "%d/%m/%Y")  # locale short-date, from system
)

message("Registered scheduled task '", task_name, "' (daily 02:00).")
message("Run R/run_all.R now to test:  Rscript R/run_all.R")
message("List tasks:  taskscheduleR::taskscheduler_ls()")
message("Delete:      taskscheduleR::taskscheduler_delete('", task_name, "')")
