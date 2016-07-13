class LandingsController < ApplicationController
  layout false
  def index
    if user_signed_in? 
       redirect_to dashboard_path
    end
  end
end
