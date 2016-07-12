# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20160712193000) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "hstore"

  create_table "crawlers", force: :cascade do |t|
    t.datetime "created_at",                            null: false
    t.datetime "updated_at",                            null: false
    t.hstore   "selectors",                             null: false
    t.string   "name",                                  null: false
    t.string   "url",                                   null: false
    t.string   "periodicity",                           null: false
    t.string   "item_url_patterns",                     null: false, array: true
    t.string   "blacklist_url_patterns", default: [],                array: true
    t.float    "items_threshold",        default: 0.5
    t.integer  "min_items_parsed",       default: 1000
    t.integer  "max_work_time",          default: 1800
    t.integer  "concurrency_level",      default: 50
  end

  create_table "parsed_items", force: :cascade do |t|
    t.string   "item_name"
    t.string   "item_price"
    t.string   "item_brand"
    t.text     "item_desc"
    t.string   "item_outer_category",               array: true
    t.string   "item_sizes",                        array: true
    t.string   "item_sizes_scale"
    t.string   "item_colors",                       array: true
    t.string   "item_composition",                  array: true
    t.json     "item_characteristics"
    t.text     "item_main_img"
    t.text     "item_imgs",                         array: true
    t.boolean  "item_availability"
    t.string   "url"
    t.string   "domain_url"
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
    t.integer  "crawler_id"
  end

  add_index "parsed_items", ["crawler_id"], name: "index_parsed_items_on_crawler_id", using: :btree
  add_index "parsed_items", ["url"], name: "index_parsed_items_on_url", using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "email",                  default: "", null: false
    t.string   "encrypted_password",     default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet     "current_sign_in_ip"
    t.inet     "last_sign_in_ip"
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree

  add_foreign_key "parsed_items", "crawlers"
end
