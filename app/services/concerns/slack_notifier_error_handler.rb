# frozen_string_literal: true

module SlackNotifierErrorHandler
  extend ActiveSupport::Concern

  private

  def handle_auth_error(error)
    message = "Slack authentication failed. Please check your SLACK_BOT_TOKEN and ensure the app is installed in the workspace."
    Rails.logger.error "#{message} Error: #{error.class.name} - #{error.message}"
    raise NotificationFailedError, message
  end

  def handle_channel_not_found_error(error)
    message = "Slack channel not found. Channel ID '#{channel_id}' may be invalid."
    Rails.logger.error "#{message} Error: #{error.class.name} - #{error.message}"
    raise NotificationFailedError, message
  end

  def handle_slack_error(error)
    error_details = extract_error_details(error)
    
    Rails.logger.error "Slack notification failed: #{error.class.name} - #{error_details}"
    Rails.logger.error "Full error: #{error.inspect}"
    
    if error.respond_to?(:response)
      Rails.logger.error "Response body: #{error.response.body rescue 'N/A'}"
    end
    
    raise NotificationFailedError, "Slack API error: #{error_details}"
  end

  def handle_unexpected_error(error)
    Rails.logger.error "Unexpected error in Slack notification: #{error.class.name} - #{error.message}"
    Rails.logger.error error.backtrace&.first(10)&.join("\n")
    raise
  end

  def extract_error_details(error)
    if error.respond_to?(:response)
      begin
        body = JSON.parse(error.response.body) rescue {}
        body["error"] || error.message
      rescue
        error.message
      end
    else
      error.message
    end
  end
end

