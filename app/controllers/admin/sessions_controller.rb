class Admin::SessionsController < ApplicationController
  layout "admin"

  def new
    # ログイン画面
    redirect_to admin_root_path if current_admin_user
  end

  def create
    admin_user = AdminUser.find_by(email: params[:email])
    
    if admin_user&.authenticate(params[:password])
      session[:admin_user_id] = admin_user.id
      redirect_to admin_root_path, notice: "ログインしました"
    else
      flash.now[:alert] = "メールアドレスまたはパスワードが正しくありません"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:admin_user_id)
    redirect_to admin_login_path, notice: "ログアウトしました"
  end

  private

  def current_admin_user
    @current_admin_user ||= AdminUser.find_by(id: session[:admin_user_id]) if session[:admin_user_id]
  end
  helper_method :current_admin_user
end

