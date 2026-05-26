//// HTTP client for a Langfuse project. Holds the base URL and API key pair
//// used to authenticate against `/api/public/*` endpoints. Domain-specific
//// modules (e.g. `langfuse/score`) drive the actual requests via `send_get`.

import gleam/bit_array
import gleam/bool
import gleam/dynamic/decode
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/httpc
import gleam/json
import gleam/result
import gleam/string
import gleam/uri

/// Credentials and host for a Langfuse project.
pub type Client {
  Client(base_url: String, public_key: String, secret_key: String)
}

/// Failure modes returned by `send_get` and its callers.
pub type Error {
  /// Transport-level failure (DNS, TCP, TLS, etc.).
  HttpError(httpc.HttpError)
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

/// Issue an authenticated GET against `path` with the given query string
/// pairs and decode the response. Used by sibling endpoint modules; not part
/// of the stable public API.
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

fn auth_header(client: Client) -> String {
  let creds = client.public_key <> ":" <> client.secret_key
  "Basic " <> bit_array.base64_encode(bit_array.from_string(creds), True)
}

fn send_raw(req: Request(String)) -> Result(Response(String), Error) {
  httpc.send(req) |> result.map_error(HttpError)
}

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
