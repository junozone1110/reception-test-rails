# frozen_string_literal: true

# アプリケーション共通の基底例外クラス
class ApplicationError < StandardError
  attr_reader :status_code, :error_code

  def initialize(message = nil, status_code: 500, error_code: nil)
    super(message)
    @status_code = status_code
    @error_code = error_code || self.class.name.underscore
  end
end

# 訪問関連の例外
class VisitNotFoundError < ApplicationError
  def initialize(message = "訪問記録が見つかりません")
    super(message, status_code: 404, error_code: "visit_not_found")
  end
end

class VisitCreationError < ApplicationError
  def initialize(message = "訪問記録の作成に失敗しました")
    super(message, status_code: 422, error_code: "visit_creation_failed")
  end
end

class VisitStatusUpdateError < ApplicationError
  def initialize(message = "ステータスの更新に失敗しました")
    super(message, status_code: 422, error_code: "visit_status_update_failed")
  end
end

class VisitAlreadyRespondedError < ApplicationError
  def initialize(message = "訪問記録は既に応答済みです")
    super(message, status_code: 409, error_code: "visit_already_responded")
  end
end

# Slack関連の例外
class SlackActionError < ApplicationError
  def initialize(message = "Slackアクションの処理に失敗しました")
    super(message, status_code: 500, error_code: "slack_action_failed")
  end
end

class SlackNotificationError < ApplicationError
  def initialize(message = "Slack通知の送信に失敗しました")
    super(message, status_code: 500, error_code: "slack_notification_failed")
  end
end

class SlackSignatureError < ApplicationError
  def initialize(message = "Slack署名の検証に失敗しました")
    super(message, status_code: 401, error_code: "slack_signature_invalid")
  end
end

class SlackPayloadError < ApplicationError
  def initialize(message = "Slackペイロードが不正です")
    super(message, status_code: 400, error_code: "slack_payload_invalid")
  end
end

