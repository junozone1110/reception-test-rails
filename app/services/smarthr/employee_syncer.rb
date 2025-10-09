# frozen_string_literal: true

module Smarthr
  class EmployeeSyncer
    attr_reader :stats

    def initialize
      @client = Smarthr::Client.new
      @stats = {
        created: 0,
        updated: 0,
        deactivated: 0,
        skipped: 0,
        errors: []
      }
    end

    # 全従業員を同期
    def sync_all
      Rails.logger.info "Starting SmartHR employee sync..."

      smarthr_employees = @client.fetch_all_employees
      Rails.logger.info "Fetched #{smarthr_employees.size} employees from SmartHR"

      sync_employees(smarthr_employees)
      deactivate_missing_employees(smarthr_employees.map { |e| e[:id] })

      Rails.logger.info "SmartHR sync completed: #{@stats}"
      @stats
    rescue Smarthr::Client::ApiError, Smarthr::Client::ConfigurationError => e
      @stats[:errors] << e.message
      Rails.logger.error "SmartHR sync failed: #{e.message}"
      raise
    end

    private

    def sync_employees(smarthr_employees)
      smarthr_employees.each do |smarthr_emp|
        sync_employee(smarthr_emp)
      rescue => e
        error_msg = "Employee #{smarthr_emp[:id]}: #{e.message}"
        @stats[:errors] << error_msg
        Rails.logger.error "Failed to sync employee #{smarthr_emp[:id]}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end

    def sync_employee(smarthr_emp)
      ActiveRecord::Base.transaction do
        # 部署を取得または作成
        department = find_or_create_department(smarthr_emp)

        # SmartHR IDで従業員を検索
        employee = Employee.find_by(smarthr_id: smarthr_emp[:id])

        employee_params = build_employee_params(smarthr_emp, department)

        if employee
          update_existing_employee(employee, employee_params, smarthr_emp[:id])
        else
          create_new_employee(employee_params, smarthr_emp[:id])
        end
      end
    end

    def update_existing_employee(employee, employee_params, smarthr_id)
      # visible_to_visitorsは維持（更新しない）
      update_params = employee_params.except(:visible_to_visitors)
      
      if needs_update?(employee, update_params)
        employee.update!(update_params)
        @stats[:updated] += 1
        Rails.logger.info "Updated employee: #{employee.name} (SmartHR ID: #{smarthr_id})"
      else
        @stats[:skipped] += 1
        Rails.logger.debug "Skipped employee (no changes): #{employee.name}"
      end
    end

    def create_new_employee(employee_params, smarthr_id)
      # visible_to_visitorsはデフォルト値（false）が設定される
      employee = Employee.create!(employee_params.merge(smarthr_id: smarthr_id))
      @stats[:created] += 1
      Rails.logger.info "Created employee: #{employee.name} (SmartHR ID: #{smarthr_id})"
    end

    def find_or_create_department(smarthr_emp)
      # SmartHR APIのレスポンス構造に応じて調整
      dept_name = extract_department_name(smarthr_emp)

      if dept_name.present?
        Department.find_or_create_by!(name: dept_name)
      else
        # デフォルト部署（必要に応じて変更）
        Department.find_or_create_by!(name: "未所属")
      end
    end

    def extract_department_name(smarthr_emp)
      # SmartHR APIのレスポンスから部署名を取得
      # 実際のAPI構造に応じて調整が必要
      if smarthr_emp[:department].is_a?(Hash)
        smarthr_emp[:department][:name]
      elsif smarthr_emp[:dept_name].present?
        smarthr_emp[:dept_name]
      else
        smarthr_emp[:department]
      end
    end

    def build_employee_params(smarthr_emp, department)
      {
        name: build_full_name(smarthr_emp),
        email: smarthr_emp[:email],
        department: department,
        is_active: smarthr_emp[:emp_status] != "resigned", # 退職者は無効化
        slack_user_id: find_slack_user_id(smarthr_emp) || generate_dummy_slack_id(smarthr_emp[:id])
      }
    end

    def build_full_name(smarthr_emp)
      # 姓名を結合（SmartHRのAPI構造に応じて調整）
      last_name = smarthr_emp[:last_name] || smarthr_emp[:family_name] || ""
      first_name = smarthr_emp[:first_name] || smarthr_emp[:given_name] || ""
      "#{last_name} #{first_name}".strip
    end

    def needs_update?(employee, new_params)
      employee.name != new_params[:name] ||
        employee.email != new_params[:email] ||
        employee.department_id != new_params[:department]&.id ||
        employee.is_active != new_params[:is_active]
    end

    def find_slack_user_id(smarthr_emp)
      # SmartHRにSlack User IDが保存されている場合はそれを使用
      # カスタムフィールドなどで管理している場合の例：
      # smarthr_emp.dig(:custom_fields, :slack_user_id)

      # メールアドレスからSlack User IDを検索する場合：
      # email = smarthr_emp[:email]
      # find_slack_user_by_email(email) if email.present?

      nil # 実装が必要な場合はここを修正
    end

    def find_slack_user_by_email(email)
      # Slack APIでメールアドレスからUser IDを取得
      # Slack Web Clientを使用して実装可能
      # 例：
      # client = Slack::Web::Client.new(token: ENV["SLACK_BOT_TOKEN"])
      # response = client.users_lookupByEmail(email: email)
      # response["user"]["id"]
      nil
    rescue => e
      Rails.logger.warn "Failed to lookup Slack user by email #{email}: #{e.message}"
      nil
    end

    def generate_dummy_slack_id(smarthr_id)
      # Slack User IDが見つからない場合のダミーID
      # 後で手動で設定することを想定
      "SMARTHR_#{smarthr_id}"
    end

    def deactivate_missing_employees(smarthr_ids)
      # SmartHRに存在しない従業員を無効化
      missing_employees = Employee.where.not(smarthr_id: smarthr_ids)
                                 .where(is_active: true)
                                 .where.not(smarthr_id: nil)

      missing_employees.each do |employee|
        employee.update!(is_active: false)
        @stats[:deactivated] += 1
        Rails.logger.info "Deactivated employee: #{employee.name} (SmartHR ID: #{employee.smarthr_id})"
      end
    end
  end
end

