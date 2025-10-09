class CreateVisits < ActiveRecord::Migration[8.0]
  def change
    create_table :visits do |t|
      t.references :employee, null: false, foreign_key: true
      t.text :notes
      t.string :status, default: "pending", null: false
      t.string :slack_message_ts

      t.timestamps
    end
    add_index :visits, :status
  end
end
