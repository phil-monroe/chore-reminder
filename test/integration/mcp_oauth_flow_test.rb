require "test_helper"

# Drives the whole MCP OAuth loop end to end - dynamic client registration,
# the login-gated user-picker authorize step, the PKCE code exchange, and a
# real tools/call against the resulting access token - to prove the pieces
# (each already unit/controller-tested individually) actually fit together,
# the way Claude's remote MCP connector would drive them for real.
class McpOauthFlowTest < ActionDispatch::IntegrationTest
  test "register -> authorize (as a chosen user) -> token -> tools/call" do
    delete logout_path

    post oauth_register_path, params: {redirect_uris: ["https://claude.example.com/callback"], client_name: "Claude"}.to_json,
      headers: {"Content-Type" => "application/json"}
    client_id = JSON.parse(response.body)["client_id"]

    code_verifier = "integration-test-code-verifier-1234567890abcdef"
    code_challenge = Digest::SHA256.base64digest(code_verifier).tr("+/", "-_").delete("=")
    authorize_params = {
      client_id: client_id, redirect_uri: "https://claude.example.com/callback", response_type: "code",
      code_challenge: code_challenge, code_challenge_method: "S256", state: "abc"
    }

    get oauth_authorize_path, params: authorize_params
    assert_redirected_to login_path

    post login_path, params: {password: ENV.fetch("ADMIN_PASSWORD")}
    redirect_path, redirect_query = response.headers["Location"].split("?", 2)
    assert_equal oauth_authorize_url, redirect_path
    assert_equal authorize_params.stringify_keys, Rack::Utils.parse_nested_query(redirect_query)

    get oauth_authorize_path, params: authorize_params
    assert_response :success

    chosen_user = users(:two)
    post oauth_authorize_path, params: authorize_params.merge(user_id: chosen_user.id)
    callback_uri = URI.parse(response.headers["Location"])
    code = URI.decode_www_form(callback_uri.query).to_h["code"]

    post oauth_token_path, params: {
      grant_type: "authorization_code", code: code, client_id: client_id,
      redirect_uri: "https://claude.example.com/callback", code_verifier: code_verifier
    }
    access_token = JSON.parse(response.body)["access_token"]
    assert access_token.present?

    post "/mcp", params: {jsonrpc: "2.0", id: 1, method: "tools/call", params: {name: "list_tasks", arguments: {}}}.to_json,
      headers: {"Content-Type" => "application/json", "Authorization" => "Bearer #{access_token}"}

    result = JSON.parse(response.body)["result"]
    task_names = JSON.parse(result["content"].first["text"]).pluck("name")
    assert_equal chosen_user.tasks.pending.pluck(:name), task_names
  end
end
