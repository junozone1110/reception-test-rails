# frozen_string_literal: true

class SlackNotifier
  class NotConfiguredError < StandardError; end
  class NotificationFailedError < StandardError; end

  include SlackNotifierLogger
  include SlackNotifierErrorHandler

  def initialize(client: nil)
    validate_configuration!
    @client = client || build_client
  end

  def notify_visit(visit)
    message_builder = ::Slack::MessageBuilder.new(visit)
    
    log_notification_start(visit)
    
    response = send_message_to_channel(message_builder)
    save_message_timestamp(visit, response)
    log_notification_success(visit)
    
    response
  rescue ::Slack::Web::Api::Errors::NotAuthed => e
    handle_auth_error(e)
  rescue ::Slack::Web::Api::Errors::ChannelNotFound => e
    handle_channel_not_found_error(e)
  rescue ::Slack::Web::Api::Errors::SlackError => e
    handle_slack_error(e)
  rescue StandardError => e
    handle_unexpected_error(e)
  end

  def update_message(visit, responder: nil, responded_at: nil)
    message_builder = ::Slack::MessageBuilder.new(
      visit, 
      responder: responder, 
      responded_at: responded_at
    )
    
    log_message_update_start(visit)
    
    response = @client.chat_update(
      channel: channel_id,
      ts: visit.slack_message_ts,
      text: message_builder.build_plain_text,
      blocks: message_builder.build_notification_blocks
    )
    
    log_message_update_success(visit)
    response
  rescue ::Slack::Web::Api::Errors::SlackError => e
    handle_slack_error(e)
  rescue StandardError => e
    handle_unexpected_error(e)
  end

  private

  def build_client
    ::Slack::Web::Client.new(token: AppConfig::Slack.bot_token)
  end

  def validate_configuration!
    unless AppConfig::Slack.bot_token?
      raise NotConfiguredError, "SLACK_BOT_TOKEN is not configured"
    end
    
    unless AppConfig::Slack.channel_id?
      raise NotConfiguredError, "SLACK_CHANNEL_ID is not configured"
    end
  end

  def channel_id
    @channel_id ||= AppConfig::Slack.channel_id
  end

  def send_message_to_channel(message_builder)
    blocks = message_builder.build_notification_blocks
    
    log_blocks(blocks) if Rails.env.development?
    
    @client.chat_postMessage(
      channel: channel_id,
      text: message_builder.build_plain_text,
      blocks: blocks
    )
  end

  def save_message_timestamp(visit, response)
    return unless response["ok"]
    
    visit.update_column(:slack_message_ts, response["ts"])
  end
end

