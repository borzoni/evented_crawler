class ChangePeriodicityColumn < ActiveRecord::Migration[5.0]
  def change
    change_column :crawlers, :periodicity,  :string, null: false
  end
end
