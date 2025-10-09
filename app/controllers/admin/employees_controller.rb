class Admin::EmployeesController < Admin::BaseController
  before_action :set_employee, only: [:show, :edit, :update, :destroy]
  before_action :set_departments, only: [:new, :edit, :create, :update]

  def index
    @employees = Employee.includes(:department)
                        .order(is_active: :desc, name: :asc)
    @active_count = @employees.count(&:is_active)
    @inactive_count = @employees.size - @active_count
  end

  def show
    @visits = @employee.visits.order(created_at: :desc).limit(10)
  end

  def new
    @employee = Employee.new(is_active: true)
  end

  def create
    @employee = Employee.new(employee_params)
    
    if @employee.save
      redirect_to admin_employees_path, notice: "従業員「#{@employee.name}」を登録しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # @departments は before_action で設定済み
  end

  def update
    if @employee.update(employee_params)
      redirect_to admin_employees_path, notice: "従業員「#{@employee.name}」の情報を更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    employee_name = @employee.name
    
    if @employee.visits.exists?
      redirect_to admin_employees_path, alert: "訪問履歴がある従業員「#{employee_name}」は削除できません"
    elsif @employee.destroy
      redirect_to admin_employees_path, notice: "従業員「#{employee_name}」を削除しました"
    else
      redirect_to admin_employees_path, alert: "削除に失敗しました"
    end
  end

  private

  def set_employee
    @employee = Employee.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_employees_path, alert: "従業員が見つかりません"
  end

  def set_departments
    @departments = Department.ordered
  end

  def employee_params
    params.require(:employee).permit(:name, :email, :slack_user_id, :department_id, :is_active, :visible_to_visitors, :avatar_url)
  end
end

