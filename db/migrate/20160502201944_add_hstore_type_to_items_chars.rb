class AddHstoreTypeToItemsChars < ActiveRecord::Migration[5.0]
  def change
    change_column :parsed_items, :item_characteristics, "hstore USING (NULL)"
  end
end
