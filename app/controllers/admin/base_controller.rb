class Admin::BaseController < ApplicationController
  before_action :require_admin_login
  layout "admin"

  private

  def require_admin_login
    unless current_admin_user
      redirect_to admin_login_path, alert: "ログインが必要です"
    end
  end

  def current_admin_user
    @current_admin_user ||= AdminUser.find_by(id: session[:admin_user_id]) if session[:admin_user_id]
  end
  helper_method :current_admin_user
end

