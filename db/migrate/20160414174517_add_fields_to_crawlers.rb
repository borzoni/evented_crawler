class AddFieldsToCrawlers < ActiveRecord::Migration[5.0]
  def up
    add_column :crawlers, :selectors, :hstore, null: false
    add_column :crawlers, :name, :string, null: false
    add_column :crawlers, :url, :string, null: false
    add_column :crawlers, :periodicity, :integer, null: false
    add_column :crawlers, :item_url_patterns, :string, array: true, null: false
    add_column :crawlers, :blacklist_url_patterns, :string, array: true, default: []
  end

  def down
    remove_column :crawlers, :selectors
    remove_column :crawlers, :name
    remove_column :crawlers, :url
    remove_column :crawlers, :periodicity
    remove_column :crawlers, :item_url_patterns
    remove_column :crawlers, :blacklist_url_patterns
  end
end
