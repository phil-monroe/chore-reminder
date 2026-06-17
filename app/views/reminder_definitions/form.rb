class Views::ReminderDefinitions::Form < Views::Base
  def initialize(user:, reminder_definition:)
    @user = user
    @reminder_definition = reminder_definition
  end

  def page_content
    h1(class: "text-2xl font-bold text-gray-900 mb-6") { @reminder_definition.persisted? ? "Edit reminder" : "New reminder for #{@user.name}" }

    render_errors

    form_with model: @reminder_definition, url: form_url, class: "space-y-4" do |f|
      div do
        f.label :time_of_day, "Time of day", class: "block text-sm font-medium text-gray-700"
        f.time_field :time_of_day, class: "mt-1 block w-full rounded-md border border-gray-300 px-3 py-2"
      end

      f.submit class: "bg-blue-600 text-white px-4 py-2 rounded-md text-sm hover:bg-blue-700"
    end
  end

  private

  def form_url
    @reminder_definition.persisted? ? user_reminder_definition_path(@user, @reminder_definition) : user_reminder_definitions_path(@user)
  end

  def render_errors
    return if @reminder_definition.errors.empty?

    div(class: "bg-red-50 border border-red-200 text-red-700 rounded-md p-3 mb-4 text-sm") do
      ul do
        @reminder_definition.errors.full_messages.each { |msg| li { msg } }
      end
    end
  end
end
