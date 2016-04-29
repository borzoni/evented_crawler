require 'active_support/concern'

module SidekiqCrawler
  module Worker
    module LoggerEnabled
      extend ActiveSupport::Concern
       
      def setup_logger(name, delete_flag=true, counter = false)
        File.delete("log/#{name}_evented_crawler.log") if File.exist?("log/#{name}_evented_crawler.log") and delete_flag
        l1 = Logger.new("log/#{name}_evented_crawler.log")
        l2 = Logger.new("log/#{name}_evented_crawler_history.log", 'weekly')
        i = 0
        offset = (get_count("log/#{name}_evented_crawler.log") - 1) if counter 
        l1.formatter = make_formatter(offset||0)
        l2.formatter = make_formatter(offset||0)
        multi_logger = MultiLogger.new(:level => Logger::DEBUG, :loggers => [l1, l2])
        return multi_logger
      end
      def make_formatter(counter=0)
        i = counter
        return proc do |severity, datetime, progname, msg|
          i += 1
          date_format = datetime.strftime("%Y-%m-%d %H:%M")
          sprintf "%5s   %10s %10s     %s\n",  "#{i}:", "[#{date_format}]", "#{severity}", "#{msg}"
        end
      end
      def get_count(filepath)
        `wc -l "#{filepath}"`.strip.to_i
      end
    end
  end
end      
