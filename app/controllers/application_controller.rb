class ApplicationController < ActionController::Base
  before_action :require_login

  private

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  rescue ActiveRecord::RecordNotFound
    session[:user_id] = nil
  end

  def require_login
    unless current_user
      redirect_to login_path, alert: "Please log in to access this page."
    end
  end

  def logged_in?
    !!current_user
  end

  helper_method :current_user, :logged_in?
end
