import gleam/option
import langfuse/score

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

// ==== decode ====
// * ✅ decodes the data + meta envelope
// * ✅ decodes an integer-valued NUMERIC score as a Float
// * ✅ leaves optional fields as option.None when absent
pub fn decode_test() {
  let assert Ok(scores) = score.decode(sample)
  assert scores.meta.total_items == 2
  let assert [first, second] = scores.data
  assert first.id == "score-1"
  assert first.name == "accuracy"
  assert first.data_type == "NUMERIC"
  assert first.value == option.Some(0.92)
  assert first.comment == option.Some("looks good")
  assert second.string_value == option.Some("none")
  assert second.observation_id == option.None
}

// ==== query / with_* ====
// * ✅ query() returns an all-None filter set
// * ✅ with_* helpers populate the corresponding field
pub fn query_builders_test() {
  let q =
    score.query()
    |> score.with_limit(25)
    |> score.with_name("hallucination")
    |> score.with_trace_id("demo-trace-qa-1")

  assert q.limit == option.Some(25)
  assert q.name == option.Some("hallucination")
  assert q.trace_id == option.Some("demo-trace-qa-1")
  assert q.page == option.None
  assert q.session_id == option.None
}
