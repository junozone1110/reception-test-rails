# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# 管理者ユーザーの作成
puts "Creating admin user..."
AdminUser.find_or_create_by!(email: "admin@example.com") do |admin|
  admin.name = "管理者"
  admin.password = "admin123"
  admin.password_confirmation = "admin123"
end
puts "Admin user created: admin@example.com / admin123"

# 部署の作成
puts "Creating departments..."
departments = [
  "営業部",
  "開発部",
  "マーケティング部",
  "人事部",
  "総務部"
].map do |dept_name|
  Department.find_or_create_by!(name: dept_name)
end
puts "#{departments.size} departments created"

# 従業員の作成
puts "Creating employees..."
employees_data = [
  { name: "田中 太郎", email: "tanaka@example.com", slack_id: "U001TANAKA", dept: "営業部" },
  { name: "佐藤 花子", email: "sato@example.com", slack_id: "U002SATO", dept: "営業部" },
  { name: "鈴木 一郎", email: "suzuki@example.com", slack_id: "U003SUZUKI", dept: "開発部" },
  { name: "高橋 美咲", email: "takahashi@example.com", slack_id: "U004TAKAHASHI", dept: "開発部" },
  { name: "伊藤 健太", email: "ito@example.com", slack_id: "U005ITO", dept: "開発部" },
  { name: "渡辺 優子", email: "watanabe@example.com", slack_id: "U006WATANABE", dept: "マーケティング部" },
  { name: "山本 大輔", email: "yamamoto@example.com", slack_id: "U007YAMAMOTO", dept: "マーケティング部" },
  { name: "中村 さくら", email: "nakamura@example.com", slack_id: "U008NAKAMURA", dept: "人事部" },
  { name: "小林 誠", email: "kobayashi@example.com", slack_id: "U009KOBAYASHI", dept: "総務部" },
  { name: "加藤 明美", email: "kato@example.com", slack_id: "U010KATO", dept: "総務部" }
]

employees_data.each do |emp_data|
  department = Department.find_by(name: emp_data[:dept])
  Employee.find_or_create_by!(slack_user_id: emp_data[:slack_id]) do |employee|
    employee.name = emp_data[:name]
    employee.email = emp_data[:email]
    employee.department = department
    employee.is_active = true
    employee.avatar_url = "https://ui-avatars.com/api/?name=#{URI.encode_www_form_component(emp_data[:name])}&background=random"
  end
end
puts "#{employees_data.size} employees created"

puts "\nSeed data successfully created!"
puts "=" * 50
puts "Admin Login:"
puts "  Email: admin@example.com"
puts "  Password: admin123"
puts "=" * 50
