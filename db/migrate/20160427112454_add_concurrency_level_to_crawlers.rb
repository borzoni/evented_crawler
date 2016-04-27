class AddConcurrencyLevelToCrawlers < ActiveRecord::Migration[5.0]
  def change
     add_column :crawlers, :concurrency_level, :integer, default: 50
  end
end
