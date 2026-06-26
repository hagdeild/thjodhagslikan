# Backcast car registrations to 2003-01 — removes the 12 leading NAs that
# otherwise gate the fully-populated panel window at 2004-01 (see pipeline.R /
# PROJECT_SPEC: panel floor is 2003-01).
#
# The combined series (car_registrations.parquet) starts 2004-01 — the source
# PDFs/Power BI don't go earlier. We extend it back through 2003 with a
# reversed-seasonal-ARIMA forecast of the series' OWN dynamics:
#   reverse the monthly series, fit auto.arima on log() with seasonality, forecast
#   12 steps (= 2003 in reverse), un-reverse, round.
#
# Why reversed-ARIMA and not a regression on other monthly series: the obvious
# contemporaneous drivers available in 2003 (card turnover, policy rate) explain
# little of monthly registrations (R^2 ~ 0.28 — car buying is lumpy/credit-driven,
# not tracking everyday spend), so importing them adds noise. The series' own
# strong seasonality + AR structure is the more honest signal, and the lower 2003
# total it implies (~11.2k vs 2004's ~14k) is economically right — 2003 sits
# earlier in the 2003-08 credit-driven car-buying ramp. (README next-action #2
# named reversed-ARIMA as the intended method.)
#
# Idempotent: if 2003 rows already exist, this is a no-op. The backcast rows carry
# source = "backcast_arima" so they're transparent and droppable.

# 1.0.0 SETUP ----
library(tidyverse)
library(arrow)
library(forecast)

PATH <- "data/raw/car_registrations.parquet"
car <- read_parquet(PATH) |> arrange(period)

if (min(car$period) <= as.Date("2003-01-01")) {
  message("car_registrations already extends to 2003 or earlier — backcast skipped.")
} else {

  # 2.0.0 REVERSED-ARIMA BACKCAST ----
  start_y <- lubridate::year(min(car$period))
  start_m <- lubridate::month(min(car$period))
  y  <- ts(car$registrations, start = c(start_y, start_m), frequency = 12)
  yr <- ts(rev(as.numeric(y)), frequency = 12)              # time-reversed

  fit <- auto.arima(log(yr), seasonal = TRUE)
  h   <- 12L                                                # 2003-01 .. 2003-12
  fc  <- forecast(fit, h = h)

  back_2003 <- tibble(
    period = seq(as.Date("2003-01-01"), by = "month", length.out = h),
    registrations = as.integer(round(exp(rev(as.numeric(fc$mean))))),  # un-reverse
    source = "backcast_arima"
  )

  message(sprintf(
    "Backcast 2003: %d months, total %d (cf. 2004 actual total %d). ARIMA(%s).",
    nrow(back_2003), sum(back_2003$registrations),
    sum(car$registrations[lubridate::year(car$period) == 2004]),
    paste(fit$arma, collapse = ",")
  ))

  # 3.0.0 PREPEND + WRITE ----
  car_ext <- bind_rows(back_2003, car) |> arrange(period)
  stopifnot(!anyDuplicated(car_ext$period))

  write_parquet(car_ext, PATH)
  write_csv(car_ext, "data/raw/car_registrations.csv")
  message(sprintf("Written %d months (%s to %s) to %s",
                  nrow(car_ext), format(min(car_ext$period), "%Y-%m"),
                  format(max(car_ext$period), "%Y-%m"), PATH))
}
