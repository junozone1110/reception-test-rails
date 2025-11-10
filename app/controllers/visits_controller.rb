class VisitsController < ApplicationController
  before_action :set_employee, only: [:new]
  
  def new
    @visit = Visit.new(employee: @employee)
  end

  def create
    @visit = VisitService.new.create_visit(visit_params, session: session)
    
    redirect_to complete_path, notice: "通知を送信しました"
  rescue VisitCreationError => e
    Rails.logger.error "Visit creation failed: #{e.message}"
    @employee = Employee.find_by(id: visit_params[:employee_id])
    flash.now[:alert] = "送信に失敗しました。もう一度お試しください。"
    render :new, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "Unexpected error in visit creation: #{e.message}"
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
    @visit = Visit.includes(:employee).find(params[:id])
    render json: {
      status: @visit.status,
      status_text: @visit.status_text,
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
end

