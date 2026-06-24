# STEP 0 — Data-contract exploration (read-only)
#
# Per PROJECT_SPEC.md: before writing/modifying pipeline.R, report the contract of
# every data/raw/*.parquet and STOP. This script is READ-ONLY — it reads the
# parquets already on disk (it does NOT fetch, transform, assemble, or write
# anything). Run it, read the report, confirm the contract, THEN proceed to STEP 1.
#
# For each parquet it prints: path, rows, date min/max; every column with type and
# NA-leading run length; inferred frequency; columns that don't map to a spec
# series; spec series (A–I) with no column anywhere; and the common monthly window.

library(arrow)
library(tidyverse)


# 1.0.0 Expected series catalogue (from macro-data-for-favar.md) ----
#
# Maps each spec series we attempt to source -> the raw column name the fetchers
# actually produce (verified against the current parquets). Series the spec marks
# as DERIVED downstream, or documented as "no source"/deferred, are listed in
# `spec_deferred` so they are NOT reported as accidental coverage gaps.
#
# `#` is the spec series number; `col` is the raw column; `freq` its native
# frequency. NA col = expected but not yet produced by any fetcher.

spec_series <- tribble(
  ~section, ~num, ~series,                              ~col,                        ~freq,
  # A. Prices (prices.parquet)
  "A",  1L, "CPI all items",                           "cpi",                        "M",
  "A",  2L, "CPI food & non-alc",                      "matur_og_oafengir_drykkir",  "M",
  "A",  3L, "CPI alcohol & tobacco",                   "afengir_drykkir_tobak_og_fikniefni", "M",
  "A",  4L, "CPI clothing & footwear",                 "fatnadur_og_skofatnadur",    "M",
  "A",  5L, "CPI housing/utilities",                   "husnaedi_vatn_rafmagn_gas_og_adrir_orkugjafar", "M",
  "A",  6L, "CPI furnishings/household",               "husbunadur_heimilistaeki_og_thjonusta_tengd_venjubundnu_vidhaldi_heimila", "M",
  "A",  7L, "CPI transport (proxy: vehicles+running)", "kaup_a_okutaekjum",          "M",
  "A",  8L, "CPI restaurants & hotels",                "veitingahus_og_gistithjonusta", "M",
  "A",  9L, "CPI misc goods & services",               "tryggingar",                 "M",
  "A", 10L, "CPI domestic component",                  "domestic",                   "M",
  "A", 11L, "CPI imported component",                  "import",                     "M",
  "A", 12L, "CPI excluding housing",                   "cpi_less_housing",           "M",
  "A", 16L, "Construction cost index",                 "byggingarvisitala",          "M",
  "A", 18L, "House prices (capital)",                  "husnaedisverd",              "M",
  # B. Real activity (gdp / card_turnover / tourism / exports / car_registrations)
  "B", 19L, "Card turnover domestic",                  "domestic_card_turnover",     "M",
  "B", 20L, "Card turnover foreign",                   "foreign_card_turnover",      "M",
  "B", 21L, "New vehicle registrations",               "registrations",              "M",
  "B", 27L, "Tourist arrivals",                        "farthegar",                  "M",
  "B", 28L, "Marine export volume",                    "marine",                     "M",
  "B", 29L, "Aluminium exports",                       "aluminum",                   "M",
  "B", 30L, "GDP",                                     "gdp",                        "Q",
  # C. Labour  (labour.parquet)
  "C", 32L, "Unemployment rate",                       "unemployment_rate",          "M",
  "C", 34L, "Wage index (IWPI)",                       "launavisitala",              "Q",
  "C", 35L, "Total hours worked",                      "unnar_stundir",              "Q",
  "C", 36L, "Labour force participation",              "atvinnuthatttaka",           "Q",
  # D. Interest rates (financial.parquet)
  "D", 37L, "Policy rate (7-day deposit)",             "policy_rate",                "M",
  "D", 38L, "REIBOR 3m",                               "reibor_3m",                  "M",
  "D", 39L, "REIBOR 6m",                               "reibor_6m",                  "M",
  "D", 43L, "Govt nominal yield 5y/10y",               "govt_yield_nominal_10y",     "M",
  "D", 44L, "Govt indexed yield 10y",                  "govt_yield_indexed_10y",     "M",
  "D", 45L, "Breakeven (bond spread)",                 "breakeven_5y",               "M",
  # E. Money & credit (money_credit.parquet)
  "E", 47L, "M3",                                      "m3",                         "M",
  "E", 48L, "Credit to households",                    "credit_households",          "M",
  "E", 49L, "Credit to businesses",                    "credit_businesses",          "M",
  "E", 50L, "IL-mortgage share (KEY)",                 "il_mortgage_share",          "M",
  "E", 51L, "New mortgage lending",                    "new_mortgage_lending",       "M",
  # F. Exchange rates (exchange.parquet)
  "F", 55L, "ISK/EUR",                                 "isk_eur",                    "M",
  "F", 56L, "ISK/USD",                                 "isk_usd",                    "M",
  "F", 57L, "Trade-weighted index (narrow)",           "twi",                        "M",
  "F", 58L, "REER",                                    "reer",                       "M",
  # G. External  (08_external.R -> external.parquet)
  "G", 59L, "Brent USD",                               "brent_usd",                  "M",
  "G", 61L, "FAO food price index",                    "fao_food",                   "M",
  "G", 62L, "Aluminium USD",                           "aluminium",                  "M",
  "G", 63L, "Euro-area HICP",                          "ea_hicp",                    "M",
  "G", 64L, "Euro-area industrial production",         "ea_ip",                      "M",
  "G", 65L, "ECB main refinancing rate",               "ecb_mro",                    "M",
  "G", 66L, "US Fed funds",                            "fed_funds",                  "M",
  "G", 67L, "US CPI",                                  "us_cpi",                     "M",
  "G", 68L, "GSCPI",                                   "gscpi",                      "M",
  "G", 70L, "VIX",                                     "vix",                        "M",
  "G", 72L, "Nordic policy rates (SE/NO/DK)",          "policy_rate_se",             "M",
  # H. Expectations (expectations.parquet)
  "H", 73L, "Household inflation expectations",        "hh_infl_exp_mean",           "Q",
  "H", 74L, "Business inflation expectations",         "biz_infl_exp_mean",          "Q",
  "H", 75L, "Market participants' expectations",       "mkt_infl_exp_h4",            "Q"
)

