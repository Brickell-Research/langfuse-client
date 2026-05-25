import gleam/option.{None, Some}
import gleeunit
import langfuse

pub fn main() -> Nil {
  gleeunit.main()
}

const sample = "{
  \"data\": [
    {
      \"id\": \"score-1\",
      \"traceId\": \"trace-1\",
      \"name\": \"accuracy\",
      \"source\": \"API\",
      \"dataType\": \"NUMERIC\",
      \"value\": 0.92,
      \"comment\": \"looks good\",
      \"timestamp\": \"2026-01-15T12:00:00.000Z\",
      \"createdAt\": \"2026-01-15T12:00:00.000Z\",
      \"updatedAt\": \"2026-01-15T12:00:00.000Z\",
      \"environment\": \"production\",
      \"metadata\": null
    },
    {
      \"id\": \"score-2\",
      \"traceId\": \"trace-2\",
      \"name\": \"hallucination\",
      \"source\": \"EVAL\",
      \"dataType\": \"CATEGORICAL\",
      \"value\": 1,
      \"stringValue\": \"none\",
      \"timestamp\": \"2026-01-16T09:00:00.000Z\",
      \"createdAt\": \"2026-01-16T09:00:00.000Z\",
      \"updatedAt\": \"2026-01-16T09:00:00.000Z\",
      \"environment\": \"production\",
      \"metadata\": null
    }
  ],
  \"meta\": { \"page\": 1, \"limit\": 50, \"totalItems\": 2, \"totalPages\": 1 }
}"

pub fn decode_scores_test() {
  let assert Ok(scores) = langfuse.decode_scores(sample)
  assert scores.meta.total_items == 2
  let assert [first, second] = scores.data
  assert first.id == "score-1"
  assert first.name == "accuracy"
  assert first.data_type == "NUMERIC"
  assert first.value == Some(0.92)
  assert first.comment == Some("looks good")
  assert second.string_value == Some("none")
  assert second.observation_id == None
}

pub fn new_strips_trailing_slash_test() {
  let client =
    langfuse.new(
      base_url: "https://us.cloud.langfuse.com/",
      public_key: "pk",
      secret_key: "sk",
    )
  assert client.base_url == "https://us.cloud.langfuse.com"
}
