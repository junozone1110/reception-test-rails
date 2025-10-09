# 訪問者受付システム - Ruby on Rails版

reception-testプロジェクト（FastAPI + Next.js）をRuby on Railsに移行したバージョンです。

## 📋 技術スタック

- **Ruby**: 3.4.3
- **Ruby on Rails**: 8.0.2
- **MySQL**: 8.0
- **Tailwind CSS**: 最新版
- **Hotwire (Turbo + Stimulus)**: SPA風のインタラクション
- **Slack API**: 訪問通知
- **Docker & Docker Compose**: コンテナ化

## 🎯 機能概要

### 訪問者向け機能
- 従業員一覧表示（検索・部署フィルタリング）
- 訪問確認画面（メモ入力可能）
- Slack通知送信

### 管理画面
- 従業員の登録・編集・削除
- ステータス管理（有効/無効）
- セッションベース認証

### Slack連携
- 訪問時にSlackダイレクトメッセージで通知
- インタラクティブなボタン（確認済みボタン）
- 非同期ジョブでの通知送信

## 🚀 セットアップ

### 前提条件
- Ruby 3.4.3
- MySQL 8.0
- Bundler
- (オプション) Docker & Docker Compose

### 方法1: ローカル環境

```bash
# リポジトリのクローン
cd reception_rails

# 依存関係のインストール
bundle install

# 環境変数の設定
cp .env.example .env
# .envファイルを編集してSlackトークンなどを設定

# データベースの作成とマイグレーション
rails db:create
rails db:migrate

# Seedデータの投入
rails db:seed

# サーバー起動
bin/dev  # Tailwind CSSの自動ビルドも含む
# または
rails server
```

### 方法2: Docker Compose

```bash
# 環境変数の設定
cp .env.example .env
# .envファイルを編集

# コンテナの起動（初回は自動でDB作成・マイグレーション）
docker-compose up -d

# Seedデータの投入
docker-compose exec web rails db:seed

# ログの確認
docker-compose logs -f web
```

## 🔧 環境変数設定

`.env`ファイルに以下の環境変数を設定してください：

```env
# データベース
DATABASE_URL=mysql2://root:password@localhost:3306/reception_rails_development

# Slack API（必須）
SLACK_BOT_TOKEN=xoxb-your-bot-token
SLACK_SIGNING_SECRET=your-signing-secret

# Rails
RAILS_ENV=development
```

### Slack Appの設定

