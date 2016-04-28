require 'sidekiq'
require 'sidekiq/cron'
require_relative  '../evented_crawler'
require_relative  '../multi_logger'
require_relative  '../crawler_xml_builder'
module SidekiqCrawler
  module Worker
    class CrawlerXMLWorker
      include Sidekiq::Worker

      def perform(crawler_id, name)
        path = "public/ymls/#{name}_evented_crawler.xml"
        SidekiqCrawler::CrawlerXMLBuilder.new(crawler_id, path).generate()    
      end
    end 
  
    class CrawlerInstanceWorker
      include Sidekiq::Worker

      def perform(name, crawler_id, url, selectors, blacklist_url_patterns, item_url_patterns, threshold, max_time, min_parsed, concurrency_level)
        l = setup_logger(name)
        c = SidekiqCrawler::EventedCrawler.new(crawler_id, url, selectors,blacklist_url_patterns, item_url_patterns,l, threshold, max_time, min_parsed, concurrency_level)
        c.go()
        process_xml(name, crawler_id)
      end
      
      private
      def process_xml(name, crawler_id)
        SidekiqCrawler::Worker::CrawlerXMLWorker.sidekiq_options(:queue => "crawlers")
        SidekiqCrawler::Worker::CrawlerXMLWorker.perform_async(crawler_id, name)
      end
       def setup_logger(name)
         File.delete("log/#{name}_evented_crawler.log") if File.exist?("log/#{name}_evented_crawler.log")
         l1 = Logger.new("log/#{name}_evented_crawler.log")
         l2 = Logger.new("log/#{name}_evented_crawler_history.log", 'weekly')
         i = 0
         formatter = 
         l1.formatter = make_formatter
         l2.formatter = make_formatter
         multi_logger = MultiLogger.new(:level => Logger::DEBUG, :loggers => [l1, l2])
         return multi_logger
       end
       def make_formatter
         i = 0
         return proc do |severity, datetime, progname, msg|
           #puts msg.inspect, severity, datetime, progname
           i ||= 0
           i += 1
           date_format = datetime.strftime("%Y-%m-%d %H:%M")
           sprintf "%5s   %10s %10s     %s\n",  "#{i}:", "[#{date_format}]", "#{severity}", "#{msg}"
         end
       end
    end
  end    
end
