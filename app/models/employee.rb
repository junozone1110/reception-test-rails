class Employee < ApplicationRecord
  belongs_to :department
  has_many :visits, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 100 }
  validates :slack_user_id, presence: true, uniqueness: true, format: { with: /\A[A-Z0-9_]+\z/, message: "は英数字（大文字）とアンダースコアのみ使用できます" }
  validates :email, uniqueness: true, allow_nil: true, format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :department, presence: true
  validates :is_active, inclusion: { in: [true, false] }
  validates :visible_to_visitors, inclusion: { in: [true, false] }
  validates :smarthr_id, uniqueness: true, allow_nil: true

  # スコープ
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :visible_to_visitors, -> { where(visible_to_visitors: true) }
  scope :hidden_from_visitors, -> { where(visible_to_visitors: false) }
  scope :by_department, ->(dept_id) { where(department_id: dept_id) if dept_id.present? }
  scope :search, ->(query) { where("name LIKE ?", "%#{sanitize_sql_like(query)}%") if query.present? }
  scope :recent, -> { order(created_at: :desc) }
  scope :synced_from_smarthr, -> { where.not(smarthr_id: nil) }
  scope :not_synced_from_smarthr, -> { where(smarthr_id: nil) }

  # アバターURLのデフォルト値
  after_initialize :set_default_avatar_url, if: :new_record?

  def display_name
    is_active? ? name : "#{name}（無効）"
  end

  private

  def set_default_avatar_url
    self.avatar_url ||= "https://ui-avatars.com/api/?name=#{URI.encode_www_form_component(name.to_s)}&background=random"
  end
end
