class CreateOneTimeReminders < ActiveRecord::Migration[8.1]
  def change
    create_table :one_time_reminders do |t|
      t.datetime :send_at, null: false
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
