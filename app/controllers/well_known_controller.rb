# Static OAuth discovery metadata for the MCP server (app/controllers/mcp/server_controller.rb).
# Both actions are unauthenticated by design - this is exactly the
# information a brand new client (e.g. Claude's remote MCP connector) needs
# before it has any credentials at all, the same way a Twilio webhook's URL
# itself isn't secret (see Integrations::TwilioController).
class WellKnownController < ApplicationController
  skip_forgery_protection

  # RFC 8414 authorization server metadata. Points clients at the
  # hand-rolled OAuth endpoints (Oauth::ClientsController/AuthorizationsController/TokensController)
  # rather than at a gem like Doorkeeper, since registration (RFC 7591) and
  # the user-picker step (see Oauth::AuthorizationsController) are bespoke.
  def oauth_authorization_server
    render json: {
      issuer: request.base_url,
      authorization_endpoint: oauth_authorize_url,
      token_endpoint: oauth_token_url,
      registration_endpoint: oauth_register_url,
      scopes_supported: ["mcp"],
      response_types_supported: ["code"],
      grant_types_supported: ["authorization_code", "refresh_token"],
      code_challenge_methods_supported: ["S256"],
      token_endpoint_auth_methods_supported: ["none"],
      authorization_response_iss_parameter_supported: true
    }
  end

  # RFC 9728 protected resource metadata for the /mcp endpoint itself.
  # Mcp::ServerController's 401 response (when a request arrives with no/an
  # invalid Bearer token) points clients here via a WWW-Authenticate header,
  # which is how a client discovers which authorization server to use.
  def oauth_protected_resource
    render json: {
      resource: mcp_url,
      authorization_servers: [request.base_url],
      scopes_supported: ["mcp"]
    }
  end
end
