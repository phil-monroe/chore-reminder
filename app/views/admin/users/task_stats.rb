class Views::Admin::Users::TaskStats < Components::Base
  def initialize(user:)
    @user = user
  end

  def view_template
    div(id: "task-stats", class: "grid grid-cols-2 sm:grid-cols-4 gap-3 mb-6") do
      stat_card "Incomplete tasks", @user.tasks.pending.count
      stat_card "Completed in last 7 days", @user.tasks.done.where(updated_at: 7.days.ago..).count
      stat_card "Completed in last 30 days", @user.tasks.done.where(updated_at: 30.days.ago..).count
      stat_card "Total tasks completed", @user.tasks.done.count
    end
  end

  private

  def stat_card(label, value)
    div(class: "bg-white border border-gray-200 rounded-lg p-4 text-center") do
      p(class: "text-2xl font-bold text-gray-900") { value.to_s }
      p(class: "text-xs text-gray-500 mt-1") { label }
    end
  end
end
