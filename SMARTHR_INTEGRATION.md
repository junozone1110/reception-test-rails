# SmartHR API連携ガイド

## 概要

このアプリケーションは、SmartHR APIを使用して従業員情報を自動的に同期する機能を備えています。

## セットアップ

### 1. SmartHR APIアクセストークンの取得

1. SmartHRの管理画面にログイン
2. 「設定」→「API」→「アクセストークン」を選択
3. 新しいアクセストークンを作成
4. 必要な権限を付与:
   - `crews:read` - 従業員情報の読み取り
   - `departments:read` - 部署情報の読み取り

### 2. 環境変数の設定

`.env`ファイルに以下の環境変数を追加:

```env
# SmartHR API設定
SMARTHR_SUBDOMAIN=your-company        # SmartHRサブドメイン
SMARTHR_ACCESS_TOKEN=your-token-here  # APIアクセストークン

# Slack設定（既存）
SLACK_BOT_TOKEN=xoxb-your-slack-bot-token
SLACK_SIGNING_SECRET=your-slack-signing-secret
```

### 3. マイグレーション実行（セットアップ済み）

```bash
rails db:migrate
```

## 使い方

### 管理画面から手動同期

1. 管理画面（`/admin/employees`）にアクセス
2. 「SmartHRと同期」ボタンをクリック
3. 確認ダイアログで「OK」を選択
4. 同期処理がバックグラウンドで開始されます
5. 「同期履歴」ページで結果を確認できます

### 定期同期の設定

#### Solid Queueを使用する場合（推奨）

`config/recurring.yml`に以下を追加:

```yaml
smarthr_sync:
  class: SmarthrSyncJob
  schedule: "0 3 * * *"  # 毎日午前3時に実行
  args: []
```

サーバー起動:

```bash
# Railsサーバー
rails server

# Solid Queueワーカー（別ターミナル）
rails solid_queue:start
```

#### Wheneverを使用する場合

`Gemfile`に追加:

```ruby
gem "whenever", require: false
```

`config/schedule.rb`を作成:

```ruby
every 1.day, at: "3:00 am" do
  runner "SmarthrSyncJob.perform_later"
end
```

Cronに登録:

```bash
bundle exec whenever --update-crontab
```

### コマンドラインから実行

```bash
# 即座に実行
rails runner "SmarthrSyncJob.perform_now"

# バックグラウンドで実行
rails runner "SmarthrSyncJob.perform_later"
```

## データ同期の仕様

### 同期される情報

- **従業員名**: SmartHRの姓名を結合
- **メールアドレス**: SmartHRのメールアドレス
- **部署**: SmartHRの部署情報（自動作成）
- **ステータス**: 退職者は自動的に無効化

### Slack User IDについて

SmartHRにはSlack User IDが保存されていないため、以下の仕様になっています:

- **初回同期時**: `SMARTHR_{SmartHR ID}`形式のダミーIDを設定
- **手動設定**: 管理画面から個別に正しいSlack User IDを設定可能
- **今後の拡張**: メールアドレスでSlack APIから自動取得する機能を追加予定

### 同期ロジック

1. **新規作成**: SmartHRに存在するが、DBに存在しない従業員
2. **更新**: 既存従業員の情報が変更された場合
3. **無効化**: SmartHRに存在しない従業員（退職者など）
4. **スキップ**: 変更がない従業員

## トラブルシューティング

### エラー: "SMARTHR_SUBDOMAIN is required"

環境変数が設定されていません。`.env`ファイルを確認してください。

### エラー: "API request failed (401)"

アクセストークンが無効または期限切れです。SmartHRで新しいトークンを発行してください。

### エラー: "API request failed (403)"

必要な権限がありません。SmartHRのAPIトークンに`crews:read`権限を付与してください。

### 同期が完了しない

1. ログを確認: `tail -f log/development.log`
2. Solid Queueワーカーが起動しているか確認
3. ネットワーク接続を確認

## API仕様

### SmartHR APIエンドポイント

- **ベースURL**: `https://api.smarthr.jp/v1`
- **認証**: Bearer Token
- **エンドポイント**: 
  - `GET /crews` - 従業員一覧取得（ページネーション対応）
  - `GET /crews/:id` - 従業員詳細取得

### レート制限

SmartHR APIのレート制限に注意してください:
- デフォルト: 1分あたり60リクエスト
- エラー時は自動的にリトライします（最大3回）

## 同期履歴

同期履歴は`sync_logs`テーブルに保存されます:

- 同期日時
- ステータス（成功/失敗）
- 詳細情報（作成・更新・無効化の件数）
- エラーメッセージ

管理画面の「同期履歴」ページで確認できます。

## セキュリティ

- APIトークンは`.env`ファイルで管理し、Gitにコミットしない
- `.env`ファイルは`.gitignore`に追加済み
- 本番環境では環境変数を直接設定

## 参考リンク

- [SmartHR API ドキュメント](https://developer.smarthr.jp/api)
- [Rails Active Job ガイド](https://guides.rubyonrails.org/active_job_basics.html)
- [Solid Queue](https://github.com/rails/solid_queue)

