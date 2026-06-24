class Views::Admin::Tasks::List < Components::Base
  ICON_BUTTON = "w-9 h-9 shrink-0 flex items-center justify-center rounded text-sm font-bold"

  def initialize(user:, tasks:, show_done: false)
    @user = user
    @tasks = tasks
    @show_done = show_done
  end

  def view_template
    div(id: "tasks", class: "space-y-2") do
      if @tasks.empty?
        empty_state
      elsif @show_done
        @tasks.group_by { |task| task.updated_at.to_date }.each do |date, tasks_for_date|
          date_header(date)
          tasks_for_date.each { |task| task_row(task) }
        end
      else
        @tasks.each { |task| task_row(task) }
      end
    end
  end

  private

  def date_header(date)
    h2(class: "text-xs font-semibold text-gray-500 uppercase pt-3 first:pt-0") { date.strftime("%B %-d, %Y") }
  end

  def empty_state
    div(class: "border border-dashed border-gray-300 rounded-lg p-8 text-center") do
      p(class: "text-gray-500 text-sm") { @show_done ? "No completed tasks in the last 2 weeks." : "No tasks yet — add one below." }
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
        button_to task.done ? "↺" : "✓", toggle_done_admin_user_task_path(@user, task, done: @show_done || nil), method: :patch,
          title: task.done ? "Mark incomplete" : "Mark done",
          class: "#{ICON_BUTTON} #{task.done ? "bg-red-100 text-red-600 hover:bg-red-200" : "bg-green-600 text-white hover:bg-green-700"}"
        button_to "↑", move_higher_admin_user_task_path(@user, task, done: @show_done || nil), method: :patch,
          class: "#{ICON_BUTTON} bg-gray-100 hover:bg-gray-200 text-gray-700"
        button_to "↓", move_lower_admin_user_task_path(@user, task, done: @show_done || nil), method: :patch,
          class: "#{ICON_BUTTON} bg-gray-100 hover:bg-gray-200 text-gray-700"
        task_actions_menu(task)
      end
    end
  end

  def task_actions_menu(task)
    details(class: "relative") do
      summary(class: "#{ICON_BUTTON} list-none [&::-webkit-details-marker]:hidden cursor-pointer bg-white border border-gray-200 text-gray-500 hover:text-gray-700 hover:bg-gray-50") { plain "⋯" }
      div(class: "absolute right-0 mt-1 w-32 bg-white border border-gray-200 rounded-lg shadow-lg z-10 py-1") do
        link_to "Edit", edit_admin_user_task_path(@user, task), class: "block px-3 py-1.5 text-sm text-gray-700 hover:bg-gray-50"
        button_to "Delete", admin_user_task_path(@user, task, done: @show_done || nil), method: :delete, data: {turbo_confirm: "Delete this task?"},
          class: "block w-full text-left px-3 py-1.5 text-sm text-red-600 hover:bg-gray-50 bg-transparent border-0 cursor-pointer"
      end
    end
  end
end
