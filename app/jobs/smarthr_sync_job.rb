# frozen_string_literal: true

class SmarthrSyncJob < ApplicationJob
  queue_as :default

  # リトライ設定
  retry_on Smarthr::Client::ApiError, wait: :exponentially_longer, attempts: 3

  # 設定エラーは再試行しない
  discard_on Smarthr::Client::ConfigurationError

  def perform
    Rails.logger.info "Starting SmartHR employee sync job..."

    syncer = Smarthr::EmployeeSyncer.new
    stats = syncer.sync_all

    # 同期結果を記録
    create_sync_log(status: "success", details: stats)

    Rails.logger.info "SmartHR sync job completed successfully: #{stats}"
  rescue Smarthr::Client::ConfigurationError => e
    # 設定エラーの場合
    Rails.logger.error "SmartHR sync job configuration error: #{e.message}"
    create_sync_log(status: "failed", error_message: e.message, details: { error_type: "configuration" })
    raise
  rescue => e
    # その他のエラー
    Rails.logger.error "SmartHR sync job failed: #{e.class.name} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    create_sync_log(
      status: "failed",
      error_message: "#{e.class.name}: #{e.message}",
      details: { error_type: e.class.name, backtrace: e.backtrace.first(10) }
    )

    raise
  end

  private

  def create_sync_log(status:, details: {}, error_message: nil)
    SyncLog.create!(
      service: "smarthr",
      status: status,
      details: details,
      error_message: error_message,
      synced_at: Time.current
    )
  rescue => e
    # ログ記録の失敗はジョブを失敗させない
    Rails.logger.error "Failed to create sync log: #{e.message}"
  end
end