1. [Slack API](https://api.slack.com/apps)で新しいAppを作成
2. OAuth & Permissions で以下のスコープを追加：
   - `chat:write`
   - `users:read`
3. Bot Token を `.env` の `SLACK_BOT_TOKEN` に設定
4. Interactivity & Shortcuts を有効化
5. Request URL に Cloudflare Tunnel の URL を設定：
   ```
   https://[your-tunnel].trycloudflare.com/slack/actions
   ```

### Cloudflare Tunnel の起動

Slackからのwebhookを受信するため、Cloudflare Tunnelを使用します：

```bash
# Cloudflare Tunnelのインストール（初回のみ）
brew install cloudflare/cloudflare/cloudflared

# トンネルの起動
cloudflared tunnel --url http://localhost:3000
```

表示されたURLをSlack AppのRequest URLに設定してください。

## 📁 プロジェクト構造

```
reception_rails/
├── app/
│   ├── controllers/
│   │   ├── employees_controller.rb         # 従業員一覧
│   │   ├── visits_controller.rb            # 訪問処理
│   │   ├── slack_actions_controller.rb     # Slack連携
│   │   └── admin/
│   │       ├── base_controller.rb          # 管理画面基底
│   │       ├── sessions_controller.rb      # 認証
│   │       └── employees_controller.rb     # 従業員管理
│   ├── models/
│   │   ├── employee.rb                     # 従業員
│   │   ├── department.rb                   # 部署
│   │   ├── visit.rb                        # 訪問記録
│   │   └── admin_user.rb                   # 管理者
│   ├── services/
│   │   └── slack_notifier.rb               # Slack通知サービス
│   ├── jobs/
│   │   └── slack_notification_job.rb       # 非同期通知ジョブ
│   └── views/
│       ├── employees/
│       │   └── index.html.erb              # 従業員選択画面
│       ├── visits/
│       │   ├── new.html.erb                # 訪問確認
│       │   └── complete.html.erb           # 完了画面
│       └── admin/
│           ├── sessions/
│           │   └── new.html.erb            # ログイン
│           └── employees/
│               ├── index.html.erb          # 一覧
│               ├── new.html.erb            # 新規登録
│               ├── edit.html.erb           # 編集
│               └── _form.html.erb          # フォーム部分
├── config/
│   ├── routes.rb                           # ルーティング定義
│   ├── database.yml                        # DB設定
│   └── initializers/
│       └── slack.rb                        # Slack設定
├── db/
│   ├── migrate/                            # マイグレーション
│   └── seeds.rb                            # 初期データ
├── docker-compose.yml                      # Docker構成
├── Dockerfile.dev                          # 開発用Dockerfile
└── .env.example                            # 環境変数テンプレート
```

## 💾 データベーススキーマ

### departments（部署）
- `id`: 主キー
- `name`: 部署名（ユニーク）

### employees（従業員）
- `id`: 主キー
- `name`: 従業員名
- `email`: メールアドレス
- `slack_user_id`: Slack User ID（ユニーク）
- `department_id`: 部署ID（外部キー）
- `is_active`: 有効フラグ（デフォルト: true）
- `avatar_url`: アバター画像URL

### visits（訪問記録）
- `id`: 主キー
- `employee_id`: 従業員ID（外部キー）
- `notes`: メモ
- `status`: ステータス（pending/acknowledged）
- `slack_message_ts`: Slackメッセージタイムスタンプ

### admin_users（管理者）
- `id`: 主キー
- `email`: メールアドレス（ユニーク）
- `password_digest`: パスワードハッシュ
- `name`: 管理者名

## 🔐 認証情報

初期管理者アカウント：
- メールアドレス: `admin@example.com`
- パスワード: `admin123`

**本番環境では必ずパスワードを変更してください！**

## 📡 APIエンドポイント

### 訪問者向け
- `GET /` - トップページ（従業員一覧）
- `GET /employees` - 従業員一覧（JSON対応）
- `GET /visits/new?employee_id=X` - 訪問確認画面
- `POST /visits` - 訪問リクエスト作成
- `GET /complete` - 送信完了画面

### Slack連携
- `POST /slack/actions` - Slackアクション処理

### 管理画面
- `GET /admin/login` - ログイン画面
- `POST /admin/login` - ログイン処理
- `DELETE /admin/logout` - ログアウト
- `GET /admin/employees` - 従業員一覧
- `GET /admin/employees/new` - 新規登録フォーム
- `POST /admin/employees` - 従業員作成
- `GET /admin/employees/:id/edit` - 編集フォーム
- `PATCH /admin/employees/:id` - 従業員更新
- `DELETE /admin/employees/:id` - 従業員削除

## 🧪 テスト

```bash
# RSpecのセットアップ（初回のみ）
rails generate rspec:install

# テスト実行
bundle exec rspec

# カバレッジ付き実行
COVERAGE=true bundle exec rspec
```

## 🎨 スタイリング

Tailwind CSS v4を使用しています。カスタムスタイルは以下で定義：

```
app/assets/tailwind/application.css
```

開発中は`bin/dev`コマンドでTailwindの自動ビルドが有効になります。

## 🚢 デプロイ

### Kamalを使用したデプロイ

```bash
# 設定ファイルの編集
vi config/deploy.yml

# デプロイ
kamal deploy
```

### 手動デプロイ

1. 環境変数の設定
2. `bundle install --without development test`
3. `rails assets:precompile`
4. `rails db:migrate`
5. Pumaサーバーの起動

## 📝 原版との主な違い

### FastAPI版との比較

| 項目 | FastAPI版 | Rails版 |
|------|-----------|---------|
| バックエンド | FastAPI (Python) | Ruby on Rails |
| フロントエンド | Next.js 15 | Hotwire (Turbo + Stimulus) |
| 認証 | JWT | セッションベース |
| API | RESTful JSON API | HTMLレスポンス中心 |
| データ検証 | Pydantic | Active Record Validations |
| ORM | SQLAlchemy | Active Record |
| 非同期処理 | asyncio | Active Job + Solid Queue |

### 実装の簡略化

Rails版では以下を簡略化：
- フロントエンドは単一のRailsアプリケーション（Next.jsなし）
- Turboによる部分更新で高速なUX
- Stimulusによる最小限のJavaScript
- よりシンプルな認証（セッション）

## 🐛 トラブルシューティング

### データベース接続エラー

```bash
# MySQLが起動しているか確認
mysql.server status

# ソケットファイルのパスを確認
ls -la /tmp/mysql.sock

# config/database.ymlのsocketパスを調整
```

### Tailwind CSSがビルドされない

```bash
# bin/devを使用（ProcfileでTailwindも起動）
bin/dev

# または手動でビルド
rails tailwindcss:build
```

### Slack通知が届かない

1. Cloudflare Tunnelが起動しているか確認
2. Slack AppのRequest URLが正しいか確認
3. SLACK_BOT_TOKENが正しく設定されているか確認
4. Slack User IDが正しいか確認（`U`で始まる文字列）

### ジョブが実行されない

```bash
# Solid Queueの状態確認
rails solid_queue:status

# ジョブワーカーの起動（bin/devに含まれる）
bin/jobs
```

## 📚 参考リンク

- [Ruby on Rails Guides](https://guides.rubyonrails.org/)
- [Tailwind CSS Documentation](https://tailwindcss.com/docs)
- [Hotwire Documentation](https://hotwired.dev/)
- [Slack API Documentation](https://api.slack.com/)
- [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)

## 📄 ライセンス

MIT

---

元のプロジェクト: [reception-test](https://github.com/junozone1110/reception-test)

