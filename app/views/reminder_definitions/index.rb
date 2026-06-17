class Views::ReminderDefinitions::Index < Views::Base
  def initialize(user:, reminder_definitions:)
    @user = user
    @reminder_definitions = reminder_definitions
  end

  def page_content
    link_to "← Back to #{@user.name}", user_path(@user), class: "text-sm text-blue-600 hover:underline block mb-4"

    div(class: "flex items-center justify-between mb-6") do
      h1(class: "text-2xl font-bold text-gray-900") { "#{@user.name}'s reminders" }
      link_to "New reminder", new_user_reminder_definition_path(@user), class: "bg-blue-600 text-white px-3 py-1.5 rounded-md text-sm hover:bg-blue-700"
    end

    if @reminder_definitions.empty?
      p(class: "text-gray-500 text-sm") { "No reminders yet — add one above." }
    else
      div(class: "space-y-2") do
        @reminder_definitions.each do |rd|
          div(class: "bg-white border border-gray-200 rounded-lg p-4 flex items-center justify-between") do
            div do
              link_to rd.time_of_day.strftime("%I:%M %p"), user_reminder_definition_path(@user, rd), class: "font-medium text-gray-900 hover:underline"
              p(class: "text-xs text-gray-500") { "Next send: #{rd.next_send_at.strftime("%a %b %-d, %I:%M %p")}" }
            end
            div(class: "flex gap-3 text-sm") do
              link_to "Edit", edit_user_reminder_definition_path(@user, rd), class: "text-blue-600 hover:underline"
              button_to "Delete", user_reminder_definition_path(@user, rd), method: :delete, data: { turbo_confirm: "Delete this reminder?" },
                class: "text-red-600 hover:underline bg-transparent border-0 p-0 cursor-pointer"
            end
          end
        end
      end
    end
  end
end
