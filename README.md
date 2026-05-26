# langfuse_client

[![Package Version](https://img.shields.io/hexpm/v/langfuse_client)](https://hex.pm/packages/langfuse_client)
[![Test](https://github.com/Brickell-Research/langfuse-client/actions/workflows/test.yml/badge.svg)](https://github.com/Brickell-Research/langfuse-client/actions/workflows/test.yml)

A minimal HTTP client for Langfuse. Intentionally dual target-able (JS & Erlang) ✅

```sh
gleam add langfuse_client
```

```gleam
import langfuse_client/client
import langfuse_client/score

pub fn main() {
  let c =
    client.new(
      base_url: "https://us.cloud.langfuse.com",
      public_key: "pk-lf-...",
      secret_key: "sk-lf-...",
    )

  let q = score.query() |> score.with_limit(20)
  let assert Ok(scores) = score.list(c, q)
}
```

Further documentation at <https://hexdocs.pm/langfuse_client>.
