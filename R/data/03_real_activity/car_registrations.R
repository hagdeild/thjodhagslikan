library(tidyverse)
library(rvest)
library(chromote)

url <- "https://bifreidatolur.samgongustofa.is/?nid=1187#eldri-manadartolur"

# Render page with headless Chrome
b <- ChromoteSession$new()
b$Page$navigate(url)
b$Page$loadEventFired()
Sys.sleep(5) # let JS finish loading the table

doc <- b$DOM$getDocument()
html_str <- b$DOM$getOuterHTML(nodeId = doc$root$nodeId)$outerHTML
b$close()

# Pull every URL on the page, filter to .pdf
pdf_urls <- read_html(html_str) |>
  html_elements("a") |>
  html_attr("href") |>
  discard(is.na) |>
  keep(\(x) str_detect(x, "\\.pdf$")) |>
  unique() |>
  map_chr(\(x) {
    if (str_starts(x, "http")) {
      x
    } else {
      paste0("https://bifreidatolur.samgongustofa.is/", str_remove(x, "^/"))
    }
  })

cat("Found", length(pdf_urls), "PDFs\n")

# Download all
out_dir <- "samgongustofa_pdf"
dir.create(out_dir, showWarnings = FALSE)

walk(pdf_urls, \(u) {
  dest <- file.path(out_dir, basename(u))
  if (file.exists(dest)) {
    message("Skip: ", basename(u))
    return(invisible())
  }
  tryCatch(
    {
      download.file(u, dest, mode = "wb", quiet = TRUE)
      message("OK: ", basename(u))
    },
    error = function(e) {
      message("FAIL: ", basename(u), " — ", conditionMessage(e))
    }
  )
  Sys.sleep(0.3)
})
