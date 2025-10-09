# frozen_string_literal: true

class Admin::SmarthrSyncsController < Admin::BaseController
  def create
    # SmartHR同期をバックグラウンドで実行
    SmarthrSyncJob.perform_later

    redirect_to admin_employees_path,
                notice: "SmartHRとの同期を開始しました。完了までしばらくお待ちください。"
  rescue => e
    Rails.logger.error "Failed to start SmartHR sync: #{e.message}"
    redirect_to admin_employees_path,
                alert: "同期の開始に失敗しました: #{e.message}"
  end

  def show
    # 同期履歴を表示
    @sync_logs = SyncLog.for_service("smarthr").recent.limit(20)
    @latest_sync = @sync_logs.first
    @success_count = @sync_logs.successful.count
    @failed_count = @sync_logs.failed.count
  end
end

