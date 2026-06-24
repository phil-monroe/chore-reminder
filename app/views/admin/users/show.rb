class Views::Admin::Users::Show < Views::Base
  include Phlex::Rails::Helpers::L

  def initialize(user:)
    @user = user
  end

  def page_content
    div(class: "flex items-center justify-between mb-6") do
      h1(class: "text-2xl font-bold text-gray-900") { @user.name }
      actions_menu
    end

    if @user.snoozed?
      div(class: "bg-white border border-gray-200 rounded-lg p-4 mb-6") do
        p(class: "text-amber-600") {
          plain "Reminders snoozed until #{l(@user.snoozed_until.in_time_zone(@user.time_zone_object), format: :short_with_time)}."
        }
      end
    end

    render Views::Admin::Users::TaskStats.new(user: @user)

    div(class: "flex items-center justify-between mb-3") do
      h2(class: "text-lg font-semibold text-gray-900") { "Incomplete tasks" }
      link_to "New task", new_admin_user_task_path(@user), class: "bg-blue-600 text-white px-3 py-1.5 rounded-md text-sm hover:bg-blue-700"
    end

    render Views::Admin::Tasks::List.new(user: @user, tasks: @user.tasks.pending.order(:position), show_done: false)
  end

  private

  def actions_menu
    details(id: "user-actions-menu", class: "relative") do
      summary(class: "list-none [&::-webkit-details-marker]:hidden cursor-pointer bg-white border border-gray-200 rounded-md text-gray-500 hover:text-gray-700 hover:bg-gray-50 text-xl px-3 py-1 leading-none") { plain "⋯" }
      div(class: "absolute right-0 mt-1 w-56 bg-white border border-gray-200 rounded-lg shadow-lg z-10 py-1") do
        menu_link "User Settings", edit_admin_user_path(@user)
        menu_link "Completed Tasks", admin_user_tasks_path(@user, done: true)
        menu_link "Task Definitions", admin_user_task_definitions_path(@user)
        menu_link "Reminders", admin_user_reminder_definitions_path(@user)
        menu_link "Conversation", conversation_admin_user_path(@user)
        div(class: "border-t border-gray-100 my-1")
        menu_link "Send message", new_message_admin_user_path(@user)
        button_to "Send welcome message", send_welcome_message_admin_user_path(@user), method: :post,
          class: "block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 bg-transparent border-0 cursor-pointer"
      end
    end
  end

  def menu_link(text, path)
    link_to text, path, class: "block px-4 py-2 text-sm text-gray-700 hover:bg-gray-50"
  end
end
