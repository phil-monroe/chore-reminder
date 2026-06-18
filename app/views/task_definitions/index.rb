class Views::TaskDefinitions::Index < Views::Base
  def initialize(user:, task_definitions:)
    @user = user
    @task_definitions = task_definitions
  end

  def page_content
    link_to "← Back to #{@user.name}", user_path(@user), class: "text-sm text-blue-600 hover:underline block mb-4"

    div(class: "flex items-center justify-between mb-6") do
      h1(class: "text-2xl font-bold text-gray-900") { "#{@user.name}'s task definitions" }
      link_to "New task definition", new_user_task_definition_path(@user), class: "bg-blue-600 text-white px-3 py-1.5 rounded-md text-sm hover:bg-blue-700"
    end

    if @task_definitions.empty?
      p(class: "text-gray-500 text-sm") { "No task definitions yet — add one above." }
    else
      div(class: "space-y-2") do
        @task_definitions.each do |td|
          div(class: "bg-white border border-gray-200 rounded-lg p-4 flex items-center justify-between") do
            div do
              link_to td.name, user_task_definition_path(@user, td), class: "font-medium text-gray-900 hover:underline"
              p(class: "text-xs text-gray-500") { recurrence_summary(td) }
            end
            div(class: "flex gap-3 text-sm") do
              link_to "Edit", edit_user_task_definition_path(@user, td), class: "text-blue-600 hover:underline"
              button_to "Delete", user_task_definition_path(@user, td), method: :delete, data: {turbo_confirm: "Delete #{td.name}?"},
                class: "text-red-600 hover:underline bg-transparent border-0 p-0 cursor-pointer"
            end
          end
        end
      end
    end
  end

  private

  DAY_NAMES = %w[Sun Mon Tue Wed Thu Fri Sat].freeze

  def recurrence_summary(td)
    return "No recurrence set" if td.recurrence_days.blank?

    td.recurrence_days.sort.map { |d| DAY_NAMES[d] }.join(", ")
  end
end
