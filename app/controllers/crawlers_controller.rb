class CrawlersController < ApplicationController
  before_action :set_crawler, only: [:show, :edit, :update, :destroy]

  # GET /crawlers
  # GET /crawlers.json
  def index
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
    #raise(params[:test_crawler].inspect)
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
    render :json => {error: "Bad inputs"}    
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

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_crawler
      @crawler = Crawler.find(params[:id])
    end
    
    def start_cron_job(crawler)
      name = "CrawlerJob_#{crawler.id}"
      args = [crawler.url, crawler.selectors, crawler.blacklist_url_patterns, crawler.item_url_patterns]
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
      params.require(:crawler).permit(:name, :test_url, :url, :periodicity, :item_url_patterns, :selectors, :blacklist_url_patterns, selectors: permit_recursive_params(params[:crawler][:selectors])) 
    end
    
end
