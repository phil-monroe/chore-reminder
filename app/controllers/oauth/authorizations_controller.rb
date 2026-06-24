# The user-facing half of the MCP OAuth flow (see CLAUDE.md "MCP server"):
# /oauth/authorize requires the existing admin session (this app's only
# concept of "logged in" - see Admin::BaseController) and then asks the
# caregiver which household member the resulting access token should act
# as. That's the only consent step - once logged in, there's nothing else
# to approve, since there's a single admin and the token's scope is just
# "this household member" (see "Authorize UX" decision in the plan).
class Oauth::AuthorizationsController < ApplicationController
  before_action :require_admin_session!
  before_action :load_and_validate_client!

  def new
    render Views::Oauth::Authorize.new(users: User.order(:name), oauth_params: oauth_params)
  end

  def create
    user = User.find(params[:user_id])
    code = Oauth::SignedTokens.generate_code(
      client_id: @client.client_id, redirect_uri: oauth_params[:redirect_uri], code_challenge: oauth_params[:code_challenge],
      user: user, resource: oauth_params[:resource]
    )

    redirect_to redirect_uri_with(code: code, state: oauth_params[:state]), allow_other_host: true
  end

  private

  # Stashes this page's own URL (params and all) so SessionsController can
  # send the caregiver right back here after logging in, instead of
  # dropping them on the admin dashboard mid-OAuth-flow.
  def require_admin_session!
    return if session[Admin::BaseController::SESSION_KEY]

    session[:return_to_after_login] = request.fullpath
    redirect_to login_path
  end

  def load_and_validate_client!
    @client = Oauth::Client.find_by(client_id: oauth_params[:client_id])

    return render_invalid_request("Unknown client_id") if @client.nil?
    return render_invalid_request("redirect_uri is not registered for this client") unless @client.redirect_uris.include?(oauth_params[:redirect_uri])
    return render_invalid_request("response_type must be \"code\"") unless oauth_params[:response_type] == "code"
    return render_invalid_request("code_challenge_method must be \"S256\"") unless oauth_params[:code_challenge_method] == "S256"
    render_invalid_request("code_challenge is required") if oauth_params[:code_challenge].blank?
  end

  # Rendered directly (not a redirect) for any malformed request: an
  # invalid/mismatched redirect_uri is exactly the case where it isn't safe
  # to redirect the browser anywhere.
  def render_invalid_request(message)
    render plain: "Invalid authorization request: #{message}", status: :bad_request
  end

  def oauth_params
    params.permit(:client_id, :redirect_uri, :state, :code_challenge, :code_challenge_method, :response_type, :scope, :resource)
  end

  # Includes `iss` per RFC 9207 (advertised via
  # `authorization_response_iss_parameter_supported` in WellKnownController)
  # so a client can confirm the authorization code in this response actually
  # came from the authorization server it sent the user to, rather than an
  # attacker-controlled one (mix-up attack mitigation - see the MCP spec's
  # "Security Considerations").
  def redirect_uri_with(code:, state:)
    uri = URI.parse(oauth_params[:redirect_uri])
    query = URI.decode_www_form(uri.query.to_s)
    query << ["code", code]
    query << ["state", state] if state.present?
    query << ["iss", request.base_url]
    uri.query = URI.encode_www_form(query)
    uri.to_s
  end
end
