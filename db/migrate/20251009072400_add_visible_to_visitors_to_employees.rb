class AddVisibleToVisitorsToEmployees < ActiveRecord::Migration[8.0]
  def change
    add_column :employees, :visible_to_visitors, :boolean, default: false, null: false
    add_index :employees, :visible_to_visitors
  end
end
