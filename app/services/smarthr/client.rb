# frozen_string_literal: true

module Smarthr
  class Client
    class ApiError < StandardError; end
    class ConfigurationError < StandardError; end

    BASE_URL = "https://api.smarthr.jp/v1"

    def initialize(subdomain: nil, access_token: nil)
      @subdomain = subdomain || ENV["SMARTHR_SUBDOMAIN"]
      @access_token = access_token || ENV["SMARTHR_ACCESS_TOKEN"]

      validate_configuration!
    end

  # 全従業員を取得（ページネーション対応）
  def fetch_all_employees
    employees = []
    page = 1
    per_page = AppConfig::SmartHR::DEFAULT_PER_PAGE

    loop do
      Rails.logger.info "Fetching employees page #{page}..."
      response = get("/crews", page: page, per: per_page)
      data = JSON.parse(response.body, symbolize_names: true)

      employees.concat(data[:data] || [])

      # 次のページがあるかチェック
      break if data[:meta][:next_page].nil?
      page = data[:meta][:next_page]
    end

    Rails.logger.info "Total employees fetched: #{employees.size}"
    employees
  rescue => e
    Rails.logger.error "SmartHR API error: #{e.message}"
    raise ApiError, "Failed to fetch employees: #{e.message}"
  end

    # 特定の従業員を取得
    def fetch_employee(crew_id)
      response = get("/crews/#{crew_id}")
      JSON.parse(response.body, symbolize_names: true)
    rescue => e
      Rails.logger.error "SmartHR API error: #{e.message}"
      raise ApiError, "Failed to fetch employee: #{e.message}"
    end

    private

    def validate_configuration!
      if @subdomain.blank?
        raise ConfigurationError, "SMARTHR_SUBDOMAIN is required. Please set the environment variable."
      end

      if @access_token.blank?
        raise ConfigurationError, "SMARTHR_ACCESS_TOKEN is required. Please set the environment variable."
      end
    end

    def get(path, params = {})
      response = connection.get(path, params)

      unless response.success?
        error_message = parse_error_message(response)
        Rails.logger.error "SmartHR API request failed: #{response.status} - #{error_message}"
        raise ApiError, "API request failed (#{response.status}): #{error_message}"
      end

      response
    end

    def parse_error_message(response)
      body = JSON.parse(response.body) rescue {}
      body["error"] || body["message"] || response.body
    end

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |conn|
        conn.request :authorization, "Bearer", @access_token
        conn.request :json
        conn.request :retry,
                     max: AppConfig::SmartHR::MAX_RETRY_COUNT,
                     interval: AppConfig::SmartHR::RETRY_INTERVAL,
                     backoff_factor: AppConfig::SmartHR::RETRY_BACKOFF_FACTOR,
                     retry_statuses: [429, 500, 502, 503, 504]
        conn.response :json
        conn.adapter Faraday.default_adapter
        conn.options.timeout = AppConfig::Timeout::SMARTHR_API_TIMEOUT
        conn.options.open_timeout = AppConfig::Timeout::SMARTHR_API_OPEN_TIMEOUT
      end
    end
  end
end

