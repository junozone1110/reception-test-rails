# frozen_string_literal: true

module SlackNotifierLogger
  extend ActiveSupport::Concern

  private

  def log_notification_start(visit)
    Rails.logger.info "Sending Slack notification - visit_id: #{visit.id}, channel: #{channel_id}, employee: #{visit.employee.name}"
  end

  def log_notification_success(visit)
    Rails.logger.info "Slack notification sent successfully - visit_id: #{visit.id}"
  end

  def log_message_update_start(visit)
    Rails.logger.info "Updating Slack message - visit_id: #{visit.id}, message_ts: #{visit.slack_message_ts}"
  end

  def log_message_update_success(visit)
    Rails.logger.info "Slack message updated successfully - visit_id: #{visit.id}"
  end

  def log_blocks(blocks)
    Rails.logger.debug "Slack blocks: #{JSON.pretty_generate(blocks)}"
  end
end

