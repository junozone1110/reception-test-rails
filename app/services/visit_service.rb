# frozen_string_literal: true

class VisitService
  def initialize
    @slack_notifier = SlackNotifier.new
  end

  # 訪問を作成し、Slack通知を送信する
  def create_visit(visit_params, session:)
    visit = Visit.new(visit_params)

    unless visit.save
      raise VisitCreationError, "訪問記録の作成に失敗しました: #{visit.errors.full_messages.join(', ')}"
    end

    # Slack通知ジョブをキューに追加（非同期）
    SlackNotificationJob.perform_later(visit.id)

    # セッションにvisit_idを保存（ポーリング用）
    session[:last_visit_id] = visit.id

    visit
  rescue => e
    Rails.logger.error "Visit creation failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise VisitCreationError, "訪問記録の作成中にエラーが発生しました: #{e.message}"
  end
end

