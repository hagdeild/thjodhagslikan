# Temporary disaggregation of GDP

# 1.0.0 SETUP ----
library(tidyverse)
library(tempdisagg)


gdp_tbl <- read_csv2(
  "https://px.hagstofa.is:443/pxis/sq/e7b63876-9200-4d72-b876-b17525bda63e"
)

gdp_tbl <- gdp_tbl |>
  select(-2) |>
  set_names("date", "gdp") |>
  mutate(
    date = str_replace(date, "Á", "Q"),
    date = date(zoo::as.yearqtr(date))
  )

# 2.0.0 DISAGGREGATE QUARTERLY TO MONTHLY ----

gdp_ts <- ts(gdp_tbl$gdp, start = c(1995, 1), frequency = 4)

gdp_td <- td(
  gdp_ts ~ 1,
  to = "monthly",
  method = "denton-cholette",
  conversion = "average"
)

gdp_monthly_tbl <- tibble(
  date = seq.Date(
    from = as.Date("1995-01-01"),
    by = "month",
    length.out = length(predict(gdp_td))
  ),
  gdp = as.numeric(predict(gdp_td))
)

# 3.0.0 VISUALIZE ----

ggplot() +
  geom_line(
    data = gdp_monthly_tbl,
    aes(x = date, y = gdp, color = "Monthly (disaggregated)"),
    linewidth = 0.5
  ) +
  geom_point(
    data = gdp_tbl,
    aes(x = date, y = gdp, color = "Quarterly (original)"),
    size = 1.5
  ) +
  scale_color_manual(
    values = c(
      "Monthly (disaggregated)" = "steelblue",
      "Quarterly (original)" = "firebrick"
    )
  ) +
  labs(
    title = "GDP: Quarterly vs Monthly (Denton-Cholette)",
    x = NULL,
    y = "GDP",
    color = NULL
  ) +
  theme_minimal()

# 4.0.0 DIAGNOSTICS ----

# 4.1 Reaggregation check: do monthly averages recover quarterly values?
reagg_tbl <- gdp_monthly_tbl |>
  mutate(quarter = floor_date(date, "quarter")) |>
  summarise(gdp_monthly_avg = mean(gdp), .by = quarter) |>
  left_join(gdp_tbl, by = c("quarter" = "date")) |>
  mutate(abs_error = abs(gdp_monthly_avg - gdp))

cat("=== Reaggregation check ===\n")
cat("Max absolute error:", max(reagg_tbl$abs_error), "\n")
cat("Mean absolute error:", mean(reagg_tbl$abs_error), "\n\n")

# 4.2 Smoothness: SD of month-to-month changes vs quarter-to-quarter
#     Denton-Cholette minimizes differences in consecutive changes,
#     so a low ratio indicates smooth interpolation.
monthly_changes <- diff(gdp_monthly_tbl$gdp)
quarterly_changes <- diff(gdp_tbl$gdp)

cat("=== Smoothness ===\n")
cat("SD of monthly changes:", round(sd(monthly_changes)), "\n")
cat("SD of quarterly changes:", round(sd(quarterly_changes)), "\n")
cat(
  "Ratio (monthly/quarterly):",
  round(sd(monthly_changes) / sd(quarterly_changes), 3),
  "\n\n"
)

# 4.3 Cross-validation: hold out last 4 quarters, disaggregate the rest,
#     then extrapolate and compare reaggregated values to actuals.
n_holdout <- 4
n_total <- length(gdp_ts)

gdp_ts_train <- ts(
  gdp_ts[1:(n_total - n_holdout)],
  start = start(gdp_ts),
  frequency = 4
)

gdp_td_train <- td(
  gdp_ts_train ~ 1,
  to = "monthly",
  method = "denton-cholette",
  conversion = "average"
)

train_monthly <- as.numeric(predict(gdp_td_train))
n_train_months <- length(train_monthly)
last_trend <- mean(diff(tail(train_monthly, 12)))
extrapolated <- train_monthly[n_train_months] + last_trend * (1:12)
holdout_predicted <- tapply(extrapolated, rep(1:4, each = 3), mean)
holdout_actual <- tail(gdp_tbl$gdp, n_holdout)

cv_mape <- mean(abs(holdout_actual - holdout_predicted) / holdout_actual) * 100

cat("=== Cross-validation (last", n_holdout, "quarters held out) ===\n")
cat("MAPE:", round(cv_mape, 2), "%\n")
cat("Note: high MAPE is expected — Denton-Cholette without an indicator\n")
cat("      has no forecasting power; it only interpolates.\n")
cat(
  "      Adding a monthly indicator (e.g. card turnover) would improve both.\n"
)
