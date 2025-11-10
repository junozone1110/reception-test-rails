# frozen_string_literal: true

class SlackActionsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_slack_request

  def create
    Rails.logger.info "=== Slack Actions Controller Called ==="
    Rails.logger.info "Request method: #{request.method}"
    Rails.logger.info "Content-Type: #{request.content_type}"
    Rails.logger.info "Headers: #{request.headers.to_h.select { |k, v| k.start_with?('X-Slack') || k == 'Content-Type' }.inspect}"
    
    payload = parse_payload
    
    Rails.logger.info "Payload type: #{payload['type']}"
    
    # Slackのurl_verificationチャレンジに対応
    if payload["type"] == "url_verification"
      Rails.logger.info "Responding to url_verification challenge"
      return render json: { challenge: payload["challenge"] }
    end
    
    handle_action(payload) if block_actions?(payload)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Visit not found: #{e.message}"
    render json: { text: "訪問記録が見つかりません" }, status: :not_found
  rescue JSON::ParserError => e
    Rails.logger.error "JSON parse error: #{e.message}"
    Rails.logger.error "Request body: #{request.body.read rescue 'N/A'}"
    render json: { text: "不正なペイロード" }, status: :bad_request
  rescue SlackSignatureVerifier::VerificationError => e
    Rails.logger.error "Slack signature verification failed: #{e.message}"
    render json: { error: e.message }, status: :unauthorized
  rescue SlackSignatureError => e
    Rails.logger.error "Slack signature error: #{e.message}"
    render json: { error: e.message }, status: :unauthorized
  rescue => e
    Rails.logger.error "Slack action error: #{e.class.name} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { text: "エラーが発生しました" }, status: :internal_server_error
  end

  private

  def verify_slack_request
    verifier = SlackSignatureVerifier.new(skip_in_development: true)
    verifier.verify(request)
  rescue SlackSignatureError => e
    Rails.logger.warn "❌ Slack request verification failed: #{e.message}"
    render json: { error: e.message }, status: :unauthorized
    false
  end

  def parse_payload
    # リクエストボディが既に読み込まれている場合
    request.body.rewind
    body = request.body.read
    request.body.rewind
    
    Rails.logger.info "Parsing Slack payload: #{body[0..200]}..." # 最初の200文字だけログ
    
    JSON.parse(params[:payload])
  end

  def block_actions?(payload)
    payload["type"] == AppConfig::Slack::PAYLOAD_TYPE_BLOCK_ACTIONS
  end

  def handle_action(payload)
    handler = SlackActionHandler.new
    result = handler.handle(payload)
    
    render json: { text: "✓ #{result[:status_text]}" }
  rescue SlackActionError => e
    Rails.logger.warn "Unknown Slack action: #{e.message}"
    render json: { text: "不明なアクション" }
  rescue SlackPayloadError => e
    Rails.logger.error "Invalid payload: #{e.message}"
    render json: { text: e.message }, status: :bad_request
  rescue VisitNotFoundError => e
    Rails.logger.error "Visit not found: #{e.message}"
    render json: { text: e.message }, status: :not_found
  rescue VisitAlreadyRespondedError
    Rails.logger.warn "Visit already responded"
    render json: { text: "既に応答済みです" }
  rescue VisitStatusUpdateError => e
    Rails.logger.error "Visit status update failed: #{e.message}"
    render json: { text: "ステータスの更新に失敗しました" }, status: :internal_server_error
  end

  def extract_responder_name(payload)
    user_id = payload.dig("user", "id")
    username = payload.dig("user", "name")
    
    # SlackユーザーIDからユーザー名を取得（簡易版）
    # 実際にはSlack APIでユーザー情報を取得する方が正確
    username || user_id || "不明なユーザー"
  end

  def render_unknown_action
    Rails.logger.warn "Unknown Slack action received"
    render json: { text: "不明なアクション" }
  end
end

