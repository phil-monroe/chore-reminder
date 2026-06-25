class Views::Admin::Settings::Index < Views::Base
  def page_content
    h1(class: "text-2xl font-bold text-gray-900 mb-6") { "Settings" }

    div(class: "space-y-2") do
      settings_link "Connected apps", admin_oauth_clients_path, "Apps connected via the MCP server, e.g. Claude."
    end
  end

  private

  def settings_link(title, path, description)
    link_to path, class: "block bg-white border border-gray-200 rounded-lg p-4 hover:border-gray-300" do
      p(class: "font-medium text-gray-900") { title }
      p(class: "text-sm text-gray-500") { description }
    end
  end
end
