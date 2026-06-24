class Views::Admin::OauthClients::Index < Views::Base
  def initialize(clients:)
    @clients = clients
  end

  def page_content
    h1(class: "text-2xl font-bold text-gray-900 mb-2") { "Connected apps" }
    p(class: "text-sm text-gray-600 mb-6") { "Apps connected via the MCP server, e.g. Claude. Disconnecting one immediately revokes its access." }

    if @clients.empty?
      p(class: "text-gray-500 text-sm") { "No apps connected yet." }
    else
      div(class: "space-y-2") do
        @clients.each do |client|
          div(class: "bg-white border border-gray-200 rounded-lg p-4 flex items-center justify-between") do
            div do
              p(class: "font-medium text-gray-900") { client.client_name.presence || "Unnamed app" }
              p(class: "text-sm text-gray-500") { "Connected #{client.created_at.to_date}" }
            end
            button_to "Disconnect", admin_oauth_client_path(client), method: :delete, data: {turbo_confirm: "Disconnect #{client.client_name.presence || "this app"}?"},
              class: "text-red-600 hover:underline bg-transparent border-0 p-0 cursor-pointer text-sm"
          end
        end
      end
    end
  end
end
