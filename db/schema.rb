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

ActiveRecord::Schema[8.1].define(version: 2026_07_24_102035) do
  create_table "completions", force: :cascade do |t|
    t.date "completed_on", null: false
    t.datetime "created_at", null: false
    t.integer "habit_id", null: false
    t.integer "points_awarded", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["habit_id", "completed_on"], name: "index_completions_on_habit_id_and_completed_on", unique: true
    t.index ["habit_id"], name: "index_completions_on_habit_id"
    t.index ["user_id"], name: "index_completions_on_user_id"
  end

  create_table "habits", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "frequency", default: "daily", null: false
    t.string "name", null: false
    t.integer "points", default: 5, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_habits_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.integer "total_points", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "completions", "habits"
  add_foreign_key "completions", "users"
  add_foreign_key "habits", "users"
  add_foreign_key "sessions", "users"
end
