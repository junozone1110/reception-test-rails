class SlackNotificationJob < ApplicationJob
  queue_as :default
  
  # リトライ設定：最大3回、指数バックオフ
  retry_on SlackNotifier::NotificationFailedError, wait: :exponentially_longer, attempts: 3
  
  # Slack設定エラーは再試行しない
  discard_on SlackNotifier::NotConfiguredError
  discard_on ActiveRecord::RecordNotFound

  def perform(visit_id)
    visit = Visit.includes(employee: :department).find(visit_id)
    
    Rails.logger.info "Starting Slack notification job for visit ##{visit_id}"
    
    # Slack通知をスキップする条件（開発時など）
    if ENV["SLACK_BOT_TOKEN"].blank?
      Rails.logger.warn "Skipping Slack notification: SLACK_BOT_TOKEN not configured"
      return
    end
    
    notifier = SlackNotifier.new
    notifier.notify_visit(visit)
    
    Rails.logger.info "Slack notification job completed for visit ##{visit_id}"
  rescue => e
    Rails.logger.error "Slack notification job failed for visit ##{visit_id}: #{e.class.name} - #{e.message}"
    raise
  end
end

