class Views::Tasks::Form < Views::Base
  def initialize(user:, task:)
    @user = user
    @task = task
  end

  def page_content
    h1(class: "text-2xl font-bold text-gray-900 mb-6") { @task.persisted? ? "Edit task" : "New task for #{@user.name}" }

    render_errors

    form_with model: @task, url: form_url, class: "space-y-4" do |f|
      div do
        f.label :name, class: "block text-sm font-medium text-gray-700"
        f.text_field :name, class: "mt-1 block w-full rounded-md border border-gray-300 px-3 py-2"
      end

      div do
        f.label :task_definition_id, "Task definition (optional)", class: "block text-sm font-medium text-gray-700"
        f.collection_select :task_definition_id, @user.task_definitions, :id, :name, {include_blank: "None — ad-hoc task"},
          class: "mt-1 block w-full rounded-md border border-gray-300 px-3 py-2"
      end

      div(class: "flex items-center gap-3") do
        f.submit class: "bg-blue-600 text-white px-4 py-2 rounded-md text-sm hover:bg-blue-700"
        link_to "Cancel", user_tasks_path(@user), class: "text-sm text-gray-600 hover:underline"
      end
    end
  end

  private

  def form_url
    @task.persisted? ? user_task_path(@user, @task) : user_tasks_path(@user)
  end

  def render_errors
    return if @task.errors.empty?

    div(class: "bg-red-50 border border-red-200 text-red-700 rounded-md p-3 mb-4 text-sm") do
      ul do
        @task.errors.full_messages.each { |msg| li { msg } }
      end
    end
  end
end
