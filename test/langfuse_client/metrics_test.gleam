import langfuse_client/metrics

const numeric_sample = "{
  \"data\": [
    {\"name\": \"hallucination\", \"dataType\": \"NUMERIC\", \"source\": \"API\", \"sum_count\": \"4\"},
    {\"name\": \"safe\", \"dataType\": \"BOOLEAN\", \"source\": \"API\", \"sum_count\": \"3\"}
  ]
}"

const empty_sample = "{ \"data\": [] }"

// ==== decode ====
// * ✅ decodes the data envelope into ScoreCountRow values
// * ✅ parses the stringified sum_count back to an Int
// * ✅ accepts BOOLEAN rows under the scores-numeric view
pub fn decode_numeric_sample_test() {
  let assert Ok(rows) = metrics.decode(numeric_sample)
  let assert [first, second] = rows
  assert first.name == "hallucination"
  assert first.data_type == "NUMERIC"
  assert first.source == "API"
  assert first.count == 4
  assert second.name == "safe"
  assert second.data_type == "BOOLEAN"
  assert second.count == 3
}

// * ✅ decodes an empty data array as an empty list
pub fn decode_empty_sample_test() {
  let assert Ok(rows) = metrics.decode(empty_sample)
  assert rows == []
}

// ==== score_count_query ====
// * ✅ captures view + window fields
pub fn score_count_query_builds_test() {
  let q =
    metrics.score_count_query(
      view: metrics.ScoresCategorical,
      from: "2026-01-01T00:00:00Z",
      to: "2026-01-02T00:00:00Z",
    )
  assert q.view == metrics.ScoresCategorical
  assert q.from_timestamp == "2026-01-01T00:00:00Z"
  assert q.to_timestamp == "2026-01-02T00:00:00Z"
}
