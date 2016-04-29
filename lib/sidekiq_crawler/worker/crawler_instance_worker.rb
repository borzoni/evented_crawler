require 'sidekiq'
require 'sidekiq/cron'
require_relative  '../evented_crawler'
require_relative  '../multi_logger'
require_relative  '../crawler_xml_builder'
require_relative './logger_enabled'

module SidekiqCrawler
  module Worker
    class CrawlerXMLWorker
      include Sidekiq::Worker
      include SidekiqCrawler::Worker::LoggerEnabled

      def perform(crawler_id, name)
        path = "public/ymls/#{name}_evented_crawler.xml"
        log_path = "log"
        l = setup_logger(name, false, true)
        SidekiqCrawler::CrawlerXMLBuilder.new(crawler_id, path, l).generate()    
      end
    end 
    class CrawlerInstanceWorker
      include Sidekiq::Worker
      include SidekiqCrawler::Worker::LoggerEnabled

      def perform(name, crawler_id, url, selectors, blacklist_url_patterns, item_url_patterns, threshold, max_time, min_parsed, concurrency_level)
        l = setup_logger(name)
        c = SidekiqCrawler::EventedCrawler.new(crawler_id, url, selectors,blacklist_url_patterns, item_url_patterns,l, threshold, max_time, min_parsed, concurrency_level, method(:cancelled?))
        c.go()
        return if cancelled?
        generate_xml(name, crawler_id)
      end
      
      def cancelled?
        Sidekiq.redis {|c| c.exists("cancelled-#{jid}") }
      end

      def self.cancel!(jid)
        Sidekiq.redis {|c| c.setex("cancelled-#{jid}", 86400, 1) }
      end
      
      private
       def generate_xml(name, crawler_id)
         SidekiqCrawler::Worker::CrawlerXMLWorker.sidekiq_options(:queue => "crawlers")
         SidekiqCrawler::Worker::CrawlerXMLWorker.perform_async(crawler_id, name)
       end
       
    end
  end    
end
