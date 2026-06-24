# Card turnover

# 1.0.0 SETUP ----
library(tidyverse)
library(arrow)


# 2.0.0 DATA ----
greidslumidlun_url <- "https://sedlabanki.is/library/?itemid=e2bba807-3848-4c61-a9e1-08e730b423f6"

kortavelta_tbl <-
  local({
    tmp <- tempfile(fileext = ".xlsx")
    download.file(greidslumidlun_url, tmp, mode = "wb", quiet = TRUE)

    raw <- readxl::read_excel(tmp, sheet = "Sheet1", col_names = FALSE)

    # Row 6 holds dates (Excel serial numbers) in cols 5+. Serials are month-end;
    # floor to first-of-month to match the raw-output contract (all sources use
    # the first day of the period as `date`).
    dates <- floor_date(
      as.Date(as.numeric(raw[6, -(1:4)]), origin = "1899-12-30"), "month"
    )

    # Rows 7-74 are data; cols: 1=code, 2=label_is, 3=label_en, 4=fame, 5+=values
    data_rows <- raw[7:74, ]
    labels <- janitor::make_clean_names(as.character(data_rows[[2]]))

    values <- data_rows[, -(1:4)] |>
      mutate(across(everything(), as.numeric)) |>
      t() |>
      as.data.frame() |>
      setNames(labels)

    bind_cols(tibble(date = dates), as_tibble(values)) |>
      filter(!is.na(date))
  })

kortavelta_tbl <- kortavelta_tbl |>
  select(
    date,
    innlend_greidslukort,
    heildaruttekt_erlendra_debet_og_kreditkorta_herlendis
  ) |>
  drop_na() |>
  set_names("date", "domestic_card_turnover", "foreign_card_turnover")


kortavelta_tbl |>
  write_parquet("data/raw/card_turnover.parquet")
