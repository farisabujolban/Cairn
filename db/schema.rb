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

ActiveRecord::Schema[8.1].define(version: 2026_08_27_105846) do
  create_table "epics", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "milestone_id"
    t.integer "position", null: false
    t.integer "project_id", null: false
    t.string "status", default: "backlog", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["milestone_id"], name: "index_epics_on_milestone_id"
    t.index ["project_id", "position"], name: "index_epics_on_project_id_and_position"
    t.index ["project_id"], name: "index_epics_on_project_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "project_id", null: false
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["project_id"], name: "index_memberships_on_project_id"
    t.index ["user_id", "project_id"], name: "index_memberships_on_user_id_and_project_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "milestones", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.date "due_on"
    t.integer "project_id", null: false
    t.string "state", default: "open", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "due_on"], name: "index_milestones_on_project_id_and_due_on"
    t.index ["project_id"], name: "index_milestones_on_project_id"
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_projects_on_slug", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "stories", force: :cascade do |t|
    t.integer "assignee_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "epic_id", null: false
    t.integer "milestone_id"
    t.integer "position", null: false
    t.string "status", default: "backlog", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id"], name: "index_stories_on_assignee_id"
    t.index ["epic_id", "position"], name: "index_stories_on_epic_id_and_position"
    t.index ["epic_id"], name: "index_stories_on_epic_id"
    t.index ["milestone_id"], name: "index_stories_on_milestone_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.boolean "system_admin", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "epics", "milestones"
  add_foreign_key "epics", "projects"
  add_foreign_key "memberships", "projects"
  add_foreign_key "memberships", "users"
  add_foreign_key "milestones", "projects"
  add_foreign_key "sessions", "users"
  add_foreign_key "stories", "epics"
  add_foreign_key "stories", "milestones"
  add_foreign_key "stories", "users", column: "assignee_id"
end
