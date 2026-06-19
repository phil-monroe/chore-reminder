class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :user, null: false, foreign_key: true
      t.string :direction, null: false
      t.text :body, null: false

      t.timestamps
    end

    add_index :messages, [:user_id, :created_at]
  end
end
