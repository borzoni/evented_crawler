class AddCrawlerIdParsedItems < ActiveRecord::Migration[5.0]
  def change
    add_reference :parsed_items, :crawler, index: true, foreign_key: true
    add_index :parsed_items, :url
  end
end
