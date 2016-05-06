class ChangeItemCharsToJson < ActiveRecord::Migration[5.0]
  def change
    change_column :parsed_items, :item_characteristics, "json USING (NULL)"
  end
end
