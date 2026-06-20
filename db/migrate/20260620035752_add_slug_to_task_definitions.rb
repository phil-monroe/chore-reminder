class AddSlugToTaskDefinitions < ActiveRecord::Migration[8.1]
  def change
    add_column :task_definitions, :slug, :string
    add_index :task_definitions, [:user_id, :slug], unique: true
  end
end
