class CrawlerForm
  include ActiveModel::Model 
  
  validate :validate_wrapped
  
  delegate :name, :url, :periodicity, :items_threshold, :min_items_parsed, :max_work_time, :concurrency_level, :id, to: :crawler
   
  attr_accessor   :crawler, :test_url
      
  def initialize(obj=nil)
    @crawler = obj || Crawler.new
    assign_hstore_attrs(@crawler.try(:selectors))
  end
  
  #blacklist_url_patterns field is an array, convert it to show as a string in a view
  def blacklist_url_patterns 
    @crawler.blacklist_url_patterns.join("\r\n")
  end
  
  #item_url_patterns field is an array, convert it to show as a string in a view
  def item_url_patterns 
    @crawler.item_url_patterns.join("\r\n")  if @crawler.item_url_patterns
  end
  
  
  #decorated to allow calling hash in <hash.field> fashion(needed to integrate with simple_form) 
  def selectors 
    CrawlerSelectorsDecorator.new(@selectors)
  end
  
  def process_params(params)
    new_params = params.slice(:name, :url, :periodicity, :blacklist_url_patterns, :item_url_patterns, :selectors, :items_threshold, :min_items_parsed, :max_work_time, :concurrency_level)
    new_params[:blacklist_url_patterns] = new_params[:blacklist_url_patterns].split(/\r\n/).map{|s| s.strip}.reject(&:empty?)
    new_params[:item_url_patterns] = new_params[:item_url_patterns].split(/\r\n/).map{|s| s.strip}.reject(&:empty?)
    new_params[:selectors].each{|k,v| new_params[:selectors][k] = v.to_json}
    crawler.update_attributes(new_params)
    assign_hstore_attrs(crawler.selectors) 
  end
  
  def assign_hstore_attrs(attributes) 
    @defined_selectors ||= [:item_name, :item_price, :item_brand, :item_desc,
                         :item_outer_category, :item_sizes, :item_sizes_scale,
                         :item_colors, :item_composition, :item_characteristics,
                          :item_main_img, :item_imgs, :item_availability ]
    @selectors = {}
    if attributes
      @defined_selectors.each{|s| @selectors[s] = JSON.parse(attributes[s.to_s], :symbolize_names => true)}
    else    
      @defined_selectors.each{|s| @selectors[s] = {req: 'false', selector_text: ''}}     
    end  
  end
  
  def self.model_name
    ActiveModel::Name.new(self, nil, "Crawler")
  end

  def persisted?
    false
  end
  
  def save
    @crawler.save! if valid?
  end 
  
  private
  
  def validate_wrapped
    if @crawler.invalid?
      promote_errors(crawler.errors)
    end
  end
  
  def promote_errors(wrapped_errors)
    wrapped_errors.each do |attribute, message|
      errors.add(attribute, message)
    end
  end
  
end

#rails5 bug - persisted always returns false, even if u redefine it
CrawlerForm.redefine_method "persisted?" do
  self.id.present?
end 

