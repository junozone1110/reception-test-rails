# frozen_string_literal: true

# Rate limiting configuration using Rack::Attack
class Rack::Attack
  # 開発環境ではRate Limitingを無効化（オプション）
  # self.enabled = false if Rails.env.development?

  # 訪問者からの受付申請のレート制限
  # 1分間に10リクエストまで
  throttle('visits/ip', limit: 10, period: 60.seconds) do |req|
    req.ip if req.path == '/visits' && req.post?
  end

  # Slack Webhookのレート制限（念のため）
  # 1分間に100リクエストまで
  throttle('slack_webhook/ip', limit: 100, period: 60.seconds) do |req|
    req.ip if req.path == '/slack/actions' && req.post?
  end

  # 管理画面のログイン試行回数制限
  # 1分間に5回まで
  throttle('admin_login/email', limit: 5, period: 60.seconds) do |req|
    if req.path == '/admin/login' && req.post?
      req.params['email'].to_s.downcase.presence
    end
  end

  # ステータス確認エンドポイントのレート制限
  # 1分間に30リクエストまで
  throttle('visit_status/ip', limit: 30, period: 60.seconds) do |req|
    req.ip if req.path.match?(%r{/visits/\d+/status}) && req.get?
  end

  # ブロック時のレスポンス
  self.blocklisted_responder = lambda do |request|
    [429, { 'Content-Type' => 'application/json' }, [{
      error: 'Too Many Requests',
      message: 'リクエストが多すぎます。しばらく待ってから再度お試しください。'
    }.to_json]]
  end

  # ログ記録（開発環境）
  ActiveSupport::Notifications.subscribe('rack.attack') do |_name, _start, _finish, _request_id, req|
    if req.env['rack.attack.match_type'] == :throttle
      Rails.logger.warn "Rate limit exceeded: #{req.env['rack.attack.matched']} for IP #{req.ip}"
    end
  end
end

