# Docker環境での動作確認

## 確認事項

Docker環境で動作するか確認するために、以下の点を確認しました：

### 1. Dockerfileの確認
- **本番環境用（Dockerfile）**: `BUNDLE_WITHOUT="development"`が設定されており、テスト用gemは含まれません（正常）
- **開発環境用（Dockerfile.dev）**: すべてのgemがインストールされます

### 2. docker-compose.ymlの改善
- ボリュームマウントを`/rails`に修正（Dockerfileと一致）
- データベースのヘルスチェックを追加
- 環境変数を追加（SLACK_CHANNEL_ID, SMARTHR_SUBDOMAIN, SMARTHR_ACCESS_TOKEN）
- 開発環境用のDockerfile.devを使用するように変更

### 3. 新しい依存関係の確認
- **rack-attack**: 本番環境でも必要なので、`BUNDLE_WITHOUT`に含まれていません（正常）
- **database_cleaner-active_record**: テスト用gemなので、本番環境ではインストールされません（正常）
- **shoulda-matchers**: テスト用gemなので、本番環境ではインストールされません（正常）

### 4. マイグレーションの確認
- 新しいマイグレーション（add_performance_indexes）が含まれています
- docker-entrypointで`db:prepare`が実行されるため、自動的にマイグレーションが実行されます

## 動作確認方法

```bash
# Docker環境でビルドと起動
docker-compose up --build

# 別のターミナルでログを確認
docker-compose logs -f web

# データベース接続確認
docker-compose exec web bundle exec rails db:migrate:status
```

## 注意事項

1. **環境変数**: `.env`ファイルに必要な環境変数を設定してください
   - SLACK_BOT_TOKEN
   - SLACK_SIGNING_SECRET
   - SLACK_CHANNEL_ID
   - SMARTHR_SUBDOMAIN（オプション）
   - SMARTHR_ACCESS_TOKEN（オプション）

2. **データベース**: 初回起動時は`db:create`と`db:migrate`が自動実行されます

3. **ポート**: アプリケーションは`http://localhost:3000`でアクセス可能です

