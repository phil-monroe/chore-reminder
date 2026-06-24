class Views::Admin::TaskDefinitions::Form < Views::Base
  DAYS = [[0, "Sunday"], [1, "Monday"], [2, "Tuesday"], [3, "Wednesday"], [4, "Thursday"], [5, "Friday"], [6, "Saturday"]].freeze

  def initialize(user:, task_definition:)
    @user = user
    @task_definition = task_definition
  end

  def page_content
    h1(class: "text-2xl font-bold text-gray-900 mb-6") { @task_definition.persisted? ? "Edit #{@task_definition.name}" : "New task definition for #{@user.name}" }

    render_errors

    form_with model: @task_definition, url: form_url, class: "space-y-4", multipart: true do |f|
      div do
        f.label :name, class: "block text-sm font-medium text-gray-700"
        f.text_field :name, class: "mt-1 block w-full rounded-md border border-gray-300 px-3 py-2"
      end

      div do
        f.label :description, "Description (Markdown)", class: "block text-sm font-medium text-gray-700"
        f.text_area :description, rows: 6, class: "mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 font-mono text-sm"
      end

      div do
        span(class: "block text-sm font-medium text-gray-700 mb-1") { "Recurs on" }
        div(class: "flex flex-wrap gap-3") do
          DAYS.each do |value, day_label|
            day_checkbox(f, value, day_label)
          end
        end
      end

      div do
        f.label :time_of_day, "Time of day", class: "block text-sm font-medium text-gray-700"
        f.time_field :time_of_day, class: "mt-1 block w-full rounded-md border border-gray-300 px-3 py-2"
      end

      div do
        f.label :time_estimate_minutes, "Time estimate (minutes, optional)", class: "block text-sm font-medium text-gray-700"
        f.number_field :time_estimate_minutes, min: 1, class: "mt-1 block w-full rounded-md border border-gray-300 px-3 py-2"
      end

      div do
        f.label :images, "Images", class: "block text-sm font-medium text-gray-700"
        f.file_field :images, multiple: true, class: "mt-1 block w-full text-sm"
      end

      div(class: "flex items-center gap-3") do
        f.submit class: "bg-blue-600 text-white px-4 py-2 rounded-md text-sm hover:bg-blue-700"
        link_to "Cancel", cancel_url, class: "text-sm text-gray-600 hover:underline"
      end
    end
  end

  private

  def cancel_url
    @task_definition.persisted? ? admin_user_task_definition_path(@user, @task_definition) : admin_user_task_definitions_path(@user)
  end

  def day_checkbox(f, value, day_label)
    checked = @task_definition.recurrence_days.include?(value)
    div(class: "flex items-center gap-1") do
      input(type: "checkbox", name: "task_definition[recurrence_days][]", value: value, id: "recurrence_day_#{value}", checked: checked, class: "rounded border-gray-300")
      label(for: "recurrence_day_#{value}", class: "text-sm text-gray-700") { plain day_label }
    end
  end

  def form_url
    @task_definition.persisted? ? admin_user_task_definition_path(@user, @task_definition) : admin_user_task_definitions_path(@user)
  end

  def render_errors
    return if @task_definition.errors.empty?

    div(class: "bg-red-50 border border-red-200 text-red-700 rounded-md p-3 mb-4 text-sm") do
      ul do
        @task_definition.errors.full_messages.each { |msg| li { msg } }
      end
    end
  end
end
