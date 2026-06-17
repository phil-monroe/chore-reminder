class Views::Tasks::Index < Views::Base
  def initialize(user:, tasks:)
    @user = user
    @tasks = tasks
  end

  def page_content
    link_to "← Back to #{@user.name}", user_path(@user), class: "text-sm text-blue-600 hover:underline block mb-4"

    div(class: "flex items-center justify-between mb-6") do
      h1(class: "text-2xl font-bold text-gray-900") { "#{@user.name}'s tasks" }
      link_to "New task", new_user_task_path(@user), class: "bg-blue-600 text-white px-3 py-1.5 rounded-md text-sm hover:bg-blue-700"
    end

    render Views::Tasks::List.new(user: @user, tasks: @tasks)
  end
end
