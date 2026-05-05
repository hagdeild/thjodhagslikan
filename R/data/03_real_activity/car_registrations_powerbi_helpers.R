# Shared Power BI helpers used by car_registrations_02_scrape_powerbi.R and
# car_registrations_04_update.R. Defines functions only — no top-level execution.

library(tidyverse)
library(httr2)
library(jsonlite)
library(lubridate)

# Public Power BI report:
# https://app.powerbi.com/view?r=eyJrIjoiZmJlMDY5N2QtYmQ5MC00ZjkwLWE4MGYtMTZkMDQ4YjBkNjk2IiwidCI6ImUxOGUxM2RjLWQ2MTUtNGUwNi1iNjBhLTkxYmNiMmY2YzRlMCIsImMiOjh9

resource_key <- "fbe0697d-bd90-4f90-a80f-16d048b0d696"
api_base <- "https://wabi-europe-north-b-api.analysis.windows.net/public/reports/"

months_is <- c(
  "01-janúar", "02-febrúar", "03-mars", "04-apríl",
  "05-maí", "06-júní", "07-júlí", "08-ágúst",
  "09-september", "10-október", "11-nóvember", "12-desember"
)

new_guid <- function() {
  chars <- c(0:9, letters[1:6])
  x <- sample(chars, 32, replace = TRUE)
  paste0(
    paste0(x[1:8], collapse = ""), "-",
    paste0(x[9:12], collapse = ""), "-",
    paste0(x[13:16], collapse = ""), "-",
    paste0(x[17:20], collapse = ""), "-",
    paste0(x[21:32], collapse = "")
  )
}

powerbi_headers <- function() {
  c(
    Accept = "application/json",
    ActivityId = new_guid(),
    RequestId = new_guid(),
    "X-PowerBI-ResourceKey" = resource_key
  )
}

`%||%` <- function(x, y) if (is.null(x)) y else x

fetch_report_metadata <- function() {
  request(paste0(api_base, resource_key, "/modelsAndExploration?preferReadOnlySession=true")) |>
    req_headers(!!!powerbi_headers()) |>
    req_perform() |>
    resp_body_string() |>
    fromJSON(simplifyVector = FALSE)
}

find_vehicle_class_table <- function(metadata) {
  visual_containers <- metadata$exploration$sections[[1]]$visualContainers

  matches <- keep(visual_containers, function(vc) {
    cfg <- fromJSON(vc$config, simplifyVector = FALSE)
    refs <- cfg$singleVisual$projections$Values |>
      map_chr(\(x) x$queryRef %||% "")

    identical(cfg$singleVisual$visualType, "tableEx") &&
      any(refs == "Query1.Ökutækisflokkur")
  })

  if (length(matches) == 0) {
    stop("Could not find the vehicle-class table visual in the Power BI report.")
  }

  vc <- matches[[1]]
  vc$config <- fromJSON(vc$config, simplifyVector = FALSE)
  vc
}

column_expr <- function(property) {
  list(Column = list(
    Expression = list(SourceRef = list(Source = "q")),
    Property = property
  ))
}

in_filter <- function(expr, values) {
  list(Condition = list(In = list(
    Expressions = list(expr),
    Values = map(values, \(value) list(list(Literal = list(Value = value))))
  )))
}

table_query_body <- function(metadata, table_visual, year, month_label) {
  query <- table_visual$config$singleVisual$prototypeQuery

  query$Where <- list(
    in_filter(column_expr("Nýtt / Notað"), "'Nýtt'"),
    in_filter(column_expr("Ár - ísl."), paste0(year, "L")),
    in_filter(column_expr("Mánuður - ísl."), paste0("'", month_label, "'"))
  )

  query$OrderBy <- list(list(
    Direction = 2L,
    Expression = list(Aggregation = query$Select[[2]]$Aggregation)
  ))

  shape_command <- list(
    SemanticQueryDataShapeCommand = list(
      Query = query,
      Binding = list(
        Primary = list(
          Groupings = list(list(Projections = list(0L, 1L)))
        ),
        DataReduction = list(
          DataVolume = 3L,
          Primary = list(Window = list(Count = 500L))
        ),
        Version = 1L
      ),
      ExecutionMetricsKind = 1L,
      Shape = list(
        PrimaryAxis = list(
          Groupings = list(list(Projections = list(0L, 1L)))
        ),
        DataReduction = list(
          DataVolume = 3L,
          Primary = list(Window = list(Count = 500L))
        )
      )
    )
  )

  list(
    version = "1.0.0",
    queries = list(list(
      Query = list(Commands = list(shape_command)),
      ApplicationContext = list(
        DatasetId = as.character(metadata$models[[1]]$id),
        Sources = list(list(
          ReportId = as.character(metadata$exploration$id),
          VisualId = table_visual$config$name
        ))
      ),
      QueryId = "",
      QueryHash = ""
    )),
    cancelQueries = list(),
    modelId = metadata$models[[1]]$id
  )
}

decode_dsr_rows <- function(rows, n_cols) {
  last <- vector("list", n_cols)
  decoded <- vector("list", length(rows))

  for (i in seq_along(rows)) {
    row <- rows[[i]]
    values <- row$C %||% list()
    repeat_mask <- as.integer(row$R %||% 0L)
    out <- vector("list", n_cols)
    value_idx <- 1L

    for (j in seq_len(n_cols)) {
      repeats_previous <- bitwAnd(repeat_mask, bitwShiftL(1L, j - 1L)) != 0L

      if (repeats_previous) {
        out[[j]] <- last[[j]]
      } else if (value_idx <= length(values)) {
        out[[j]] <- values[[value_idx]]
        value_idx <- value_idx + 1L
      } else {
        out[[j]] <- NA
      }
    }

    last <- out
    decoded[[i]] <- out
  }

  decoded
}

extract_vehicle_class_table <- function(response) {
  data <- response$results[[1]]$result$data
  error <- data$dsr$DataShapes[[1]]$`odata.error`$message$value %||% NULL
  if (!is.null(error)) {
    stop(error)
  }

  rows <- data$dsr$DS[[1]]$PH[[1]]$DM0 %||% list()
  if (length(rows) == 0) {
    return(tibble(vehicle_class = character(), registrations = integer()))
  }

  decoded <- decode_dsr_rows(rows, n_cols = 2)

  tibble(
    vehicle_class = map_chr(decoded, \(x) as.character(x[[1]])),
    registrations = map_int(decoded, \(x) as.integer(x[[2]]))
  ) |>
    filter(!is.na(vehicle_class), !is.na(registrations))
}

query_vehicle_class_table <- function(metadata, table_visual, year, month, period) {
  month_label <- months_is[[month]]
  body <- table_query_body(metadata, table_visual, year, month_label)

  response <- request(paste0(api_base, "querydata?synchronous=true")) |>
    req_headers(!!!powerbi_headers()) |>
    req_body_json(body, auto_unbox = TRUE) |>
    req_perform() |>
    resp_body_string() |>
    fromJSON(simplifyVector = FALSE)

  extract_vehicle_class_table(response) |>
    mutate(
      period = period,
      year = year,
      month = month,
      import_status = "Nýtt",
      .before = 1
    )
}
