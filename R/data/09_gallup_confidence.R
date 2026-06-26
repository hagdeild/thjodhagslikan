# Gallup consumer confidence — DATA_GAPS #76 (Væntingavísitala Gallup, VVG).
#
# Source: Gallup Iceland's public Looker dashboard, embedded at
#   https://www.gallup.is/data/geytenbq/sso/
# The page loads an SSO-signed Looker embed (gogn.gallup.is) as an iframe. The
# VVG line/column tile is backed by a Looker query; its data is exposed at
#   /explore/<query_slug>.csv
# which the (anonymous) embed session is authorised to fetch. We drive the page
# headless with chromote, read the tile's query slug off the dashboard's own
# network call (it changes if Gallup rebuilds the dashboard, so we capture it
# live rather than hard-coding), then fetch the CSV from inside the iframe.
#
# Notes:
# • The bare download link and the /api/internal/ endpoints return 403/login to a
#   non-embed session — the data is reachable ONLY through the embed iframe, hence
#   chromote. (The whole-dashboard `downloadzip` needs a real UI session too.)
# • The tile carries a table-calculation trend line ("Miðlína", constant ref) plus
#   the index itself ("VVG"). We keep VVG. Monthly, from 2001-03.
# • Values use Icelandic decimal commas -> parsed with locale.
# Stored RAW (index level); §H transform/interpolation happens in pipeline.R.

# 1.0.0 SETUP ----
library(tidyverse)
library(arrow)
library(chromote)

source("R/data/01_helpers.R")

EMBED_PAGE <- "https://www.gallup.is/data/geytenbq/sso/"


# 2.0.0 FETCH (headless embed -> tile query CSV) ----

fetch_vvg_csv <- function(page = EMBED_PAGE, timeout = 90) {
  b <- ChromoteSession$new(wait_ = TRUE)
  on.exit(b$close(), add = TRUE)
  b$default_timeout <- timeout

  # Capture the VVG tile's Looker query slug from the dashboard's own calls.
  store <- new.env(); store$slug <- NULL
  b$Network$enable()
  b$Network$responseReceived(function(msg) {
    u <- msg$response$url
    if (grepl("/api/internal/queries/[A-Za-z0-9]{10,}", u)) {
      store$slug <- sub(".*/queries/([A-Za-z0-9]+).*", "\\1", u)
    }
  })

  b$Page$navigate(page)
  b$Page$loadEventFired(wait_ = TRUE)

  # Find the gogn.gallup.is embed iframe (poll until it attaches).
  child <- NULL
  for (i in 1:30) {
    Sys.sleep(1)
    ft <- b$Page$getFrameTree()
    for (c in ft$frameTree$childFrames %||% list())
      if (grepl("gogn.gallup.is", c$frame$url)) child <- c$frame
    if (!is.null(child)) break
  }
  if (is.null(child)) stop("Gallup embed iframe never attached on ", page)
  Sys.sleep(8)  # let the Looker dashboard render its tiles

  world <- b$Page$createIsolatedWorld(frameId = child$id, worldName = "vvg")
  ctx   <- world$executionContextId
  ev <- function(js) b$Runtime$evaluate(
    expression = js, returnByValue = TRUE, contextId = ctx, awaitPromise = TRUE
  )$result$value

  # Trigger the VVG tile's "Download data" action so its query runs (this is what
  # surfaces the query slug on the wire). Pump the event loop so the network
  # callback fires.
  ev(paste0(
    "(function(){var e=Array.from(document.querySelectorAll('[aria-label]'))",
    ".find(x=>(x.getAttribute('aria-label')||'')",
    ".indexOf('V\\u00e6ntingav\\u00edsitala Gallup - Tile actions')>-1);e&&e.click();})()"
  ))
  for (i in 1:4) { Sys.sleep(1); ev("1") }
  ev(paste0(
    "(function(){var m=Array.from(document.querySelectorAll('[role=menuitem]'))",
    ".filter(e=>/Download data/i.test(e.textContent||''));m.length&&m[m.length-1].click();})()"
  ))
  for (i in 1:15) { Sys.sleep(1); ev("1"); if (!is.null(store$slug)) break }
  if (is.null(store$slug)) stop("Could not capture the VVG Looker query slug")

  # Fetch the tile data as CSV from inside the embed (same-origin, authorised).
  js <- sprintf(paste0(
    "(async()=>{const r=await fetch('/explore/%s.csv?apply_formatting=true",
    "&apply_vis=true&download=yes&limit=5000',{credentials:'include'});",
    "return await r.text();})()"), store$slug)
  csv <- ev(js)
  if (is.null(csv) || !grepl("VVG", csv)) stop("VVG CSV fetch failed (slug ", store$slug, ")")
  csv
}

raw_csv <- fetch_vvg_csv()


# 3.0.0 PARSE ----
# Columns: "  Month" (YYYY-MM), "Miðlína" (constant ref line, dropped), "VVG".

gallup_confidence_tbl <-
  read_csv(I(raw_csv), show_col_types = FALSE, locale = locale(decimal_mark = ",",
                                                               grouping_mark = ".")) |>
  rename_with(str_trim) |>
  transmute(
    date = make_date(str_sub(Month, 1, 4), str_sub(Month, 6, 7)),
    gallup_confidence = as.numeric(VVG)
  ) |>
  filter(!is.na(gallup_confidence)) |>
  arrange(date) |>
  assert_unique_dates()


gallup_confidence_tbl |>
  write_parquet("data/raw/gallup_confidence.parquet")
