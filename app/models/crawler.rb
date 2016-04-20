class Crawler < ApplicationRecord
  validates_presence_of :item_url_patterns, :name, :url, :selectors, :periodicity
end
