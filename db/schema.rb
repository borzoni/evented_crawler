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

ActiveRecord::Schema.define(version: 20160421103758) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "hstore"

  create_table "crawlers", force: :cascade do |t|
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.hstore   "selectors",                           null: false
    t.string   "name",                                null: false
    t.string   "url",                                 null: false
    t.string   "periodicity",                         null: false
    t.string   "item_url_patterns",                   null: false, array: true
    t.string   "blacklist_url_patterns", default: [],              array: true
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
    t.text     "item_composition"
    t.text     "item_characteristics"
    t.text     "item_main_img"
    t.text     "item_imgs",                         array: true
    t.boolean  "item_availability"
    t.string   "url"
    t.string   "domain_url"
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
  end

end
