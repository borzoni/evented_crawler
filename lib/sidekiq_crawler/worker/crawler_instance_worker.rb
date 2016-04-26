require 'sidekiq'
require 'sidekiq/cron'
require_relative  '../evented_crawler'
require_relative  '../multi_logger'
module SidekiqCrawler
  module Worker
    class CrawlerInstanceWorker
      include Sidekiq::Worker

      def perform(name, crawler_id, url, selectors, blacklist_url_patterns, item_url_patterns, threshold, max_time, min_parsed)
        l = setup_logger(name)
        c = SidekiqCrawler::EventedCrawler.new(crawler_id, url, selectors,blacklist_url_patterns, item_url_patterns,l, threshold, max_time, min_parsed)
        c.go
      end
      
      private
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
