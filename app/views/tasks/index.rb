class Views::Tasks::Index < Views::Base
  def initialize(user:, tasks:, show_done: false)
    @user = user
    @tasks = tasks
    @show_done = show_done
  end

  def page_content
    link_to "← Back to #{@user.name}", user_path(@user), class: "text-sm text-blue-600 hover:underline block mb-4"

    div(class: "flex items-center justify-between mb-6") do
      h1(class: "text-2xl font-bold text-gray-900") { "#{@user.name}'s #{@show_done ? "completed tasks" : "tasks"}" }
      link_to "New task", new_user_task_path(@user), class: "bg-blue-600 text-white px-3 py-1.5 rounded-md text-sm hover:bg-blue-700"
    end

    render Views::Tasks::List.new(user: @user, tasks: @tasks, show_done: @show_done)

    div(class: "mt-8 text-center") do
      if @show_done
        link_to "← Back to pending tasks", user_tasks_path(@user), class: "text-sm text-gray-400 hover:text-gray-600 hover:underline"
      else
        link_to "Show completed tasks", user_tasks_path(@user, done: true), class: "text-sm text-gray-400 hover:text-gray-600 hover:underline"
      end
    end
  end
end
