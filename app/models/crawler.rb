class Crawler < ApplicationRecord
  validates_presence_of :item_url_patterns, :name, :url, :selectors
  validates :periodicity, :numericality => { :greater_than => 0 }
end
