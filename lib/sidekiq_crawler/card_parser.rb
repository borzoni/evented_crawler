require 'nokogiri'
require 'typhoeus'
require 'json'
require_relative './crawler_card_error'

module SidekiqCrawler
  class CardParser
    def initialize(url, settings)
     @url = url
     @settings = settings.symbolize_keys   
    end
    
    def fetch_page
      @page ||= Nokogiri::HTML(Typhoeus.get(@url, followlocation: true).body)
      self
    end
    
    def set_page(page)
      @page = Nokogiri::HTML(page)
    end
    
    def parse
      result = {}
      @settings.each do |k, v|
        result[k] = nil
        temp = JSON.parse(v)
        next if temp['selector_text'] == ''
        
        req = temp['req']
        text = temp['selector_text']
        eval_flag = false
        
        if text.start_with?('page') 
          eval_flag = true
        end
        begin
          res = apply_selectors(@page, text, eval_flag) 
        rescue
          raise SidekiqCrawler::CrawlerCardError , "selector expression invalid" 
        end
        raise SidekiqCrawler::CrawlerCardError , "required selector not found" if res.empty? and req=="true"
        next if res.empty?
        
        case k
        when  :item_name, :item_brand, :item_desc, :item_main_img, :item_sizes_scale, :item_characteristics
          result[k] = res.first.text 
        when :item_price
          result[k] = res.first.text.try(:to_i)  
        when  :item_outer_category, :item_sizes, :item_colors, :item_composition, :item_imgs
          temp_ar = []
          res.each do |r|
            temp_ar << r.text 
          end
           result[k] = temp_ar  
        when :item_availability
          result[k] = res || (!res.empty?)
        end  
      end
      result
    end
    
    private
    def apply_selectors(page,selector, eval_flag)
      if eval_flag
        return eval(selector)
      else
        page.css(selector)
      end    
    end

  end
end  
