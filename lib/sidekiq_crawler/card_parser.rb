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
        temp = JSON.parse(v)
        next if temp['selector_text'] == ''
        result[k] = nil
        req = temp['req']
        text = temp['selector_text']
        eval_flag = false
        
        if text[/\(*page/]
          eval_flag = true
        end
        begin
          res = apply_selectors(@page, text, eval_flag) 
        rescue Exception => e
          raise SidekiqCrawler::CrawlerCardError.new(k, "selector expression invalid #{text} #{e.message}", :invalid) 
        end
        raise SidekiqCrawler::CrawlerCardError.new(k,"required selector #{k} = #{text} not found", :not_found) if empty_selector?(res) and req=="true"
        next if empty_selector?(res)
        result[k] = res
      end
      result
    end
    
    private
    def normalize_results(input)
      return normalize_str(input) if (input.instance_of? String) 
      return input if  ([true, false].include? input) ||(input.is_a?(Numeric))
      if input.instance_of?(Nokogiri::XML::Node) || input.instance_of?(Nokogiri::XML::NodeSet)
        return input.text
      elsif input.instance_of?(Array)
        return input.map{|e| normalize_results(e)}
      else
        return input  
      end      
    end
    
    def empty_selector?(s)
      return false if  s.is_a?(Numeric)
      return (!s||s==""||s.empty?)
    end
    
    def normalize_str(str)
      str.strip.gsub(/\s+/, " ")
    end
    
    def apply_selectors(page,selector, eval_flag)
      eval_flag ? result= eval(selector) : result = page.css(selector)
      normalize_results(result)   
    end

  end
end  
