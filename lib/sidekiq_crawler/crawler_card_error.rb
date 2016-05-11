module SidekiqCrawler
  class CrawlerCardError < StandardError
    def initialize(selector, message, type=:invalid)
      @selector = selector
      @mes = message
      @type = type
    end
    
    def message
      @mes
    end
    
    def selector_message
      return "selector #{@selector} is invalid" if @type==:invalid
      return "required selector #{@selector} is not found" if @type==:not_found
      return @mes if @type==:type_error
    end
  end
end
