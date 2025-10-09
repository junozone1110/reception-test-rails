class CreateEmployees < ActiveRecord::Migration[8.0]
  def change
    create_table :employees do |t|
      t.string :name, null: false
      t.string :email
      t.string :slack_user_id, null: false
      t.references :department, null: false, foreign_key: true
      t.boolean :is_active, default: true, null: false
      t.string :avatar_url

      t.timestamps
    end
    add_index :employees, :slack_user_id, unique: true
    add_index :employees, :email, unique: true
  end
end
