require 'eventmachine'
require 'em-http-request'
require 'nokogiri'
require 'set'
require 'open-uri'
require 'time'
require_relative './card_parser'

module SidekiqCrawler
  class EventedCrawler
    include EM::Protocols
    
    def initialize(url, selectors,blacklist_url_patterns, item_url_patterns )
      @url = url
      @selectors = selectors
      @blacklisted = blacklist_url_patterns
      @card_url_pattern = item_url_patterns
      @links_found = Set.new
      @links_todo = []
      @connections = 0
      @CONCURRENT_CONNECTIONS = 50
      @er = []
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
                issue_more_connections(base, depth)                                       
            end
        end
    end
    
    def get_er
      @er
    end
    
    def issue_more_connections(base, depth)
      unless @links_todo.empty? or @connections > @CONCURRENT_CONNECTIONS
         make_connection(@links_todo.pop, base, depth+1) 
      end
    end

    def make_connection(url, base=nil, depth=0)
        # Set the base for the first run.
        base ||= URI.parse(url)
        begin
            conn_opts = {:connect_timeout => 60}
            req = EventMachine::HttpRequest.new(url, conn_opts).get :head => {"User-Agent" => "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html"}
            #request in progress
            @connections += 1
            req.errback{|er| @er << er; @connections -= 1}

            @links_found.add(url) 

            # Callback to be executed when the request is finished.
            req.callback do
              begin
                  # This request is finished.
                  @connections -= 1

                  links, duration = @links_found.size, Time.now - @start_time 
                  puts "Cnn:#{@connections} Td:#{@links_todo.size} Fnd:#{links} T:#{duration} Rt:#{links/duration} Fnd/s"
                  
                  if url_item_card?(url)
                    begin
                      parser = SidekiqCrawler::CardParser.new(url, @selectors)
                      parser.set_page(req.response)
                      results = parser.parse
                    rescue => e
                      puts e.message
                    end    
                    #save them in defer call
                  end

                  # Process the links in the response.
                  get_inner_links(url, req.response, base, depth)
                  issue_more_connections(base, depth) 
                  # If there are no more links to process and no ongoing connections, we can quit.
                  if @links_todo.empty? and @connections == 0
                      EM.stop
                  end
              rescue => e
                EM.stop
                raise e
              end   
            end
        rescue => e
            @er << e
            if @connections == 0
                puts "Parsing error."
                EM.stop
            end
        end
    end

  # EventMachine reactor loop.
    def go
      EM.run do
       EM.kqueue  
          @start_time = Time.now
          make_connection(@url)
      end
    end      
  end
end  
