class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Employeeテーブル
    add_index :employees, [:is_active, :visible_to_visitors], 
              name: 'idx_employees_on_active_visible'
    add_index :employees, [:department_id, :is_active], 
              name: 'idx_employees_on_dept_active'
    
    # emailのインデックスは既に存在するが、NULLを除外する条件付きインデックスに変更
    remove_index :employees, :email if index_exists?(:employees, :email)
    add_index :employees, :email, unique: true, where: "email IS NOT NULL", 
              name: 'index_employees_on_email'
    
    # Visitテーブル
    add_index :visits, [:employee_id, :created_at], 
              name: 'idx_visits_on_employee_created'
    add_index :visits, [:status, :created_at], 
              name: 'idx_visits_on_status_created'
    add_index :visits, :slack_message_ts, unique: true, 
              where: "slack_message_ts IS NOT NULL",
              name: 'index_visits_on_slack_message_ts'
    
    # Departmentテーブル
    # positionのインデックスは既に存在するため追加不要
    
    # 複合インデックス（カバリングインデックス）
    add_index :employees, 
              [:is_active, :visible_to_visitors, :department_id, :name], 
              name: 'idx_employees_for_visitor_search'
  end
end
