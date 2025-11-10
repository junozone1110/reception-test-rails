class EmployeesController < ApplicationController
  def index
    @employees = Employee.active
                        .visible_to_visitors
                        .includes(:department)
                        .by_department(params[:department_id])
                        .search(params[:q])
                        .ordered
    
    @departments = Department.ordered
  end
end

