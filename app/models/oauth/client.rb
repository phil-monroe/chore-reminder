# A client app dynamically registered via the MCP OAuth flow (RFC 7591 -
# see Oauth::ClientsController#create). Deliberately has no client_secret
# column: every client is treated as public (token_endpoint_auth_method
# "none") and authenticated at the token endpoint via PKCE instead (see
# Oauth::TokensController) - the modern recommended approach for clients
# like Claude's remote MCP connector that can't keep a secret confidential.
#
# Deleting a row here is the only revocation mechanism (see
# Admin::OauthClientsController#destroy): Oauth::TokensController and
# Mcp::ServerController both re-check Oauth::Client.exists?(client_id:) on
# every refresh/request, since access/refresh tokens themselves are
# self-contained signed payloads (ActiveSupport::MessageVerifier) with no
# database row of their own to delete.
class Oauth::Client < ApplicationRecord
  validates :client_id, presence: true, uniqueness: true
  validates :redirect_uris, presence: true
  validate :redirect_uris_are_valid_uris

  private

  LOCALHOST_HOSTS = %w[localhost 127.0.0.1 ::1].freeze

  # MCP spec "Communication Security" (quoting OAuth 2.1 Section 1.5):
  # redirect URIs MUST be either localhost or HTTPS - rejecting a plain
  # http:// callback to a non-local host here, at registration time, is
  # what keeps Oauth::AuthorizationsController from ever being able to
  # redirect an authorization code over an unencrypted connection.
  def redirect_uris_are_valid_uris
    return if redirect_uris.blank?

    redirect_uris.each do |uri|
      parsed = URI.parse(uri)
      if parsed.scheme.blank? || parsed.host.blank?
        errors.add(:redirect_uris, "must be absolute URIs")
      elsif parsed.scheme != "https" && !LOCALHOST_HOSTS.include?(parsed.host)
        errors.add(:redirect_uris, "must use https, or be localhost")
      end
    rescue URI::InvalidURIError
      errors.add(:redirect_uris, "must be valid URIs")
    end
  end
end
