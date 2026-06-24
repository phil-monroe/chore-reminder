require "test_helper"

class Oauth::ClientsControllerTest < ActionDispatch::IntegrationTest
  test "POST /oauth/register creates a client and returns its credentials" do
    assert_difference -> { Oauth::Client.count }, 1 do
      post oauth_register_path, params: {redirect_uris: ["https://claude.ai/api/mcp/callback"], client_name: "Claude"}.to_json,
        headers: {"Content-Type" => "application/json"}
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "none", body["token_endpoint_auth_method"]
    assert_equal ["https://claude.ai/api/mcp/callback"], body["redirect_uris"]

    client = Oauth::Client.find_by!(client_id: body["client_id"])
    assert_equal "Claude", client.client_name
  end

  test "POST /oauth/register without redirect_uris is rejected" do
    assert_no_difference -> { Oauth::Client.count } do
      post oauth_register_path, params: {}.to_json, headers: {"Content-Type" => "application/json"}
    end

    assert_response :bad_request
    assert_equal "invalid_client_metadata", JSON.parse(response.body)["error"]
  end
end
