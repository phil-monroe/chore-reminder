class AddTimeOfDayAndNextGenerateAtToTaskDefinitions < ActiveRecord::Migration[8.1]
  def up
    add_column :task_definitions, :time_of_day, :time
    add_column :task_definitions, :next_generate_at, :datetime

    TaskDefinition.reset_column_information
    TaskDefinition.find_each do |td|
      Time.use_zone(td.user.time_zone) { td.update!(time_of_day: "08:00") }
    end

    change_column_null :task_definitions, :time_of_day, false
    change_column_null :task_definitions, :next_generate_at, false
  end

  def down
    remove_column :task_definitions, :time_of_day
    remove_column :task_definitions, :next_generate_at
  end
end
