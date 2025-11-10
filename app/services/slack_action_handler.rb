# frozen_string_literal: true

class SlackActionHandler
  def initialize(visit_status_updater: nil)
    @visit_status_updater = visit_status_updater || VisitStatusUpdater.new
  end

  # Slackアクションを処理する
  def handle(payload)
    validate_payload(payload)
    
    action = payload["actions"]&.first
    raise SlackPayloadError, "Action not found in payload" unless action

    visit_id = action["value"].to_i
    visit = Visit.find(visit_id)
    
    responder = extract_responder_name(payload)
    status = map_action_to_status(action["action_id"])
    
    @visit_status_updater.update_status(visit, status, responder: responder)
    
    { success: true, visit: visit, status_text: visit.reload.status_text }
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Visit not found: #{e.message}"
    raise VisitNotFoundError
  end

  private

  def validate_payload(payload)
    raise SlackPayloadError, "Payload is nil" if payload.nil?
    raise SlackPayloadError, "Payload type is invalid" unless payload.is_a?(Hash)
  end

  def map_action_to_status(action_id)
    case action_id
    when AppConfig::Slack::ACTION_GOING_NOW
      :going_now
    when AppConfig::Slack::ACTION_WAITING
      :waiting
    when AppConfig::Slack::ACTION_NO_MATCH
      :no_match
    else
      raise SlackActionError, "Unknown action_id: #{action_id}"
    end
  end

  def extract_responder_name(payload)
    user_id = payload.dig("user", "id")
    username = payload.dig("user", "name")
    
    # SlackユーザーIDからユーザー名を取得（簡易版）
    # 実際にはSlack APIでユーザー情報を取得する方が正確
    username || user_id || "不明なユーザー"
  end
end

