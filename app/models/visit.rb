class Visit < ApplicationRecord
  belongs_to :employee

  # ステータス定義
  enum :status, {
    pending: "pending",
    going_now: "going_now",        # すぐ行きます
    waiting: "waiting",             # お待ちいただく
    no_match: "no_match"            # 心当たりがない
  }, prefix: true

  validates :status, presence: true
  validates :employee, presence: true

  # スコープ
  scope :recent, -> { order(created_at: :desc) }
  scope :today, -> { where("created_at >= ?", Time.zone.now.beginning_of_day) }
  scope :this_week, -> { where("created_at >= ?", Time.zone.now.beginning_of_week) }

  # ステータス確認メソッド
  def pending?
    status == "pending"
  end

  def going_now?
    status == "going_now"
  end

  def waiting?
    status == "waiting"
  end

  def no_match?
    status == "no_match"
  end

  def responded?
    !pending?
  end

  # 表示用メソッド
  def formatted_created_at
    created_at.strftime("%Y年%m月%d日 %H:%M")
  end
end
