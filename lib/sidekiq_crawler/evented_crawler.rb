require 'eventmachine'
require 'em-http-request'
require 'nokogiri'
require 'set'
require 'addressable/uri'
require 'time'
require 'active_record'
require 'yaml'
require_relative './card_parser'
require_relative './crawler_card_error'
require_relative './crawler_session'
require_relative './url_checkable'

module SidekiqCrawler
      class Item < ActiveRecord::Base
        self.table_name = "parsed_items"
      end
      
  class EventedCrawler
    include EM::Protocols
    include SidekiqCrawler::UrlCheckable
    
    def initialize(name, crawler_id, url, selectors,blacklist_url_patterns, item_url_patterns, logger, threshold, max_time, min_parsed, concurrency_level, cancel, retries= nil )
      dbconfig = YAML.load(File.read('lib/sidekiq_crawler/crawler_db.yml'))
      ActiveRecord::Base.establish_connection dbconfig
      @session = SidekiqCrawler::CrawlerSession.create
      @url = url
      @name = name
      @threshold = threshold
      @max_time = max_time
      @min_parsed = min_parsed
      @max_retries = retries || 5;
      @crawler_id = crawler_id
      @selectors = selectors
      @blacklisted = blacklist_url_patterns
      @card_url_pattern = item_url_patterns
      @cancel_check = cancel
      @links_found = Set.new
      @links_todo = []
      @connections = 0
      @CONCURRENT_CONNECTIONS = concurrency_level
      @er = []
      @logger = logger
      @cards_counter = 0
      @cards_saved_counter = 0
      @cards_errors_counter = 0
      @finalized = false
      @tick_time = nil
      @base = nil
      @requests = 0
    end

    def get_inner_links(root, content)
        host = @base.host
        doc = Nokogiri::HTML(content)

        # Find all <a> elements.
        doc.css('a').each do |link|
            begin
                url = Addressable::URI.parse(Addressable::URI.unencode(link['href']))
                url.fragment = nil
            rescue => e
                next
            end
            
            if url.relative?
              url = @base.join(url) 
            end
            unless @links_todo.include? url.to_s or @links_found.include? url.to_s or url_blacklisted?(url.to_s)

                if url.host == host
                    @links_todo.push url.to_s 
                end  
                issue_connection()                                     
            end
        end
    end
   
    def issue_connection
      unless @links_todo.empty? or @connections > @CONCURRENT_CONNECTIONS
         make_connection(@links_todo.pop) 
      end
    end

    def make_connection(url)
        
        # Set the base for the first run.
        @base ||= Addressable::URI.parse(Addressable::URI.unencode(url))
        begin
            crawler_cancel_check()
            conn_opts = {:connect_timeout => 60, :inactivity_timeout => 60}
            req = EventMachine::HttpRequest.new(url, conn_opts).get :head => {"User-Agent" => "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html", 'Accept-Language' => 'ru,en-US', :cookies => {:country_iso => 'RU'}}, :redirects => 5
            #request in progress
            @connections += 1
            @requests += 1
            @session.increment :requests
            check_border_conditions if @links_found.size >= @min_parsed
            req.errback do |r| 
              process_response do
                @er << r
                @session.increment :connection_errors
                @logger.error "#{r.conn.uri} - #{r.error}"
              end  
            end
            @links_found.add(url) 
            
            # Callback to be executed when the request is finished.
            req.callback do
              process_response do 
                @logger.debug "#{url} loaded"
                if url_item_card?(url)
                  process_card(url, req) 
                end     
                get_inner_links(url, req.response)
                issue_connection() #if no links found on page, just to continue the chain
              end  
            end
        rescue Exception => e
            puts e.message
            if @connections == 0
              finalize do
                @session.update(status: "error", finish_time: Time.now.to_i)
                @logger.error "Parser crashed - #{e.message}"
              end
            end
        end
    end
    
    def process_stats_tick(tick_period, duration, links)
      return if (tick_period < 1)
      if (tick_period >= 1)
        @logger.info "Cnn:#{@connections} Td:#{@links_todo.size} FndLnk:#{links}(#{(links/(duration/60)).floor} Links/min) FndGoods:#{@cards_saved_counter}(#{(@cards_saved_counter/(duration/60)).floor} Goods/min) T:#{duration}"
        @tick_time = Time.now
      end
    end
    
    def check_border_conditions
      if ((Time.now - @start_time)/60)>= @max_time
        finalize do
          @session.update(status: "error", finish_time: Time.now.to_i)
          @logger.error "Maximum running time of #{@max_time} mins reached. Stopping ..."
        end
      elsif (@cards_counter.to_f/@links_found.size) < @threshold
        finalize do
          @session.update(status: "error", finish_time: Time.now.to_i)
          @logger.error "Maximum effective parsing threshold of #{@threshold} reached. Stopping ..."
        end
      end 
    end
    
    def crawler_cancel_check
      if @cancel_check .call()
        finalize do
          @session.update(status: "stopped", finish_time: Time.now.to_i)
          @logger.info "Received manual terminatation signal. Stopping ..."
        end       
      end
    end
    
    def process_card(url, req)
      @cards_counter += 1
      parser = SidekiqCrawler::CardParser.new(url, @selectors)
      parser.set_page(req.response)
      results = parser.parse
      if !results.empty?
        item = Item.find_or_create_by(url: url, crawler_id: @crawler_id)
        item.update(results.merge({:url => url, :domain_url => @base}))
        @cards_saved_counter += 1
        @session.increment :items
      end  
    rescue SidekiqCrawler::CrawlerCardError => e
      @cards_errors_counter += 1
      @session.increment :parse_errors
      @logger.error "#{url} - #{e.selector_message}"    
    rescue => e
      @cards_errors_counter += 1
      @session.increment :parse_errors
      @logger.error "#{url} - #{e.message}" 
    end
    
    def process_response
      @connections -= 1
      links, duration, tick_period = @links_found.size, Time.now - @start_time, (Time.now - @tick_time)/60
      process_stats_tick(tick_period, duration, links)
      yield if block_given?
      if  (@links_todo.empty?) and (@max_retries > 0) and (!@er.empty?) and @connections == 0
        @er.each{|e| @links_todo.push Addressable::URI.unencode(e.conn.uri)}
        @er = []
        10.times{ issue_connection() }
        @max_retries -= 1  
      end
      if @links_todo.empty? and @connections == 0
        finalize do
          @session.update(status: "finished", finish_time: Time.now.to_i)
          @logger.info "Successfully finished #{@url} parsing task" 
        end
      end
    end
    
    def finalize
      return if @finalized
      @finalized = true
      EM.add_shutdown_hook do
        yield if block_given?
        @logger.info "Finished in #{Time.now - @start_time}" 
        @logger.info "Connection errors: #{@er.size} "
        @logger.info "Processed total links: #{@links_found.size}"
        @logger.info "Processed card links: #{@cards_counter}"
        @logger.info "Succesfully processed card links: #{@cards_saved_counter}"
        @logger.info "Failed card links: #{@cards_errors_counter} "
      end  
      EM.stop
    end
    
    def purge_items(id)
      Item.where(crawler_id: id).delete_all
    end

  # EventMachine reactor loop.
    def go()
      purge_items(@crawler_id)
      EM.run do
        @start_time = @tick_time = Time.now
        @logger.info "Crawler started"
        @session.update(crawler_id: @crawler_id, start_time: @start_time.to_i, name: @name, url: @url, status: "running")
        make_connection(@url)
      end 
    rescue Exception => e
      puts e.message
      puts e.backtrace
      @logger.error "CRITICAL. Terminated - #{e.message}"
      @logger.info "Finished in #{Time.now - @start_time}" 
      @logger.info "Connection errors: #{@er.size} "
      @logger.info "Processed total links: #{@links_found.size}"
      @logger.info "Processed card links: #{@cards_counter}"
      @logger.info "Succesfully processed card links: #{@cards_saved_counter}"
      @logger.info "Failed card links: #{@cards_errors_counter} "
    end      
  end
end  
