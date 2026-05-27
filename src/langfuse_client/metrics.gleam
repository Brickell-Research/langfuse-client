//// `GET /api/public/v2/metrics` — server-side aggregations over Langfuse
//// score data. Build a query with `score_count_query` /
//// `score_value_query` and pass it to the matching `list_*` function.
////
//// The Langfuse v2 metrics endpoint is BETA. This module exposes score
//// count + avg-value queries grouped by `(name, dataType, source)`, with
//// optional server-side filters. Broader surface (other measures, views,
//// dimensions) will follow the same shape once the endpoint stabilises.

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/result

@target(erlang)
import langfuse_client/client.{type Client, type Error}

/// Which family of scores to aggregate over.
///
/// - `ScoresNumeric` covers `NUMERIC` and `BOOLEAN` scores.
/// - `ScoresCategorical` covers `CATEGORICAL` scores.
pub type ScoreView {
  ScoresNumeric
  ScoresCategorical
}

/// One row of the `data` array: the count of scores grouped by the
/// `(name, data_type, source)` triple. `count` is the `sum_count` measure
/// decoded from its string representation.
pub type ScoreCountRow {
  ScoreCountRow(name: String, data_type: String, source: String, count: Int)
}

/// A server-side filter on a v2 metrics query. The Langfuse API uses a
/// tagged union — the `type` field discriminates the shape; this module
/// mirrors that with one Gleam variant per supported filter type.
pub type Filter {
  /// `any of` / `none of` matching against a column's string values.
  /// E.g., restricting `name` (scorer) to a specific set.
  StringOptions(
    column: String,
    operator: StringOptionsOperator,
    values: List(String),
  )
}

/// Set-membership operator for `StringOptions` filters.
pub type StringOptionsOperator {
  AnyOf
  NoneOf
}

/// Convenience: filter to scores whose `name` (scorer) is in the given
/// list. Saves bytes on the wire and downstream work — server-side filter
/// always preferred over client-side.
pub fn scorer_names(names: List(String)) -> Filter {
  StringOptions(column: "name", operator: AnyOf, values: names)
}

/// Filters for `list_score_counts`. Window is `[from_timestamp,
/// to_timestamp)` in ISO 8601. Build with `score_count_query`.
pub type ScoreCountQuery {
  ScoreCountQuery(
    view: ScoreView,
    from_timestamp: String,
    to_timestamp: String,
    filters: List(Filter),
  )
}

/// Build a query for counts of scores grouped by `(name, data_type,
/// source)` in the given window, with optional server-side filters.
pub fn score_count_query(
  view view: ScoreView,
  from from_timestamp: String,
  to to_timestamp: String,
  filters filters: List(Filter),
) -> ScoreCountQuery {
  ScoreCountQuery(view:, from_timestamp:, to_timestamp:, filters:)
}

