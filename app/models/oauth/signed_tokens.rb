# Issues and verifies the three kinds of signed, self-contained tokens the
# MCP OAuth flow uses in place of database-backed grant/token records (see
# CLAUDE.md "MCP server"): authorization codes (Oauth::AuthorizationsController),
# access and refresh tokens (Oauth::TokensController, Mcp::ServerController).
# All three are ActiveSupport::MessageVerifier payloads keyed off
# SECRET_KEY_BASE - the same mechanism Rails already uses to sign session
# cookies, so there's no separate secret to manage. `purpose:` keeps the
# three kinds from being swapped for one another (e.g. a code presented
# where an access token is expected), and `expires_in:` makes
# `#verify` raise ActiveSupport::MessageVerifier::InvalidSignature for an
# expired token the same way it does for a tampered one - one rescue clause
# covers both at every call site.
#
# `resource:` carries the RFC 8707 resource indicator through codes and
# tokens (when the client sends one) so Mcp::ServerController can validate
# token audience per the MCP spec's "Access Token Privilege Restriction"
# requirement, even though this app only ever has one resource (`/mcp`) to
# bind to.
module Oauth::SignedTokens
  CODE_EXPIRY = 2.minutes
  ACCESS_TOKEN_EXPIRY = 1.hour
  REFRESH_TOKEN_EXPIRY = 90.days

  def self.verifier
    Rails.application.message_verifier(:mcp_oauth)
  end

  def self.generate_code(client_id:, redirect_uri:, code_challenge:, user:, resource: nil)
    verifier.generate({client_id: client_id, redirect_uri: redirect_uri, code_challenge: code_challenge, user_gid: user.to_gid.to_s, resource: resource},
      expires_in: CODE_EXPIRY, purpose: :oauth_code)
  end

  def self.verify_code(code)
    verifier.verify(code, purpose: :oauth_code)
  end

  def self.generate_access_token(client_id:, user:, resource: nil)
    verifier.generate({client_id: client_id, user_gid: user.to_gid.to_s, resource: resource}, expires_in: ACCESS_TOKEN_EXPIRY, purpose: :oauth_access_token)
  end

  def self.verify_access_token(token)
    verifier.verify(token, purpose: :oauth_access_token)
  end

  def self.generate_refresh_token(client_id:, user:, resource: nil)
    verifier.generate({client_id: client_id, user_gid: user.to_gid.to_s, resource: resource}, expires_in: REFRESH_TOKEN_EXPIRY, purpose: :oauth_refresh_token)
  end

  def self.verify_refresh_token(token)
    verifier.verify(token, purpose: :oauth_refresh_token)
  end

  def self.user_for_gid(gid)
    GlobalID::Locator.locate(gid)
  end

  # Authorization codes and refresh tokens are otherwise reusable for their
  # whole validity window, since they're stateless signed payloads rather
  # than database rows that could be marked used/revoked. This is OAuth
  # 2.1's "authorization codes MUST be single-use" requirement (and the
  # MUST-rotate-refresh-tokens-for-public-clients requirement, see
  # Oauth::TokensController), implemented as a one-time claim check against
  # Rails.cache rather than a new database table: the first caller to claim
  # a given token's digest within `expires_in` wins, every subsequent claim
  # (replay, or a stolen/duplicated token) is rejected.
  def self.claim_single_use!(token, expires_in:)
    Rails.cache.write("oauth_single_use:#{Digest::SHA256.hexdigest(token)}", true, unless_exist: true, expires_in: expires_in)
  end
end