# Spec series intentionally NOT expected as a fetched column (derived downstream,
# or documented as no-free-source / deferred). Kept here so STEP 0's gap check
# does not flag known, deliberate omissions.
spec_deferred <- tribble(
  ~num, ~series,                                ~reason,
  13L, "CPI services",                          "subcomponent not separately fetched",
  14L, "CPI goods",                             "subcomponent not separately fetched",
  15L, "PPI",                                   "not wired",
  17L, "Import price index",                    "dropped: embeds FX (redundant with EER)",
  22L, "Retail sales index",                    "not wired",
  23L, "Industrial production index",           "not wired",
  24L, "Building permits",                      "not wired",
  25L, "Housing starts/completions",            "not wired",
  26L, "Electricity consumption",               "not wired",
  31L, "Registered unemployment (level)",       "only the rate (32) is emitted, not the count",
  33L, "Job vacancies",                         "not wired",
  40L, "Non-indexed mortgage rate",             "no machine-readable Seðlabanki source",
  41L, "Indexed mortgage rate",                 "no machine-readable Seðlabanki source",
  42L, "Corporate lending rate",                "no machine-readable Seðlabanki source",
  46L, "Household deposit rate",                "no machine-readable Seðlabanki source",
  52L, "OMXI index",                            "no clean free deep-history source",
  53L, "CDS spread",                            "Bloomberg/Refinitiv only",
  54L, "Financial conditions index",            "CB publishes no clean monthly FCI",
  60L, "Brent in ISK",                          "DERIVED (59 x 56) at assembly",
  69L, "Baltic Dry Index",                      "no free deep-history source",
  71L, "Fish price index",                      "covered by marine export price (B)",
  76L, "Consumer confidence",                   "Gallup/Capacent source, not wired",
  77L, "Business sentiment",                    "Gallup/SA source, not wired",
  78L, "PMI",                                   "SA/Capacent source, not wired",
  79L, "Government revenue",                     "fiscal block not wired",
  80L, "Government expenditure",                 "fiscal block not wired",
  81L, "Net fiscal balance",                    "DERIVED / fiscal block not wired"
)


# 2.0.0 Helpers ----

# The date-like column may be named `date` or `period`.
date_col_of <- function(df) {
  cand <- intersect(c("date", "period"), names(df))
  if (length(cand) == 0) {
    cand <- names(df)[map_lgl(df, \(x) inherits(x, "Date"))]
  }
  if (length(cand) == 0) NA_character_ else cand[1]
}

# Leading run of NA in a column (the ragged left edge), after ordering by date.
na_lead <- function(x) {
  r <- rle(is.na(x))
  if (length(r$values) && isTRUE(r$values[1])) r$lengths[1] else 0L
}

# Infer monthly vs quarterly from the median gap between consecutive dates.
infer_freq <- function(d) {
  d <- sort(unique(d))
  if (length(d) < 3) return("unknown")
  gap <- median(as.numeric(diff(d)))
  if (gap <= 45) "monthly" else if (gap <= 135) "quarterly" else
    paste0("~", round(gap), "d")
}


