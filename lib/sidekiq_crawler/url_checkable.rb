require 'active_support/concern'

module SidekiqCrawler
  module UrlCheckable
    extend ActiveSupport::Concern
    
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
  end
end   
