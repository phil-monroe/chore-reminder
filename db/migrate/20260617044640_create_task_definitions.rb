class CreateTaskDefinitions < ActiveRecord::Migration[8.1]
  def change
    create_table :task_definitions do |t|
      t.string :name, null: false
      t.text :description
      t.integer :recurrence_days, array: true, null: false, default: []
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
