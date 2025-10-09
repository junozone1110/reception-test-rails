# frozen_string_literal: true

class Admin::DepartmentsController < Admin::BaseController
  before_action :set_department, only: [:show, :edit, :update, :destroy]

  def index
    @departments = Department.ordered.includes(:employees)
  end

  def show
    @employees = @department.employees.order(is_active: :desc, name: :asc)
  end

  def new
    @department = Department.new
  end

  def create
    @department = Department.new(department_params)
    
    if @department.save
      redirect_to admin_departments_path, notice: "部署「#{@department.name}」を登録しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # @department は before_action で設定済み
  end

  def update
    if @department.update(department_params)
      redirect_to admin_departments_path, notice: "部署「#{@department.name}」の情報を更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    department_name = @department.name
    
    if @department.employees.exists?
      redirect_to admin_departments_path, alert: "従業員が所属している部署「#{department_name}」は削除できません"
    elsif @department.destroy
      redirect_to admin_departments_path, notice: "部署「#{department_name}」を削除しました"
    else
      redirect_to admin_departments_path, alert: "削除に失敗しました"
    end
  end

  private

  def set_department
    @department = Department.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_departments_path, alert: "部署が見つかりません"
  end

  def department_params
    params.require(:department).permit(:name, :position)
  end
end

