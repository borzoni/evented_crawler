require 'nokogiri'
require 'typhoeus'
require 'json'
require_relative './crawler_card_error'

module SidekiqCrawler
  class CardParser
    
    def initialize(url, settings)
     @url = url
     @settings = settings.symbolize_keys
     fill_types()
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
        check_field(k, res) #check types
        result[k] = res
      end
      convert_to_json(result)
    end
    
    private
    def fill_types
     @field_checker = {}
     @field_checker[:item_brand]=@field_checker[:item_brand]=@field_checker[:item_name]=@field_checker[:item_desc]=@field_checker[:item_sizes_scale]=@field_checker[:item_main_img] = String
     @field_checker[:item_outer_category] = @field_checker[:item_sizes] = @field_checker[:item_colors] = @field_checker[:item_imgs] = @field_checker[:item_composition] = [lambda{|i| i.instance_of?(Array) and i.all?{|j| j.instance_of?(String)}}, "Array of Strings"]  
     @field_checker[:item_availability] = [lambda{|i| [true, false].include?(i)}, "Boolean"]
     @field_checker[:item_characteristics] = [lambda{|i| i.instance_of?(Array) and i.all?{|j| j.instance_of?(Hash)}}, "Array of Hashes"]
    end
    
    def check_field(selector_key, input)
      check = @field_checker[selector_key.to_sym]
      return if !check
      if check.instance_of?(Class)
        make_type_error(selector_key, check.class, input.class)  if !input.instance_of?(check) 
      elsif check.instance_of?(Array)
        make_type_error(selector_key, check[1], input.class) if !(check[0].call(input))  
      end
    end
    
    def normalize_results(input)
      return normalize_str(input) if (input.instance_of? String) 
      return input if  ([true, false].include? input) ||(input.is_a?(Numeric))
      if input.instance_of?(Nokogiri::XML::Node) || input.instance_of?(Nokogiri::XML::NodeSet)
        return normalize_str(input.text)
      elsif input.instance_of?(Array)
        return input.map{|e| normalize_results(e)}
      elsif input.instance_of?(Hash)
        return stringify_hash(input)
      else
        return input  
      end      
    end
    
    def types_convert(a)
       return a.map{|el| Hash[*el]} if a.instance_of?(Array) and a.all?{|j| j.instance_of?(Array) and j.size == 2}  #hash supposed
       return a
    end
    
    def empty_selector?(s)
      return false if  s.is_a?(Numeric)
      return (s==nil||(instance_of?(Array) and s.empty?))
    end
    
    def normalize_str(str)
      str.strip.gsub(/\s+/, " ")
    end
    
    def stringify_hash(h)
      h.inject({}) do |options, (key, value)|
        skey = normalize_str(key.to_s)
        svalue =  normalize_str(value.to_s)
        options[skey] = svalue
        options
      end
    end
    
    def apply_selectors(page,selector, eval_flag)
      eval_flag ? result= eval(selector) : result = page.css(selector)
      res  = normalize_results(types_convert(result))
    end
    
    def make_type_error(selector, expected, got)
     raise SidekiqCrawler::CrawlerCardError.new(selector, "#{selector} invalid. Expected #{expected}, got #{got}", :type_error)
    end
    
    def convert_to_json(res)
      if res["item_characteristics"] 
        res["item_characteristics"] = res["item_characteristics"].to_json
      end
      res
    end

  end
end  
