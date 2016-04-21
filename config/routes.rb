Rails.application.routes.draw do
  root 'crawlers#index'
  resources :crawlers do
    resources :parsed_items, :only => [:index]
  end
  match "/test_crawler" => "crawlers#test", :via => :post
  get "/crawler_logs/:id", :to => "crawlers#crawler_logs"
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  # Serve websocket cable requests in-process
  # mount ActionCable.server => '/cable'
  require 'sidekiq/web'
  require 'sidekiq/cron/web'
  mount Sidekiq::Web => '/sidekiq'
end
