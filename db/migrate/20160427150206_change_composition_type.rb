class ChangeCompositionType < ActiveRecord::Migration[5.0]
  def change
    change_column :parsed_items, :item_composition, "varchar[] USING (string_to_array(item_composition, ','))"
  end
end
