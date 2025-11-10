# Docker環境でのビルドと動作確認手順

## 前提条件

1. DockerとDocker Composeがインストールされていること
2. ColimaまたはDocker Desktopが起動していること

## ビルドと起動

```bash
# 1. 既存のコンテナを停止・削除（クリーンな状態から）
docker-compose down -v

# 2. Dockerイメージをビルド
docker-compose build --no-cache web

# 3. コンテナを起動（バックグラウンド）
docker-compose up -d

# 4. ログを確認
docker-compose logs -f web

# 5. データベースの状態を確認
docker-compose exec web bundle exec rails db:migrate:status

# 6. Railsコンソールで動作確認
docker-compose exec web bundle exec rails console
```

## 動作確認項目

### 1. アプリケーションの起動確認
```bash
# ログで以下を確認
# - "Listening on tcp://0.0.0.0:3000"
# - データベース接続成功
# - マイグレーション実行成功
```

### 2. データベース接続確認
```bash
docker-compose exec web bundle exec rails db:migrate:status
# すべてのマイグレーションが "up" になっていることを確認
```

### 3. モデルの動作確認
```bash
docker-compose exec web bundle exec rails console
# コンソールで以下を実行
> Department.count
> Employee.count
> Visit.count
```

### 4. テストの実行確認
```bash
docker-compose exec web bundle exec rspec spec/models/visit_spec.rb
# テストが正常に実行されることを確認
```

## トラブルシューティング

### Dockerデーモンが起動していない場合
```bash
# Colimaを使用している場合
colima start

# Docker Desktopを使用している場合
# Docker Desktopアプリケーションを起動
```

### ビルドエラーが発生した場合
```bash
# 詳細なログを確認
docker-compose build --progress=plain web

# キャッシュをクリアして再ビルド
docker-compose build --no-cache web
```

### データベース接続エラーが発生した場合
```bash
# データベースコンテナの状態を確認
docker-compose ps db

# データベースコンテナのログを確認
docker-compose logs db

# データベースコンテナを再起動
docker-compose restart db
```

### ポートが既に使用されている場合
```bash
# ポート3000を使用しているプロセスを確認
lsof -i :3000

# docker-compose.ymlのポート番号を変更
# ports:
#   - "3001:3000"  # 3001に変更
```

## 環境変数の設定

`.env`ファイルを作成して、以下の環境変数を設定してください：

```env
SLACK_BOT_TOKEN=xoxb-your-token-here
SLACK_SIGNING_SECRET=your-signing-secret-here
SLACK_CHANNEL_ID=C1234567890
SMARTHR_SUBDOMAIN=your-subdomain
SMARTHR_ACCESS_TOKEN=your-access-token
```

## 停止とクリーンアップ

```bash
# コンテナを停止
docker-compose stop

# コンテナとボリュームを削除
docker-compose down -v

# イメージも削除する場合
docker-compose down -v --rmi all
```

