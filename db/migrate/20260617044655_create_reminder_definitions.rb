class CreateReminderDefinitions < ActiveRecord::Migration[8.1]
  def change
    create_table :reminder_definitions do |t|
      t.time :time_of_day, null: false
      t.datetime :next_send_at, null: false
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
