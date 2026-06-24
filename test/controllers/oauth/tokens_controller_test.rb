require "test_helper"

class Oauth::TokensControllerTest < ActionDispatch::IntegrationTest
  # Oauth::SignedTokens.claim_single_use! (single-use codes/refresh token
  # rotation) relies on Rails.cache actually persisting between requests.
  # Test env defaults to :null_store (config/environments/test.rb), which
  # accepts every write and reports it as new every time - that would make
  # single-use enforcement invisibly untested rather than failing loudly,
  # so this swaps in a real in-memory store for just this file.
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    @client = oauth_clients(:one)
    @user = users(:one)
    @redirect_uri = @client.redirect_uris.first
    @code_verifier = "test-code-verifier-1234567890abcdefghijklmnop"
    @code_challenge = Digest::SHA256.base64digest(@code_verifier).tr("+/", "-_").delete("=")
  end

  teardown do
    Rails.cache = @original_cache
  end

  def generate_code(**overrides)
    Oauth::SignedTokens.generate_code(
      client_id: @client.client_id, redirect_uri: @redirect_uri, code_challenge: @code_challenge, user: @user, **overrides
    )
  end

  test "authorization_code grant with the matching code_verifier returns an access and refresh token" do
    post oauth_token_path, params: {
      grant_type: "authorization_code", code: generate_code, client_id: @client.client_id,
      redirect_uri: @redirect_uri, code_verifier: @code_verifier
    }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Bearer", body["token_type"]
    assert body["access_token"].present?
    assert body["refresh_token"].present?

    payload = Oauth::SignedTokens.verify_access_token(body["access_token"])
    assert_equal @user.to_gid.to_s, payload["user_gid"]
  end

  test "authorization_code grant with the wrong code_verifier is rejected" do
    post oauth_token_path, params: {
      grant_type: "authorization_code", code: generate_code, client_id: @client.client_id,
      redirect_uri: @redirect_uri, code_verifier: "wrong-verifier"
    }

    assert_response :bad_request
    assert_equal "invalid_grant", JSON.parse(response.body)["error"]
  end

  test "authorization_code grant with a mismatched redirect_uri is rejected" do
    post oauth_token_path, params: {
      grant_type: "authorization_code", code: generate_code, client_id: @client.client_id,
      redirect_uri: "https://attacker.example.com/callback", code_verifier: @code_verifier
    }

    assert_response :bad_request
    assert_equal "invalid_grant", JSON.parse(response.body)["error"]
  end

  test "authorization_code grant with a tampered code is rejected" do
    post oauth_token_path, params: {
      grant_type: "authorization_code", code: "#{generate_code}tampered", client_id: @client.client_id,
      redirect_uri: @redirect_uri, code_verifier: @code_verifier
    }

    assert_response :bad_request
    assert_equal "invalid_grant", JSON.parse(response.body)["error"]
  end

  test "authorization_code grant with an expired code is rejected" do
    code = travel_to(3.minutes.ago) { generate_code }

    post oauth_token_path, params: {
      grant_type: "authorization_code", code: code, client_id: @client.client_id,
      redirect_uri: @redirect_uri, code_verifier: @code_verifier
    }

    assert_response :bad_request
    assert_equal "invalid_grant", JSON.parse(response.body)["error"]
  end

  test "authorization_code grant rejects reuse of an already-redeemed code" do
    code = generate_code
    post oauth_token_path, params: {
      grant_type: "authorization_code", code: code, client_id: @client.client_id,
      redirect_uri: @redirect_uri, code_verifier: @code_verifier
    }
    assert_response :success

    post oauth_token_path, params: {
      grant_type: "authorization_code", code: code, client_id: @client.client_id,
      redirect_uri: @redirect_uri, code_verifier: @code_verifier
    }

    assert_response :bad_request
    assert_equal "invalid_grant", JSON.parse(response.body)["error"]
  end

  test "authorization_code grant with a matching resource indicator succeeds and binds it to the issued tokens" do
    code = generate_code(resource: mcp_url)

    post oauth_token_path, params: {
      grant_type: "authorization_code", code: code, client_id: @client.client_id,
      redirect_uri: @redirect_uri, code_verifier: @code_verifier
    }

    assert_response :success
    payload = Oauth::SignedTokens.verify_access_token(JSON.parse(response.body)["access_token"])
    assert_equal mcp_url, payload["resource"]
  end

  test "authorization_code grant with a resource indicator for a different server is rejected" do
    code = generate_code(resource: "https://not-this-server.example.com/mcp")

    post oauth_token_path, params: {
      grant_type: "authorization_code", code: code, client_id: @client.client_id,
      redirect_uri: @redirect_uri, code_verifier: @code_verifier
    }

    assert_response :bad_request
    assert_equal "invalid_grant", JSON.parse(response.body)["error"]
  end

  test "refresh_token grant returns a fresh access token and rotates the refresh token" do
    refresh_token = Oauth::SignedTokens.generate_refresh_token(client_id: @client.client_id, user: @user)

    post oauth_token_path, params: {grant_type: "refresh_token", refresh_token: refresh_token, client_id: @client.client_id}

    assert_response :success
    body = JSON.parse(response.body)
    assert body["access_token"].present?
    assert body["refresh_token"].present?
    assert_not_equal refresh_token, body["refresh_token"]
  end

  test "refresh_token grant rejects reuse of an already-rotated refresh token" do
    refresh_token = Oauth::SignedTokens.generate_refresh_token(client_id: @client.client_id, user: @user)
    post oauth_token_path, params: {grant_type: "refresh_token", refresh_token: refresh_token, client_id: @client.client_id}
    assert_response :success

    post oauth_token_path, params: {grant_type: "refresh_token", refresh_token: refresh_token, client_id: @client.client_id}

    assert_response :bad_request
    assert_equal "invalid_grant", JSON.parse(response.body)["error"]
  end

  test "refresh_token grant is rejected once the client has been revoked" do
    refresh_token = Oauth::SignedTokens.generate_refresh_token(client_id: @client.client_id, user: @user)
    @client.destroy

    post oauth_token_path, params: {grant_type: "refresh_token", refresh_token: refresh_token, client_id: @client.client_id}

    assert_response :bad_request
    assert_equal "invalid_grant", JSON.parse(response.body)["error"]
  end

  test "an unsupported grant_type is rejected" do
    post oauth_token_path, params: {grant_type: "password"}

    assert_response :bad_request
    assert_equal "unsupported_grant_type", JSON.parse(response.body)["error"]
  end
end
