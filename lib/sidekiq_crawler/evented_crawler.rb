require 'eventmachine'
require 'em-http-request'
require 'nokogiri'
require 'set'
require 'open-uri'
require 'time'
require 'active_record'
require_relative './card_parser'

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
    
    def initialize(crawler_id, url, selectors,blacklist_url_patterns, item_url_patterns, logger, retries= nil )
      @url = url
      @max_retries = retries || 10;
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
    end

    def url_blacklisted?(url)
      @blacklisted.each do |p|
        r = Regexp.new(p)
        return true if url =~ r
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
                url = URI.parse(link['href'])
                url.fragment = nil
            rescue => e
                next
            end
            
            if url.relative?
              url = base.merge(url) 
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
        base ||= URI.parse(url)
        begin
            conn_opts = {:connect_timeout => 60, :inactivity_timeout => 60}
            req = EventMachine::HttpRequest.new(url, conn_opts).get :head => {"User-Agent" => "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html"}
            #request in progress
            @connections += 1
            req.errback do |r| 
              @er << r
              @connections -= 1
              @logger.error "#{r.conn.uri} - #{r.error}"
            end
            @links_found.add(url) 

            # Callback to be executed when the request is finished.
            req.callback do
                  # This request is finished.
                  @connections -= 1

                  links, duration = @links_found.size, Time.now - @start_time 
                  @logger.info "Cnn:#{@connections} Td:#{@links_todo.size} Fnd:#{links} T:#{duration} Rt:#{links/duration} Fnd/s"
                  
                  if url_item_card?(url)
                    @cards_counter += 1
                    begin
                      parser = SidekiqCrawler::CardParser.new(url, @selectors)
                      parser.set_page(req.response)
                      results = parser.parse
                      item = Item.find_or_create_by(url: url, crawler_id: @crawler_id)
                      item.update(results.merge({:url => url, :domain_url => base}))
                      @cards_saved_counter += 1
                      @logger.info "#{url} saved"
                    rescue => e
                      @cards_errors_counter += 1
                      @logger.error "#{url} - #{e.message}"
                    end 
                  end     


                  # Process the links in the response.
                  get_inner_links(url, req.response, base, depth)
                  issue_connection(base, depth) 
                  # If there are no more links to process and no ongoing connections, we can quit.
                  if  (@links_todo.empty?) and (@max_retries > 0) and (!@er.empty?)
                    until @er.empty?
                      uri = @er.pop.conn.uri
                      @links_todo.push uri
                      issue_connection(base, depth)
                    end
                    @max_retries -= 1  
                  end
                  if @links_todo.empty? and @connections == 0
                     finalize do
                       @logger.info "Successfully finished #{@url} parsing task" 
                     end
                  end
            end
        rescue => e
            @er << e
            if @connections == 0
              finalize do
                logger.error "Parser crashed - #{e.message}"
              end
            end
        end
    end
    
    def finalize
      yield if block_given?
      @logger.info "Finished in #{Time.now - @start_time}" 
      @logger.info "Connection errors: #{@er.size} "
      @logger.info "Processed total links: #{@links_found.size}"
      @logger.info "Processed card links: #{@cards_counter}"
      @logger.info "Succesfully processed card links: #{@cards_saved_counter}"
      @logger.info "Failed card links: #{@cards_errors_counter} "
      EM.stop
    end

  # EventMachine reactor loop.
    def go
      EM.run do
       EM.kqueue  
          @start_time = Time.now
          @logger.info "Crawler started: #{@start_time}"
          make_connection(@url)
      end
    end      
  end
end  
