# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_10_09_073128) do
  create_table "admin_users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
  end

  create_table "departments", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "position", default: 0, null: false
    t.index ["name"], name: "index_departments_on_name", unique: true
    t.index ["position"], name: "index_departments_on_position"
  end

  create_table "employees", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "email"
    t.string "slack_user_id", null: false
    t.bigint "department_id", null: false
    t.boolean "is_active", default: true, null: false
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "smarthr_id"
    t.boolean "visible_to_visitors", default: false, null: false
    t.index ["department_id"], name: "index_employees_on_department_id"
    t.index ["email"], name: "index_employees_on_email", unique: true
    t.index ["slack_user_id"], name: "index_employees_on_slack_user_id", unique: true
    t.index ["smarthr_id"], name: "index_employees_on_smarthr_id", unique: true
    t.index ["visible_to_visitors"], name: "index_employees_on_visible_to_visitors"
  end

  create_table "sync_logs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "service", null: false
    t.string "status", null: false
    t.json "details"
    t.text "error_message"
    t.datetime "synced_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service", "synced_at"], name: "index_sync_logs_on_service_and_synced_at"
  end

  create_table "visits", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.text "notes"
    t.string "status", default: "pending", null: false
    t.string "slack_message_ts"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_visits_on_employee_id"
    t.index ["status"], name: "index_visits_on_status"
  end

  add_foreign_key "employees", "departments"
  add_foreign_key "visits", "employees"
end
