class ChangeDefaultMessageTemplateForUsers < ActiveRecord::Migration[8.1]
  def change
    change_column_default :users, :message_template,
      from: "{{ task_name }}\n\n{% if link %}{{ link }}{% endif %}",
      to: "Up next: {{ task_name }}\n{% if link %}{{ link }}{% endif %}"
  end
end
