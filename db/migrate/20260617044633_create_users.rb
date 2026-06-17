class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :phone_number, null: false
      t.text :message_template, null: false, default: "{{ task_name }}\n\n{% if link %}{{ link }}{% endif %}"

      t.timestamps
    end
  end
end
