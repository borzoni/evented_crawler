class ParsedItemsController < ApplicationController
  before_filter :load_crawler
  
  def index
    @parsed_items = @crawler.parsed_items.all
  end
  
  private
  def load_crawler
    @crawler = Crawler.find(params[:crawler_id])
  end
end
