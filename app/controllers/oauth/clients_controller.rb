# RFC 7591 Dynamic Client Registration for the MCP OAuth flow. Deliberately
# unauthenticated (per the spec - a client has no credentials yet) and not
# under /admin: a caregiver still has to log in and pick a household member
# at /oauth/authorize (Oauth::AuthorizationsController) before this
# registration is worth anything, and Admin::OauthClientsController lets the
# caregiver revoke any client registered here.
class Oauth::ClientsController < ApplicationController
  skip_forgery_protection

  def create
    redirect_uris = Array(registration_params[:redirect_uris]).map(&:to_s)
    if redirect_uris.empty?
      render json: {error: "invalid_client_metadata", error_description: "redirect_uris is required"}, status: :bad_request
      return
    end

    client = Oauth::Client.new(
      client_id: SecureRandom.hex(16),
      client_name: registration_params[:client_name],
      redirect_uris: redirect_uris
    )

    if client.save
      render json: {
        client_id: client.client_id,
        client_id_issued_at: client.created_at.to_i,
        client_name: client.client_name,
        redirect_uris: client.redirect_uris,
        token_endpoint_auth_method: "none",
        grant_types: ["authorization_code", "refresh_token"],
        response_types: ["code"]
      }, status: :created
    else
      render json: {error: "invalid_client_metadata", error_description: client.errors.full_messages.to_sentence}, status: :bad_request
    end
  end

  private

  def registration_params
    params.permit(:client_name, redirect_uris: [])
  end
end
