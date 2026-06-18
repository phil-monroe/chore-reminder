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
      p { span(class: "text-gray-500") { "Phone: " }; plain @user.phone_number }
      p(class: "text-gray-500 text-sm") { "Message template:" }
      pre(class: "bg-gray-50 rounded p-2 text-sm whitespace-pre-wrap") { @user.message_template }
    end

    div(class: "flex gap-3 mb-6") do
      button_to "Send test SMS", send_test_sms_user_path(@user), method: :post,
        class: "bg-gray-800 text-white px-3 py-1.5 rounded-md text-sm hover:bg-gray-900"
      button_to "Send welcome message", send_welcome_message_user_path(@user), method: :post,
        class: "bg-gray-800 text-white px-3 py-1.5 rounded-md text-sm hover:bg-gray-900"
    end

    div(class: "bg-white border border-gray-200 rounded-lg p-4 mb-6") do
      h2(class: "text-sm font-medium text-gray-700 mb-2") { "Send a message" }
      form_with url: send_message_user_path(@user), method: :post, class: "space-y-2" do |f|
        f.text_area :body, rows: 3, placeholder: "Type a one-off message to send right now…",
          class: "block w-full rounded-md border border-gray-300 px-3 py-2"
        f.submit "Send", class: "bg-blue-600 text-white px-3 py-1.5 rounded-md text-sm hover:bg-blue-700"
      end
    end

    div(class: "grid grid-cols-1 sm:grid-cols-3 gap-3") do
      link_to "Tasks", user_tasks_path(@user), class: "block bg-white border border-gray-200 rounded-lg p-4 text-center hover:bg-gray-50"
      link_to "Task Definitions", user_task_definitions_path(@user), class: "block bg-white border border-gray-200 rounded-lg p-4 text-center hover:bg-gray-50"
      link_to "Reminders", user_reminder_definitions_path(@user), class: "block bg-white border border-gray-200 rounded-lg p-4 text-center hover:bg-gray-50"
    end
  end
end
