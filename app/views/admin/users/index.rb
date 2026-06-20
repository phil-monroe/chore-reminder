class Views::Admin::Users::Index < Views::Base
  def initialize(users:)
    @users = users
  end

  def page_content
    div(class: "flex items-center justify-between mb-6") do
      h1(class: "text-2xl font-bold text-gray-900") { "Users" }
      link_to "New user", new_admin_user_path, class: "bg-blue-600 text-white px-3 py-1.5 rounded-md text-sm hover:bg-blue-700"
    end

    if @users.empty?
      p(class: "text-gray-500 text-sm") { "No users yet — add one above." }
    else
      div(class: "space-y-2") do
        @users.each do |user|
          div(class: "bg-white border border-gray-200 rounded-lg p-4 flex items-center justify-between") do
            div do
              link_to user.name, admin_user_path(user), class: "font-medium text-gray-900 hover:underline"
              p(class: "text-sm text-gray-500") { user.phone_number }
            end
            div(class: "flex gap-3 text-sm") do
              link_to "Edit", edit_admin_user_path(user), class: "text-blue-600 hover:underline"
              button_to "Delete", admin_user_path(user), method: :delete, data: {turbo_confirm: "Delete #{user.name}?"},
                class: "text-red-600 hover:underline bg-transparent border-0 p-0 cursor-pointer"
            end
          end
        end
      end
    end
  end
end
