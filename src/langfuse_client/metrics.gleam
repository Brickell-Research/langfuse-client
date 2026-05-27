//// `GET /api/public/v2/metrics` — server-side aggregations over Langfuse
//// score data. Build a query with `score_count_query` and pass it to
//// `list_score_counts(client, query)`.
////
//// The Langfuse v2 metrics endpoint is BETA. This module exposes only
//// score-count queries grouped by `(name, dataType, source)`; broader
//// surface (other measures, views, dimensions) will follow the same
//// shape once the endpoint stabilises.

import gleam/dynamic/decode
import gleam/int
import gleam/json
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

/// Filters for `list_score_counts`. Build with `score_count_query` and
/// pass to `list_score_counts`. Window is `[from_timestamp, to_timestamp)`
/// in ISO 8601.
pub type ScoreCountQuery {
  ScoreCountQuery(view: ScoreView, from_timestamp: String, to_timestamp: String)
}

/// Build a query for counts of scores grouped by `(name, data_type,
/// source)` in the given window.
pub fn score_count_query(
  view view: ScoreView,
  from from_timestamp: String,
  to to_timestamp: String,
) -> ScoreCountQuery {
  ScoreCountQuery(view:, from_timestamp:, to_timestamp:)
}

@target(erlang)
/// Aggregate score counts for the query. Returns one row per distinct
/// `(name, data_type, source)` combination present in the window.
/// Erlang-only — see `langfuse_client/client` module docs.
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

// --- Internals --------------------------------------------------------------

fn query_body(q: ScoreCountQuery) -> String {
  json.object([
    #("view", json.string(view_string(q.view))),
    #("fromTimestamp", json.string(q.from_timestamp)),
    #("toTimestamp", json.string(q.to_timestamp)),
    #("dimensions", json.preprocessed_array(score_count_dimensions())),
    #("metrics", json.preprocessed_array(score_count_metrics())),
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
  // The v2 metrics API stringifies numeric measures; parse back to Int.
  use sum_count_str <- decode.field("sum_count", decode.string)
  let count = result.unwrap(int.parse(sum_count_str), 0)
  decode.success(ScoreCountRow(name:, data_type:, source:, count:))
}
