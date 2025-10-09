# 受付管理システム (Reception Management System)

企業の訪問者受付を効率化するWebアプリケーション。訪問者が担当者を選択すると、その担当者にSlack DMで通知を送信します。

[![Ruby Version](https://img.shields.io/badge/Ruby-3.2+-red.svg)](https://www.ruby-lang.org/)
[![Rails Version](https://img.shields.io/badge/Rails-8.0+-red.svg)](https://rubyonrails.org/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## 📋 目次

- [主な機能](#主な機能)
- [技術スタック](#技術スタック)
- [システムアーキテクチャ](#システムアーキテクチャ)
- [セットアップ](#セットアップ)
- [使用方法](#使用方法)
- [データベース設計](#データベース設計)
- [API連携](#api連携)
- [デプロイメント](#デプロイメント)
- [開発ガイド](#開発ガイド)
- [ドキュメント](#ドキュメント)

## 🎯 主な機能

### 訪問者向け機能
- **担当者選択**: 部署別の従業員一覧から担当者を選択
- **メモ入力**: 訪問目的や伝言をメモとして記録
- **即時通知**: 選択した担当者にSlack DMで自動通知

### 管理者向け機能
- **従業員管理**: CRUD操作、有効/無効切り替え、受付画面表示制御
- **部署管理**: CRUD操作、表示順管理
- **SmartHR連携**: 従業員情報の自動同期
- **同期履歴管理**: SmartHR同期の成功/失敗履歴確認
- **認証機能**: 管理画面へのアクセス制御

### 連携機能
- **Slack通知**: 訪問時に担当者へDM送信、確認ボタン付き
- **SmartHR API**: 従業員マスタの自動同期（手動/定期実行可能）

## 🛠 技術スタック

### バックエンド
- **Ruby**: 3.2+
- **Rails**: 8.0.3
- **MySQL**: 8.0+
- **Puma**: Webサーバー

### フロントエンド
- **Hotwire (Turbo + Stimulus)**: SPAライクなUI
- **Tailwind CSS**: UIスタイリング
- **Importmap**: JavaScript管理

### インフラ・デプロイ
- **Docker**: コンテナ化
- **Kamal**: デプロイツール
- **Solid Queue**: ジョブキュー
- **Solid Cache**: キャッシュ
- **Solid Cable**: WebSocket

### 外部API
- **Slack API**: メッセージ送信、インタラクション
- **SmartHR API**: 従業員情報取得

### テスト・品質管理
- **RSpec**: テストフレームワーク
- **Factory Bot**: テストデータ生成
- **Faker**: ダミーデータ生成
- **Rubocop**: コード品質チェック
- **Brakeman**: セキュリティ監査

## 🏗 システムアーキテクチャ

```
┌─────────────┐
│  訪問者端末  │ (タブレット等)
└──────┬──────┘
       │ HTTP
       ▼
┌─────────────────────────────────┐
│     Rails Application           │
│  ┌─────────────────────────┐   │
│  │  Controllers            │   │
│  │  - Visitors             │   │
│  │  - Admin                │   │
│  └────────┬────────────────┘   │
│           │                     │
│  ┌────────▼────────────────┐   │
│  │  Services               │   │
│  │  - SlackNotifier        │   │
│  │  - SmartHR::Client      │   │
│  │  - SmartHR::Syncer      │   │
│  └────────┬────────────────┘   │
│           │                     │
│  ┌────────▼────────────────┐   │
│  │  Jobs (Solid Queue)     │   │
│  │  - SlackNotificationJob │   │
│  │  - SmarthrSyncJob       │   │
│  └─────────────────────────┘   │
└─────────────────────────────────┘
       │           │
       │           └──────────┐
       ▼                      ▼
┌─────────────┐      ┌────────────────┐
│   MySQL     │      │  External APIs │
│  Database   │      │  - Slack       │
└─────────────┘      │  - SmartHR    │
                     └────────────────┘
```

## 🚀 セットアップ

### 必要な環境

- Ruby 3.2以上
- MySQL 8.0以上
- Node.js (Importmap使用のため最小限)

### インストール手順

```bash
# リポジトリクローン
git clone https://github.com/junozone1110/reception-test-rails.git
cd reception-test-rails

# 依存パッケージインストール
bundle install

# データベース作成
rails db:create
rails db:migrate

# シードデータ投入（オプション）
rails db:seed

# 環境変数設定
cp .env.example .env
# .envファイルを編集（後述）

# サーバー起動
rails server
```

### 環境変数の設定

`.env`ファイルを作成し、以下の環境変数を設定：

```env
# Slack設定
SLACK_BOT_TOKEN=xoxb-your-slack-bot-token
SLACK_SIGNING_SECRET=your-slack-signing-secret

# SmartHR API設定（オプション）
SMARTHR_SUBDOMAIN=your-company
SMARTHR_ACCESS_TOKEN=your-smarthr-access-token

# データベース設定（必要に応じて）
DATABASE_URL=mysql2://root:password@localhost:3306/reception_rails_development
```

#### Slack設定の取得方法

1. [Slack App](https://api.slack.com/apps)でアプリを作成
2. OAuth & Permissions → Scopes:
   - `chat:write` - メッセージ送信
   - `im:write` - DM送信
3. Install App to Workspace → Bot Token取得
4. Basic Information → Signing Secret取得
5. Interactivity & Shortcuts:
   - Request URL: `https://your-domain.com/slack/actions`

#### SmartHR設定の取得方法

1. SmartHR管理画面 → 設定 → API
2. アクセストークンを作成
3. 必要な権限: `crews:read`, `departments:read`

## 📖 使用方法

### 訪問者の受付フロー

1. ブラウザで `http://localhost:3000/` にアクセス
2. 担当者を部署別一覧から選択
3. 訪問目的をメモ欄に入力（任意）
4. 「呼び出す」ボタンをクリック
5. 担当者のSlackにDMが届く
6. 完了画面が表示される

### 管理画面の使用

1. `http://localhost:3000/admin/login` にアクセス
2. デフォルト管理者でログイン:
   - Email: `admin@example.com`
   - Password: `admin123`

#### 従業員管理

- **一覧表示**: 有効/無効、受付表示/非表示のステータス確認
- **新規登録**: 名前、メール、Slack ID、部署を入力
- **編集**: 情報の更新、受付画面表示の切り替え
- **削除**: 訪問履歴がない従業員のみ削除可能

#### 部署管理

- **一覧表示**: 部署名、表示順、所属従業員数
- **新規登録**: 部署名と表示順を入力
- **編集**: 部署名の変更（SmartHRの内部名を対外名に変更）
- **削除**: 所属従業員がいない部署のみ削除可能

#### SmartHR同期

- **手動同期**: 「SmartHRと同期」ボタンをクリック
- **同期履歴**: 成功/失敗の履歴、詳細統計を確認
- **定期同期**: `config/recurring.yml`で設定可能

## 🗄 データベース設計

### ER図

```
┌─────────────┐       ┌──────────────┐
│ departments │       │  employees   │
├─────────────┤       ├──────────────┤
│ id          │◄──┐   │ id           │
│ name        │   └───│ department_id│
│ position    │       │ name         │
│ created_at  │       │ email        │
│ updated_at  │       │ slack_user_id│
└─────────────┘       │ is_active    │
                      │ visible_to_v.│
                      │ smarthr_id   │
                      │ avatar_url   │
                      │ created_at   │
                      │ updated_at   │
                      └──────┬───────┘
                             │
                             │
                      ┌──────▼───────┐
                      │   visits     │
                      ├──────────────┤
                      │ id           │
                      │ employee_id  │
                      │ notes        │
                      │ status       │
                      │ slack_msg_ts │
                      │ created_at   │
                      │ updated_at   │
                      └──────────────┘

┌──────────────┐       ┌──────────────┐
│ admin_users  │       │  sync_logs   │
├──────────────┤       ├──────────────┤
│ id           │       │ id           │
│ email        │       │ service      │
│ password_dig.│       │ status       │
│ name         │       │ details      │
│ created_at   │       │ error_msg    │
│ updated_at   │       │ synced_at    │
└──────────────┘       │ created_at   │
                       │ updated_at   │
                       └──────────────┘
```

### 主要テーブル

#### employees（従業員）
- SmartHR IDで一意識別
- `visible_to_visitors`: 受付画面での表示制御
- `is_active`: 有効/無効（退職者など）

#### departments（部署）
- `position`: 表示順（小さいほど上位）
- SmartHRからの内部名を対外名に変更可能

#### visits（訪問）
- `status`: pending（未確認）/ acknowledged（確認済み）
- `slack_message_ts`: Slackメッセージの特定用

#### sync_logs（同期ログ）
- SmartHR同期の履歴管理
- 詳細統計（作成/更新/無効化/スキップ件数）

## 🔌 API連携

### Slack API

**用途**: 訪問通知の送信とインタラクション処理

**フロー**:
1. 訪問者が担当者を選択
2. `SlackNotificationJob`がバックグラウンドで実行
3. `SlackNotifier`が担当者のSlack IDにDM送信
4. メッセージにインタラクティブボタン付与
5. 担当者が「確認済み」ボタンをクリック
6. `SlackActionsController`がステータス更新

**実装**:
- `app/services/slack_notifier.rb`
- `app/services/slack/message_builder.rb`
- `app/jobs/slack_notification_job.rb`
- `app/controllers/slack_actions_controller.rb`

### SmartHR API

**用途**: 従業員マスタの自動同期

**フロー**:
1. 管理者が「SmartHRと同期」実行
2. `SmarthrSyncJob`がバックグラウンドで実行
3. `Smarthr::Client`がAPI経由で従業員情報取得
4. `Smarthr::EmployeeSyncer`が差分更新
5. 新規作成/更新/無効化を実行
6. 同期結果を`sync_logs`に記録

**実装**:
- `app/services/smarthr/client.rb`
- `app/services/smarthr/employee_syncer.rb`
- `app/jobs/smarthr_sync_job.rb`

**仕様**:
- 新規従業員: デフォルトで受付非表示
- 既存従業員: `visible_to_visitors`は維持（上書きしない）
- SmartHRに存在しない従業員: 自動的に無効化

## 🚢 デプロイメント

### Docker環境

```bash
# イメージビルド
docker-compose build

# コンテナ起動
docker-compose up -d

# マイグレーション
docker-compose exec web rails db:migrate

# ログ確認
docker-compose logs -f web
```

### Kamalでのデプロイ

```bash
# 初回デプロイ
kamal setup

# 通常デプロイ
kamal deploy

# ログ確認
kamal app logs
```

### 本番環境の設定

#### 環境変数（production）

- `RAILS_MASTER_KEY`: `config/master.key`の内容
- `DATABASE_URL`: 本番DB接続情報
- `SLACK_BOT_TOKEN`: Slack Bot Token
- `SLACK_SIGNING_SECRET`: Slack Signing Secret
- `SMARTHR_SUBDOMAIN`: SmartHRサブドメイン
- `SMARTHR_ACCESS_TOKEN`: SmartHR API Token

#### Solid Queueの設定

```yaml
# config/recurring.yml
smarthr_sync:
  class: SmarthrSyncJob
  schedule: "0 3 * * *"  # 毎日午前3時実行
  args: []
```

ワーカープロセスの起動:
```bash
bin/jobs
```

## 👨‍💻 開発ガイド

### ディレクトリ構造

```
app/
├── controllers/
│   ├── admin/              # 管理画面コントローラー
│   │   ├── base_controller.rb
│   │   ├── employees_controller.rb
│   │   ├── departments_controller.rb
│   │   ├── sessions_controller.rb
│   │   └── smarthr_syncs_controller.rb
│   ├── employees_controller.rb
│   ├── visits_controller.rb
│   └── slack_actions_controller.rb
├── models/
│   ├── employee.rb
│   ├── department.rb
│   ├── visit.rb
│   ├── admin_user.rb
│   └── sync_log.rb
├── services/
│   ├── slack/
│   │   └── message_builder.rb
│   ├── slack_notifier.rb
│   └── smarthr/
│       ├── client.rb
│       └── employee_syncer.rb
├── jobs/
│   ├── slack_notification_job.rb
│   └── smarthr_sync_job.rb
└── views/
    ├── employees/          # 訪問者画面
    ├── visits/
    └── admin/              # 管理画面
        ├── employees/
        ├── departments/
        ├── sessions/
        └── smarthr_syncs/
```

### コーディング規約

- **Rubocop**: `bundle exec rubocop`
- **セキュリティ監査**: `bundle exec brakeman`
- **テスト**: `bundle exec rspec`

### テストの実行

```bash
# 全テスト実行
bundle exec rspec

# 特定のファイルのみ
bundle exec rspec spec/models/employee_spec.rb

# 特定の行のみ
bundle exec rspec spec/models/employee_spec.rb:10
```

### リファクタリング履歴

コードベースは以下のリファクタリングが実施済みです：

1. **Slackメッセージビルダーの分離**: 責任の明確化
2. **共通ビューヘルパーの追加**: DRY原則の適用
3. **定数の集約管理**: マジックナンバー排除
4. **バリデーションメッセージの日本語化**: UX向上
5. **エラーハンドリングの改善**: ロバスト性向上
6. **SmartHR同期ロジックの改善**: トランザクション処理

詳細は [`REFACTORING_CHANGELOG.md`](REFACTORING_CHANGELOG.md) 参照。

## 🐛 トラブルシューティング

### Slack通知が届かない

1. 環境変数の確認: `SLACK_BOT_TOKEN`が設定されているか
2. Slack App設定: 必要なスコープ（`chat:write`, `im:write`）が付与されているか
3. Slack User ID: 正しいIDが従業員マスタに登録されているか
4. ログ確認: `log/development.log`でエラーメッセージを確認

### SmartHR同期が失敗する

1. 環境変数の確認: `SMARTHR_SUBDOMAIN`, `SMARTHR_ACCESS_TOKEN`
2. APIスコープ: `crews:read`権限が付与されているか
3. 同期履歴: 管理画面 → SmartHR同期 → 同期履歴でエラー詳細確認
4. ネットワーク: API接続が可能か確認

### データベース接続エラー

```bash
# MySQL起動確認
mysql.server status

# データベース再作成
rails db:drop db:create db:migrate db:seed
```

### ポートが既に使用されている

```bash
# プロセス確認
lsof -i :3000

# プロセス終了
kill -9 [PID]
```

## 📚 ドキュメント

- **[SETUP.md](SETUP.md)**: 詳細なセットアップ手順
- **[SMARTHR_INTEGRATION.md](SMARTHR_INTEGRATION.md)**: SmartHR連携の詳細ガイド
- **[REFACTORING_CHANGELOG.md](REFACTORING_CHANGELOG.md)**: リファクタリング履歴
- **[PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)**: プロジェクト要件定義

## 🤝 コントリビューション

1. このリポジトリをフォーク
2. 機能ブランチを作成 (`git checkout -b feature/amazing-feature`)
3. 変更をコミット (`git commit -m 'feat: Add amazing feature'`)
4. ブランチにプッシュ (`git push origin feature/amazing-feature`)
5. Pull Requestを作成

### コミットメッセージ規約

```
feat: 新機能
fix: バグ修正
docs: ドキュメント
style: フォーマット
refactor: リファクタリング
test: テスト追加
chore: ビルド・設定変更
```

## 📝 ライセンス

MIT License - 詳細は [LICENSE](LICENSE) 参照

## 👥 作成者

- GitHub: [@junozone1110](https://github.com/junozone1110)

## 🙏 謝辞

- FastAPI版リポジトリ: [reception-test](https://github.com/junozone1110/reception-test)
- Rails Community
- Hotwire/Turbo Contributors

---

**Note**: このプロジェクトは企業の受付業務効率化を目的として開発されました。
質問や問題がある場合は、[Issues](https://github.com/junozone1110/reception-test-rails/issues)でお気軽にお問い合わせください。
