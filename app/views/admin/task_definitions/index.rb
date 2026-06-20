class Views::Admin::TaskDefinitions::Index < Views::Base
  def initialize(user:, task_definitions:)
    @user = user
    @task_definitions = task_definitions
  end

  def page_content
    link_to "← Back to #{@user.name}", admin_user_path(@user), class: "text-sm text-blue-600 hover:underline block mb-4"

    div(class: "flex items-center justify-between mb-6") do
      h1(class: "text-2xl font-bold text-gray-900") { "#{@user.name}'s task definitions" }
      link_to "New task definition", new_admin_user_task_definition_path(@user),
        class: "bg-blue-600 text-white px-3 py-1.5 rounded-md text-sm font-medium text-center shadow-sm hover:bg-blue-700 transition-colors"
    end

    if @task_definitions.empty?
      p(class: "text-gray-500 text-sm") { "No task definitions yet — add one above." }
    else
      div(class: "space-y-2") do
        @task_definitions.each do |td|
          div(class: "bg-white border border-gray-200 rounded-lg p-4 flex items-center justify-between") do
            div do
              link_to td.name, admin_user_task_definition_path(@user, td), class: "font-medium text-gray-900 hover:underline"
              p(class: "text-xs text-gray-500") { recurrence_summary(td) }
            end
            div(class: "flex gap-2 text-sm") do
              link_to "Edit", edit_admin_user_task_definition_path(@user, td),
                class: "px-3 py-1.5 rounded-md border border-gray-300 text-gray-700 font-medium shadow-sm hover:bg-gray-50 transition-colors"
              button_to "Delete", admin_user_task_definition_path(@user, td), method: :delete, data: {turbo_confirm: "Delete #{td.name}?"},
                class: "px-3 py-1.5 rounded-md border border-red-200 text-red-600 font-medium shadow-sm hover:bg-red-50 transition-colors cursor-pointer"
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
