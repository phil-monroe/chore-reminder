class Views::Admin::Tasks::List < Components::Base
  def initialize(user:, tasks:, show_done: false)
    @user = user
    @tasks = tasks
    @show_done = show_done
  end

  def view_template
    div(id: "tasks", class: "space-y-2") do
      if @tasks.empty?
        empty_state
      else
        @tasks.each { |task| task_row(task) }
      end
    end
  end

  private

  def empty_state
    div(class: "border border-dashed border-gray-300 rounded-lg p-8 text-center") do
      p(class: "text-gray-500 text-sm") { @show_done ? "No completed tasks yet." : "No tasks yet — add one below." }
    end
  end

  def task_row(task)
    div(class: "bg-white border border-gray-200 rounded-lg p-3 flex items-center justify-between gap-3 #{"opacity-50" if task.done}") do
      div(class: "flex items-center gap-2") do
        span(class: task.done ? "line-through text-gray-400" : "text-gray-900") { task.name }
        if task.task_definition
          link_to "(details)", admin_user_task_definition_path(@user, task.task_definition), class: "text-xs text-blue-600 hover:underline"
        end
      end

      div(class: "flex items-center gap-1") do
        button_to "done", toggle_done_admin_user_task_path(@user, task, done: @show_done || nil), method: :patch,
          class: "text-xs px-2 py-1 rounded #{task.done ? "bg-gray-200 text-gray-700" : "bg-green-600 text-white hover:bg-green-700"}"
        button_to "↑", move_higher_admin_user_task_path(@user, task, done: @show_done || nil), method: :patch,
          class: "text-xs px-2 py-1 rounded bg-gray-100 hover:bg-gray-200"
        button_to "↓", move_lower_admin_user_task_path(@user, task, done: @show_done || nil), method: :patch,
          class: "text-xs px-2 py-1 rounded bg-gray-100 hover:bg-gray-200"
        link_to "Edit", edit_admin_user_task_path(@user, task), class: "text-xs text-blue-600 hover:underline"
        button_to "Delete", admin_user_task_path(@user, task, done: @show_done || nil), method: :delete, data: {turbo_confirm: "Delete this task?"},
          class: "text-xs text-red-600 hover:underline bg-transparent border-0 p-0 cursor-pointer"
      end
    end
  end
end
