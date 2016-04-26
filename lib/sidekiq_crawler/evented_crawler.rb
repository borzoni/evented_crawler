require 'eventmachine'
require 'em-http-request'
require 'nokogiri'
require 'set'
require 'addressable/uri'
require 'time'
require 'active_record'
require_relative './card_parser'
require_relative './crawler_card_error'

module SidekiqCrawler
        ActiveRecord::Base.establish_connection(
          :adapter  => "postgresql",
          :host     => "localhost",
          :username => "crawlers_user",
          :password => "12345",
          :database => "cloth_crawlers",
          :port => 5432
      )


      class Item < ActiveRecord::Base
        self.table_name = "parsed_items"
      end
      
  class EventedCrawler
    include EM::Protocols
    
    def initialize(crawler_id, url, selectors,blacklist_url_patterns, item_url_patterns, logger, threshold, max_time, min_parsed, retries= nil )
      @url = url
      @threshold = threshold
      @max_time = max_time
      @min_parsed = min_parsed
      @max_retries = retries || 5;
      @crawler_id = crawler_id
      @selectors = selectors
      @blacklisted = blacklist_url_patterns
      @card_url_pattern = item_url_patterns
      @links_found = Set.new
      @links_todo = []
      @connections = 0
      @CONCURRENT_CONNECTIONS = 50
      @er = []
      @logger = logger
      @cards_counter = 0
      @cards_saved_counter = 0
      @cards_errors_counter = 0
      @finalized = false
      @tick_time = nil
    end

    def url_blacklisted?(url)
      return true if (url =~/\.(png|jpg|jpeg|bmp)$/)
      @blacklisted.each do |p|
        r = Regexp.new(p)
        return true if (url =~ r)
      end  
      false
    end
    
    def url_item_card?(url)
      @card_url_pattern.each do |p|
        r = Regexp.new(p)
        return true if url =~ r
      end
      false      
    end

    def get_inner_links(root, content, base, depth)
        host = base.host
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
              url = base.join(url) 
            end
            unless @links_todo.include? url.to_s or @links_found.include? url.to_s or url_blacklisted?(url.to_s)

                if url.host == host
                    @links_todo.push url.to_s 
                end  
                issue_connection(base, depth)                                       
            end
        end
    end
    
    def get_er
      @er
    end
    
    def issue_connection(base, depth)
      unless @links_todo.empty? or @connections > @CONCURRENT_CONNECTIONS
         make_connection(@links_todo.pop, base, depth+1) 
      end
    end

    def make_connection(url, base=nil, depth=0)
        # Set the base for the first run.
        base ||= Addressable::URI.parse(Addressable::URI.unencode(url))
        begin
            conn_opts = {:connect_timeout => 60, :inactivity_timeout => 60}
            req = EventMachine::HttpRequest.new(url, conn_opts).get :head => {"User-Agent" => "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html", 'Accept-Language' => 'ru,en-US', :cookies => {:country_iso => 'RU'}}, :redirects => 5
            #request in progress
            @connections += 1
            req.errback do |r| 
              @er << r
              @connections -= 1
              @logger.error "#{r.conn.uri} - #{r.error}"
            end
            @links_found.add(url) 
            
            check_border_conditions if @links_found.size >= @min_parsed
            # Callback to be executed when the request is finished.
            req.callback do
                  # This request is finished.
                  @connections -= 1
                  @logger.debug "#{url} loaded"
                  links, duration, tick_period = @links_found.size, Time.now - @start_time, (Time.now - @tick_time)/60
                  process_stats_tick(tick_period, duration, links)
                  if url_item_card?(url)
                    @cards_counter += 1
                    begin
                      parser = SidekiqCrawler::CardParser.new(url, @selectors)
                      parser.set_page(req.response)
                      results = parser.parse
                      item = Item.find_or_create_by(url: url, crawler_id: @crawler_id)
                      item.update(results.merge({:url => url, :domain_url => base}))
                      @cards_saved_counter += 1
                    rescue SidekiqCrawler::CrawlerCardError => e
                      @cards_errors_counter += 1
                      @logger.error "#{url} - #{e.selector_message}"    
                    rescue => e
                      @cards_errors_counter += 1
                      @logger.error "#{url} - #{e.message}"
                    end 
                  end     


                  # Process the links in the response.
                  get_inner_links(url, req.response, base, depth)
                  issue_connection(base, depth) 
                  # If there are no more links to process and no ongoing connections, we can quit.
                  if  (@links_todo.empty?) and (@max_retries > 0) and (!@er.empty?) and @connections == 0
                    puts @max_retries, @er.size, @links_todo.size
                    @er.each{|e| @links_todo.push Addressable::URI.unencode(e.conn.uri)}
                    @er = []
                    10.times{ issue_connection(base, depth) }
                    @max_retries -= 1  
                  end
                  if @links_todo.empty? and @connections == 0
                     finalize do
                       @logger.info "Successfully finished #{@url} parsing task" 
                     end
                  end
            end
        rescue Exception => e
            puts e.message
            if @connections == 0
              finalize do
                logger.error "Parser crashed - #{e.message}"
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
          @logger.error "Maximum running time of #{@max_time} mins reached. Stopping ..."
        end
      elsif (@cards_counter.to_f/@links_found.size) < @threshold
        finalize do
          @logger.error "Maximum effective parsing threshold of #{@threshold} reached. Stopping ..."
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

  # EventMachine reactor loop.
    def go
      EM.run do
       EM.kqueue  
          @start_time = @tick_time = Time.now
          @logger.info "Crawler started"
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
