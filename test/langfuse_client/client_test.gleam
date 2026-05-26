import langfuse_client/client

// ==== new ====
// * ✅ strips a trailing slash from base_url so callers can pass either form
pub fn new_strips_trailing_slash_test() {
  let c =
    client.new(
      base_url: "https://us.cloud.langfuse.com/",
      public_key: "pk",
      secret_key: "sk",
    )
  assert c.base_url == "https://us.cloud.langfuse.com"
}

// * ✅ leaves a base_url without a trailing slash untouched
pub fn new_preserves_base_url_without_slash_test() {
  let c =
    client.new(
      base_url: "https://us.cloud.langfuse.com",
      public_key: "pk",
      secret_key: "sk",
    )
  assert c.base_url == "https://us.cloud.langfuse.com"
}
