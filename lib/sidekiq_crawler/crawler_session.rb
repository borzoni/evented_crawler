require "ohm"

module SidekiqCrawler
  class CrawlerSession < Ohm::Model
    attribute :crawler_id
    counter :items
    counter :connection_errors
    counter :parse_errors
    attribute :start_time
    attribute :finish_time
    counter :requests
    attribute :status
    attribute :name
    attribute :url
    index :crawler_id
    index :status
  end
end  
