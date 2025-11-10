# frozen_string_literal: true

class SlackNotifier
  class NotConfiguredError < StandardError; end
  class NotificationFailedError < StandardError; end

  def initialize
    validate_configuration!
    @client = ::Slack::Web::Client.new(token: AppConfig::Slack.bot_token)
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
  rescue => e
    handle_unexpected_error(e)
  end

  def update_message(visit, responder: nil, responded_at: nil)
    message_builder = ::Slack::MessageBuilder.new(visit, responder: responder, responded_at: responded_at)
    channel_id = get_channel_id
    
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
  rescue => e
    handle_unexpected_error(e)
  end

  private

  def validate_configuration!
    unless AppConfig::Slack.bot_token?
      raise NotConfiguredError, "SLACK_BOT_TOKEN is not configured"
    end
    
    unless AppConfig::Slack.channel_id?
      raise NotConfiguredError, "SLACK_CHANNEL_ID is not configured"
    end
  end

  def get_channel_id
    AppConfig::Slack.channel_id
  end

  def send_message_to_channel(message_builder)
    blocks = message_builder.build_notification_blocks
    Rails.logger.info "Sending blocks to Slack: #{JSON.pretty_generate(blocks)}"
    
    @client.chat_postMessage(
      channel: get_channel_id,
      text: message_builder.build_plain_text,
      blocks: blocks
    )
  end

  def save_message_timestamp(visit, response)
    return unless response["ok"]
    
    visit.update(slack_message_ts: response["ts"])
  end

  def log_notification_start(visit)
    Rails.logger.info "Sending Slack notification to channel #{get_channel_id} for visit ##{visit.id}"
  end

  def log_notification_success(visit)
    Rails.logger.info "Slack notification sent successfully for visit ##{visit.id}"
  end

  def log_message_update_start(visit)
    Rails.logger.info "Updating Slack message for visit ##{visit.id}"
  end

  def log_message_update_success(visit)
    Rails.logger.info "Slack message updated successfully for visit ##{visit.id}"
  end

  def handle_auth_error(error)
    message = "Slack authentication failed. Please check your SLACK_BOT_TOKEN and ensure the app is installed in the workspace."
    Rails.logger.error "#{message} Error: #{error.message}"
    raise NotificationFailedError, message
  end

  def handle_channel_not_found_error(error)
    message = "Slack channel not found. Channel ID '#{get_channel_id}' may be invalid."
    Rails.logger.error "#{message} Error: #{error.message}"
    raise NotificationFailedError, message
  end

  def handle_slack_error(error)
    error_details = if error.respond_to?(:response)
      begin
        body = JSON.parse(error.response.body) rescue {}
        body["error"] || error.message
      rescue
        error.message
      end
    else
      error.message
    end
    
    Rails.logger.error "Slack notification failed: #{error.class.name} - #{error_details}"
    Rails.logger.error "Full error: #{error.inspect}"
    if error.respond_to?(:response)
      Rails.logger.error "Response body: #{error.response.body rescue 'N/A'}"
    end
    raise NotificationFailedError, "Slack API error: #{error_details}"
  end

  def handle_unexpected_error(error)
    Rails.logger.error "Unexpected error in Slack notification: #{error.class.name} - #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
    raise
  end
end

