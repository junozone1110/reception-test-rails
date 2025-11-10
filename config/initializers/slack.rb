# Slack設定の初期化
# 開発環境ではSlack tokenが未設定でもエラーにしない
if Rails.env.production? && !AppConfig::Slack.bot_token?
  raise "SLACK_BOT_TOKEN is required in production"
end

Slack.configure do |config|
  config.token = AppConfig::Slack.bot_token
end if AppConfig::Slack.bot_token?

