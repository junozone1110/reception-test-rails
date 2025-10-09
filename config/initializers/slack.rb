# Slack設定の初期化
# 開発環境ではSlack tokenが未設定でもエラーにしない
if Rails.env.production? && ENV["SLACK_BOT_TOKEN"].blank?
  raise "SLACK_BOT_TOKEN is required in production"
end

Slack.configure do |config|
  config.token = ENV["SLACK_BOT_TOKEN"]
end if ENV["SLACK_BOT_TOKEN"].present?

