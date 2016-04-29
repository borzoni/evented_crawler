#ToDo factor out all sidekiq manipulation to helper class 
require 'sidekiq/api'
class CrawlersController < ApplicationController
  before_action :set_crawler, only: [:show, :edit, :update, :destroy, :crawler_logs, :start_crawler, :stop_crawler]

  # GET /crawlers
  # GET /crawlers.json
  def index
    @in_progress = {}
    @crawlers = Crawler.all
    @crawlers.each do |c|
      job = SidekiqHelper::Client.new(c)
      @in_progress[c.id] = job.in_progress? 
    end  
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
        SidekiqHelper::Client.new(@crawler_form.crawler).schedule_crawler()
        format.html { redirect_to @crawler_form.crawler, notice: 'Crawler was successfully created.' }
        format.json { render :show, status: :created, location: @crawler_form.crawler }
      else
        format.html { render :new }
        format.json { render json: @crawler_form.errors, status: :unprocessable_entity }
      end
    end
  end
  
  def test_selectors
    selectors = {}
    crawler_params["selectors"].each{|k,v| selectors[k] = v.to_json}
    parser = SidekiqCrawler::CardParser.new crawler_params["test_url2"], selectors
    results = parser.fetch_page.parse
    render :json => results
  rescue SidekiqCrawler::CrawlerCardError => e
    render :json => {error: e.message}  
  rescue => e
    render :json => {error: "Bad input: #{e.message} "}    
  end
  
  def test_url
    black_patters = crawler_params["blacklist_url_patterns"].split(/\r\n/).map{|s| s.strip}.reject(&:empty?)
    item_patterns = crawler_params["item_url_patterns"].split(/\r\n/).map{|s| s.strip}.reject(&:empty?) 
    checker = SidekiqCrawler::UrlChecker.new(black_patters, item_patterns, crawler_params["test_url1"].strip)
    blacklisted = checker.blacklisted?
    item = checker.item?
    render :json => [blacklisted, item]
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
        SidekiqHelper::Client.new(@crawler_form.crawler).schedule_crawler()
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
   @logs = analyzer.get_lines(@level, @include_upper).paginate(:page =>params[:page] , :per_page => 1000) 
  end
  
  def start_crawler
    SidekiqHelper::Client.new(@crawler).start_crawler()   
    respond_to do |format|
      format.html {redirect_to crawlers_path, notice: 'Crawler was started' } 
    end  
  end
  
  def stop_crawler
    SidekiqHelper::Client.new(@crawler).stop_crawler()   
    respond_to do |format|
      format.html {redirect_to crawlers_path, notice: 'Crawler was stopped' } 
    end  
  end
  
  

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_crawler
      @crawler = Crawler.find(params[:id])
    end
    
    # Never trust parameters from the scary internet, only allow the white list through.
    def crawler_params
      params.require(:crawler).permit(:name, :test_url1,:test_url2, :url, :periodicity, :item_url_patterns, :selectors, :items_threshold, :min_items_parsed, :concurrency_level, :max_work_time, :blacklist_url_patterns, selectors: permit_recursive_params(params[:crawler][:selectors])) 
    end
    
end
