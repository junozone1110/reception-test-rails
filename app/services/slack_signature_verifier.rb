# frozen_string_literal: true

class SlackSignatureVerifier
  # タイムスタンプの有効期限（秒）
  TIMESTAMP_TOLERANCE = 60 * 5 # 5分

  def initialize(signing_secret: nil, skip_in_development: true)
    @signing_secret = signing_secret || AppConfig::Slack.signing_secret
    @skip_in_development = skip_in_development && Rails.env.development?
  end

  # リクエストの署名を検証する
  def verify(request)
    return true if @skip_in_development && @signing_secret.blank?
    return true if @signing_secret.blank?

    timestamp = request.headers["X-Slack-Request-Timestamp"]
    slack_signature = request.headers["X-Slack-Signature"]

    verify_timestamp(timestamp)
    verify_signature(request, timestamp, slack_signature)

    true
  end

  private

  def verify_timestamp(timestamp)
    if timestamp.nil?
      raise SlackSignatureError, "X-Slack-Request-Timestamp header is missing"
    end

    request_time = timestamp.to_i
    current_time = Time.now.to_i
    time_diff = (current_time - request_time).abs

    if time_diff > TIMESTAMP_TOLERANCE
      raise SlackSignatureError, "Request timestamp is too old (difference: #{time_diff}s, max: #{TIMESTAMP_TOLERANCE}s)"
    end
  end

  def verify_signature(request, timestamp, slack_signature)
    request.body.rewind
    body = request.body.read
    request.body.rewind

    sig_basestring = "v0:#{timestamp}:#{body}"
    expected_signature = "v0=" + OpenSSL::HMAC.hexdigest("SHA256", @signing_secret, sig_basestring)

    unless ActiveSupport::SecurityUtils.secure_compare(expected_signature, slack_signature.to_s)
      raise SlackSignatureError, "Signature verification failed"
    end
  end
end

