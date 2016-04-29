module SidekiqCrawler
  class UrlChecker
    include UrlCheckable
    
    def initialize(black_patterns, item_patters, url)
      @blacklisted = black_patterns
      @card_url_pattern = item_patters
      @url = url
    end
    
    def blacklisted?
      url_blacklisted?(@url)
    end
    
    def item?
      url_item_card?(@url)
    end
  end
end  
