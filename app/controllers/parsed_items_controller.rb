class ParsedItemsController < ApplicationController
  before_filter :load_crawler
  
  def index
    if !params[:field]
      @parsed_items = @crawler.parsed_items
    else
      @parsed_items = @crawler.parsed_items.where(params[:field].to_sym => nil)
    end   
    @parsed_items = @parsed_items.paginate(:page =>params[:page] , :per_page => 50) 
    if !@parsed_items.empty?
      @stats = calculate_percentages()
    end  
  end
  
  private
  def load_crawler
    @crawler = Crawler.find(params[:crawler_id])
  end
  
  def calculate_percentages
    stats = {}
    total_size = @crawler.parsed_items.size
    selectors = ParsedItem.column_names.select{|i| i.starts_with?("item")}
    selectors.each do |s|
      found = @crawler.parsed_items.where("#{s} is NOT NULL").size
      stats[s.to_sym] = {count: found , percentage: (found/total_size.to_f * 100).floor}
    end
    stats
  end
end
