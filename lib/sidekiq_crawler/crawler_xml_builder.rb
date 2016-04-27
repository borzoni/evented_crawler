require 'builder'
require 'yaml'
require 'active_record'
require 'digest/md5'



module SidekiqCrawler
  class Item < ActiveRecord::Base
    self.table_name = "parsed_items"
  end
  
  class Crawler < ActiveRecord::Base
    self.table_name = "crawlers"
  end
      
  class CrawlerXMLBuilder
    def initialize(crawler_id, file_path)
      dbconfig = YAML.load(File.read('lib/sidekiq_crawler/crawler_db.yml'))
      ActiveRecord::Base.establish_connection dbconfig
      @file = File.new(file_path, "wb")
      @crawler = Crawler.find(crawler_id)
      @builder = Builder::XmlMarkup.new(:target => @file, :indent=>2)
    end
    
    def generate
      @builder.yml_catalog(date: get_datetime(false)) do
        build_header(@builder)
        build_currencies(@builder)
        build_categories(@builder)
        build_offers(@builder)
      end  
      @file.close()
    end
    
    private
    def get_datetime(unix)
      return Time.now.to_i if unix
      return Time.now.strftime("%Y-%m-%d %H:%M")
    end
    
    def get_hexdigest(str)
      Digest::MD5.hexdigest(str)
    end
    
    def build_currencies(yml)
      yml.currencies do
        yml.currency id: "RUR", rate: 1
      end
    end
    
    def build_categories(yml)
      yml.categories do
        categories.each do |c|
          yml.category c, id: get_hexdigest(c)[0..4]
        end    
      end
    end
    
    def build_header(yml)
      yml.name @crawler.name
      yml.company @crawler.name
      yml.url @crawler.url
    end
    
    def build_offer(yml, item, id)
      avlblty = item.item_availability||true
      category = item.item_outer_category.last if item.item_outer_category and (!item.item_outer_category.empty?)
      category = get_hexdigest(category) if category
      sizes = join_array(item.item_sizes)
      colors = join_array(item.item_colors)
      imgs = make_imgs_array(item)
      
      yml.offer(:available => item.item_availability||true, id: id ) do
        yml.categoryId category if category
        yml.currencyId "RUR" 
        yml.description(item.item_desc) if item.item_desc
        yml.modified_time(get_datetime(true))
        yml.name(item.item_name) if item.item_name
        yml.param(item.item_sizes_scale, name: "Размерная сетка") if item.item_sizes_scale
        yml.param(sizes, name: "Размеры") if sizes
        yml.param(item.item_composition, name: "Состав") if item.item_composition
        build_images(yml, imgs)
        yml.price(item.item_price) if item.item_price
        yml.url(item.url) if item.url
        yml.vendor(item.item_brand) if item.item_brand
      end  
    end
    
    def join_array(items_ar)
      return items_ar.join(", ") if items_ar and (!items_ar.empty?)
      return nil
    end
    
    def make_imgs_array(item)
      if item.item_imgs and (!item.item_imgs.empty?)
        imgs = item.item_imgs
      else
        imgs = []
      end
      imgs.unshift(item.item_main_img) if item.item_main_img
      return imgs
    end
    
    def build_offers(yml)
      i = 1
      yml.offers do 
        items.find_each do |item|
          build_offer(yml, item, i)
          i+= 1
        end  
      end
    end
    
    def build_images(yml, images)
      images.each do |img|
        yml.picture img
      end
    end
    
    def categories
      categories ||= Item.where(:crawler_id => @crawler.id).pluck(:item_outer_category).flatten.uniq
      return categories
    end
    def items
      items ||= Item.where(:crawler_id => @crawler.id)
      return items
    end
  end
end 

