class Employee < ApplicationRecord
  belongs_to :department
  has_many :visits, dependent: :restrict_with_error

  # バリデーション
  validates :name, presence: true, length: { maximum: 100 }
  validates :slack_user_id, 
            presence: true, 
            uniqueness: { case_sensitive: true },
            format: { 
              with: /\A[A-Z0-9_]+\z/, 
              message: "は英数字（大文字）とアンダースコアのみ使用できます" 
            }
  validates :email, 
            uniqueness: { case_sensitive: false }, 
            allow_nil: true,
            format: { 
              with: URI::MailTo::EMAIL_REGEXP, 
              allow_blank: true 
            }
  validates :department, presence: true
  validates :is_active, inclusion: { in: [true, false] }
  validates :visible_to_visitors, inclusion: { in: [true, false] }
  validates :smarthr_id, uniqueness: true, allow_nil: true

  # スコープの改善
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :visible_to_visitors, -> { where(visible_to_visitors: true) }
  scope :hidden_from_visitors, -> { where(visible_to_visitors: false) }
  scope :by_department, ->(dept_id) { where(department_id: dept_id) if dept_id.present? }
  scope :search, ->(query) { 
    return none if query.blank?
    
    sanitized = sanitize_sql_like(query.to_s)
    where("name LIKE :query OR email LIKE :query", query: "%#{sanitized}%")
  }
  scope :recent, -> { order(created_at: :desc) }
  scope :ordered, -> { joins(:department).merge(Department.ordered).order(:name) }
  scope :synced_from_smarthr, -> { where.not(smarthr_id: nil) }
  scope :not_synced_from_smarthr, -> { where(smarthr_id: nil) }
  scope :with_visit_stats, -> {
    left_joins(:visits)
      .select('employees.*, COUNT(visits.id) as visits_count')
      .group('employees.id')
  }

  # コールバック
  after_initialize :set_default_avatar_url, if: :new_record?
  before_validation :normalize_email

  # ビジネスロジック
  def display_name
    is_active? ? name : "#{name}（無効）"
  end

  def full_info
    "#{name} (#{department.name})"
  end

  # Slack通知可能かチェック
  def notifiable?
    is_active? && slack_user_id.present? && slack_user_id_valid?
  end

  private

  def set_default_avatar_url
    self.avatar_url ||= generate_avatar_url
  end

  def generate_avatar_url
    encoded_name = URI.encode_www_form_component(name.to_s)
    "https://ui-avatars.com/api/?name=#{encoded_name}&background=random&size=200"
  end

  def normalize_email
    self.email = email.downcase.strip if email.present?
  end

  def slack_user_id_valid?
    # より厳密なバリデーション（オプション）
    slack_user_id.match?(/\A[A-Z][A-Z0-9_]{7,}\z/)
  end
end
