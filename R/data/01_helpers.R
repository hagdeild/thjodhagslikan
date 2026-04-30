# ── 01_helpers.R ──────────────────────────────────────────────────────────────
# Shared utility functions used across data-ingestion scripts.
# ──────────────────────────────────────────────────────────────────────────────

library(lubridate)
library(dplyr)
library(tidyr)
library(zoo)

# ── Date helpers ───────────────────────────────────────────────────────────────

#' Parse a variety of date formats to the first day of the period.
#'
#' Handles:  "2024-01", "2024Q1", "2024-Q1", "01/2024", plain Date/POSIXct.
fix_date <- function(x) {
  if (inherits(x, c("Date", "POSIXct", "POSIXlt"))) return(as.Date(x))

  x <- as.character(x)

  # "2024-01" or "2024-1"
  if (grepl("^\\d{4}-\\d{1,2}$", x))
    return(as.Date(paste0(x, "-01")))

  # "2024Q1" or "2024-Q1"
  if (grepl("^\\d{4}-?Q[1-4]$", x)) {
    yr <- as.integer(substr(x, 1, 4))
    q  <- as.integer(sub(".*Q", "", x))
    return(as.Date(ISOdate(yr, (q - 1L) * 3L + 1L, 1L)))
  }

  # "01/2024"
  if (grepl("^\\d{1,2}/\\d{4}$", x)) {
    parts <- strsplit(x, "/")[[1]]
    return(as.Date(paste0(parts[2], "-", parts[1], "-01")))
  }

  as.Date(x)   # fallback — let base R try
}

# ── Series helpers ─────────────────────────────────────────────────────────────

#' Splice two overlapping series: use `base` where available, extend with
#' `extension` outside the base range, scaled to match at the overlap boundary.
#'
#' @param base       data.frame with columns `date`, `value`
#' @param extension  data.frame with columns `date`, `value`
#' @param direction  "back" (extend earlier) or "forward" (extend later)
splice_series <- function(base, extension, direction = "back") {
  stopifnot(direction %in% c("back", "forward"))

  base      <- base      |> arrange(date) |> filter(!is.na(value))
  extension <- extension |> arrange(date) |> filter(!is.na(value))

  if (direction == "back") {
    boundary_date  <- min(base$date)
    anchor_base    <- base$value[base$date == boundary_date]
    anchor_ext     <- extension$value[extension$date == boundary_date]

    if (length(anchor_ext) == 0 || is.na(anchor_ext))
      stop("splice_series: extension has no value at the base boundary date")

    scale <- anchor_base / anchor_ext

    back_ext <- extension |>
      filter(date < boundary_date) |>
      mutate(value = value * scale)

    bind_rows(back_ext, base) |> arrange(date)

  } else {
    boundary_date  <- max(base$date)
    anchor_base    <- base$value[base$date == boundary_date]
    anchor_ext     <- extension$value[extension$date == boundary_date]

    if (length(anchor_ext) == 0 || is.na(anchor_ext))
      stop("splice_series: extension has no value at the base boundary date")

    scale <- anchor_base / anchor_ext

    fwd_ext <- extension |>
      filter(date > boundary_date) |>
      mutate(value = value * scale)

    bind_rows(base, fwd_ext) |> arrange(date)
  }
}

# ── Frequency helpers ──────────────────────────────────────────────────────────

#' Convert a monthly data.frame (date, value) to quarterly averages.
monthly_to_quarterly <- function(df, value_col = "value", fun = mean) {
  df |>
    mutate(date = floor_date(date, "quarter")) |>
    group_by(date) |>
    summarise(across(all_of(value_col), \(x) fun(x, na.rm = TRUE)),
              .groups = "drop")
}

#' Interpolate a quarterly series to monthly using cubic spline.
quarterly_to_monthly <- function(df, value_col = "value") {
  all_months <- seq(min(df$date), max(df$date), by = "month")
  approx_vals <- spline(as.numeric(df$date), df[[value_col]],
                        xout = as.numeric(all_months),
                        method = "natural")$y
  tibble(date = all_months, !!value_col := approx_vals)
}

# ── Growth / transformation helpers ───────────────────────────────────────────

pct_change <- function(x, lag = 1) (x / lag(x, lag) - 1) * 100
log_diff   <- function(x, lag = 1) c(rep(NA, lag), diff(log(x), lag = lag)) * 100
yoy        <- function(x) pct_change(x, lag = 12)   # monthly year-on-year
yoy_q      <- function(x) pct_change(x, lag = 4)    # quarterly year-on-year

# ── Seasonal adjustment wrapper ────────────────────────────────────────────────

#' Convenience wrapper around stats::stl for quick seasonal adjustment.
#' Returns the seasonally-adjusted component.
sa_stl <- function(x, frequency = 12, s.window = "periodic", ...) {
  if (sum(!is.na(x)) < 2 * frequency) return(rep(NA_real_, length(x)))
  ts_obj <- ts(x, frequency = frequency)
  fit    <- stl(na.approx(ts_obj), s.window = s.window, ...)
  as.numeric(seasadj(fit))   # requires forecast package
}

# ── Misc ───────────────────────────────────────────────────────────────────────

#' Return the last non-NA value (useful for labelling charts).
last_obs <- function(x) tail(x[!is.na(x)], 1)

#' Ensure a data.frame has no duplicate dates.
assert_unique_dates <- function(df, date_col = "date") {
  dups <- df[[date_col]][duplicated(df[[date_col]])]
  if (length(dups) > 0)
    stop("Duplicate dates found: ", paste(dups, collapse = ", "))
  invisible(df)
}
