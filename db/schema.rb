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

ActiveRecord::Schema[8.0].define(version: 2025_06_12_032511) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "thumbnails", force: :cascade do |t|
    t.string "youtube_id", null: false
    t.string "url", null: false
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["youtube_id"], name: "index_thumbnails_on_youtube_id"
  end

  create_table "videos", force: :cascade do |t|
    t.string "youtube_id", null: false
    t.string "title"
    t.text "description"
    t.string "date_published"
    t.string "channel_id"
    t.string "draft_status"
    t.string "length_seconds"
    t.string "time_created_seconds"
    t.string "watch_url"
    t.string "user_set_monetization"
    t.string "ad_friendly_review_decision"
    t.string "view_count"
    t.string "comment_count"
    t.string "like_count"
    t.string "external_view_count"
    t.string "is_shorts_renderable"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["youtube_id"], name: "index_videos_on_youtube_id", unique: true
  end

  create_table "views", force: :cascade do |t|
    t.string "youtube_id", null: false
    t.string "date", null: false
    t.string "millis_data"
    t.bigint "daily_view_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["youtube_id", "date"], name: "index_views_on_youtube_id_and_date", unique: true
    t.index ["youtube_id"], name: "index_views_on_youtube_id"
  end

  add_foreign_key "thumbnails", "videos", column: "youtube_id", primary_key: "youtube_id"
  add_foreign_key "views", "videos", column: "youtube_id", primary_key: "youtube_id"
end
