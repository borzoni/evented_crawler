require 'sidekiq'
require 'sidekiq/cron'
require_relative  '../evented_crawler'
module SidekiqCrawler
  module Worker
    class CrawlerInstanceWorker
      include Sidekiq::Worker

      def perform(crawler_id, url, selectors, blacklist_url_patterns, item_url_patterns)
        c = SidekiqCrawler::EventedCrawler.new(crawler_id, url, selectors,blacklist_url_patterns, item_url_patterns)
        c.go
      end
    end
  end    
end
