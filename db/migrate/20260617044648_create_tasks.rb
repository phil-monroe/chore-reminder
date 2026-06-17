class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.string :name, null: false
      t.boolean :done, null: false, default: false
      t.integer :position
      t.references :user, null: false, foreign_key: true
      t.references :task_definition, null: true, foreign_key: { on_delete: :nullify }

      t.timestamps
    end
  end
end
