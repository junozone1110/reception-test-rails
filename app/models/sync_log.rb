class SyncLog < ApplicationRecord
  # バリデーション
  validates :service, presence: true
  validates :status, presence: true, inclusion: { in: %w[success failed] }
  validates :synced_at, presence: true

  # スコープ
  scope :recent, -> { order(synced_at: :desc) }
  scope :successful, -> { where(status: "success") }
  scope :failed, -> { where(status: "failed") }
  scope :for_service, ->(service) { where(service: service) }

  # 表示用メソッド
  def success?
    status == "success"
  end

  def failed?
    status == "failed"
  end

  def formatted_synced_at
    synced_at.strftime("%Y年%m月%d日 %H:%M")
  end
end
