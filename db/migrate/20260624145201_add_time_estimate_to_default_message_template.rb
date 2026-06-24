class AddTimeEstimateToDefaultMessageTemplate < ActiveRecord::Migration[8.1]
  def change
    change_column_default :users, :message_template,
      from: "Up next: {{ task_name }}\n{% if link %}{{ link }}{% endif %}",
      to: "Up next: {{ task_name }}{% if time_estimate %} ({{ time_estimate }}){% endif %}\n{% if link %}{{ link }}{% endif %}"
  end
end
