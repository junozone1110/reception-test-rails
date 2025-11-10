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

  # ステータステキストのマッピング（定数化）
  STATUS_TEXTS = {
    "pending" => "確認待ち",
    "going_now" => "すぐ行きます",
    "waiting" => "お待ちいただく",
    "no_match" => "心当たりがない"
  }.freeze

  # スコープ
  scope :recent, -> { order(created_at: :desc) }
  scope :today, -> { where("created_at >= ?", Time.zone.now.beginning_of_day) }
  scope :this_week, -> { where("created_at >= ?", Time.zone.now.beginning_of_week) }
  scope :responded, -> { where.not(status: :pending) }

  # enumが自動生成するメソッド（status_pending?, status_going_now?など）を使用
  # 重複したメソッド定義は削除

  def responded?
    !status_pending?
  end

  # ステータスの表示テキストを返す
  def status_text
    STATUS_TEXTS.fetch(status, "確認済み")
  end

  # クラスメソッドとしても使用可能にする（後方互換性のため）
  def self.status_text_for(status_value)
    STATUS_TEXTS.fetch(status_value.to_s, "確認済み")
  end

  # 表示用メソッド
  def formatted_created_at
    created_at.strftime("%Y年%m月%d日 %H:%M")
  end
end
