# langfuse

[![Package Version](https://img.shields.io/hexpm/v/langfuse)](https://hex.pm/packages/langfuse)
[![Test](https://github.com/Brickell-Research/langfuse-client/actions/workflows/test.yml/badge.svg)](https://github.com/Brickell-Research/langfuse-client/actions/workflows/test.yml)

Minimal [Langfuse](https://langfuse.com) HTTP client for Gleam — in the same
spirit as [`datadog_client`](https://hex.pm/packages/datadog_client).

```sh
gleam add langfuse
```

```gleam
import langfuse/client
import langfuse/score

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

Further documentation at <https://hexdocs.pm/langfuse>.
