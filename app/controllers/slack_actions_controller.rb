# frozen_string_literal: true

class SlackActionsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    payload = parse_payload
    
    handle_action(payload) if block_actions?(payload)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Visit not found: #{e.message}"
    render json: { text: "訪問記録が見つかりません" }, status: :not_found
  rescue => e
    Rails.logger.error "Slack action error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { text: "エラーが発生しました" }, status: :internal_server_error
  end

  private

  def parse_payload
    JSON.parse(params[:payload])
  end

  def block_actions?(payload)
    payload["type"] == AppConfig::Slack::PAYLOAD_TYPE_BLOCK_ACTIONS
  end

  def handle_action(payload)
    action = payload["actions"]&.first
    return render_unknown_action unless action
    
    case action["action_id"]
    when AppConfig::Slack::ACTION_ACKNOWLEDGE_VISIT
      acknowledge_visit(action["value"])
    else
      render_unknown_action
    end
  end

  def acknowledge_visit(visit_id)
    visit = Visit.find(visit_id.to_i)
    visit.update!(status: :acknowledged)
    
    render json: { text: "✓ 確認済み" }
  end

  def render_unknown_action
    render json: { text: "不明なアクション" }
  end
end

