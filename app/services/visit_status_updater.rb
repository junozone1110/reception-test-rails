# frozen_string_literal: true

class VisitStatusUpdater
  def initialize(slack_notifier: nil)
    @slack_notifier = slack_notifier || SlackNotifier.new
  end

  # 訪問のステータスを更新し、Slackメッセージを更新する
  def update_status(visit, status, responder:, responded_at: nil)
    raise VisitAlreadyRespondedError if visit.responded?

    responded_at ||= Time.current

    ActiveRecord::Base.transaction do
      visit.update!(status: status)
      
      # Slackメッセージを更新
      @slack_notifier.update_message(
        visit,
        responder: responder,
        responded_at: responded_at
      )
    end

    Rails.logger.info "Visit ##{visit.id} status updated to #{status} by #{responder}"
    visit
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Visit status update validation failed: #{e.message}"
    raise VisitStatusUpdateError, "ステータスの更新に失敗しました: #{e.message}"
  rescue SlackNotifier::NotificationFailedError => e
    Rails.logger.error "Slack message update failed: #{e.message}"
    # ステータスは更新されているが、Slack通知に失敗した場合
    # トランザクションをロールバックするか、そのまま進めるかは要件による
    # 現状はそのまま進める（ステータス更新は成功）
    visit
  rescue => e
    Rails.logger.error "Visit status update failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise VisitStatusUpdateError, "ステータスの更新中にエラーが発生しました: #{e.message}"
  end
end

