#ToDo factor out all sidekiq manipulation to helper class 
require 'sidekiq/api'
class CrawlersController < ApplicationController
  before_action :set_crawler, only: [:show, :edit, :update, :destroy, :crawler_logs, :start_crawler]

  # GET /crawlers
  # GET /crawlers.json
  def index
     @in_progress = {}
     
     w =Sidekiq::Workers.new
     w.each do |process_id, thread_id, work|
       if work["payload"]["class"] == "SidekiqCrawler::Worker::CrawlerInstanceWorker"
         id = work["payload"]["args"][1]
         @in_progress[id] = true
       end
     end
     q = Sidekiq::Queue.new "crawlers"
     d = Sidekiq::ScheduledSet.new
     d.each do |c|
       @in_progress[c.args[1]] = true if c.klass == "SidekiqCrawler::Worker::CrawlerInstanceWorker"
     end
     q.each do |c|
       @in_progress[c.args[1]] = true if c.klass == "SidekiqCrawler::Worker::CrawlerInstanceWorker"
     end 
    @crawlers = Crawler.all
  end

  # GET /crawlers/1
  # GET /crawlers/1.json
  def show
  end

  # GET /crawlers/new
  def new
    @crawler_form = CrawlerForm.new 
  end

  # GET /crawlers/1/edit
  def edit
    @crawler_form = CrawlerForm.new @crawler
  end

  # POST /crawlers
  # POST /crawlers.json
  def create
    @crawler_form = CrawlerForm.new
    @crawler_form.process_params(crawler_params)
    respond_to do |format|
      if @crawler_form.save
        start_cron_job @crawler_form.crawler
        format.html { redirect_to @crawler_form.crawler, notice: 'Crawler was successfully created.' }
        format.json { render :show, status: :created, location: @crawler_form.crawler }
      else
        format.html { render :new }
        format.json { render json: @crawler_form.errors, status: :unprocessable_entity }
      end
    end
  end
  
  def test
    selectors = {}
    crawler_params["selectors"].each{|k,v| selectors[k] = v.to_json}
    parser = SidekiqCrawler::CardParser.new crawler_params["test_url"], selectors
    results = parser.fetch_page.parse
    render :json => results
  rescue SidekiqCrawler::CrawlerCardError => e
    render :json => {error: e.message}  
  rescue => e
    render :json => {error: "Bad input: #{e.message} "}    
  end

  # PATCH/PUT /crawlers/1
  # PATCH/PUT /crawlers/1.json
  def update
    @crawler_form = CrawlerForm.new @crawler
    @crawler_form.process_params(crawler_params)
    respond_to do |format|
      if @crawler_form.save
        start_cron_job @crawler_form.crawler
        format.html { redirect_to @crawler_form.crawler, notice: 'Crawler was successfully updated.' }
        format.json { render :show, status: :ok, location: @crawler_form.crawler }
      else
        format.html { render :edit }
        format.json { render json: @crawler_form.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /crawlers/1
  # DELETE /crawlers/1.json
  def destroy
    @crawler.destroy
    respond_to do |format|
      format.html { redirect_to crawlers_url, notice: 'Crawler was successfully destroyed.' }
      format.json { head :no_content }
    end
  end
  
  def crawler_logs
   #f= File.join(Rails.root, 'log', "#{@crawler.name}_evented_crawler.log") 
   #if File.exists?(f)
   #   @text = `tail -n 5000 #{f}`
   #   render :text => "<pre>" + @text.gsub("\n",'<br />') + "</pre>"
   #else
   #  render :text => "No logs found"
   #end
   #raise(params.inspect)
   filepath = "log/#{@crawler.name}_evented_crawler.log"
   analyzer = LogAnalyzer::Analyzer.new(filepath)
   @level = params[:level] || "INFO"
   @include_upper = params[:include_upper] == "true" || params[:include_upper] == "1"
   @counts = analyzer.get_counts
   @filters_select = analyzer.levels.map{|l| ["#{l}(#{@counts[l.downcase.to_sym]})", l]} #for select tag
   @logs = analyzer.get_lines(@level, @include_upper).paginate(:page =>params[:page] , :per_page => 10) 
  end
  
  def start_crawler
    crawler = @crawler
    args = [crawler.name, crawler.id, crawler.url, crawler.selectors, crawler.blacklist_url_patterns, crawler.item_url_patterns, crawler.items_threshold, crawler.max_work_time, crawler.min_items_parsed, crawler.concurrency_level]
    jid = Sidekiq::Client.push({
        'class' => SidekiqCrawler::Worker::CrawlerInstanceWorker,
        'queue' => 'crawlers',
        'args'  => args
    })
    sleep(2) # to test queue update.   
    #SidekiqCrawler::Worker::CrawlerInstanceWorker.perform_async(args)
    respond_to do |format|
      format.html {redirect_to crawlers_path, notice: 'Crawler was started' } 
    end  
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_crawler
      @crawler = Crawler.find(params[:id])
    end
    
    def start_cron_job(crawler)
      name = "CrawlerJob_#{crawler.id}"
      args = [crawler.name, crawler.id, crawler.url, crawler.selectors, crawler.blacklist_url_patterns, crawler.item_url_patterns, crawler.items_threshold, crawler.max_work_time, crawler.min_items_parsed, crawler.concurrency_level]
      Sidekiq::Cron::Job.destroy name
      job = Sidekiq::Cron::Job.new(name: name, cron: crawler.periodicity, args: args, queue: 'crawlers', class: 'SidekiqCrawler::Worker::CrawlerInstanceWorker')
      if job.valid?
        job.save
      else
        puts "CRON SIDEKIQ: #{job.errors}"
      end  
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def crawler_params
      params.require(:crawler).permit(:name, :test_url, :url, :periodicity, :item_url_patterns, :selectors, :items_threshold, :min_items_parsed, :concurrency_level, :max_work_time, :blacklist_url_patterns, selectors: permit_recursive_params(params[:crawler][:selectors])) 
    end
    
end
