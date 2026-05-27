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
// * ✅ captures view + window + filters fields
pub fn score_count_query_builds_test() {
  let q =
    metrics.score_count_query(
      view: metrics.ScoresCategorical,
      from: "2026-01-01T00:00:00Z",
      to: "2026-01-02T00:00:00Z",
      filters: [],
    )
  assert q.view == metrics.ScoresCategorical
  assert q.from_timestamp == "2026-01-01T00:00:00Z"
  assert q.to_timestamp == "2026-01-02T00:00:00Z"
  assert q.filters == []
}

// * ✅ carries the scorer_names filter through
pub fn score_count_query_with_scorer_filter_test() {
  let q =
    metrics.score_count_query(
      view: metrics.ScoresNumeric,
      from: "2026-01-01T00:00:00Z",
      to: "2026-01-02T00:00:00Z",
      filters: [metrics.scorer_names(["helpfulness", "safe"])],
    )
  let assert [filter] = q.filters
  let metrics.StringOptions(column:, operator:, values:) = filter
  assert column == "name"
  assert operator == metrics.AnyOf
  assert values == ["helpfulness", "safe"]
}

const value_sample = "{
  \"data\": [
    {\"name\": \"hallucination\", \"dataType\": \"NUMERIC\", \"source\": \"API\", \"avg_value\": 0.405},
    {\"name\": \"safe\", \"dataType\": \"BOOLEAN\", \"source\": \"API\", \"avg_value\": 1}
  ]
}"

// ==== decode_score_values ====
// * ✅ decodes the data envelope into ScoreValueRow values
// * ✅ accepts an integer-valued avg_value as a Float
pub fn decode_score_values_test() {
  let assert Ok(rows) = metrics.decode_score_values(value_sample)
  let assert [first, second] = rows
  assert first.name == "hallucination"
  assert first.avg_value == 0.405
  assert second.name == "safe"
  assert second.data_type == "BOOLEAN"
  assert second.avg_value == 1.0
}

// ==== score_value_query ====
// * ✅ captures the window + filters without requiring a view (numeric-only)
pub fn score_value_query_builds_test() {
  let q =
    metrics.score_value_query(
      from: "2026-01-01T00:00:00Z",
      to: "2026-01-02T00:00:00Z",
      filters: [],
    )
  assert q.from_timestamp == "2026-01-01T00:00:00Z"
  assert q.to_timestamp == "2026-01-02T00:00:00Z"
  assert q.filters == []
}
