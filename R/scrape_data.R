# Scrape data

# 1.0.0 SETUP ----
library(tidyverse)


# 2.0.0 HMS ----

csv_url <- "https://frs3o1zldvgn.objectstorage.eu-frankfurt-1.oci.customer-oci.com/n/frs3o1zldvgn/b/public_data_for_download/o/kaupvisitala.csv"

download.file(csv_url, destfile = "kaupvisitala.csv", mode = "wb")

kaupvisitala_tbl <- read_csv("kaupvisitala.csv") |>
  janitor::clean_names()

kaupvisitala_tbl |>
  mutate(
    date = make_date(ar, as.numeric(manudur))
  ) |>
  select(date, visitala)
