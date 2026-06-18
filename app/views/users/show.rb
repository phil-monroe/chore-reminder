class Views::Users::Show < Views::Base
  def initialize(user:)
    @user = user
  end

  def page_content
    link_to "← Back to users", users_path, class: "text-sm text-blue-600 hover:underline block mb-4"

    div(class: "flex items-center justify-between mb-6") do
      h1(class: "text-2xl font-bold text-gray-900") { @user.name }
      link_to "Edit", edit_user_path(@user), class: "text-sm text-blue-600 hover:underline"
    end

    div(class: "bg-white border border-gray-200 rounded-lg p-4 space-y-2 mb-6") do
      p {
        span(class: "text-gray-500") { "Phone: " }
        plain @user.phone_number
      }
      p(class: "text-gray-500 text-sm") { "Message template:" }
      pre(class: "bg-gray-50 rounded p-2 text-sm whitespace-pre-wrap") { @user.message_template }
    end

    div(class: "flex gap-3 mb-6") do
      link_to "Send message", new_message_user_path(@user),
        class: "bg-gray-800 text-white px-3 py-1.5 rounded-md text-sm hover:bg-gray-900"
      button_to "Send welcome message", send_welcome_message_user_path(@user), method: :post,
        class: "bg-gray-800 text-white px-3 py-1.5 rounded-md text-sm hover:bg-gray-900"
    end

    div(class: "grid grid-cols-1 sm:grid-cols-3 gap-3") do
      link_to "Tasks", user_tasks_path(@user), class: "block bg-white border border-gray-200 rounded-lg p-4 text-center hover:bg-gray-50"
      link_to "Task Definitions", user_task_definitions_path(@user), class: "block bg-white border border-gray-200 rounded-lg p-4 text-center hover:bg-gray-50"
      link_to "Reminders", user_reminder_definitions_path(@user), class: "block bg-white border border-gray-200 rounded-lg p-4 text-center hover:bg-gray-50"
    end
  end
end
