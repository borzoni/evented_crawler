require 'sidekiq/api'
module SidekiqHelper
  class Client
    def initialize(crawler)
      @crawler = crawler
    end
    
    def start_crawler()
      args = fetch_args()
      jid = Sidekiq::Client.push({
        'class' => SidekiqCrawler::Worker::CrawlerInstanceWorker,
        'queue' => 'crawlers',
        'args'  => args
      })
      time = Time.now
      until in_progress?  
       return if (Time.now - time) > 6
       next   
      end
    end
    
    def in_progress?
      w =Sidekiq::Workers.new
      w.each do |process_id, thread_id, work|
        if work["payload"]["class"] == "SidekiqCrawler::Worker::CrawlerInstanceWorker"
          return true if @crawler.id == work["payload"]["args"][1]
        end
      end
      q = Sidekiq::Queue.new "crawlers"
      d = Sidekiq::ScheduledSet.new
      d.each do |c|
        return true if c.klass == "SidekiqCrawler::Worker::CrawlerInstanceWorker" and c.args[1] == @crawler.id
      end
      q.each do |c|
        return true if c.klass == "SidekiqCrawler::Worker::CrawlerInstanceWorker" and c.args[1] == @crawler.id
      end 
      false  
    end
    
    def schedule_crawler()
      name = "CrawlerPeriodicJob_#{@crawler.id}"
      args = fetch_args()
      Sidekiq::Cron::Job.destroy name
      job = Sidekiq::Cron::Job.new(name: name, cron: @crawler.periodicity, args: args, queue: 'crawlers', class: 'SidekiqCrawler::Worker::CrawlerInstanceWorker')
      if job.valid?
        job.save
      else
        puts "CRON SIDEKIQ: #{job.errors}"
      end  
    end
    
    def stop_crawler()
      delete_from_queue() || delete_from_scheduled() || delete_from_running()
      time = Time.now
      while in_progress?
       return if (Time.now - time) > 10
       next   
      end
    end
    
    
    
    private
    def fetch_args
      @args ||= [@crawler.name, @crawler.id, @crawler.url, @crawler.selectors, @crawler.blacklist_url_patterns, @crawler.item_url_patterns, @crawler.items_threshold, @crawler.max_work_time, @crawler.min_items_parsed, @crawler.concurrency_level]
    end
    
    def delete_from_queue
      q = Sidekiq::Queue.new "crawlers"
      return delete_from(q)
    end
    
    def delete_from_scheduled
      s = Sidekiq::ScheduledSet.new
      return delete_from(s)
    end
    
    def delete_from_running
      jid = find_jid()
      return false if !jid
      SidekiqCrawler::Worker::CrawlerInstanceWorker.cancel!(jid)
      return true
    end
    
    def delete_from(source)
      source.each do |c|
        (c.delete and return true) if c.klass == "SidekiqCrawler::Worker::CrawlerInstanceWorker" and c.args[1] == @crawler.id
      end
      false
    end
    
    def find_jid
      w =Sidekiq::Workers.new
      w.each do |process_id, thread_id, work|
        return work['payload']['jid'] if work["payload"]["class"] == "SidekiqCrawler::Worker::CrawlerInstanceWorker" and @crawler.id == work["payload"]["args"][1]
      end
      nil
    end
    
  end
end
