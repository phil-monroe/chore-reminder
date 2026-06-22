class AddSnoozedUntilToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :snoozed_until, :datetime
  end
end
