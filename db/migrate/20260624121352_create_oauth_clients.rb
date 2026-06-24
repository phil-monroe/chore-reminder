class CreateOauthClients < ActiveRecord::Migration[8.1]
  def change
    create_table :oauth_clients do |t|
      t.string :client_id, null: false
      t.string :client_name
      t.string :redirect_uris, array: true, null: false, default: []

      t.timestamps
    end

    add_index :oauth_clients, :client_id, unique: true
  end
end
