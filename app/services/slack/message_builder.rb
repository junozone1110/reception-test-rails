# frozen_string_literal: true

module Slack
  class MessageBuilder
    def initialize(visit)
      @visit = visit
      @employee = visit.employee
    end

    def build_notification_blocks
      [
        header_block,
        employee_info_block,
        notes_block,
        action_block
      ].compact
    end

    def build_plain_text
      "訪問者が来訪しました"
    end

    private

    def header_block
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*:wave: 訪問者が来訪しました*"
        }
      }
    end

    def employee_info_block
      {
        type: "section",
        fields: [
          {
            type: "mrkdwn",
            text: "*従業員:*\n#{@employee.name}"
          },
          {
            type: "mrkdwn",
            text: "*部署:*\n#{@employee.department.name}"
          }
        ]
      }
    end

    def notes_block
      return nil unless @visit.notes.present?

      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*メモ:*\n#{@visit.notes}"
        }
      }
    end

    def action_block
      {
        type: "actions",
        elements: [
          {
            type: "button",
            text: {
              type: "plain_text",
              text: "確認済みにする"
            },
            style: "primary",
            action_id: AppConfig::Slack::ACTION_ACKNOWLEDGE_VISIT,
            value: @visit.id.to_s
          }
        ]
      }
    end
  end
end

