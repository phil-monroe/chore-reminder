require "test_helper"

class Oauth::AuthorizationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @client = oauth_clients(:one)
  end

  def authorize_params(overrides = {})
    {
      client_id: @client.client_id,
      redirect_uri: @client.redirect_uris.first,
      response_type: "code",
      code_challenge: "challenge",
      code_challenge_method: "S256",
      state: "xyz"
    }.merge(overrides)
  end

  test "GET /oauth/authorize redirects to /login when not authenticated, then back here after logging in" do
    delete logout_path

    get oauth_authorize_path, params: authorize_params

    assert_redirected_to login_path

    stashed_path, stashed_query = session[:return_to_after_login].split("?", 2)
    assert_equal oauth_authorize_path, stashed_path
    assert_equal authorize_params.stringify_keys, Rack::Utils.parse_nested_query(stashed_query)

    post login_path, params: {password: ENV.fetch("ADMIN_PASSWORD")}

    redirect_path, redirect_query = response.headers["Location"].split("?", 2)
    assert_equal oauth_authorize_url, redirect_path
    assert_equal authorize_params.stringify_keys, Rack::Utils.parse_nested_query(redirect_query)
  end

  test "GET /oauth/authorize renders the user picker once authenticated" do
    get oauth_authorize_path, params: authorize_params

    assert_response :success
    assert_select "input[type=radio][name=user_id]", count: User.count
  end

  test "GET /oauth/authorize rejects an unknown client_id" do
    get oauth_authorize_path, params: authorize_params(client_id: "nope")

    assert_response :bad_request
  end

  test "GET /oauth/authorize rejects a redirect_uri not registered for the client" do
    get oauth_authorize_path, params: authorize_params(redirect_uri: "https://evil.example.com/callback")

    assert_response :bad_request
  end

  test "POST /oauth/authorize redirects to redirect_uri with a code and the given state" do
    user = users(:one)

    post oauth_authorize_path, params: authorize_params.merge(user_id: user.id)

    assert_response :redirect
    redirect_uri = URI.parse(response.headers["Location"])
    query = URI.decode_www_form(redirect_uri.query).to_h
    assert_equal "xyz", query["state"]
    assert query["code"].present?

    payload = Oauth::SignedTokens.verify_code(query["code"])
    assert_equal @client.client_id, payload["client_id"]
    assert_equal user.to_gid.to_s, payload["user_gid"]
  end

  test "POST /oauth/authorize includes an iss parameter naming this server (RFC 9207)" do
    post oauth_authorize_path, params: authorize_params.merge(user_id: users(:one).id)

    redirect_uri = URI.parse(response.headers["Location"])
    query = URI.decode_www_form(redirect_uri.query).to_h
    assert_equal "http://www.example.com", query["iss"]
  end

  test "POST /oauth/authorize passes a resource indicator through to the issued code" do
    post oauth_authorize_path, params: authorize_params.merge(user_id: users(:one).id, resource: mcp_url)

    redirect_uri = URI.parse(response.headers["Location"])
    code = URI.decode_www_form(redirect_uri.query).to_h["code"]
    payload = Oauth::SignedTokens.verify_code(code)
    assert_equal mcp_url, payload["resource"]
  end
end
