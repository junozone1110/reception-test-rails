class CreateSyncLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :sync_logs do |t|
      t.string :service, null: false
      t.string :status, null: false
      t.json :details
      t.text :error_message
      t.datetime :synced_at, null: false

      t.timestamps
    end
    add_index :sync_logs, [:service, :synced_at]
  end
end
