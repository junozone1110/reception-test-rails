class VisitsController < ApplicationController
  before_action :set_employee, only: [:new]
  
  def new
    @visit = Visit.new(employee: @employee)
  end

  def create
    @visit = Visit.new(visit_params)
    
    if @visit.save
      # Slack通知ジョブをキューに追加（非同期）
      SlackNotificationJob.perform_later(@visit.id)
      
      # セッションにvisit_idを保存（ポーリング用）
      session[:last_visit_id] = @visit.id
      
      redirect_to complete_path, notice: "通知を送信しました"
    else
      @employee = @visit.employee
      flash.now[:alert] = "送信に失敗しました。もう一度お試しください。"
      render :new, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "Visit creation failed: #{e.message}"
    @employee = Employee.find_by(id: visit_params[:employee_id])
    flash.now[:alert] = "エラーが発生しました。しばらくしてからお試しください。"
    render :new, status: :internal_server_error
  end

  def complete
    @visit = Visit.find(session[:last_visit_id]) if session[:last_visit_id]
  rescue ActiveRecord::RecordNotFound
    @visit = nil
  end

  def status
    @visit = Visit.find(params[:id])
    render json: {
      status: @visit.status,
      status_text: status_text(@visit.status),
      responded: @visit.responded?,
      updated_at: @visit.updated_at.iso8601
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "訪問記録が見つかりません" }, status: :not_found
  end

  private

  def set_employee
    @employee = Employee.active.find(params[:employee_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "従業員が見つかりません"
  end

  def visit_params
    params.require(:visit).permit(:employee_id, :notes)
  end

  def status_text(status)
    case status
    when "going_now"
      "すぐ行きます"
    when "waiting"
      "お待ちいただく"
    when "no_match"
      "心当たりがない"
    else
      "確認待ち"
    end
  end
end

