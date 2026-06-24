# The MCP server itself (see CLAUDE.md "MCP server"). Builds a fresh
# MCP::Server + StreamableHTTPTransport per request (the pattern documented
# in the `mcp` gem's README for Rails controllers, as opposed to mounting a
# single shared transport at boot) so each request's tools run with
# server_context scoped to the household member the caller's access token
# was issued for (see Oauth::AuthorizationsController) - that's what lets
# Mcp::Tools::ResolvesUser default a tool's user_id to "whoever this token
# is for" without any cross-request state.
class Mcp::ServerController < ApplicationController
  skip_forgery_protection

  before_action :authenticate!

  def endpoint
    server = MCP::Server.new(
      name: "chore_reminder",
      title: "Chore Reminder",
      tools: Mcp::ToolRegistry.all,
      server_context: {current_user: @current_mcp_user}
    )
    transport = MCP::Server::Transports::StreamableHTTPTransport.new(server, stateless: true, enable_json_response: true)
    status, headers, body = transport.handle_request(request)

    render(json: body.first, status: status, headers: headers)
  end

  private

  def authenticate!
    token = request.headers["Authorization"].to_s[/\ABearer (.+)\z/, 1]
    return unauthorized!(token_presented: false) if token.blank?

    payload = Oauth::SignedTokens.verify_access_token(token)
    # RFC 8707 audience validation (MCP spec "Access Token Privilege
    # Restriction"): a token minted with a resource indicator must name
    # this server's own MCP endpoint, not some other resource - tolerated
    # absent for tokens minted without one (see Oauth::TokensController).
    return unauthorized!(token_presented: true) unless payload["resource"].blank? || payload["resource"] == mcp_url
    return unauthorized!(token_presented: true) unless Oauth::Client.exists?(client_id: payload["client_id"])

    @current_mcp_user = Oauth::SignedTokens.user_for_gid(payload["user_gid"])
    unauthorized!(token_presented: true) unless @current_mcp_user
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    unauthorized!(token_presented: true)
  end

  # RFC 9728: points the client at this resource's protected-resource
  # metadata, which in turn names the authorization server to use - how a
  # client with no token yet discovers where to register/authorize. Per
  # RFC 6750 Section 3.1, `error="invalid_token"` is only included once a
  # token was actually presented and rejected - a bare "no credentials yet"
  # request gets the challenge without implying anything was wrong.
  def unauthorized!(token_presented:)
    challenge = %(Bearer resource_metadata="#{oauth_protected_resource_metadata_url}")
    challenge += ', error="invalid_token"' if token_presented
    response.set_header("WWW-Authenticate", challenge)
    render json: {error: "invalid_token"}, status: :unauthorized
  end
end
