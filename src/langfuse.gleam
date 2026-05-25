//// Minimal Langfuse HTTP client.
////
////   let client = langfuse.new(
////     base_url: "https://us.cloud.langfuse.com",
////     public_key: "pk-lf-...",
////     secret_key: "sk-lf-...",
////   )
////
////   langfuse.list_scores(client, langfuse.score_query() |> langfuse.with_limit(10))

import gleam/bit_array
import gleam/dynamic/decode
import gleam/http.{Get}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/httpc
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri

pub type Client {
  Client(base_url: String, public_key: String, secret_key: String)
}

pub fn new(
  base_url base_url: String,
  public_key public_key: String,
  secret_key secret_key: String,
) -> Client {
  // Strip trailing slash so callers can pass either form.
  let trimmed = case string.ends_with(base_url, "/") {
    True -> string.drop_end(base_url, 1)
    False -> base_url
  }
  Client(base_url: trimmed, public_key: public_key, secret_key: secret_key)
}

pub type Error {
  HttpError(httpc.HttpError)
  BadStatus(status: Int, body: String)
  BadUrl(String)
  DecodeError(json.DecodeError)
}

// ---------------------------------------------------------------------------
// Scores
// ---------------------------------------------------------------------------

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

pub type Page {
  Page(page: Int, limit: Int, total_items: Int, total_pages: Int)
}

pub type Scores {
  Scores(data: List(Score), meta: Page)
}

pub type ScoreQuery {
  ScoreQuery(
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

/// Empty query — pass to `list_scores` to retrieve the first page with the
/// server defaults (page 1, limit 50).
pub fn score_query() -> ScoreQuery {
  ScoreQuery(
    page: None,
    limit: None,
    user_id: None,
    name: None,
    from_timestamp: None,
    to_timestamp: None,
    source: None,
    trace_id: None,
    session_id: None,
    dataset_run_id: None,
    data_type: None,
  )
}

pub fn with_page(q: ScoreQuery, page: Int) -> ScoreQuery {
  ScoreQuery(..q, page: Some(page))
}

pub fn with_limit(q: ScoreQuery, limit: Int) -> ScoreQuery {
  ScoreQuery(..q, limit: Some(limit))
}

pub fn with_name(q: ScoreQuery, name: String) -> ScoreQuery {
  ScoreQuery(..q, name: Some(name))
}

pub fn with_trace_id(q: ScoreQuery, trace_id: String) -> ScoreQuery {
  ScoreQuery(..q, trace_id: Some(trace_id))
}

pub fn with_session_id(q: ScoreQuery, session_id: String) -> ScoreQuery {
  ScoreQuery(..q, session_id: Some(session_id))
}

pub fn with_dataset_run_id(q: ScoreQuery, dataset_run_id: String) -> ScoreQuery {
  ScoreQuery(..q, dataset_run_id: Some(dataset_run_id))
}

pub fn with_user_id(q: ScoreQuery, user_id: String) -> ScoreQuery {
  ScoreQuery(..q, user_id: Some(user_id))
}

pub fn with_data_type(q: ScoreQuery, data_type: String) -> ScoreQuery {
  ScoreQuery(..q, data_type: Some(data_type))
}

pub fn with_from_timestamp(q: ScoreQuery, from: String) -> ScoreQuery {
  ScoreQuery(..q, from_timestamp: Some(from))
}

pub fn with_to_timestamp(q: ScoreQuery, to: String) -> ScoreQuery {
  ScoreQuery(..q, to_timestamp: Some(to))
}

pub fn list_scores(client: Client, query: ScoreQuery) -> Result(Scores, Error) {
  use req <- result.try(build_request(client, "/api/public/v2/scores"))
  let req = request.set_query(req, score_query_pairs(query))
  use resp <- result.try(send(req))
  decode_body(resp, scores_decoder())
}

/// Parse a `GET /api/public/v2/scores` response body. Useful if you already
/// have the raw body in hand (e.g. from a cached/recorded response).
pub fn decode_scores(body: String) -> Result(Scores, json.DecodeError) {
  json.parse(body, scores_decoder())
}

fn score_query_pairs(q: ScoreQuery) -> List(#(String, String)) {
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
      Some(value) -> Ok(#(k, value))
      None -> Error(Nil)
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
    None,
    decode.optional(decode.string),
  )
  use session_id <- decode.optional_field(
    "sessionId",
    None,
    decode.optional(decode.string),
  )
  use observation_id <- decode.optional_field(
    "observationId",
    None,
    decode.optional(decode.string),
  )
  use name <- decode.field("name", decode.string)
  use data_type <- decode.field("dataType", decode.string)
  use source <- decode.field("source", decode.string)
  use value <- decode.optional_field(
    "value",
    None,
    decode.optional(lenient_float()),
  )
  use string_value <- decode.optional_field(
    "stringValue",
    None,
    decode.optional(decode.string),
  )
  use comment <- decode.optional_field(
    "comment",
    None,
    decode.optional(decode.string),
  )
  use timestamp <- decode.field("timestamp", decode.string)
  use environment <- decode.optional_field(
    "environment",
    None,
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

// ---------------------------------------------------------------------------
// Internals
// ---------------------------------------------------------------------------

fn build_request(
  client: Client,
  path: String,
) -> Result(Request(String), Error) {
  case uri.parse(client.base_url <> path) {
    Ok(parsed) ->
      case request.from_uri(parsed) {
        Ok(req) ->
          req
          |> request.set_method(Get)
          |> request.prepend_header("authorization", auth_header(client))
          |> request.prepend_header("accept", "application/json")
          |> Ok
        Error(Nil) -> Error(BadUrl(client.base_url <> path))
      }
    Error(Nil) -> Error(BadUrl(client.base_url <> path))
  }
}

fn auth_header(client: Client) -> String {
  let creds = client.public_key <> ":" <> client.secret_key
  "Basic " <> bit_array.base64_encode(bit_array.from_string(creds), True)
}

fn send(req: Request(String)) -> Result(Response(String), Error) {
  case httpc.send(req) {
    Ok(resp) -> Ok(resp)
    Error(e) -> Error(HttpError(e))
  }
}

fn decode_body(
  resp: Response(String),
  decoder: decode.Decoder(a),
) -> Result(a, Error) {
  case resp.status >= 200 && resp.status < 300 {
    True ->
      json.parse(resp.body, decoder)
      |> result.map_error(DecodeError)
    False -> Error(BadStatus(resp.status, resp.body))
  }
}
