class Views::Dashboard::NextTask < Components::Base
  def self.frame_id(user) = "user_#{user.id}_next_task"

  def initialize(user:)
    @user = user
  end

  def view_template
    turbo_frame_tag(self.class.frame_id(@user)) do
      task = Task.next_for(@user)

      if task
        div(class: "mt-3 flex items-center justify-between gap-3") do
          span(class: "text-gray-700") { task.name }
          button_to "Mark done", toggle_done_user_task_path(@user, task), method: :patch,
            class: "text-sm bg-green-600 text-white px-3 py-1 rounded-md hover:bg-green-700"
        end
      else
        p(class: "mt-3 text-sm text-gray-500") { "No pending tasks. All done!" }
      end
    end
  end
end
