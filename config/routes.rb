Rails.application.routes.draw do
  root 'crawlers#index'
  resources :crawlers do
    resources :parsed_items, :only => [:index]
  end
  match "/test_selectors" => "crawlers#test_selectors", :via => :post
  match "/dashboard" => "crawlers#dashboard", :via => :get
  match "/test_url" => "crawlers#test_url", :via => :post
  match "/crawler_logs", :to => "crawlers#crawler_logs", via: [:get, :post]
  get "/start_crawler/:id", :to => "crawlers#start_crawler"
  get "/stop_crawler/:id", :to => "crawlers#stop_crawler"
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  # Serve websocket cable requests in-process
  # mount ActionCable.server => '/cable'
  require 'sidekiq/web'
  require 'sidekiq/cron/web'
  mount Sidekiq::Web => '/sidekiq'
end
