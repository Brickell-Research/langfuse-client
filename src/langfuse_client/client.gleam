//// HTTP client for a Langfuse project. Holds the base URL and API key pair
//// used to authenticate against `/api/public/*` endpoints. Domain-specific
//// modules (e.g. `langfuse_client/score`) drive the actual requests via `send_get`.
////
//// The pure pieces (types, `new`) compile on both the Erlang and JavaScript
//// targets; the HTTP-issuing pieces are Erlang-only because they depend on
//// `gleam_httpc`.

import gleam/bool
import gleam/json
import gleam/string

@target(erlang)
import gleam/bit_array
@target(erlang)
import gleam/dynamic/decode
@target(erlang)
import gleam/http
@target(erlang)
import gleam/http/request.{type Request}
@target(erlang)
import gleam/http/response.{type Response}
@target(erlang)
import gleam/httpc
@target(erlang)
import gleam/result
@target(erlang)
import gleam/uri

/// Credentials and host for a Langfuse project.
pub type Client {
  Client(base_url: String, public_key: String, secret_key: String)
}

/// Failure modes returned by `send_get` and its callers.
pub type Error {
  /// Transport-level failure (DNS, TCP, TLS, etc.) — body is the underlying
  /// error inspected as a string so the type stays target-agnostic.
  HttpError(String)
  /// Langfuse returned a non-2xx status.
  BadStatus(status: Int, body: String)
  /// Could not assemble a valid request URL from `base_url <> path`.
  BadUrl(String)
  /// Response body did not match the expected JSON shape.
  DecodeError(json.DecodeError)
}

/// Build a client. Trailing slashes on `base_url` are stripped so callers
/// can pass either form.
pub fn new(
  base_url base_url: String,
  public_key public_key: String,
  secret_key secret_key: String,
) -> Client {
  use <- bool.guard(!string.ends_with(base_url, "/"), {
    Client(base_url: base_url, public_key: public_key, secret_key: secret_key)
  })
  Client(
    base_url: string.drop_end(base_url, 1),
    public_key: public_key,
    secret_key: secret_key,
  )
}

@target(erlang)
/// Issue an authenticated GET against `path` with the given query string
/// pairs and decode the response. Used by sibling endpoint modules; not part
/// of the stable public API. Erlang-only — see module docs.
@internal
pub fn send_get(
  client: Client,
  path: String,
  query: List(#(String, String)),
  decoder: decode.Decoder(a),
) -> Result(a, Error) {
  use req <- result.try(build_request(client, path))
  let req = request.set_query(req, query)
  use resp <- result.try(send_raw(req))
  decode_body(resp, decoder)
}

// --- Internals --------------------------------------------------------------

@target(erlang)
fn build_request(
  client: Client,
  path: String,
) -> Result(Request(String), Error) {
  let url = client.base_url <> path
  use parsed <- result.try(uri.parse(url) |> result.replace_error(BadUrl(url)))
  use req <- result.try(
    request.from_uri(parsed) |> result.replace_error(BadUrl(url)),
  )
  req
  |> request.set_method(http.Get)
  |> request.prepend_header("authorization", auth_header(client))
  |> request.prepend_header("accept", "application/json")
  |> Ok
}

@target(erlang)
fn auth_header(client: Client) -> String {
  let creds = client.public_key <> ":" <> client.secret_key
  "Basic " <> bit_array.base64_encode(bit_array.from_string(creds), True)
}

@target(erlang)
fn send_raw(req: Request(String)) -> Result(Response(String), Error) {
  httpc.send(req)
  |> result.map_error(fn(e) { HttpError(string.inspect(e)) })
}

@target(erlang)
fn decode_body(
  resp: Response(String),
  decoder: decode.Decoder(a),
) -> Result(a, Error) {
  use <- bool.guard(
    resp.status < 200 || resp.status >= 300,
    Error(BadStatus(resp.status, resp.body)),
  )
  json.parse(resp.body, decoder) |> result.map_error(DecodeError)
}
