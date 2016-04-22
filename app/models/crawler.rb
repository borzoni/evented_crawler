class Crawler < ApplicationRecord
  validates_presence_of :item_url_patterns, :name, :url, :selectors, :periodicity, :items_threshold, :min_items_parsed, :max_work_time
  validates_numericality_of :items_threshold, :greater_than_or_equal_to => 0
  validates_numericality_of :min_items_parsed, :greater_than_or_equal_to => 0, :only_integer => true 
  validates_numericality_of :max_work_time, :greater_than_or_equal_to => 0, :only_integer => true 
  has_many :parsed_items
end
