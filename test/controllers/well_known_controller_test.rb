require "test_helper"

class WellKnownControllerTest < ActionDispatch::IntegrationTest
  test "GET /.well-known/oauth-authorization-server returns discovery metadata" do
    get "/.well-known/oauth-authorization-server"

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal oauth_authorize_url, body["authorization_endpoint"]
    assert_equal oauth_token_url, body["token_endpoint"]
    assert_equal oauth_register_url, body["registration_endpoint"]
    assert_equal ["S256"], body["code_challenge_methods_supported"]
  end

  test "GET /.well-known/oauth-protected-resource points at the MCP endpoint and authorization server" do
    get "/.well-known/oauth-protected-resource"

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal mcp_url, body["resource"]
    assert_equal [oauth_token_url.delete_suffix("/oauth/token")], body["authorization_servers"]
  end
end
