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
  rescue => e
    Rails.logger.error "Slack action error: #{e.class.name} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { text: "エラーが発生しました" }, status: :internal_server_error
  end

  private

  def verify_slack_request
    # 開発環境では署名検証をスキップ（デバッグ用）
    if Rails.env.development?
      Rails.logger.info "⚠️  Development mode: Skipping Slack signature verification"
      return true
    end

    # 本番環境での署名検証
    return true unless ENV["SLACK_SIGNING_SECRET"].present?

    timestamp = request.headers["X-Slack-Request-Timestamp"]
    slack_signature = request.headers["X-Slack-Signature"]

    Rails.logger.info "Verifying Slack request - Timestamp: #{timestamp}, Signature: #{slack_signature}"

    # タイムスタンプチェック（リプレイアタック対策）
    if timestamp.nil? || (Time.now.to_i - timestamp.to_i).abs > 60 * 5
      Rails.logger.warn "❌ Slack request timestamp is too old or missing"
      render json: { error: "Invalid timestamp" }, status: :unauthorized
      return false
    end

    # 署名の検証
    request.body.rewind
    body = request.body.read
    sig_basestring = "v0:#{timestamp}:#{body}"
    my_signature = "v0=" + OpenSSL::HMAC.hexdigest("SHA256", ENV["SLACK_SIGNING_SECRET"], sig_basestring)

    Rails.logger.info "Expected signature: #{my_signature}"
    Rails.logger.info "Received signature: #{slack_signature}"

    unless ActiveSupport::SecurityUtils.secure_compare(my_signature, slack_signature.to_s)
      Rails.logger.warn "❌ Slack signature verification failed"
      render json: { error: "Invalid signature" }, status: :unauthorized
      return false
    end

    Rails.logger.info "✅ Slack request signature verified successfully"
    request.body.rewind # 次の処理のためにリセット
    true
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
    action = payload["actions"]&.first
    return render_unknown_action unless action
    
    Rails.logger.info "Handling Slack action: #{action["action_id"]}"
    
    visit_id = action["value"].to_i
    visit = Visit.find(visit_id)
    
    # 既に応答済みの場合は処理しない
    if visit.responded?
      Rails.logger.warn "Visit ##{visit_id} already responded"
      render json: { text: "既に応答済みです" }
      return
    end
    
    responder = extract_responder_name(payload)
    
    case action["action_id"]
    when AppConfig::Slack::ACTION_GOING_NOW
      update_visit_status(visit, :going_now, responder)
    when AppConfig::Slack::ACTION_WAITING
      update_visit_status(visit, :waiting, responder)
    when AppConfig::Slack::ACTION_NO_MATCH
      update_visit_status(visit, :no_match, responder)
    else
      render_unknown_action
    end
  end

  def update_visit_status(visit, status, responder)
    responded_at = Time.current
    visit.update!(status: status)
    
    # Slackメッセージを更新
    notifier = SlackNotifier.new
    notifier.update_message(visit, responder: responder, responded_at: responded_at)
    
    Rails.logger.info "Visit ##{visit.id} status updated to #{status} by #{responder}"
    render json: { text: "✓ #{status_text(status)}" }
  end

  def extract_responder_name(payload)
    user_id = payload.dig("user", "id")
    username = payload.dig("user", "name")
    
    # SlackユーザーIDからユーザー名を取得（簡易版）
    # 実際にはSlack APIでユーザー情報を取得する方が正確
    username || user_id || "不明なユーザー"
  end

  def status_text(status)
    case status
    when :going_now
      "すぐ行きます"
    when :waiting
      "お待ちいただく"
    when :no_match
      "心当たりがない"
    else
      "確認済み"
    end
  end

  def render_unknown_action
    Rails.logger.warn "Unknown Slack action received"
    render json: { text: "不明なアクション" }
  end
end

