class Views::Admin::ReminderDefinitions::Show < Views::Base
  include Phlex::Rails::Helpers::L

  def initialize(user:, reminder_definition:)
    @user = user
    @reminder_definition = reminder_definition
  end

  def page_content
    link_to "← Back to reminders", admin_user_reminder_definitions_path(@user), class: "text-sm text-blue-600 hover:underline block mb-4"

    div(class: "flex items-center justify-between mb-6") do
      h1(class: "text-2xl font-bold text-gray-900") { "Reminder at #{l(@reminder_definition.time_of_day, format: :time_of_day)}" }
      link_to "Edit", edit_admin_user_reminder_definition_path(@user, @reminder_definition), class: "text-sm text-blue-600 hover:underline"
    end

    div(class: "bg-white border border-gray-200 rounded-lg p-4 mb-6") do
      p {
        span(class: "text-gray-500") { "Next send: " }
        plain l(@reminder_definition.next_send_at, format: :short_with_time)
      }
    end

    button_to "Send now", send_now_admin_user_reminder_definition_path(@user, @reminder_definition), method: :post,
      class: "bg-gray-800 text-white px-3 py-1.5 rounded-md text-sm hover:bg-gray-900"
  end
end
