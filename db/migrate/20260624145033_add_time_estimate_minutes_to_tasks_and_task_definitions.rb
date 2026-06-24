class AddTimeEstimateMinutesToTasksAndTaskDefinitions < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :time_estimate_minutes, :integer
    add_column :task_definitions, :time_estimate_minutes, :integer
  end
end