# 3.0.0 Per-file report ----

raw_dir <- "data/raw"
files   <- sort(list.files(raw_dir, pattern = "[.]parquet$", full.names = TRUE))

all_cols     <- character(0)   # every (file::col) seen, for the gap check
monthly_spans <- list()        # min/max of each monthly file, for the common window

cat(strrep("=", 78), "\n")
cat("STEP 0 — data-contract report for", raw_dir, "\n")
cat(strrep("=", 78), "\n")

for (f in files) {
  df <- tryCatch(read_parquet(f), error = function(e) e)
  cat("\n###", basename(f), "\n")
  if (inherits(df, "error")) { cat("  !! READ ERROR:", conditionMessage(df), "\n"); next }

  dcol <- date_col_of(df)
  if (!is.na(dcol)) df <- df |> arrange(.data[[dcol]])
  drange <- if (!is.na(dcol)) range(df[[dcol]], na.rm = TRUE) else c(NA, NA)
  freq   <- if (!is.na(dcol)) infer_freq(df[[dcol]]) else "no-date-col"

  cat(sprintf("  rows: %d   cols: %d   date col: %s   range: %s -> %s   freq: %s\n",
              nrow(df), ncol(df), dcol %||% "<none>",
              as.character(drange[1]), as.character(drange[2]), freq))

  if (identical(freq, "monthly") && !is.na(dcol)) {
    monthly_spans[[basename(f)]] <- drange
  }

  cat("  columns:\n")
  for (nm in names(df)) {
    col <- df[[nm]]
    tag <- if (nm == dcol) "  [date]" else if (!is.numeric(col)) "  [non-numeric]" else ""
    cat(sprintf("    %-72s <%s> NA-lead=%d%s\n",
                nm, class(col)[1], na_lead(col), tag))
    if (nm != dcol) all_cols <- c(all_cols, nm)
  }

  # Point 4: columns in this file not mapped to any spec series.
  mapped <- spec_series$col[!is.na(spec_series$col)]
  unmapped <- setdiff(setdiff(names(df), dcol),
                      c(mapped, "source"))           # `source` is a label, not a series
  unmapped <- unmapped[map_lgl(df[unmapped], is.numeric)]
  if (length(unmapped)) {
    cat("  (!) columns not in spec map:", paste(unmapped, collapse = ", "), "\n")
  }
}


# 4.0.0 Cross-file checks ----

cat("\n", strrep("-", 78), "\n", sep = "")
cat("COVERAGE — spec series (A–I) with NO matching column on disk\n")
cat(strrep("-", 78), "\n")

have <- spec_series |>
  mutate(present = !is.na(col) & col %in% all_cols)

gaps <- have |> filter(!present)
if (nrow(gaps) == 0) {
  cat("  none — every mapped spec series has a column.\n")
} else {
  gaps |>
    mutate(line = sprintf("  §%s %2d  %-34s %s", section, num, series,
                          if_else(is.na(col), "(no fetcher column)",
                                  paste0("expected col '", col, "' MISSING")))) |>
    pull(line) |>
    walk(cat, "\n")
}

cat("\n  (informational) spec series deliberately deferred / derived — not gaps:\n")
spec_deferred |>
  mutate(line = sprintf("    %2d %-32s — %s", num, series, reason)) |>
  pull(line) |>
  walk(cat, "\n")


# Point 6: common monthly window across all monthly sources.
cat("\n", strrep("-", 78), "\n", sep = "")
cat("PANEL WINDOW — overlap across monthly sources\n")
cat(strrep("-", 78), "\n")
if (length(monthly_spans)) {
  starts <- map_dbl(monthly_spans, \(r) as.numeric(r[1]))
  ends   <- map_dbl(monthly_spans, \(r) as.numeric(r[2]))
  cat(sprintf("  latest start : %s   (%s)\n",
              as.character(as.Date(max(starts))), names(monthly_spans)[which.max(starts)]))
  cat(sprintf("  earliest end : %s   (%s)\n",
              as.character(as.Date(min(ends))),  names(monthly_spans)[which.min(ends)]))
  cat(sprintf("  full-overlap monthly window: %s -> %s\n",
              as.character(as.Date(max(starts))), as.character(as.Date(min(ends)))))
  cat("  per-source monthly spans:\n")
  imap(monthly_spans, \(r, nm)
       cat(sprintf("    %-42s %s -> %s\n", nm,
                   as.character(r[1]), as.character(r[2])))) |> invisible()
} else {
  cat("  (no monthly sources detected)\n")
}

cat("\n", strrep("=", 78), "\n", sep = "")
cat("END STEP 0. Review the contract above, then confirm before STEP 1 (pipeline.R).\n")
cat(strrep("=", 78), "\n")
