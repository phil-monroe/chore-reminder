# The MCP OAuth consent step (see Oauth::AuthorizationsController): the
# caregiver is already logged in by the time they reach this page (enforced
# by the controller), so the only choice left is which household member the
# connecting app (e.g. Claude) should act as. Tools default to this user
# when called without an explicit user_id, but every tool still accepts one
# to act on any user - this just sets the convenient default.
class Views::Oauth::Authorize < Views::Base
  def initialize(users:, oauth_params:)
    @users = users
    @oauth_params = oauth_params
  end

  def page_content
    h1(class: "text-2xl font-bold text-gray-900 mb-2") { "Connect an app" }
    p(class: "text-sm text-gray-600 mb-6") { "Choose which household member this connection should act as. You can still manage any household member through it - this just sets the default." }

    form_with url: oauth_authorize_path, method: :post, class: "space-y-4" do
      @oauth_params.to_h.compact_blank.each { |key, value| input(type: "hidden", name: key, value: value) }

      div(class: "space-y-2") do
        @users.each do |user|
          label(class: "flex items-center gap-3 border border-gray-200 rounded-md p-3 cursor-pointer hover:bg-gray-50") do
            input(type: "radio", name: "user_id", value: user.id, checked: (user == @users.first))
            span(class: "text-sm font-medium text-gray-900") { user.name }
          end
        end
      end

      button(type: "submit", class: "w-full bg-blue-600 text-white px-4 py-2 rounded-md text-sm font-medium hover:bg-blue-700") { "Continue" }
    end
  end
end
