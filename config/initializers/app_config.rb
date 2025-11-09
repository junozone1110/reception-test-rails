# frozen_string_literal: true

# アプリケーション全体で使用する定数
module AppConfig
  # Slack関連
  module Slack
    ACTION_GOING_NOW = "going_now"           # すぐ行きます
    ACTION_WAITING = "waiting"               # お待ちいただく
    ACTION_NO_MATCH = "no_match"             # 心当たりがない
    PAYLOAD_TYPE_BLOCK_ACTIONS = "block_actions"
  end

  # ページネーション
  module Pagination
    DEFAULT_PER_PAGE = 20
    MAX_PER_PAGE = 100
  end

  # SmartHR関連
  module SmartHR
    DEFAULT_PER_PAGE = 100
    MAX_RETRY_COUNT = 3
    RETRY_INTERVAL = 0.5
    RETRY_BACKOFF_FACTOR = 2
  end

  # タイムアウト設定
  module Timeout
    SLACK_API_TIMEOUT = 10
    SLACK_API_OPEN_TIMEOUT = 5
    SMARTHR_API_TIMEOUT = 30
    SMARTHR_API_OPEN_TIMEOUT = 10
  end
end

