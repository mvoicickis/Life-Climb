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

ActiveRecord::Schema[8.1].define(version: 2026_07_26_031911) do
  create_table "buildings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "shipped_at"
    t.string "status", default: "active", null: false
    t.integer "step_id", null: false
    t.text "summary"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["step_id"], name: "index_buildings_on_step_id"
    t.index ["user_id", "status"], name: "index_buildings_on_user_id_and_status"
    t.index ["user_id"], name: "index_buildings_on_user_id"
  end

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

  create_table "daily_logs", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.datetime "created_at", null: false
    t.decimal "goal", precision: 12, scale: 2
    t.integer "habit_id", null: false
    t.date "logged_on", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["habit_id", "logged_on"], name: "index_daily_logs_on_habit_id_and_logged_on", unique: true
    t.index ["habit_id"], name: "index_daily_logs_on_habit_id"
    t.index ["user_id"], name: "index_daily_logs_on_user_id"
  end

  create_table "daily_todos", force: :cascade do |t|
    t.string "aspect_key", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.integer "lp_reward", default: 30, null: false
    t.integer "position", default: 0, null: false
    t.date "scheduled_on", null: false
    t.string "tag"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "scheduled_on", "aspect_key"], name: "index_daily_todos_on_user_id_and_scheduled_on_and_aspect_key"
    t.index ["user_id"], name: "index_daily_todos_on_user_id"
  end

  create_table "dreams", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_dreams_on_user_id"
  end

  create_table "feedbacks", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_feedbacks_on_user_id"
  end

  create_table "finished_products", force: :cascade do |t|
    t.integer "building_id"
    t.datetime "created_at", null: false
    t.integer "goal_id"
    t.date "shipped_on", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.text "value_summary"
    t.index ["building_id"], name: "index_finished_products_on_building_id"
    t.index ["goal_id"], name: "index_finished_products_on_goal_id"
    t.index ["user_id"], name: "index_finished_products_on_user_id"
  end

  create_table "gap_snapshots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "gap_percent", precision: 5, scale: 2, null: false
    t.integer "life_journey_id", null: false
    t.date "recorded_on", null: false
    t.datetime "updated_at", null: false
    t.index ["life_journey_id", "recorded_on"], name: "index_gap_snapshots_on_life_journey_id_and_recorded_on", unique: true
    t.index ["life_journey_id"], name: "index_gap_snapshots_on_life_journey_id"
  end

  create_table "goals", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "dream_id", null: false
    t.integer "life_area_id"
    t.integer "position", default: 0, null: false
    t.string "status", default: "active", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["dream_id"], name: "index_goals_on_dream_id"
    t.index ["life_area_id"], name: "index_goals_on_life_area_id"
    t.index ["user_id", "position"], name: "index_goals_on_user_id_and_position"
    t.index ["user_id"], name: "index_goals_on_user_id"
  end

  create_table "habits", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "frequency", default: "daily", null: false
    t.decimal "goal", precision: 12, scale: 2
    t.date "goal_raise_declined_on"
    t.decimal "max_value", precision: 12, scale: 2
    t.decimal "min_value", precision: 12, scale: 2
    t.string "name", null: false
    t.integer "points", default: 5, null: false
    t.integer "position", default: 0, null: false
    t.boolean "show_on_home", default: true, null: false
    t.string "stat_type", default: "growth", null: false
    t.string "unit", default: "times", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "position"], name: "index_habits_on_user_id_and_position"
    t.index ["user_id"], name: "index_habits_on_user_id"
  end

  create_table "journey_targets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "current_value", precision: 12, scale: 2, default: "0.0", null: false
    t.string "kind", default: "oneshot", null: false
    t.integer "life_journey_id", null: false
    t.integer "position", default: 0, null: false
    t.string "status", default: "active", null: false
    t.json "tags", default: [], null: false
    t.decimal "target_value", precision: 12, scale: 2, default: "1.0", null: false
    t.string "title", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["life_journey_id", "status"], name: "index_journey_targets_on_life_journey_id_and_status"
    t.index ["life_journey_id"], name: "index_journey_targets_on_life_journey_id"
    t.index ["user_id"], name: "index_journey_targets_on_user_id"
  end

  create_table "life_areas", force: :cascade do |t|
    t.text "ambition"
    t.integer "closer_score", default: 1, null: false
    t.datetime "created_at", null: false
    t.integer "dream_id"
    t.string "key", null: false
    t.json "meta", default: {}, null: false
    t.integer "number", null: false
    t.integer "position", default: 0, null: false
    t.text "present_scene"
    t.datetime "selected_at"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["dream_id", "key"], name: "index_life_areas_on_dream_id_and_key", unique: true
    t.index ["dream_id"], name: "index_life_areas_on_dream_id"
    t.index ["user_id", "key"], name: "index_life_areas_v2_on_user_id_and_key", unique: true, where: "dream_id IS NULL"
    t.index ["user_id", "number"], name: "index_life_areas_on_user_id_and_number"
    t.index ["user_id"], name: "index_life_areas_on_user_id"
  end

  create_table "life_journeys", force: :cascade do |t|
    t.datetime "activated_at"
    t.text "approach"
    t.json "approaches", default: [], null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "current_reality", null: false
    t.text "finished_result"
    t.integer "focus_position"
    t.decimal "gap_percent", precision: 5, scale: 2, default: "70.0", null: false
    t.text "ideal_scene", null: false
    t.integer "life_area_id", null: false
    t.json "milestones", default: [], null: false
    t.text "next_win"
    t.text "policy"
    t.text "program"
    t.json "programs", default: [], null: false
    t.text "purpose"
    t.datetime "scenes_revised_at"
    t.json "setup_flags", default: {}, null: false
    t.string "status", default: "active", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["life_area_id", "status"], name: "index_life_journeys_on_life_area_id_and_status"
    t.index ["life_area_id"], name: "index_life_journeys_on_life_area_id"
    t.index ["user_id", "focus_position"], name: "index_life_journeys_on_user_focus_position", unique: true, where: "focus_position IS NOT NULL"
    t.index ["user_id", "status"], name: "index_life_journeys_on_user_id_and_status"
    t.index ["user_id"], name: "index_life_journeys_on_user_id"
  end

  create_table "life_point_ledgers", force: :cascade do |t|
    t.integer "amount", null: false
    t.datetime "created_at", null: false
    t.string "reason", null: false
    t.integer "source_id"
    t.string "source_type"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["source_type", "source_id"], name: "index_life_point_ledgers_on_source_type_and_source_id"
    t.index ["user_id"], name: "index_life_point_ledgers_on_user_id"
  end

  create_table "missions", force: :cascade do |t|
    t.string "aspect_key"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.integer "gap_delta_basis_points", default: 80, null: false
    t.boolean "is_primary", default: false, null: false
    t.integer "life_journey_id", null: false
    t.integer "lp_reward", default: 50, null: false
    t.integer "position", default: 0, null: false
    t.date "scheduled_on", null: false
    t.string "source", default: "system", null: false
    t.string "status", default: "pending", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["life_journey_id", "scheduled_on"], name: "index_missions_on_life_journey_id_and_scheduled_on"
    t.index ["life_journey_id"], name: "index_missions_on_life_journey_id"
    t.index ["user_id", "life_journey_id", "scheduled_on", "is_primary"], name: "index_missions_one_primary_per_journey_day", unique: true, where: "is_primary = TRUE AND status != 'replaced'"
    t.index ["user_id", "scheduled_on"], name: "index_missions_on_user_id_and_scheduled_on"
    t.index ["user_id"], name: "index_missions_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "steps", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "goal_id", null: false
    t.integer "position", default: 0, null: false
    t.string "status", default: "pending", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["goal_id", "position"], name: "index_steps_on_goal_id_and_position"
    t.index ["goal_id"], name: "index_steps_on_goal_id"
    t.index ["user_id"], name: "index_steps_on_user_id"
  end

  create_table "today_actions", force: :cascade do |t|
    t.integer "building_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.integer "position", default: 0, null: false
    t.date "scheduled_on", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["building_id", "scheduled_on"], name: "index_today_actions_on_building_id_and_scheduled_on"
    t.index ["building_id"], name: "index_today_actions_on_building_id"
    t.index ["user_id", "scheduled_on"], name: "index_today_actions_on_user_id_and_scheduled_on"
    t.index ["user_id"], name: "index_today_actions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.string "character"
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.integer "focus_building_id"
    t.integer "home_stat_count", default: 6, null: false
    t.string "name"
    t.datetime "onboarding_completed_at"
    t.string "password_digest", null: false
    t.integer "planning_version", default: 2, null: false
    t.json "support_milestones_shown", default: [], null: false
    t.boolean "support_prompts_muted", default: false, null: false
    t.integer "total_points", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["focus_building_id"], name: "index_users_on_focus_building_id"
  end

  add_foreign_key "buildings", "steps"
  add_foreign_key "buildings", "users"
  add_foreign_key "completions", "habits"
  add_foreign_key "completions", "users"
  add_foreign_key "daily_logs", "habits"
  add_foreign_key "daily_logs", "users"
  add_foreign_key "daily_todos", "users"
  add_foreign_key "dreams", "users"
  add_foreign_key "feedbacks", "users"
  add_foreign_key "finished_products", "buildings"
  add_foreign_key "finished_products", "goals"
  add_foreign_key "finished_products", "users"
  add_foreign_key "gap_snapshots", "life_journeys"
  add_foreign_key "goals", "dreams"
  add_foreign_key "goals", "life_areas"
  add_foreign_key "goals", "users"
  add_foreign_key "habits", "users"
  add_foreign_key "journey_targets", "life_journeys"
  add_foreign_key "journey_targets", "users"
  add_foreign_key "life_areas", "dreams"
  add_foreign_key "life_areas", "users"
  add_foreign_key "life_journeys", "life_areas"
  add_foreign_key "life_journeys", "users"
  add_foreign_key "life_point_ledgers", "users"
  add_foreign_key "missions", "life_journeys"
  add_foreign_key "missions", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "steps", "goals"
  add_foreign_key "steps", "users"
  add_foreign_key "today_actions", "buildings"
  add_foreign_key "today_actions", "users"
  add_foreign_key "users", "buildings", column: "focus_building_id"
end
