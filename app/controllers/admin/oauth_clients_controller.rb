# Lets the caregiver see and revoke apps connected via the MCP OAuth flow
# (see CLAUDE.md "MCP server"). Deleting a client here is the only
# revocation mechanism: access/refresh tokens are self-contained signed
# payloads (Oauth::SignedTokens) rather than database rows, so
# Oauth::TokensController and Mcp::ServerController both re-check
# Oauth::Client.exists?(client_id:) on every use - destroying the row here
# is what makes that check start failing.
class Admin::OauthClientsController < Admin::BaseController
  def index
    @clients = Oauth::Client.order(:created_at)
    render Views::Admin::OauthClients::Index.new(clients: @clients)
  end

  def destroy
    Oauth::Client.find(params[:id]).destroy
    redirect_to admin_oauth_clients_path, notice: "App disconnected."
  end
end
