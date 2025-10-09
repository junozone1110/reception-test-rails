# frozen_string_literal: true

class SlackNotifier
  class NotConfiguredError < StandardError; end
  class NotificationFailedError < StandardError; end

  def initialize
    validate_configuration!
    @client = ::Slack::Web::Client.new(token: ENV["SLACK_BOT_TOKEN"])
  end

  def notify_visit(visit)
    employee = visit.employee
    message_builder = ::Slack::MessageBuilder.new(visit)
    
    log_notification_start(employee)
    
    response = send_message(employee, message_builder)
    save_message_timestamp(visit, response)
    log_notification_success(employee)
    
    response
  rescue ::Slack::Web::Api::Errors::NotAuthed => e
    handle_auth_error(e)
  rescue ::Slack::Web::Api::Errors::ChannelNotFound => e
    handle_channel_not_found_error(employee, e)
  rescue ::Slack::Web::Api::Errors::SlackError => e
    handle_slack_error(e)
  rescue => e
    handle_unexpected_error(e)
  end

  private

  def validate_configuration!
    return if ENV["SLACK_BOT_TOKEN"].present?
    
    raise NotConfiguredError, "SLACK_BOT_TOKEN is not configured"
  end

  def send_message(employee, message_builder)
    @client.chat_postMessage(
      channel: employee.slack_user_id,
      text: message_builder.build_plain_text,
      blocks: message_builder.build_notification_blocks
    )
  end

  def save_message_timestamp(visit, response)
    return unless response["ok"]
    
    visit.update(slack_message_ts: response["ts"])
  end

  def log_notification_start(employee)
    Rails.logger.info "Sending Slack notification to #{employee.name} (#{employee.slack_user_id})"
  end

  def log_notification_success(employee)
    Rails.logger.info "Slack notification sent successfully to #{employee.name}"
  end

  def handle_auth_error(error)
    message = "Slack authentication failed. Please check your SLACK_BOT_TOKEN and ensure the app is installed in the workspace."
    Rails.logger.error "#{message} Error: #{error.message}"
    raise NotificationFailedError, message
  end

  def handle_channel_not_found_error(employee, error)
    message = "Slack user not found. User ID '#{employee.slack_user_id}' may be invalid."
    Rails.logger.error "#{message} Error: #{error.message}"
    raise NotificationFailedError, message
  end

  def handle_slack_error(error)
    Rails.logger.error "Slack notification failed: #{error.class.name} - #{error.message}"
    raise NotificationFailedError, "Slack API error: #{error.message}"
  end

  def handle_unexpected_error(error)
    Rails.logger.error "Unexpected error in Slack notification: #{error.class.name} - #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
    raise
  end
end

