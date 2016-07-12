class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.

  protect_from_forgery with: :exception
  def resource_name
    :user
  end
  
  def after_sign_in_path_for(resource)
    if resource.class == User
      dashboard_path 
    end
  end

  def resource
    @resource ||= User.new
  end

  def devise_mapping
    @devise_mapping ||= Devise.mappings[:user]
  end
  helper_method :resource, :resource_name, :devise_mapping
  protected
  def permit_recursive_params(params)
      params.map do |key, value|
        if value.is_a?(Array)
          { key => [ permit_recursive_params(value.first) ] }
        elsif value.is_a?(Hash) || value.is_a?(ActionController::Parameters)
          { key => permit_recursive_params(value) }
        else
          key
        end
      end
    end  
end
