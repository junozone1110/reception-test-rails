# frozen_string_literal: true

module Slack
  class MessageBuilder
    def initialize(visit, responder: nil, responded_at: nil)
      @visit = visit
      @employee = visit.employee
      @responder = responder # ボタンを押した人（Slackユーザー名）
      @responded_at = responded_at || Time.current
    end

    def build_notification_blocks
      if @visit.responded?
        build_updated_blocks
      else
        build_initial_blocks
      end
    end

    def build_plain_text
      if @visit.responded?
        "#{@employee.name}さんへの来客 - #{status_text}"
      else
        "#{@employee.name}さんへの来客があります"
      end
    end

    private

    def build_initial_blocks
      [
        header_block,
        visitor_info_block,
        action_instruction_block,
        action_buttons_block
      ].compact
    end

    def build_updated_blocks
      [
        header_block,
        visitor_info_block,
        response_history_block
      ].compact
    end

    def header_block
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*受付アプリからの通知です*"
        }
      }
    end

    def visitor_info_block
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "<@#{@employee.slack_user_id}>\n11階に#{@employee.name}さんへの来客があります。"
        }
      }
    end

    def action_instruction_block
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "下記ボタンからお客様にリアクションしましょう。"
        }
      }
    end

    def action_buttons_block
      {
        type: "actions",
        elements: [
          {
            type: "button",
            text: {
              type: "plain_text",
              text: "すぐ行きます"
            },
            style: "primary",
            action_id: AppConfig::Slack::ACTION_GOING_NOW,
            value: @visit.id.to_s
          },
          {
            type: "button",
            text: {
              type: "plain_text",
              text: "お待ちいただく"
            },
            action_id: AppConfig::Slack::ACTION_WAITING,
            value: @visit.id.to_s
          },
          {
            type: "button",
            text: {
              type: "plain_text",
              text: "心当たりがない"
            },
            style: "danger",
            action_id: AppConfig::Slack::ACTION_NO_MATCH,
            value: @visit.id.to_s
          }
        ]
      }
    end

    def response_history_block
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "#{@responder}さんが #{formatted_time} に「#{status_text}」ボタンを押しました。"
        }
      }
    end

    def status_text
      case @visit.status
      when "going_now"
        "すぐ行きます"
      when "waiting"
        "お待ちいただく"
      when "no_match"
        "心当たりがない"
      else
        "確認済み"
      end
    end

    def formatted_time
      @responded_at.strftime("%H:%M")
    end
  end
end

