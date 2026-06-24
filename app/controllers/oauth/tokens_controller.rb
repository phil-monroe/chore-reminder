# The token-issuing half of the MCP OAuth flow (see CLAUDE.md "MCP server").
# Public/unauthenticated like Oauth::ClientsController - the client has no
# session, only the authorization code or refresh token it's presenting -
# and outside /admin for the same reason.
class Oauth::TokensController < ApplicationController
  skip_forgery_protection

  def create
    case params[:grant_type]
    when "authorization_code" then exchange_code
    when "refresh_token" then exchange_refresh_token
    else render_error("unsupported_grant_type")
    end
  end

  private

  def exchange_code
    payload = Oauth::SignedTokens.verify_code(params[:code])

    return render_error("invalid_grant", "client_id does not match") unless payload["client_id"] == params[:client_id]
    return render_error("invalid_grant", "redirect_uri does not match") unless payload["redirect_uri"] == params[:redirect_uri]
    return render_error("invalid_grant", "code_verifier does not match code_challenge") unless pkce_verified?(payload["code_challenge"])
    return render_error("invalid_grant", "resource does not match this server") unless resource_valid?(payload["resource"])
    # OAuth 2.1 requires authorization codes to be single-use; codes here are
    # stateless signed payloads (see Oauth::SignedTokens) rather than rows
    # that could be marked redeemed, so this claims the code's digest in
    # Rails.cache instead - the first redemption wins, any replay within the
    # code's own validity window is rejected.
    return render_error("invalid_grant", "code has already been used") unless Oauth::SignedTokens.claim_single_use!(params[:code], expires_in: Oauth::SignedTokens::CODE_EXPIRY)

    user = Oauth::SignedTokens.user_for_gid(payload["user_gid"])
    return render_error("invalid_grant", "user no longer exists") if user.nil?

    render_tokens(client_id: payload["client_id"], user: user, resource: payload["resource"])
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    render_error("invalid_grant", "code is invalid or expired")
  end

  def exchange_refresh_token
    payload = Oauth::SignedTokens.verify_refresh_token(params[:refresh_token])

    return render_error("invalid_grant", "client_id does not match") unless payload["client_id"] == params[:client_id]
    return render_error("invalid_grant", "client is no longer registered") unless Oauth::Client.exists?(client_id: payload["client_id"])
    return render_error("invalid_grant", "resource does not match this server") unless resource_valid?(payload["resource"])
    # Public clients (every client here - see Oauth::Client) MUST have their
    # refresh tokens rotated on use (OAuth 2.1 4.3.1): each refresh both
    # consumes the presented token (one-time, same Rails.cache mechanism as
    # authorization codes above) and mints a brand new one, rather than
    # letting the same refresh token be reused indefinitely until its own
    # expiry.
    return render_error("invalid_grant", "refresh_token has already been used") unless Oauth::SignedTokens.claim_single_use!(params[:refresh_token], expires_in: Oauth::SignedTokens::REFRESH_TOKEN_EXPIRY)

    user = Oauth::SignedTokens.user_for_gid(payload["user_gid"])
    return render_error("invalid_grant", "user no longer exists") if user.nil?

    render_tokens(client_id: payload["client_id"], user: user, resource: payload["resource"])
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    render_error("invalid_grant", "refresh_token is invalid or expired")
  end

  def pkce_verified?(code_challenge)
    computed = Digest::SHA256.base64digest(params[:code_verifier].to_s).tr("+/", "-_").delete("=")
    ActiveSupport::SecurityUtils.secure_compare(computed, code_challenge.to_s)
  end

  # RFC 8707: only validated when the client actually sent a resource
  # indicator (still tolerated absent, since this isn't a multi-tenant
  # authorization server and older clients may predate this requirement) -
  # but if one was sent, it must name this server's own MCP endpoint, not
  # some other resource this authorization server has no business issuing
  # tokens for.
  def resource_valid?(resource)
    resource.blank? || resource == mcp_url
  end

  def render_tokens(client_id:, user:, resource:)
    body = {
      access_token: Oauth::SignedTokens.generate_access_token(client_id: client_id, user: user, resource: resource),
      token_type: "Bearer",
      expires_in: Oauth::SignedTokens::ACCESS_TOKEN_EXPIRY.to_i,
      refresh_token: Oauth::SignedTokens.generate_refresh_token(client_id: client_id, user: user, resource: resource)
    }

    render json: body
  end

  def render_error(error, description = nil)
    render json: {error: error, error_description: description}.compact, status: :bad_request
  end
end
