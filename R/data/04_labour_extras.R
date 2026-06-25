# Labour extras — DATA_GAPS #33 (job vacancies) and a monthly employment-count
# series related to #31.
#
#   #33  Job vacancies      — Hagstofa JVS00001, QUARTERLY 2019Q1-, total economy.
#   #31  (employment count) — Hagstofa VIN10001, register-based number EMPLOYED,
#        MONTHLY 2005-. NB this is the *employed* headcount, NOT the registered-
#        *unemployed* count the gap note asks for (that lives in the Vinnumála-
#        stofnun workbook, added in 04_labour.R). Pulled here as a genuine
#        monthly labour-quantity signal.

# 1.0.0 SETUP ----
library(tidyverse)
library(arrow)
library(httr2)

source("R/data/01_helpers.R")

px_fetch <- function(url, query) {
  raw <- request(url) |>
    req_body_json(list(query = query, response = list(format = "csv"))) |>
    req_perform() |>
    resp_body_string(encoding = "UTF-8")
  read_csv(I(raw), show_col_types = FALSE)
}

.base <- "https://px.hagstofa.is/pxis/api/v1/is/Samfelag/vinnumarkadur"


# 2.0.0 JOB VACANCIES (#33) ----
# Atvinnugrein = 0 (Alls), Eining = VAC (count) + VAC_RT (rate). Quarterly.

vac_raw <- px_fetch(
  file.path(.base, "lausstorf/JVS00001.px"),
  list(
    list(code = "Atvinnugrein", selection = list(filter = "item", values = list("0"))),
    list(code = "Eining",       selection = list(filter = "item", values = list("VAC", "VAC_RT")))
  )
)

vacancies_tbl <-
  vac_raw |>
  rename(quarter = Ársfjórðungur) |>
  rename_with(~ case_when(
    str_detect(.x, "Fjöldi lausra")    ~ "vacancies",
    str_detect(.x, "Hlutfall lausra")  ~ "vacancy_rate",
    TRUE                               ~ .x
  )) |>
  mutate(                                       # "2019Q1" -> first day of quarter
    year  = as.integer(str_sub(quarter, 1, 4)),
    qtr   = as.integer(str_sub(quarter, 6, 6)),
    date  = make_date(year, (qtr - 1L) * 3L + 1L, 1L)
  ) |>
  select(date, vacancies, vacancy_rate) |>
  arrange(date)


# 3.0.0 EMPLOYMENT COUNT (#31-related) ----
# All totals: Kyn=0, Aldursflokkar=Total, Uppruni=0, Lögheimili=0. Monthly.

emp_raw <- px_fetch(
  file.path(.base, "vinnuaflskraargogn/VIN10001.px"),
  list(
    list(code = "Kyn",           selection = list(filter = "item", values = list("0"))),
    list(code = "Aldursflokkar", selection = list(filter = "item", values = list("Total"))),
    list(code = "Uppruni",       selection = list(filter = "item", values = list("0"))),
    list(code = "Lögheimili",    selection = list(filter = "item", values = list("0")))
  )
)

# After selecting all four dims to single values, one value column remains plus
# the monthly time column (named "Mánuður").
employment_tbl <-
  emp_raw |>
  rename(month = Mánuður) |>
  mutate(date = make_date(str_sub(month, 1, 4), str_sub(month, 6, 7))) |>
  transmute(date, employment = .data[[setdiff(names(emp_raw), "Mánuður")[1]]]) |>
  arrange(date)


# 4.0.0 SAVE ----
vacancies_tbl  |> write_parquet("data/raw/vacancies.parquet")
employment_tbl |> write_parquet("data/raw/employment_count.parquet")
