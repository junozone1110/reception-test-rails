# 受付管理システム - アーキテクチャ・コード改善提案書

**プロジェクト**: Reception Management System  
**対象**: Rails 8.0.3 アプリケーション  
**分析日**: 2025年11月10日

---

## 📋 目次

1. [エグゼクティブサマリー](#エグゼクティブサマリー)
2. [現状分析](#現状分析)
3. [重大な問題](#重大な問題)
4. [アーキテクチャ改善提案](#アーキテクチャ改善提案)
5. [コード品質改善提案](#コード品質改善提案)
6. [セキュリティ改善](#セキュリティ改善)
7. [パフォーマンス最適化](#パフォーマンス最適化)
8. [テスト戦略](#テスト戦略)
9. [実装優先度](#実装優先度)

---

## エグゼクティブサマリー

### 🎯 全体評価

**総合スコア: 7.0/10**

| 項目 | 評価 | コメント |
|------|------|----------|
| アーキテクチャ設計 | ⭐⭐⭐⭐☆ | サービス層の分離は良好だが、設定管理に課題 |
| コード品質 | ⭐⭐⭐⭐☆ | 概ね良好だが、一部に重複やマジックナンバーあり |
| セキュリティ | ⭐⭐⭐☆☆ | 基本的な対策はあるが、改善の余地あり |
| テストカバレッジ | ⭐☆☆☆☆ | テストコードが未実装（致命的） |
| ドキュメント | ⭐⭐⭐⭐⭐ | 非常に詳細で整理されている |
| 保守性 | ⭐⭐⭐⭐☆ | 良好だが、設定の一元化が必要 |

### 🚨 最重要課題（今すぐ対応すべき）

1. **AppConfig未定義問題** - アプリケーションが起動しない（致命的）
2. **テストコードの不在** - 品質保証ができない
3. **エラーハンドリングの不統一** - 予期せぬエラーが発生する可能性

---

## 現状分析

### ✅ 優れている点

#### 1. サービス層の適切な分離
```ruby
# 良い例: 責任の明確な分離
app/services/
├── slack_notifier.rb          # Slack通知の責務
├── slack/message_builder.rb   # メッセージ構築の責務
├── smarthr/client.rb          # API通信の責務
└── smarthr/employee_syncer.rb # 同期ロジックの責務
```

#### 2. カスタムエラークラスの定義
```ruby
# 良い例: 統一されたエラーハンドリング
class ApplicationError < StandardError
  attr_reader :status_code, :error_code
  # ...
end
```

#### 3. スコープの適切な活用
```ruby
# 良い例: 再利用可能なクエリロジック
scope :active, -> { where(is_active: true) }
scope :visible_to_visitors, -> { where(visible_to_visitors: true) }
scope :by_department, ->(dept_id) { where(department_id: dept_id) if dept_id.present? }
```

#### 4. 非同期ジョブの活用
```ruby
# 良い例: リトライ戦略の実装
retry_on SlackNotifier::NotificationFailedError, 
         wait: :exponentially_longer, 
         attempts: 3
```

### ❌ 改善が必要な点

#### 1. Visitモデルの重複コード
```ruby
# 問題: enumの状態チェックメソッドが重複
def pending?
  status == "pending"  # enumが既に提供している
end

# Railsのenumは自動的に`pending?`メソッドを生成するため不要
```

#### 2. マジックナンバーとハードコーディング
```ruby
# 問題: ハードコーディングされた値
text: "11階に#{@employee.name}さんへの来客があります。"  # 11階が固定

# 問題: 固定されたユーザー名生成
"https://ui-avatars.com/api/?name=#{...}&background=random"  # UI生成サービスに依存
```

#### 3. N+1クエリの懸念
```ruby
# VisitsController#create
# employeeとdepartmentの関連が適切にロードされているか要確認
```

---

## 重大な問題

### 🔴 CRITICAL: AppConfig未定義

**問題の詳細**:
コード全体で`AppConfig::Slack`、`AppConfig::SmartHR`などを参照しているが、定義が見つからない。

**影響**:
- アプリケーションが起動しない
- すべてのSlack/SmartHR連携が動作しない

**場所**:
```ruby
# 未定義のまま使用されている箇所
app/services/slack_notifier.rb:9
app/services/slack/message_builder.rb:88
app/services/smarthr/client.rb:12
# 他多数...
```

**解決策**: 以下のような設定クラスを作成

```ruby
# config/initializers/app_config.rb
module AppConfig
  module Slack
    class << self
      def bot_token
        ENV.fetch("SLACK_BOT_TOKEN", nil)
      end
      
      def bot_token?
        bot_token.present?
      end
      
      def channel_id
        ENV.fetch("SLACK_CHANNEL_ID", nil)
      end
      
      def channel_id?
        channel_id.present?
      end
      
      def signing_secret
        ENV.fetch("SLACK_SIGNING_SECRET", nil)
      end
    end
    
    # アクションID定数
    ACTION_GOING_NOW = "visit_going_now"
    ACTION_WAITING = "visit_waiting"
    ACTION_NO_MATCH = "visit_no_match"
    
    PAYLOAD_TYPE_BLOCK_ACTIONS = "block_actions"
  end
  
  module SmartHR
    class << self
      def subdomain
        ENV.fetch("SMARTHR_SUBDOMAIN", nil)
      end
      
      def access_token
        ENV.fetch("SMARTHR_ACCESS_TOKEN", nil)
      end
    end
    
    DEFAULT_PER_PAGE = 100
    MAX_RETRY_COUNT = 3
    RETRY_INTERVAL = 1
    RETRY_BACKOFF_FACTOR = 2
  end
  
  module Timeout
    SMARTHR_API_TIMEOUT = 30
    SMARTHR_API_OPEN_TIMEOUT = 10
    SLACK_API_TIMEOUT = 10
  end
end
```

---

## アーキテクチャ改善提案

### 1. 設定管理の一元化

#### 現状の問題
- 環境変数が散在
- マジックナンバーがコード内に埋め込まれている
- 設定の変更が困難

#### 提案: Dry-Configurableの導入

```ruby
# Gemfile
gem 'dry-configurable'

# config/initializers/app_settings.rb
require 'dry/configurable'

class AppSettings
  extend Dry::Configurable
  
  setting :reception_floor, default: "11階"
  setting :company_name, default: "株式会社サンプル"
  
  setting :slack do
    setting :bot_token, constructor: -> (value) { ENV.fetch("SLACK_BOT_TOKEN", value) }
    setting :channel_id, constructor: -> (value) { ENV.fetch("SLACK_CHANNEL_ID", value) }
    setting :signing_secret, constructor: -> (value) { ENV.fetch("SLACK_SIGNING_SECRET", value) }
    setting :timeout, default: 10
  end
  
  setting :smarthr do
    setting :subdomain, constructor: -> (value) { ENV.fetch("SMARTHR_SUBDOMAIN", value) }
    setting :access_token, constructor: -> (value) { ENV.fetch("SMARTHR_ACCESS_TOKEN", value) }
    setting :per_page, default: 100
    setting :timeout, default: 30
  end
end

# 使用例
AppSettings.config.reception_floor # => "11階"
AppSettings.config.slack.bot_token # => ENV["SLACK_BOT_TOKEN"]
```

### 2. Repository パターンの導入（オプション）

大規模化を見越して、データアクセス層を抽象化

```ruby
# app/repositories/employee_repository.rb
class EmployeeRepository
  class << self
    def find_active_by_department(department_id, search_query: nil)
      scope = Employee.active
                      .visible_to_visitors
                      .includes(:department)
                      .by_department(department_id)
      
      scope = scope.search(search_query) if search_query.present?
      scope.ordered
    end
    
    def find_with_visit_stats(employee_id)
      Employee.includes(:visits)
              .where(id: employee_id)
              .select('employees.*, COUNT(visits.id) as visits_count')
              .group('employees.id')
              .first
    end
    
    def sync_from_smarthr(smarthr_data)
      # 同期ロジックをRepositoryに集約
    end
  end
end

# 使用例
employees = EmployeeRepository.find_active_by_department(params[:department_id])
```

### 3. Form Object パターンの導入

複雑なバリデーションや複数モデルにまたがる処理を分離

```ruby
# app/forms/visit_creation_form.rb
class VisitCreationForm
  include ActiveModel::Model
  include ActiveModel::Attributes
  
  attribute :employee_id, :integer
  attribute :notes, :string
  attribute :visitor_name, :string
  attribute :visitor_company, :string
  
  validates :employee_id, presence: true
  validates :visitor_name, presence: true, if: -> { visitor_info_required? }
  validates :notes, length: { maximum: 500 }
  
  def save
    return false unless valid?
    
    ActiveRecord::Base.transaction do
      @visit = Visit.create!(
        employee_id: employee_id,
        notes: notes
      )
      
      # 追加の処理（ログ記録など）
      
      @visit
    end
  end
  
  private
  
  def visitor_info_required?
    # ビジネスロジックに応じた判定
    AppSettings.config.require_visitor_info
  end
end
```

### 4. イベント駆動アーキテクチャの部分導入

Slack通知やログ記録などの副作用を疎結合に

```ruby
# app/events/visit_created_event.rb
class VisitCreatedEvent
  attr_reader :visit
  
  def initialize(visit)
    @visit = visit
  end
end

# app/subscribers/slack_notification_subscriber.rb
class SlackNotificationSubscriber
  def call(event)
    SlackNotificationJob.perform_later(event.visit.id)
  end
end

# app/subscribers/visit_log_subscriber.rb
class VisitLogSubscriber
  def call(event)
    Rails.logger.info "Visit created: #{event.visit.id} for employee #{event.visit.employee.name}"
  end
end

# config/initializers/event_subscribers.rb
Rails.application.config.after_initialize do
  ActiveSupport::Notifications.subscribe("visit.created") do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    visit = event.payload[:visit]
    
    SlackNotificationSubscriber.new.call(VisitCreatedEvent.new(visit))
    VisitLogSubscriber.new.call(VisitCreatedEvent.new(visit))
  end
end

# モデルから発行
class Visit < ApplicationRecord
  after_create :publish_created_event
  
  private
  
  def publish_created_event
    ActiveSupport::Notifications.instrument("visit.created", visit: self)
  end
end
```

### 5. API バージョニング戦略

将来のAPI提供を見越した構造化

```ruby
# app/controllers/api/v1/base_controller.rb
module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods
      
      before_action :authenticate
      
      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ApplicationError, with: :handle_application_error
      
      private
      
      def authenticate
        authenticate_or_request_with_http_token do |token, options|
          # API認証ロジック
          ApiKey.exists?(token: token, revoked_at: nil)
        end
      end
      
      def handle_application_error(error)
        render json: {
          error: {
            code: error.error_code,
            message: error.message
          }
        }, status: error.status_code
      end
    end
  end
end

# app/controllers/api/v1/visits_controller.rb
module Api
  module V1
    class VisitsController < BaseController
      def create
        form = VisitCreationForm.new(visit_params)
        
        if form.save
          render json: VisitSerializer.new(form.visit), status: :created
        else
          render json: { errors: form.errors }, status: :unprocessable_entity
        end
      end
      
      private
      
      def visit_params
        params.require(:visit).permit(:employee_id, :notes, :visitor_name)
      end
    end
  end
end
```

---

## コード品質改善提案

### 1. Visitモデルのリファクタリング

#### 問題点
- enumの状態チェックメソッドが重複
- `status_text`メソッドの重複定義

#### 改善後
```ruby
class Visit < ApplicationRecord
  belongs_to :employee
  
  # ステータス定義
  enum :status, {
    pending: "pending",
    going_now: "going_now",
    waiting: "waiting",
    no_match: "no_match"
  }, prefix: true
  
  validates :status, presence: true
  validates :employee, presence: true
  
  # スコープ
  scope :recent, -> { order(created_at: :desc) }
  scope :today, -> { where(created_at: Time.zone.now.beginning_of_day..) }
  scope :this_week, -> { where(created_at: Time.zone.now.beginning_of_week..) }
  scope :responded, -> { where.not(status: :pending) }
  
  # ステータステキストのマッピング（定数化）
  STATUS_TEXTS = {
    "pending" => "確認待ち",
    "going_now" => "すぐ行きます",
    "waiting" => "お待ちいただく",
    "no_match" => "心当たりがない"
  }.freeze
  
  # responded?はenumから自動生成されるメソッドを利用
  def responded?
    !status_pending?
  end
  
  # ステータステキストの取得
  def status_text
    STATUS_TEXTS.fetch(status, "確認済み")
  end
  
  # クラスメソッド版（後方互換性）
  def self.status_text_for(status_value)
    STATUS_TEXTS.fetch(status_value.to_s, "確認済み")
  end
  
  # 表示用メソッド
  def formatted_created_at
    I18n.l(created_at, format: :long) # i18n対応
  end
end
```

### 2. Employeeモデルの改善

```ruby
class Employee < ApplicationRecord
  belongs_to :department
  has_many :visits, dependent: :restrict_with_error
  
  # バリデーション
  validates :name, presence: true, length: { maximum: 100 }
  validates :slack_user_id, 
            presence: true, 
            uniqueness: { case_sensitive: true },
            format: { 
              with: /\A[A-Z0-9_]+\z/, 
              message: :invalid_slack_user_id 
            }
  validates :email, 
            uniqueness: { case_sensitive: false }, 
            allow_nil: true,
            format: { 
              with: URI::MailTo::EMAIL_REGEXP, 
              allow_blank: true 
            }
  validates :department, presence: true
  
  # スコープの改善
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :visible_to_visitors, -> { where(visible_to_visitors: true) }
  scope :hidden_from_visitors, -> { where(visible_to_visitors: false) }
  scope :by_department, ->(dept_id) { where(department_id: dept_id) if dept_id.present? }
  scope :search, ->(query) { 
    sanitized = sanitize_sql_like(query)
    where("name LIKE :query OR email LIKE :query", query: "%#{sanitized}%") if query.present?
  }
  scope :recent, -> { order(created_at: :desc) }
  scope :ordered, -> { joins(:department).merge(Department.ordered).order(:name) }
  scope :synced_from_smarthr, -> { where.not(smarthr_id: nil) }
  scope :not_synced_from_smarthr, -> { where(smarthr_id: nil) }
  
  # Concernに抽出可能
  scope :with_visit_stats, -> {
    left_joins(:visits)
      .select('employees.*, COUNT(visits.id) as visits_count')
      .group('employees.id')
  }
  
  # コールバック
  after_initialize :set_default_avatar_url, if: :new_record?
  before_validation :normalize_email
  
  # ビジネスロジック
  def display_name
    is_active? ? name : "#{name}（無効）"
  end
  
  def full_info
    "#{name} (#{department.name})"
  end
  
  # Slack通知可能かチェック
  def notifiable?
    is_active? && slack_user_id.present? && slack_user_id_valid?
  end
  
  private
  
  def set_default_avatar_url
    self.avatar_url ||= generate_avatar_url
  end
  
  def generate_avatar_url
    # サービスクラスに委譲する方が良い
    AvatarUrlGenerator.generate(name)
  end
  
  def normalize_email
    self.email = email.downcase.strip if email.present?
  end
  
  def slack_user_id_valid?
    # より厳密なバリデーション
    slack_user_id.match?(/\A[A-Z][A-Z0-9]{8,10}\z/)
  end
end

# app/services/avatar_url_generator.rb
class AvatarUrlGenerator
  DEFAULT_SERVICE = "ui-avatars.com"
  
  class << self
    def generate(name, service: DEFAULT_SERVICE)
      case service
      when "ui-avatars.com"
        generate_ui_avatars_url(name)
      when "gravatar"
        generate_gravatar_url(name)
      else
        default_avatar_url
      end
    end
    
    private
    
    def generate_ui_avatars_url(name)
      encoded_name = ERB::Util.url_encode(name.to_s)
      "https://ui-avatars.com/api/?name=#{encoded_name}&background=random&size=200"
    end
    
    def generate_gravatar_url(email)
      hash = Digest::MD5.hexdigest(email.to_s.downcase)
      "https://www.gravatar.com/avatar/#{hash}?d=identicon&s=200"
    end
    
    def default_avatar_url
      "/assets/default_avatar.png"
    end
  end
end
```

### 3. SlackNotifierの改善

```ruby
# app/services/slack_notifier.rb
class SlackNotifier
  class NotConfiguredError < StandardError; end
  class NotificationFailedError < StandardError; end
  
  def initialize(client: nil)
    validate_configuration!
    @client = client || build_client
  end
  
  def notify_visit(visit)
    message_builder = Slack::MessageBuilder.new(visit)
    
    log_notification_start(visit)
    
    response = send_message_to_channel(message_builder)
    save_message_timestamp(visit, response)
    log_notification_success(visit)
    
    response
  rescue ::Slack::Web::Api::Errors::SlackError => e
    handle_slack_error(e)
  rescue StandardError => e
    handle_unexpected_error(e)
  end
  
  def update_message(visit, responder: nil, responded_at: nil)
    message_builder = Slack::MessageBuilder.new(
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
    ::Slack::Web::Client.new(token: bot_token)
  end
  
  def validate_configuration!
    raise NotConfiguredError, "SLACK_BOT_TOKEN is not configured" unless bot_token.present?
    raise NotConfiguredError, "SLACK_CHANNEL_ID is not configured" unless channel_id.present?
  end
  
  def bot_token
    @bot_token ||= AppSettings.config.slack.bot_token
  end
  
  def channel_id
    @channel_id ||= AppSettings.config.slack.channel_id
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
  
  # ログメソッド群をLoggerモジュールに抽出
  include SlackNotifierLogger
  
  # エラーハンドリングをErrorHandlerモジュールに抽出
  include SlackNotifierErrorHandler
end

# app/services/concerns/slack_notifier_logger.rb
module SlackNotifierLogger
  extend ActiveSupport::Concern
  
  private
  
  def log_notification_start(visit)
    Rails.logger.info(
      "Sending Slack notification",
      visit_id: visit.id,
      channel: channel_id,
      employee: visit.employee.name
    )
  end
  
  def log_notification_success(visit)
    Rails.logger.info(
      "Slack notification sent successfully",
      visit_id: visit.id
    )
  end
  
  def log_blocks(blocks)
    Rails.logger.debug "Slack blocks: #{JSON.pretty_generate(blocks)}"
  end
  
  # 他のログメソッド...
end
```

### 4. SmartHR Syncerの改善

```ruby
# app/services/smarthr/employee_syncer.rb
module Smarthr
  class EmployeeSyncer
    attr_reader :stats, :errors
    
    def initialize(client: nil)
      @client = client || Smarthr::Client.new
      @stats = SyncStats.new
      @errors = []
    end
    
    def sync_all
      log_sync_start
      
      ActiveRecord::Base.transaction do
        smarthr_employees = fetch_employees
        
        sync_employees(smarthr_employees)
        deactivate_missing_employees(smarthr_employees.map { |e| e[:id] })
      end
      
      log_sync_completion
      create_sync_log
      
      @stats
    rescue Smarthr::Client::ApiError, Smarthr::Client::ConfigurationError => e
      handle_sync_error(e)
      raise
    end
    
    private
    
    def fetch_employees
      employees = @client.fetch_all_employees
      log_fetch_completion(employees.size)
      employees
    end
    
    def sync_employees(smarthr_employees)
      smarthr_employees.each do |smarthr_emp|
        sync_employee(smarthr_emp)
      rescue StandardError => e
        record_employee_error(smarthr_emp[:id], e)
      end
    end
    
    def sync_employee(smarthr_emp)
      EmployeeSyncService.new(smarthr_emp, @stats).call
    end
    
    def deactivate_missing_employees(smarthr_ids)
      MissingEmployeeDeactivator.new(smarthr_ids, @stats).call
    end
    
    def create_sync_log
      SyncLog.create!(
        service: "smarthr",
        status: @errors.empty? ? "success" : "partial_success",
        details: @stats.to_h,
        error_message: @errors.join("\n"),
        synced_at: Time.current
      )
    end
    
    def record_employee_error(employee_id, error)
      error_msg = "Employee #{employee_id}: #{error.message}"
      @errors << error_msg
      @stats.increment_errors
      Rails.logger.error error_msg
    end
    
    # ロギングメソッド
    def log_sync_start
      Rails.logger.info "Starting SmartHR employee sync..."
    end
    
    def log_fetch_completion(count)
      Rails.logger.info "Fetched #{count} employees from SmartHR"
    end
    
    def log_sync_completion
      Rails.logger.info "SmartHR sync completed: #{@stats}"
    end
    
    def handle_sync_error(error)
      @errors << error.message
      Rails.logger.error "SmartHR sync failed: #{error.message}"
    end
  end
  
  # app/services/smarthr/sync_stats.rb
  class SyncStats
    attr_reader :created, :updated, :deactivated, :skipped, :errors
    
    def initialize
      @created = 0
      @updated = 0
      @deactivated = 0
      @skipped = 0
      @errors = 0
    end
    
    def increment_created
      @created += 1
    end
    
    def increment_updated
      @updated += 1
    end
    
    def increment_deactivated
      @deactivated += 1
    end
    
    def increment_skipped
      @skipped += 1
    end
    
    def increment_errors
      @errors += 1
    end
    
    def to_h
      {
        created: @created,
        updated: @updated,
        deactivated: @deactivated,
        skipped: @skipped,
        errors: @errors
      }
    end
    
    def to_s
      "Created: #{@created}, Updated: #{@updated}, " \
      "Deactivated: #{@deactivated}, Skipped: #{@skipped}, " \
      "Errors: #{@errors}"
    end
  end
  
  # app/services/smarthr/employee_sync_service.rb
  class EmployeeSyncService
    def initialize(smarthr_employee, stats)
      @smarthr_emp = smarthr_employee
      @stats = stats
    end
    
    def call
      ActiveRecord::Base.transaction do
        department = find_or_create_department
        employee = find_employee
        
        if employee
          update_employee(employee, department)
        else
          create_employee(department)
        end
      end
    end
    
    private
    
    def find_employee
      Employee.find_by(smarthr_id: @smarthr_emp[:id])
    end
    
    def find_or_create_department
      dept_name = DepartmentNameExtractor.extract(@smarthr_emp)
      Department.find_or_create_by!(name: dept_name)
    end
    
    def update_employee(employee, department)
      params = build_employee_params(department)
      
      if employee_changed?(employee, params)
        employee.update!(params)
        @stats.increment_updated
        log_update(employee)
      else
        @stats.increment_skipped
        log_skip(employee)
      end
    end
    
    def create_employee(department)
      params = build_employee_params(department).merge(
        smarthr_id: @smarthr_emp[:id],
        visible_to_visitors: false  # 新規は非表示
      )
      
      employee = Employee.create!(params)
      @stats.increment_created
      log_create(employee)
    end
    
    def build_employee_params(department)
      {
        name: NameBuilder.build(@smarthr_emp),
        email: @smarthr_emp[:email],
        department: department,
        is_active: @smarthr_emp[:emp_status] != "resigned",
        slack_user_id: SlackUserIdResolver.resolve(@smarthr_emp)
      }
    end
    
    def employee_changed?(employee, params)
      employee.name != params[:name] ||
        employee.email != params[:email] ||
        employee.department_id != params[:department]&.id ||
        employee.is_active != params[:is_active]
    end
    
    # ログメソッド
    def log_update(employee)
      Rails.logger.info "Updated employee: #{employee.name} (SmartHR ID: #{employee.smarthr_id})"
    end
    
    def log_skip(employee)
      Rails.logger.debug "Skipped employee (no changes): #{employee.name}"
    end
    
    def log_create(employee)
      Rails.logger.info "Created employee: #{employee.name} (SmartHR ID: #{employee.smarthr_id})"
    end
  end
end
```

### 5. コントローラーの改善

```ruby
# app/controllers/visits_controller.rb
class VisitsController < ApplicationController
  before_action :set_employee, only: [:new]
  
  def new
    @visit = Visit.new(employee: @employee)
  end
  
  def create
    result = CreateVisitService.call(visit_params, session: session)
    
    if result.success?
      redirect_to complete_path, notice: t(".success")
    else
      handle_creation_failure(result)
    end
  end
  
  def complete
    @visit = find_last_visit
  end
  
  def status
    @visit = Visit.includes(:employee).find(params[:id])
    render json: VisitStatusSerializer.new(@visit).as_json
  rescue ActiveRecord::RecordNotFound
    render json: { error: t(".not_found") }, status: :not_found
  end
  
  private
  
  def set_employee
    @employee = Employee.active.visible_to_visitors.find(params[:employee_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: t(".employee_not_found")
  end
  
  def find_last_visit
    return nil unless session[:last_visit_id]
    
    Visit.find(session[:last_visit_id])
  rescue ActiveRecord::RecordNotFound
    nil
  end
  
  def handle_creation_failure(result)
    @employee = Employee.find_by(id: visit_params[:employee_id])
    flash.now[:alert] = result.error_message
    render :new, status: result.status_code
  end
  
  def visit_params
    params.require(:visit).permit(:employee_id, :notes)
  end
end

# app/services/create_visit_service.rb
class CreateVisitService
  Result = Struct.new(:success?, :visit, :error_message, :status_code, keyword_init: true)
  
  class << self
    def call(params, session:)
      new(params, session).call
    end
  end
  
  def initialize(params, session)
    @params = params
    @session = session
  end
  
  def call
    ActiveRecord::Base.transaction do
      visit = Visit.create!(
        employee_id: @params[:employee_id],
        notes: @params[:notes]
      )
      
      @session[:last_visit_id] = visit.id
      
      # 非同期でSlack通知
      SlackNotificationJob.perform_later(visit.id)
      
      success_result(visit)
    end
  rescue ActiveRecord::RecordInvalid => e
    validation_error_result(e)
  rescue SlackNotifier::NotConfiguredError => e
    configuration_error_result(e)
  rescue StandardError => e
    unexpected_error_result(e)
  end
  
  private
  
  def success_result(visit)
    Result.new(
      success?: true,
      visit: visit,
      error_message: nil,
      status_code: :ok
    )
  end
  
  def validation_error_result(error)
    Rails.logger.error "Visit validation failed: #{error.message}"
    Result.new(
      success?: false,
      visit: nil,
      error_message: I18n.t("visits.create.validation_error"),
      status_code: :unprocessable_entity
    )
  end
  
  def configuration_error_result(error)
    Rails.logger.error "Slack not configured: #{error.message}"
    Result.new(
      success?: false,
      visit: nil,
      error_message: I18n.t("visits.create.configuration_error"),
      status_code: :internal_server_error
    )
  end
  
  def unexpected_error_result(error)
    Rails.logger.error "Unexpected error: #{error.class.name} - #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
    Result.new(
      success?: false,
      visit: nil,
      error_message: I18n.t("visits.create.unexpected_error"),
      status_code: :internal_server_error
    )
  end
end

# app/serializers/visit_status_serializer.rb
class VisitStatusSerializer
  def initialize(visit)
    @visit = visit
  end
  
  def as_json
    {
      id: @visit.id,
      status: @visit.status,
      status_text: @visit.status_text,
      responded: @visit.responded?,
      employee: {
        id: @visit.employee.id,
        name: @visit.employee.name,
        department: @visit.employee.department.name
      },
      created_at: @visit.created_at.iso8601,
      updated_at: @visit.updated_at.iso8601
    }
  end
end
```

---

## セキュリティ改善

### 1. SQL Injection対策の強化

```ruby
# 現状（脆弱性あり）
scope :search, ->(query) { 
  where("name LIKE ?", "%#{sanitize_sql_like(query)}%") if query.present? 
}

# 改善後（より安全）
scope :search, ->(query) {
  return none if query.blank?
  
  sanitized = sanitize_sql_like(query.to_s)
  where("name LIKE :query OR email LIKE :query", query: "%#{sanitized}%")
}

# さらに良い方法: Arel使用
scope :search, ->(query) {
  return none if query.blank?
  
  sanitized = sanitize_sql_like(query.to_s)
  name_matches = arel_table[:name].matches("%#{sanitized}%")
  email_matches = arel_table[:email].matches("%#{sanitized}%")
  where(name_matches.or(email_matches))
}
```

### 2. CSRF対策の強化

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  # CSRFトークンをヘッダーに設定（SPA対応）
  after_action :set_csrf_cookie
  
  private
  
  def set_csrf_cookie
    cookies["CSRF-TOKEN"] = {
      value: form_authenticity_token,
      same_site: :strict,
      secure: Rails.env.production?
    }
  end
end

# Slack Webhook用のコントローラーはCSRFを無効化するが、
# 代わりにSlack署名検証を必須に
class SlackActionsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_slack_signature  # 必須
  
  private
  
  def verify_slack_signature
    verifier = SlackSignatureVerifier.new(skip_in_development: false)  # 開発環境でも検証
    verifier.verify(request)
  rescue SlackSignatureError => e
    Rails.logger.error "Slack signature verification failed: #{e.message}"
    head :unauthorized
  end
end
```

### 3. 環境変数の暗号化

```ruby
# config/initializers/encrypted_credentials.rb
# Rails 7.1+のencrypted credentialsを活用

# 使用例
Rails.application.credentials.dig(:slack, :bot_token)
Rails.application.credentials.dig(:smarthr, :access_token)

# config/credentials/production.yml.enc に保存
# EDITOR="vim" rails credentials:edit --environment production
```

### 4. Rate Limiting の導入

```ruby
# Gemfile
gem 'rack-attack'

# config/initializers/rack_attack.rb
class Rack::Attack
  # 訪問者からの受付申請のレート制限
  throttle('visits/ip', limit: 10, period: 60.seconds) do |req|
    req.ip if req.path == '/visits' && req.post?
  end
  
  # Slack Webhookのレート制限（念のため）
  throttle('slack_webhook/ip', limit: 100, period: 60.seconds) do |req|
    req.ip if req.path == '/slack/actions' && req.post?
  end
  
  # 管理画面のログイン試行回数制限
  throttle('admin_login/email', limit: 5, period: 60.seconds) do |req|
    if req.path == '/admin/login' && req.post?
      req.params['email'].to_s.downcase.presence
    end
  end
  
  # ブロック時のレスポンス
  self.blocklisted_responder = lambda do |request|
    [429, {'Content-Type' => 'application/json'}, [{
      error: 'Too Many Requests',
      message: 'リクエストが多すぎます。しばらく待ってから再度お試しください。'
    }.to_json]]
  end
end
```

### 5. 管理画面の認証強化

```ruby
# app/controllers/admin/base_controller.rb
module Admin
  class BaseController < ApplicationController
    before_action :authenticate_admin
    before_action :check_admin_session_timeout
    after_action :update_session_timestamp
    
    private
    
    def authenticate_admin
      unless current_admin
        redirect_to admin_login_path, alert: "ログインが必要です"
      end
    end
    
    def current_admin
      return @current_admin if defined?(@current_admin)
      
      @current_admin = AdminUser.find_by(id: session[:admin_id]) if session[:admin_id]
    end
    helper_method :current_admin
    
    def check_admin_session_timeout
      if session_expired?
        reset_session
        redirect_to admin_login_path, alert: "セッションが期限切れです。再度ログインしてください。"
      end
    end
    
    def session_expired?
      return false unless session[:last_activity_at]
      
      Time.current - session[:last_activity_at].to_time > 30.minutes
    end
    
    def update_session_timestamp
      session[:last_activity_at] = Time.current
    end
  end
end

# 2要素認証の追加（オプション）
# Gemfile
gem 'devise'
gem 'devise-two-factor'
gem 'rqrcode'
```

---

## パフォーマンス最適化

### 1. N+1クエリの解決

```ruby
# app/controllers/employees_controller.rb
class EmployeesController < ApplicationController
  def index
    @departments = Department.ordered
                             .includes(:employees)  # N+1解消
                             .with_active_employees
    
    @employees = Employee.active
                         .visible_to_visitors
                         .includes(:department)  # N+1解消
                         .by_department(params[:department_id])
                         .search(params[:query])
                         .ordered
  end
end

# app/controllers/admin/employees_controller.rb
module Admin
  class EmployeesController < BaseController
    def index
      @employees = Employee.includes(:department)  # N+1解消
                           .with_visit_count  # カウントを事前計算
                           .page(params[:page])
                           .per(25)
    end
  end
end

# app/models/employee.rb
scope :with_visit_count, -> {
  left_joins(:visits)
    .select('employees.*, COUNT(visits.id) as visits_count')
    .group('employees.id')
}
```

### 2. キャッシング戦略

```ruby
# app/models/department.rb
class Department < ApplicationRecord
  # カウンターキャッシュ
  has_many :employees, dependent: :restrict_with_error, counter_cache: true
  
  # フラグメントキャッシュ（ビュー）
  def cache_key_with_employees
    [cache_key, employees_count, employees.maximum(:updated_at)].join('/')
  end
end

# app/views/employees/index.html.erb
<% @departments.each do |department| %>
  <% cache department.cache_key_with_employees do %>
    <!-- 部署セクション -->
  <% end %>
<% end %>

# ロシアンドール（Russian Doll）キャッシング
<% cache @employees do %>
  <% @employees.each do |employee| %>
    <% cache employee do %>
      <!-- 従業員カード -->
    <% end %>
  <% end %>
<% end %>
```

### 3. データベースインデックスの最適化

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_performance_indexes.rb
class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Employeeテーブル
    add_index :employees, [:is_active, :visible_to_visitors], 
              name: 'idx_employees_on_active_visible'
    add_index :employees, [:department_id, :is_active], 
              name: 'idx_employees_on_dept_active'
    add_index :employees, :slack_user_id, unique: true
    add_index :employees, :email, unique: true, where: "email IS NOT NULL"
    
    # Visitテーブル
    add_index :visits, [:employee_id, :created_at], 
              name: 'idx_visits_on_employee_created'
    add_index :visits, [:status, :created_at], 
              name: 'idx_visits_on_status_created'
    add_index :visits, :slack_message_ts, unique: true, 
              where: "slack_message_ts IS NOT NULL"
    
    # Departmentテーブル
    add_index :departments, :position
    
    # 複合インデックス（カバリングインデックス）
    add_index :employees, 
              [:is_active, :visible_to_visitors, :department_id, :name], 
              name: 'idx_employees_for_visitor_search'
  end
end
```

### 4. バックグラウンドジョブの最適化

```ruby
# app/jobs/slack_notification_job.rb
class SlackNotificationJob < ApplicationJob
  queue_as :critical  # 優先度の高いキュー
  
  # より詳細なリトライ設定
  retry_on SlackNotifier::NotificationFailedError,
           wait: :polynomially_longer,  # 1s, 4s, 9s, 16s...
           attempts: 5,
           queue: :default
  
  retry_on Faraday::TimeoutError,
           wait: 5.seconds,
           attempts: 3
  
  # 一時的なエラーのみリトライ
  retry_on ::Slack::Web::Api::Errors::RateLimited,
           wait: ->(executions) { executions * 60 },  # 1分, 2分, 3分...
           attempts: 3
  
  discard_on SlackNotifier::NotConfiguredError
  discard_on ActiveRecord::RecordNotFound
  discard_on ::Slack::Web::Api::Errors::AccountInactive
  
  def perform(visit_id)
    visit = Visit.includes(employee: :department).find(visit_id)
    
    # Slack通知をスキップする条件
    return unless should_send_notification?
    
    notifier = SlackNotifier.new
    notifier.notify_visit(visit)
    
    log_success(visit)
  rescue StandardError => e
    log_failure(visit_id, e)
    raise
  end
  
  private
  
  def should_send_notification?
    AppSettings.config.slack.bot_token.present?
  end
  
  def log_success(visit)
    Rails.logger.info(
      "Slack notification completed",
      visit_id: visit.id,
      employee: visit.employee.name,
      attempts: executions
    )
  end
  
  def log_failure(visit_id, error)
    Rails.logger.error(
      "Slack notification failed",
      visit_id: visit_id,
      error: error.class.name,
      message: error.message,
      attempts: executions
    )
  end
end

# config/initializers/solid_queue.rb
# キューの優先度設定
Rails.application.configure do
  config.solid_queue.connects_to = { database: { writing: :queue } }
  
  # ワーカー設定
  config.solid_queue.workers = [
    {
      queues: "critical",
      threads: 3,
      processes: 2,
      polling_interval: 1
    },
    {
      queues: "default",
      threads: 5,
      processes: 2,
      polling_interval: 5
    },
    {
      queues: "low_priority",
      threads: 2,
      processes: 1,
      polling_interval: 10
    }
  ]
end
```

### 5. ページネーションとページングの改善

```ruby
# Gemfile
gem 'kaminari'  # または 'pagy' (より軽量)

# app/controllers/admin/employees_controller.rb
def index
  @employees = Employee.includes(:department)
                       .order(created_at: :desc)
                       .page(params[:page])
                       .per(25)
end

# カーソルベースページネーション（大量データ向け）
# Gemfile
gem 'pagy'

# app/controllers/api/v1/visits_controller.rb
def index
  @pagy, @visits = pagy(
    Visit.includes(:employee)
         .where('created_at > ?', params[:after])
         .order(created_at: :desc),
    items: 50
  )
  
  render json: {
    visits: @visits,
    pagy: pagy_metadata(@pagy)
  }
end
```

---

## テスト戦略

### 1. テスト環境のセットアップ

```ruby
# spec/rails_helper.rb
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
abort("Running in production mode!") if Rails.env.production?

require 'rspec/rails'
require 'capybara/rspec'
require 'webmock/rspec'

# FactoryBotの設定
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end
  
  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
  
  # Slack APIをモック
  config.before(:each) do
    allow_any_instance_of(SlackNotifier).to receive(:notify_visit)
    WebMock.disable_net_connect!(allow_localhost: true)
  end
end

# spec/support/shared_contexts/with_slack_mocked.rb
RSpec.shared_context 'with slack mocked' do
  let(:slack_client) { instance_double(::Slack::Web::Client) }
  let(:slack_response) { { 'ok' => true, 'ts' => '1234567890.123456' } }
  
  before do
    allow(::Slack::Web::Client).to receive(:new).and_return(slack_client)
    allow(slack_client).to receive(:chat_postMessage).and_return(slack_response)
    allow(slack_client).to receive(:chat_update).and_return(slack_response)
  end
end
```

### 2. モデルテスト

```ruby
# spec/models/employee_spec.rb
require 'rails_helper'

RSpec.describe Employee, type: :model do
  describe 'associations' do
    it { should belong_to(:department) }
    it { should have_many(:visits).dependent(:restrict_with_error) }
  end
  
  describe 'validations' do
    subject { build(:employee) }
    
    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(100) }
    it { should validate_presence_of(:slack_user_id) }
    it { should validate_uniqueness_of(:slack_user_id).case_sensitive }
    
    context 'slack_user_id format' do
      it 'accepts valid Slack user ID' do
        employee = build(:employee, slack_user_id: 'U1234ABCD')
        expect(employee).to be_valid
      end
      
      it 'rejects invalid Slack user ID' do
        employee = build(:employee, slack_user_id: 'invalid_id')
        expect(employee).not_to be_valid
        expect(employee.errors[:slack_user_id]).to be_present
      end
    end
    
    context 'email format' do
      it 'accepts valid email' do
        employee = build(:employee, email: 'test@example.com')
        expect(employee).to be_valid
      end
      
      it 'rejects invalid email' do
        employee = build(:employee, email: 'invalid_email')
        expect(employee).not_to be_valid
      end
      
      it 'allows nil email' do
        employee = build(:employee, email: nil)
        expect(employee).to be_valid
      end
    end
  end
  
  describe 'scopes' do
    let!(:active_employee) { create(:employee, is_active: true) }
    let!(:inactive_employee) { create(:employee, is_active: false) }
    let!(:visible_employee) { create(:employee, visible_to_visitors: true) }
    let!(:hidden_employee) { create(:employee, visible_to_visitors: false) }
    
    describe '.active' do
      it 'returns only active employees' do
        expect(Employee.active).to include(active_employee)
        expect(Employee.active).not_to include(inactive_employee)
      end
    end
    
    describe '.visible_to_visitors' do
      it 'returns only visible employees' do
        expect(Employee.visible_to_visitors).to include(visible_employee)
        expect(Employee.visible_to_visitors).not_to include(hidden_employee)
      end
    end
    
    describe '.search' do
      let!(:john) { create(:employee, name: 'John Doe') }
      let!(:jane) { create(:employee, name: 'Jane Smith') }
      
      it 'finds employees by name' do
        results = Employee.search('John')
        expect(results).to include(john)
        expect(results).not_to include(jane)
      end
      
      it 'is case insensitive' do
        results = Employee.search('john')
        expect(results).to include(john)
      end
      
      it 'returns all when query is blank' do
        expect(Employee.search('').count).to eq(Employee.count)
      end
    end
  end
  
  describe '#display_name' do
    it 'returns name for active employee' do
      employee = build(:employee, name: 'John Doe', is_active: true)
      expect(employee.display_name).to eq('John Doe')
    end
    
    it 'returns name with inactive marker for inactive employee' do
      employee = build(:employee, name: 'John Doe', is_active: false)
      expect(employee.display_name).to eq('John Doe（無効）')
    end
  end
  
  describe '#notifiable?' do
    it 'returns true for active employee with valid Slack ID' do
      employee = build(:employee, is_active: true, slack_user_id: 'U1234ABCD')
      expect(employee.notifiable?).to be true
    end
    
    it 'returns false for inactive employee' do
      employee = build(:employee, is_active: false, slack_user_id: 'U1234ABCD')
      expect(employee.notifiable?).to be false
    end
  end
  
  describe 'callbacks' do
    describe 'avatar URL generation' do
      it 'sets default avatar URL on create' do
        employee = create(:employee, avatar_url: nil)
        expect(employee.avatar_url).to be_present
      end
      
      it 'does not overwrite existing avatar URL' do
        url = 'https://example.com/avatar.png'
        employee = create(:employee, avatar_url: url)
        expect(employee.avatar_url).to eq(url)
      end
    end
  end
end

# spec/factories/employees.rb
FactoryBot.define do
  factory :employee do
    sequence(:name) { |n| "Employee #{n}" }
    sequence(:email) { |n| "employee#{n}@example.com" }
    sequence(:slack_user_id) { |n| "U#{n.to_s.rjust(9, '0')}" }
    association :department
    is_active { true }
    visible_to_visitors { true }
    
    trait :inactive do
      is_active { false }
    end
    
    trait :hidden do
      visible_to_visitors { false }
    end
    
    trait :with_visits do
      transient do
        visits_count { 3 }
      end
      
      after(:create) do |employee, evaluator|
        create_list(:visit, evaluator.visits_count, employee: employee)
      end
    end
  end
end
```

### 3. サービステスト

```ruby
# spec/services/slack_notifier_spec.rb
require 'rails_helper'

RSpec.describe SlackNotifier, type: :service do
  include_context 'with slack mocked'
  
  let(:department) { create(:department) }
  let(:employee) { create(:employee, department: department) }
  let(:visit) { create(:visit, employee: employee) }
  
  describe '#notify_visit' do
    context 'when configuration is valid' do
      before do
        allow(AppSettings.config.slack).to receive(:bot_token).and_return('xoxb-test-token')
        allow(AppSettings.config.slack).to receive(:channel_id).and_return('C1234567890')
      end
      
      it 'sends notification successfully' do
        notifier = described_class.new
        response = notifier.notify_visit(visit)
        
        expect(response['ok']).to be true
        expect(slack_client).to have_received(:chat_postMessage)
      end
      
      it 'saves message timestamp' do
        notifier = described_class.new
        notifier.notify_visit(visit)
        
        visit.reload
        expect(visit.slack_message_ts).to eq('1234567890.123456')
      end
    end
    
    context 'when bot token is not configured' do
      before do
        allow(AppSettings.config.slack).to receive(:bot_token).and_return(nil)
      end
      
      it 'raises NotConfiguredError' do
        expect {
          described_class.new
        }.to raise_error(SlackNotifier::NotConfiguredError, /SLACK_BOT_TOKEN/)
      end
    end
    
    context 'when Slack API returns error' do
      before do
        allow(AppSettings.config.slack).to receive(:bot_token).and_return('xoxb-test-token')
        allow(AppSettings.config.slack).to receive(:channel_id).and_return('C1234567890')
        allow(slack_client).to receive(:chat_postMessage)
          .and_raise(::Slack::Web::Api::Errors::ChannelNotFound.new('channel_not_found'))
      end
      
      it 'raises NotificationFailedError' do
        notifier = described_class.new
        
        expect {
          notifier.notify_visit(visit)
        }.to raise_error(SlackNotifier::NotificationFailedError, /channel not found/i)
      end
    end
  end
  
  describe '#update_message' do
    let(:visit) { create(:visit, employee: employee, slack_message_ts: '1234567890.123456') }
    
    before do
      allow(AppSettings.config.slack).to receive(:bot_token).and_return('xoxb-test-token')
      allow(AppSettings.config.slack).to receive(:channel_id).and_return('C1234567890')
    end
    
    it 'updates message successfully' do
      notifier = described_class.new
      response = notifier.update_message(visit, responder: 'Test User')
      
      expect(response['ok']).to be true
      expect(slack_client).to have_received(:chat_update)
    end
  end
end

# spec/services/smarthr/employee_syncer_spec.rb
require 'rails_helper'

RSpec.describe Smarthr::EmployeeSyncer, type: :service do
  let(:client) { instance_double(Smarthr::Client) }
  let(:syncer) { described_class.new(client: client) }
  
  let(:smarthr_employees) do
    [
      {
        id: 'smarthr_123',
        first_name: 'Taro',
        last_name: 'Yamada',
        email: 'taro@example.com',
        emp_status: 'employed',
        department: { name: '営業部' }
      },
      {
        id: 'smarthr_456',
        first_name: 'Hanako',
        last_name: 'Tanaka',
        email: 'hanako@example.com',
        emp_status: 'employed',
        department: { name: '開発部' }
      }
    ]
  end
  
  before do
    allow(client).to receive(:fetch_all_employees).and_return(smarthr_employees)
  end
  
  describe '#sync_all' do
    context 'when employees do not exist' do
      it 'creates new employees' do
        expect {
          syncer.sync_all
        }.to change(Employee, :count).by(2)
      end
      
      it 'creates departments' do
        expect {
          syncer.sync_all
        }.to change(Department, :count).by(2)
      end
      
      it 'returns correct stats' do
        stats = syncer.sync_all
        expect(stats[:created]).to eq(2)
        expect(stats[:updated]).to eq(0)
      end
    end
    
    context 'when employees already exist' do
      let!(:department) { create(:department, name: '営業部') }
      let!(:employee) do
        create(:employee,
               smarthr_id: 'smarthr_123',
               name: 'Yamada Taro',
               department: department)
      end
      
      it 'updates existing employee' do
        syncer.sync_all
        
        employee.reload
        expect(employee.email).to eq('taro@example.com')
      end
      
      it 'returns correct stats' do
        stats = syncer.sync_all
        expect(stats[:created]).to eq(1)  # Hanako
        expect(stats[:updated]).to eq(0)  # Taroは変更なし
        expect(stats[:skipped]).to eq(1)  # Taroはスキップ
      end
    end
    
    context 'when employee is missing from SmartHR' do
      let!(:missing_employee) do
        create(:employee, smarthr_id: 'smarthr_999', is_active: true)
      end
      
      it 'deactivates missing employee' do
        syncer.sync_all
        
        missing_employee.reload
        expect(missing_employee.is_active).to be false
      end
      
      it 'returns correct stats' do
        stats = syncer.sync_all
        expect(stats[:deactivated]).to eq(1)
      end
    end
    
    context 'when API error occurs' do
      before do
        allow(client).to receive(:fetch_all_employees)
          .and_raise(Smarthr::Client::ApiError, 'API error')
      end
      
      it 'raises error and records it in stats' do
        expect {
          syncer.sync_all
        }.to raise_error(Smarthr::Client::ApiError)
        
        expect(syncer.errors).to include('API error')
      end
    end
  end
end
```

### 4. コントローラーテスト

```ruby
# spec/requests/visits_spec.rb
require 'rails_helper'

RSpec.describe 'Visits', type: :request do
  include_context 'with slack mocked'
  
  let(:department) { create(:department) }
  let(:employee) { create(:employee, department: department) }
  
  describe 'GET /visits/new' do
    it 'returns success' do
      get new_visit_path(employee_id: employee.id)
      expect(response).to have_http_status(:success)
    end
    
    it 'assigns @visit' do
      get new_visit_path(employee_id: employee.id)
      expect(assigns(:visit)).to be_a_new(Visit)
    end
    
    context 'when employee is not found' do
      it 'redirects to root' do
        get new_visit_path(employee_id: 999999)
        expect(response).to redirect_to(root_path)
      end
    end
  end
  
  describe 'POST /visits' do
    let(:valid_params) do
      {
        visit: {
          employee_id: employee.id,
          notes: 'Test visit'
        }
      }
    end
    
    context 'with valid parameters' do
      before do
        allow(AppSettings.config.slack).to receive(:bot_token).and_return('xoxb-test')
        allow(AppSettings.config.slack).to receive(:channel_id).and_return('C123')
      end
      
      it 'creates a new visit' do
        expect {
          post visits_path, params: valid_params
        }.to change(Visit, :count).by(1)
      end
      
      it 'enqueues Slack notification job' do
        expect {
          post visits_path, params: valid_params
        }.to have_enqueued_job(SlackNotificationJob)
      end
      
      it 'redirects to complete page' do
        post visits_path, params: valid_params
        expect(response).to redirect_to(complete_path)
      end
      
      it 'stores visit ID in session' do
        post visits_path, params: valid_params
        expect(session[:last_visit_id]).to eq(Visit.last.id)
      end
    end
    
    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          visit: {
            employee_id: nil,
            notes: 'Test'
          }
        }
      end
      
      it 'does not create a visit' do
        expect {
          post visits_path, params: invalid_params
        }.not_to change(Visit, :count)
      end
      
      it 'renders new template' do
        post visits_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
  
  describe 'GET /visits/:id/status' do
    let(:visit) { create(:visit, employee: employee) }
    
    it 'returns visit status as JSON' do
      get status_visit_path(visit)
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['status']).to eq(visit.status)
      expect(json['responded']).to eq(visit.responded?)
    end
  end
end

# spec/requests/admin/employees_spec.rb
require 'rails_helper'

RSpec.describe 'Admin::Employees', type: :request do
  let(:admin) { create(:admin_user) }
  let(:department) { create(:department) }
  
  before do
    # ログイン処理（セッション認証）
    post admin_login_path, params: {
      email: admin.email,
      password: 'password'
    }
  end
  
  describe 'GET /admin/employees' do
    it 'returns success' do
      get admin_employees_path
      expect(response).to have_http_status(:success)
    end
    
    it 'assigns @employees' do
      create_list(:employee, 3)
      get admin_employees_path
      expect(assigns(:employees).count).to eq(3)
    end
  end
  
  describe 'POST /admin/employees' do
    let(:valid_params) do
      {
        employee: {
          name: 'Test Employee',
          email: 'test@example.com',
          slack_user_id: 'U123456789',
          department_id: department.id
        }
      }
    end
    
    it 'creates a new employee' do
      expect {
        post admin_employees_path, params: valid_params
      }.to change(Employee, :count).by(1)
    end
    
    it 'redirects to index' do
      post admin_employees_path, params: valid_params
      expect(response).to redirect_to(admin_employees_path)
    end
  end
end
```

### 5. 統合テスト（システムテスト）

```ruby
# spec/system/visitor_reception_spec.rb
require 'rails_helper'

RSpec.describe 'Visitor Reception', type: :system do
  include_context 'with slack mocked'
  
  let(:department) { create(:department, name: '営業部') }
  let!(:employee) { create(:employee, name: '山田太郎', department: department) }
  
  before do
    driven_by(:rack_test)
    allow(AppSettings.config.slack).to receive(:bot_token).and_return('xoxb-test')
    allow(AppSettings.config.slack).to receive(:channel_id).and_return('C123')
  end
  
  scenario 'Visitor selects employee and submits visit' do
    # 従業員一覧ページにアクセス
    visit root_path
    
    # 従業員が表示されていることを確認
    expect(page).to have_content('山田太郎')
    expect(page).to have_content('営業部')
    
    # 従業員を選択
    click_link '山田太郎'
    
    # 訪問確認画面が表示される
    expect(page).to have_content('訪問確認')
    expect(page).to have_content('山田太郎')
    
    # メモを入力
    fill_in 'メモ', with: '打ち合わせで来ました'
    
    # 呼び出すボタンをクリック
    click_button '呼び出す'
    
    # 完了画面が表示される
    expect(page).to have_content('通知を送信しました')
    expect(page).to have_content('受付が完了しました')
    
    # データベースに記録されている
    visit = Visit.last
    expect(visit.employee).to eq(employee)
    expect(visit.notes).to eq('打ち合わせで来ました')
  end
  
  scenario 'Search employee by name' do
    create(:employee, name: '佐藤花子', department: department)
    
    visit root_path
    
    # 検索フォームに入力
    fill_in '検索', with: '山田'
    click_button '検索'
    
    # 検索結果が表示される
    expect(page).to have_content('山田太郎')
    expect(page).not_to have_content('佐藤花子')
  end
end

# spec/system/admin/employee_management_spec.rb
require 'rails_helper'

RSpec.describe 'Admin Employee Management', type: :system do
  let(:admin) { create(:admin_user) }
  let(:department) { create(:department) }
  
  before do
    driven_by(:rack_test)
    
    # ログイン
    visit admin_login_path
    fill_in 'メールアドレス', with: admin.email
    fill_in 'パスワード', with: 'password'
    click_button 'ログイン'
  end
  
  scenario 'Admin creates new employee' do
    visit admin_employees_path
    
    click_link '新規登録'
    
    fill_in '名前', with: '新入社員'
    fill_in 'メールアドレス', with: 'newbie@example.com'
    fill_in 'Slack User ID', with: 'U123456789'
    select department.name, from: '部署'
    
    click_button '登録'
    
    expect(page).to have_content('従業員を登録しました')
    expect(page).to have_content('新入社員')
  end
  
  scenario 'Admin edits employee' do
    employee = create(:employee, department: department)
    
    visit admin_employees_path
    
    click_link '編集', match: :first
    
    fill_in '名前', with: '更新された名前'
    click_button '更新'
    
    expect(page).to have_content('従業員を更新しました')
    expect(page).to have_content('更新された名前')
  end
end
```

---

## 実装優先度

### 🔴 Phase 1: 緊急対応（1週間）

**優先度: CRITICAL**

1. ✅ **AppConfig実装** (2時間)
   - `config/initializers/app_config.rb`作成
   - 環境変数の整理
   - 動作確認

2. ✅ **基本テストの追加** (3日)
   - モデルテスト（Employee, Visit, Department）
   - サービステスト（SlackNotifier, EmployeeSyncer）
   - 最低限のカバレッジ確保

3. ✅ **セキュリティ修正** (1日)
   - Slack署名検証の厳格化
   - SQLインジェクション対策の見直し
   - Rate Limiting追加

### 🟡 Phase 2: 重要改善（2週間）

**優先度: HIGH**

4. ✅ **Visitモデルのリファクタリング** (半日)
   - 重複メソッドの削除
   - 定数化

5. ✅ **N+1クエリの解消** (1日)
   - includes追加
   - カウンターキャッシュ導入

6. ✅ **エラーハンドリングの統一** (2日)
   - Service Objectパターンの導入
   - Result Objectの実装

7. ✅ **設定管理の改善** (1日)
   - dry-configurable導入
   - マジックナンバーの排除

### 🟢 Phase 3: 品質向上（3週間）

**優先度: MEDIUM**

8. ⬜ **フルテストスイート** (1週間)
   - 統合テスト
   - システムテスト
   - 80%以上のカバレッジ

9. ⬜ **パフォーマンス最適化** (1週間)
   - データベースインデックス
   - キャッシング戦略
   - ジョブ最適化

10. ⬜ **国際化対応** (3日)
    - I18n設定
    - 日本語/英語対応

### ⚪ Phase 4: 将来対応（継続的）

**優先度: LOW**

11. ⬜ **API バージョニング** (1週間)
    - REST API v1実装
    - 認証機構

12. ⬜ **モニタリング・ロギング** (1週間)
    - 構造化ログ
    - APM導入
    - エラートラッキング

13. ⬜ **ドキュメント自動生成** (3日)
    - Swagger/OpenAPI
    - APIドキュメント

---

## まとめ

### 現状の評価

このプロジェクトは全体的に**良好な設計**がなされていますが、以下の点で改善の余地があります：

✅ **良い点**
- サービス層の適切な分離
- カスタムエラークラスの実装
- 非同期ジョブの活用
- 詳細なドキュメント

❌ **改善が必要な点**
- AppConfig未定義（致命的）
- テストコードの不在
- 一部の重複コード
- パフォーマンス最適化の余地

### 推奨アクション

1. **今すぐ**: AppConfigを実装してアプリケーションを起動可能にする
2. **1週間以内**: 基本的なテストを追加して品質を担保
3. **1ヶ月以内**: コードリファクタリングとパフォーマンス最適化
4. **継続的**: テストカバレッジの向上とモニタリング強化

### 期待される効果

これらの改善により：
- **信頼性**: テストにより品質が保証される
- **保守性**: リファクタリングにより変更が容易になる
- **パフォーマンス**: 最適化により応答速度が向上する
- **セキュリティ**: 対策強化により安全性が向上する

---

**作成者**: Claude (Anthropic)  
**作成日**: 2025年11月10日  
**バージョン**: 1.0
