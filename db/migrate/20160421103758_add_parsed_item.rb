class AddParsedItem < ActiveRecord::Migration[5.0]
    def change
      create_table :parsed_items do |t|
        t.string :item_name
        t.string :item_price
        t.string :item_brand
        t.text :item_desc
        t.string :item_outer_category, array: true
        t.string :item_sizes, array: true
        t.string :item_sizes_scale
        t.string :item_colors, array: true
        t.text :item_composition
        t.text :item_characteristics
        t.text :item_main_img
        t.text :item_imgs, array: true
        t.boolean :item_availability
        t.string :url
        t.string :domain_url

      t.timestamps
    end
  end
end
