class AddPositionToDepartments < ActiveRecord::Migration[8.0]
  def change
    add_column :departments, :position, :integer, default: 0, null: false
    add_index :departments, :position
  end
end
