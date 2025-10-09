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
    # 送信完了画面
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
end

