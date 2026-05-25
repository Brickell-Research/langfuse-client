# langfuse

Minimal [Langfuse](https://langfuse.com) HTTP client for Gleam. Today it
covers a single endpoint — `GET /api/public/v2/scores` — enough to pull eval
scores out of a Langfuse project and inspect them from Gleam.

```sh
gleam add langfuse
```

```gleam
import gleam/io
import gleam/list
import langfuse

pub fn main() {
  let client =
    langfuse.new(
      base_url: "https://us.cloud.langfuse.com",
      public_key: "pk-lf-...",
      secret_key: "sk-lf-...",
    )

  let query =
    langfuse.score_query()
    |> langfuse.with_limit(20)
    |> langfuse.with_name("hallucination")

  let assert Ok(scores) = langfuse.list_scores(client, query)
  list.each(scores.data, fn(score) {
    io.println(score.name <> " = " <> score.data_type)
  })
}
```

## What's here

- `langfuse.new/3` — build a client with base URL + public/secret API keys.
- `langfuse.list_scores/2` — paginated fetch of `GET /api/public/v2/scores`.
- `ScoreQuery` builders: `with_limit`, `with_page`, `with_name`, `with_trace_id`,
  `with_session_id`, `with_dataset_run_id`, `with_user_id`, `with_data_type`,
  `with_from_timestamp`, `with_to_timestamp`.
- `langfuse.decode_scores/1` — decode a raw response body (handy for tests).

Self-hosted? Pass your own base URL (e.g. `https://langfuse.mycorp.com`).

## Development

```sh
gleam test
```