@target(erlang)
/// Aggregate score counts for the query. Returns one row per distinct
/// `(name, data_type, source)` combination present in the window after
/// filters are applied. Erlang-only — see `langfuse_client/client` module
/// docs.
pub fn list_score_counts(
  c: Client,
  q: ScoreCountQuery,
) -> Result(List(ScoreCountRow), Error) {
  client.send_get(
    c,
    "/api/public/v2/metrics",
    [#("query", query_body(q))],
    rows_decoder(),
  )
}

/// Parse a `GET /api/public/v2/metrics` response body for a score-count
/// query. Useful if you already have the raw body in hand (e.g. from a
/// cached/recorded response).
pub fn decode(body: String) -> Result(List(ScoreCountRow), json.DecodeError) {
  json.parse(body, rows_decoder())
}

/// One row from a score-value query: the avg `value` of scores grouped by
/// `(name, data_type, source)`. The Langfuse API restricts the `value`
/// measure to numeric/boolean scores; categorical scores are not included.
pub type ScoreValueRow {
  ScoreValueRow(
    name: String,
    data_type: String,
    source: String,
    avg_value: Float,
  )
}

/// Filters for `list_score_values`. The view is implicitly numeric — the
/// API rejects `value` measure on categorical scores. Build with
/// `score_value_query`.
pub type ScoreValueQuery {
  ScoreValueQuery(
    from_timestamp: String,
    to_timestamp: String,
    filters: List(Filter),
  )
}

/// Build a query for avg score values grouped by `(name, data_type,
/// source)` in the given window, with optional server-side filters. Only
/// numeric and boolean scores are returned.
pub fn score_value_query(
  from from_timestamp: String,
  to to_timestamp: String,
  filters filters: List(Filter),
) -> ScoreValueQuery {
  ScoreValueQuery(from_timestamp:, to_timestamp:, filters:)
}

@target(erlang)
/// Aggregate avg score values for the query. One row per `(name,
/// data_type, source)` combination over the window after filters are
/// applied. Erlang-only — see `langfuse_client/client` module docs.
pub fn list_score_values(
  c: Client,
  q: ScoreValueQuery,
) -> Result(List(ScoreValueRow), Error) {
  client.send_get(
    c,
    "/api/public/v2/metrics",
    [#("query", value_query_body(q))],
    value_rows_decoder(),
  )
}

/// Parse a `GET /api/public/v2/metrics` response body for a score-value
/// query.
pub fn decode_score_values(
  body: String,
) -> Result(List(ScoreValueRow), json.DecodeError) {
  json.parse(body, value_rows_decoder())
}

// --- Internals --------------------------------------------------------------

fn query_body(q: ScoreCountQuery) -> String {
  json.object([
    #("view", json.string(view_string(q.view))),
    #("fromTimestamp", json.string(q.from_timestamp)),
    #("toTimestamp", json.string(q.to_timestamp)),
    #("dimensions", json.preprocessed_array(score_count_dimensions())),
    #("metrics", json.preprocessed_array(score_count_metrics())),
    #("filters", filters_to_json(q.filters)),
  ])
  |> json.to_string
}

fn score_count_dimensions() -> List(json.Json) {
  [
    json.object([#("field", json.string("name"))]),
    json.object([#("field", json.string("dataType"))]),
    json.object([#("field", json.string("source"))]),
  ]
}

fn score_count_metrics() -> List(json.Json) {
  [
    json.object([
      #("measure", json.string("count")),
      #("aggregation", json.string("sum")),
    ]),
  ]
}

fn view_string(v: ScoreView) -> String {
  case v {
    ScoresNumeric -> "scores-numeric"
    ScoresCategorical -> "scores-categorical"
  }
}

fn rows_decoder() -> decode.Decoder(List(ScoreCountRow)) {
  use rows <- decode.field("data", decode.list(row_decoder()))
  decode.success(rows)
}

fn row_decoder() -> decode.Decoder(ScoreCountRow) {
  use name <- decode.field("name", decode.string)
  use data_type <- decode.field("dataType", decode.string)
  use source <- decode.field("source", decode.string)
  // The v2 metrics API stringifies the `count` measure; parse back to Int.
  use sum_count_str <- decode.field("sum_count", decode.string)
  let count = result.unwrap(int.parse(sum_count_str), 0)
  decode.success(ScoreCountRow(name:, data_type:, source:, count:))
}

fn value_query_body(q: ScoreValueQuery) -> String {
  json.object([
    #("view", json.string("scores-numeric")),
    #("fromTimestamp", json.string(q.from_timestamp)),
    #("toTimestamp", json.string(q.to_timestamp)),
    #("dimensions", json.preprocessed_array(score_count_dimensions())),
    #("metrics", json.preprocessed_array(score_value_metrics())),
    #("filters", filters_to_json(q.filters)),
  ])
  |> json.to_string
}

fn score_value_metrics() -> List(json.Json) {
  [
    json.object([
      #("measure", json.string("value")),
      #("aggregation", json.string("avg")),
    ]),
  ]
}

fn value_rows_decoder() -> decode.Decoder(List(ScoreValueRow)) {
  use rows <- decode.field("data", decode.list(value_row_decoder()))
  decode.success(rows)
}

fn value_row_decoder() -> decode.Decoder(ScoreValueRow) {
  use name <- decode.field("name", decode.string)
  use data_type <- decode.field("dataType", decode.string)
  use source <- decode.field("source", decode.string)
  // Unlike `sum_count`, `avg_value` is a JSON number — but may be int
  // (e.g. avg of [1,1,1] = 1) or float. Accept either, like score.gleam.
  use avg_value <- decode.field("avg_value", lenient_float())
  decode.success(ScoreValueRow(name:, data_type:, source:, avg_value:))
}

fn lenient_float() -> decode.Decoder(Float) {
  decode.one_of(decode.float, [decode.int |> decode.map(int.to_float)])
}

fn filters_to_json(filters: List(Filter)) -> json.Json {
  json.preprocessed_array(list.map(filters, filter_to_json))
}

fn filter_to_json(f: Filter) -> json.Json {
  case f {
    StringOptions(column:, operator:, values:) ->
      json.object([
        #("type", json.string("stringOptions")),
        #("column", json.string(column)),
        #("operator", json.string(string_options_operator_string(operator))),
        #("value", json.array(values, of: json.string)),
      ])
  }
}

fn string_options_operator_string(op: StringOptionsOperator) -> String {
  case op {
    AnyOf -> "any of"
    NoneOf -> "none of"
  }
}
