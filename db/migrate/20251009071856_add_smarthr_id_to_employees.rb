class AddSmarthrIdToEmployees < ActiveRecord::Migration[8.0]
  def change
    add_column :employees, :smarthr_id, :string
    add_index :employees, :smarthr_id, unique: true
  end
end
