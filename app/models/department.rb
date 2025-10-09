class Department < ApplicationRecord
  has_many :employees, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 50 }
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # スコープ
  scope :with_active_employees, -> { joins(:employees).merge(Employee.active).distinct }
  scope :alphabetical, -> { order(:name) }
  scope :ordered, -> { order(:position, :name) }

  # コールバック
  before_validation :set_default_position, on: :create

  # 統計メソッド
  def active_employees_count
    employees.active.count
  end

  def total_employees_count
    employees.count
  end

  private

  def set_default_position
    return if position.present?
    
    max_position = Department.maximum(:position) || 0
    self.position = max_position + 1
  end
end
