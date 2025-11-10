# Slack Webhook テストガイド

## 🔍 問題のデバッグ

### 1. ログをリアルタイムで確認

```bash
tail -f log/development.log
```

### 2. ngrokまたはCloudflare Tunnelの起動

#### Cloudflare Tunnelを使用する場合（推奨）

```bash
# インストール（初回のみ）
brew install cloudflare/cloudflare/cloudflared

# トンネル起動
cloudflared tunnel --url http://localhost:3000
```

表示されるURL（例: `https://xxxx-xxxx-xxxx.trycloudflare.com`）をコピーしてください。

#### ngrokを使用する場合

```bash
# インストール（初回のみ）
brew install ngrok

# トンネル起動
ngrok http 3000
```

### 3. Slack Appの設定

1. [Slack API Apps](https://api.slack.com/apps) にアクセス
2. アプリを選択
3. **Interactivity & Shortcuts** を選択
4. **Interactivity** をONに設定
5. **Request URL** に以下を設定:
   ```
   https://your-tunnel-url.trycloudflare.com/slack/actions
   ```
6. **Save Changes** をクリック

### 4. テスト手順

1. 従業員一覧から従業員を選択
2. メモを入力して「通知を送信」をクリック
3. SlackのDMを確認
4. 「確認済みにする」ボタンをクリック
5. ログで以下のメッセージを確認:
   ```
   Slack request signature verified successfully
   Handling Slack action: acknowledge_visit
   Visit #X acknowledged successfully
   ```

## 🛠 トラブルシューティング

### エラー: "Slackペイロードが処理できません"

**原因1: 署名検証エラー**
- SLACK_SIGNING_SECRETが正しく設定されているか確認
- Slack Appの設定でSigning Secretを再確認

**原因2: タイムスタンプエラー**
- サーバーの時刻が正しいか確認
- 5分以上古いリクエストは拒否されます

**原因3: Request URLが間違っている**
- Slack Appの設定で正しいURLが設定されているか確認
- トンネルが起動しているか確認

### 開発環境で署名検証をスキップする

一時的に署名検証をスキップしたい場合（デバッグ目的）:

`.env`ファイルから`SLACK_SIGNING_SECRET`を一時的にコメントアウト:

```env
# SLACK_SIGNING_SECRET=7eafa3a072a1e8167a6f5d999f4bb121
```

**注意**: 本番環境では必ず署名検証を有効にしてください！

### ログの確認ポイント

```bash
# Slackからのリクエストを確認
tail -f log/development.log | grep -i slack

# エラーのみ確認
tail -f log/development.log | grep -i error
```

## 📝 期待される動作

1. ボタンクリック時、Slackから`/slack/actions`にPOSTリクエスト
2. 署名検証が成功
3. ペイロードがパースされる
4. Visit レコードのステータスが`acknowledged`に更新
5. Slackに「✓ 確認済み」と返信

## 🔐 セキュリティ

- **本番環境**: 必ず署名検証を有効にする
- **開発環境**: 署名検証はオプション（デバッグを容易にするため）
- **Request URL**: HTTPSが必須（Slack側の要件）

## 📊 現在の設定確認

```bash
# 環境変数の確認
cd /Users/zone/Documents/work/Cursor/23_reception_mgmt
grep SLACK .env

# ルートの確認
rails routes | grep slack

# 出力例:
# POST   /slack/actions   slack_actions#create
```

## 🧪 手動テスト（curl）

トンネルを使わずにローカルでテストする場合:

```bash
# 署名検証をスキップした状態で
curl -X POST http://localhost:3000/slack/actions \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d 'payload={"type":"block_actions","actions":[{"action_id":"acknowledge_visit","value":"1"}]}'
```

このコマンドは開発環境でSLACK_SIGNING_SECRETが未設定の場合のみ動作します。

