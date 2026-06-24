class Views::Admin::Dashboard::Index < Views::Base
  def initialize(users:)
    @users = users
  end

  def page_content
    h1(class: "text-2xl font-bold text-gray-900 mb-6") { "Dashboard" }

    if @users.empty?
      empty_state
    else
      div(class: "space-y-4 mb-6") do
        @users.each { |user| user_card(user) }
      end

      div(class: "text-center") do
        link_to "Add user", new_admin_user_path, class: "text-sm text-gray-400 hover:text-gray-600 hover:underline"
      end
    end
  end

  private

  def empty_state
    div(class: "text-gray-500 text-sm") do
      plain "No users yet. "
      link_to "Add one", new_admin_user_path, class: "text-blue-600 hover:underline"
      plain "."
    end
  end

  def user_card(user)
    div(class: "bg-white border border-gray-200 rounded-lg p-4 shadow-sm") do
      link_to user.name, admin_user_path(user), class: "font-semibold text-gray-900 hover:underline"

      render Views::Admin::Dashboard::NextTask.new(user: user)
    end
  end
end
