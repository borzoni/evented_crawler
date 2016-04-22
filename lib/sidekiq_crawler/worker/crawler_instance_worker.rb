require 'sidekiq'
require 'sidekiq/cron'
require_relative  '../evented_crawler'
module SidekiqCrawler
  module Worker
    class CrawlerInstanceWorker
      include Sidekiq::Worker

      def perform(name, crawler_id, url, selectors, blacklist_url_patterns, item_url_patterns, threshold, max_time, min_parsed)
        l = Logger.new("log/#{name}_evented_crawler.log")
        c = SidekiqCrawler::EventedCrawler.new(crawler_id, url, selectors,blacklist_url_patterns, item_url_patterns,l, threshold, max_time, min_parsed)
        c.go
      end
    end
  end    
end
