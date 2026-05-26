//// Umbrella module that re-exports the public API. The implementation lives
//// in `langfuse_client/client` and `langfuse_client/score`; importing those directly is
//// equivalent.
////
////   let c = langfuse_client.new(
////     base_url: "https://us.cloud.langfuse.com",
////     public_key: "pk-lf-...",
////     secret_key: "sk-lf-...",
////   )
////
////   langfuse_client.list_scores(c, langfuse_client.score_query() |> langfuse_client.with_limit(10))

import gleam/json
import langfuse_client/client
import langfuse_client/score

// --- Re-exported types ------------------------------------------------------

/// Alias for [`client.Client`](./langfuse_client/client.html#Client).
pub type Client =
  client.Client

/// Alias for [`client.Error`](./langfuse_client/client.html#Error).
pub type Error =
  client.Error

/// Alias for [`score.Score`](./langfuse_client/score.html#Score).
pub type Score =
  score.Score

/// Alias for [`score.Page`](./langfuse_client/score.html#Page).
pub type Page =
  score.Page

/// Alias for [`score.Scores`](./langfuse_client/score.html#Scores).
pub type Scores =
  score.Scores

/// Alias for [`score.Query`](./langfuse_client/score.html#Query).
pub type ScoreQuery =
  score.Query

// --- Client -----------------------------------------------------------------

/// See [`client.new`](./langfuse_client/client.html#new).
pub fn new(
  base_url base_url: String,
  public_key public_key: String,
  secret_key secret_key: String,
) -> Client {
  client.new(base_url:, public_key:, secret_key:)
}

// --- Scores -----------------------------------------------------------------

@target(erlang)
/// See [`score.list`](./langfuse_client/score.html#list). Erlang-only.
pub fn list_scores(c: Client, q: ScoreQuery) -> Result(Scores, Error) {
  score.list(c, q)
}

/// See [`score.decode`](./langfuse_client/score.html#decode).
pub fn decode_scores(body: String) -> Result(Scores, json.DecodeError) {
  score.decode(body)
}

/// See [`score.query`](./langfuse_client/score.html#query).
pub fn score_query() -> ScoreQuery {
  score.query()
}

/// See [`score.with_page`](./langfuse_client/score.html#with_page).
pub fn with_page(q: ScoreQuery, page: Int) -> ScoreQuery {
  score.with_page(q, page)
}

/// See [`score.with_limit`](./langfuse_client/score.html#with_limit).
pub fn with_limit(q: ScoreQuery, limit: Int) -> ScoreQuery {
  score.with_limit(q, limit)
}

/// See [`score.with_name`](./langfuse_client/score.html#with_name).
pub fn with_name(q: ScoreQuery, name: String) -> ScoreQuery {
  score.with_name(q, name)
}

/// See [`score.with_trace_id`](./langfuse_client/score.html#with_trace_id).
pub fn with_trace_id(q: ScoreQuery, trace_id: String) -> ScoreQuery {
  score.with_trace_id(q, trace_id)
}

/// See [`score.with_session_id`](./langfuse_client/score.html#with_session_id).
pub fn with_session_id(q: ScoreQuery, session_id: String) -> ScoreQuery {
  score.with_session_id(q, session_id)
}

/// See [`score.with_dataset_run_id`](./langfuse_client/score.html#with_dataset_run_id).
pub fn with_dataset_run_id(
  q: ScoreQuery,
  dataset_run_id: String,
) -> ScoreQuery {
  score.with_dataset_run_id(q, dataset_run_id)
}

/// See [`score.with_user_id`](./langfuse_client/score.html#with_user_id).
pub fn with_user_id(q: ScoreQuery, user_id: String) -> ScoreQuery {
  score.with_user_id(q, user_id)
}

/// See [`score.with_data_type`](./langfuse_client/score.html#with_data_type).
pub fn with_data_type(q: ScoreQuery, data_type: String) -> ScoreQuery {
  score.with_data_type(q, data_type)
}

/// See [`score.with_from_timestamp`](./langfuse_client/score.html#with_from_timestamp).
pub fn with_from_timestamp(q: ScoreQuery, from: String) -> ScoreQuery {
  score.with_from_timestamp(q, from)
}

/// See [`score.with_to_timestamp`](./langfuse_client/score.html#with_to_timestamp).
pub fn with_to_timestamp(q: ScoreQuery, to: String) -> ScoreQuery {
  score.with_to_timestamp(q, to)
}
