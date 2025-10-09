class Visit < ApplicationRecord
  belongs_to :employee

  # ステータス定義
  enum :status, { pending: "pending", acknowledged: "acknowledged" }, prefix: true

  validates :status, presence: true
  validates :employee, presence: true

  # スコープ
  scope :recent, -> { order(created_at: :desc) }
  scope :today, -> { where("created_at >= ?", Time.zone.now.beginning_of_day) }
  scope :this_week, -> { where("created_at >= ?", Time.zone.now.beginning_of_week) }

  # ステータス確認メソッド
  def acknowledged?
    status == "acknowledged"
  end

  def pending?
    status == "pending"
  end

  # 表示用メソッド
  def formatted_created_at
    created_at.strftime("%Y年%m月%d日 %H:%M")
  end
end
