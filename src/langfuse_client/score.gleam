//// `GET /api/public/v2/scores` — paginated fetch of eval scores from a
//// Langfuse project. Build a `Query` with `query()` and the `with_*` helpers,
//// then pass it to `list(client, query)`.

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option.{type Option}

@target(erlang)
import gleam/list
@target(erlang)
import langfuse_client/client.{type Client, type Error}

/// A score as returned by `GET /api/public/v2/scores`. Only the fields common
/// across data types are decoded; inspect `data_type` to decide whether to
/// read `value` (numeric/boolean/categorical/correction) or `string_value`
/// (boolean/categorical/correction/text).
pub type Score {
  Score(
    id: String,
    trace_id: Option(String),
    session_id: Option(String),
    observation_id: Option(String),
    name: String,
    data_type: String,
    source: String,
    value: Option(Float),
    string_value: Option(String),
    comment: Option(String),
    timestamp: String,
    environment: Option(String),
  )
}

/// Pagination metadata returned alongside `data`.
pub type Page {
  Page(page: Int, limit: Int, total_items: Int, total_pages: Int)
}

/// A page of scores plus its pagination metadata.
pub type Scores {
  Scores(data: List(Score), meta: Page)
}

/// Filters for `list`. Build with `query()` and the `with_*` helpers. All
/// fields default to `None`, which means "no filter" and lets Langfuse apply
/// its server-side defaults.
pub type Query {
  Query(
    page: Option(Int),
    limit: Option(Int),
    user_id: Option(String),
    name: Option(String),
    from_timestamp: Option(String),
    to_timestamp: Option(String),
    source: Option(String),
    trace_id: Option(String),
    session_id: Option(String),
    dataset_run_id: Option(String),
    data_type: Option(String),
  )
}

/// Empty query — pass to `list` to retrieve the first page with the server
/// defaults (page 1, limit 50).
pub fn query() -> Query {
  Query(
    page: option.None,
    limit: option.None,
    user_id: option.None,
    name: option.None,
    from_timestamp: option.None,
    to_timestamp: option.None,
    source: option.None,
    trace_id: option.None,
    session_id: option.None,
    dataset_run_id: option.None,
    data_type: option.None,
  )
}

/// Set the page number (1-indexed).
pub fn with_page(q: Query, page: Int) -> Query {
  Query(..q, page: option.Some(page))
}

/// Set the page size (Langfuse defaults to 50).
pub fn with_limit(q: Query, limit: Int) -> Query {
  Query(..q, limit: option.Some(limit))
}

/// Filter to scores with this exact name.
pub fn with_name(q: Query, name: String) -> Query {
  Query(..q, name: option.Some(name))
}

/// Filter to scores attached to this trace.
pub fn with_trace_id(q: Query, trace_id: String) -> Query {
  Query(..q, trace_id: option.Some(trace_id))
}

/// Filter to scores attached to this session.
pub fn with_session_id(q: Query, session_id: String) -> Query {
  Query(..q, session_id: option.Some(session_id))
}

/// Filter to scores tied to this dataset run.
pub fn with_dataset_run_id(q: Query, dataset_run_id: String) -> Query {
  Query(..q, dataset_run_id: option.Some(dataset_run_id))
}

/// Filter to scores whose trace has this user id.
pub fn with_user_id(q: Query, user_id: String) -> Query {
  Query(..q, user_id: option.Some(user_id))
}

/// Filter to scores of a given data type (`NUMERIC`, `BOOLEAN`, `CATEGORICAL`).
pub fn with_data_type(q: Query, data_type: String) -> Query {
  Query(..q, data_type: option.Some(data_type))
}

/// Lower bound on `timestamp` (ISO 8601, inclusive).
pub fn with_from_timestamp(q: Query, from: String) -> Query {
  Query(..q, from_timestamp: option.Some(from))
}

/// Upper bound on `timestamp` (ISO 8601, exclusive).
pub fn with_to_timestamp(q: Query, to: String) -> Query {
  Query(..q, to_timestamp: option.Some(to))
}

@target(erlang)
/// Fetch one page of scores from `GET /api/public/v2/scores`. Erlang-only —
/// the JavaScript target lacks an HTTP transport in this library.
pub fn list(c: Client, q: Query) -> Result(Scores, Error) {
  client.send_get(c, "/api/public/v2/scores", query_pairs(q), scores_decoder())
}

/// Parse a `GET /api/public/v2/scores` response body. Useful if you already
/// have the raw body in hand (e.g. from a cached/recorded response).
pub fn decode(body: String) -> Result(Scores, json.DecodeError) {
  json.parse(body, scores_decoder())
}

@target(erlang)
fn query_pairs(q: Query) -> List(#(String, String)) {
  [
    #("page", option.map(q.page, int.to_string)),
    #("limit", option.map(q.limit, int.to_string)),
    #("userId", q.user_id),
    #("name", q.name),
    #("fromTimestamp", q.from_timestamp),
    #("toTimestamp", q.to_timestamp),
    #("source", q.source),
    #("traceId", q.trace_id),
    #("sessionId", q.session_id),
    #("datasetRunId", q.dataset_run_id),
    #("dataType", q.data_type),
  ]
  |> list.filter_map(fn(pair) {
    let #(k, v) = pair
    case v {
      option.Some(value) -> Ok(#(k, value))
      option.None -> Error(Nil)
    }
  })
}

fn scores_decoder() -> decode.Decoder(Scores) {
  use data <- decode.field("data", decode.list(score_decoder()))
  use meta <- decode.field("meta", meta_decoder())
  decode.success(Scores(data: data, meta: meta))
}

// JSON numbers like `1` decode as Int while `1.0` decodes as Float; accept
// either so callers don't have to special-case integer-valued scores.
fn lenient_float() -> decode.Decoder(Float) {
  decode.one_of(decode.float, [decode.int |> decode.map(int.to_float)])
}

fn meta_decoder() -> decode.Decoder(Page) {
  use page <- decode.field("page", decode.int)
  use limit <- decode.field("limit", decode.int)
  use total_items <- decode.field("totalItems", decode.int)
  use total_pages <- decode.field("totalPages", decode.int)
  decode.success(Page(page:, limit:, total_items:, total_pages:))
}

fn score_decoder() -> decode.Decoder(Score) {
  use id <- decode.field("id", decode.string)
  use trace_id <- decode.optional_field(
    "traceId",
    option.None,
    decode.optional(decode.string),
  )
  use session_id <- decode.optional_field(
    "sessionId",
    option.None,
    decode.optional(decode.string),
  )
  use observation_id <- decode.optional_field(
    "observationId",
    option.None,
    decode.optional(decode.string),
  )
  use name <- decode.field("name", decode.string)
  use data_type <- decode.field("dataType", decode.string)
  use source <- decode.field("source", decode.string)
  use value <- decode.optional_field(
    "value",
    option.None,
    decode.optional(lenient_float()),
  )
  use string_value <- decode.optional_field(
    "stringValue",
    option.None,
    decode.optional(decode.string),
  )
  use comment <- decode.optional_field(
    "comment",
    option.None,
    decode.optional(decode.string),
  )
  use timestamp <- decode.field("timestamp", decode.string)
  use environment <- decode.optional_field(
    "environment",
    option.None,
    decode.optional(decode.string),
  )
  decode.success(Score(
    id:,
    trace_id:,
    session_id:,
    observation_id:,
    name:,
    data_type:,
    source:,
    value:,
    string_value:,
    comment:,
    timestamp:,
    environment:,
  ))
}
