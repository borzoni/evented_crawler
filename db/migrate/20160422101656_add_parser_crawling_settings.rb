class AddParserCrawlingSettings < ActiveRecord::Migration[5.0]
  def change
    add_column :crawlers, :items_threshold, :float, default: 0.5
    add_column :crawlers, :min_items_parsed, :integer, default: 1000
    add_column :crawlers, :max_work_time, :integer, default: 1800
  end
end
