# Slack エラー「ペイロードが処理できません」のトラブルシューティング

## 🔍 現在の状況

エラーメッセージ: **「Slackペイロードが処理できません」**

このエラーは **Slack側** で表示されているもので、以下の原因が考えられます:

## ❌ 主な原因

### 1. Request URLが設定されていない（最も可能性が高い）

Slack Appの設定で、InteractivityのRequest URLが設定されていないか、無効なURLが設定されている可能性があります。

### 2. トンネルが起動していない

Request URLに指定したトンネル（Cloudflare Tunnel / ngrok）が起動していない。

### 3. Request URLが間違っている

URLの末尾が `/slack/actions` になっていない、または別のポートを指定している。

## ✅ 解決手順

### ステップ1: トンネルを起動

**Option A: Cloudflare Tunnel（推奨）**

```bash
# 別のターミナルで実行
cloudflared tunnel --url http://localhost:3000
```

出力例:
```
Your quick Tunnel has been created! Visit it at (it may take some time to be reachable):
https://abc-def-ghi.trycloudflare.com
```

このURL（`https://abc-def-ghi.trycloudflare.com`）をコピーしてください。

**Option B: ngrok**

```bash
# 別のターミナルで実行
ngrok http 3000
```

表示されるForwarding URLをコピーしてください。

### ステップ2: Slack Appの設定を確認・更新

1. **Slack API Apps** にアクセス
   👉 https://api.slack.com/apps

2. 使用しているアプリを選択

3. 左メニューから **「Interactivity & Shortcuts」** をクリック

4. **「Interactivity」** をONにする

5. **「Request URL」** に以下を入力:
   ```
   https://abc-def-ghi.trycloudflare.com/slack/actions
   ```
   ⚠️ 必ず `/slack/actions` を付けてください
   ⚠️ あなたのトンネルURLに置き換えてください

6. **「Save Changes」** をクリック

7. ✅ 緑色のチェックマークが表示されれば成功

### ステップ3: テスト実行

1. ブラウザで http://localhost:3000/ にアクセス
2. 従業員を選択
3. メモを入力して「通知を送信」
4. SlackのDMを確認
5. **「確認済みにする」** ボタンをクリック

### ステップ4: ログ確認

別のターミナルで以下を実行:

```bash
cd /Users/zone/Documents/work/Cursor/23_reception_mgmt
tail -f log/development.log
```

ボタンをクリックすると、以下のようなログが表示されるはずです:

```
Started POST "/slack/actions" for xxx.xxx.xxx.xxx
Processing by SlackActionsController#create
Slack request signature verified successfully
Parsing Slack payload: payload=...
Handling Slack action: acknowledge_visit
Visit #1 acknowledged successfully
Completed 200 OK
```

## 🔍 エラーの見分け方

### エラー表示場所で判断

| エラーの表示場所 | 原因 |
|--------------|------|
| **Slackのメッセージ内**（赤いエラー）| Request URLの設定問題 |
| **Railsのログ**（development.log）| コード内のエラー |
| **ブラウザの画面** | Railsアプリのエラー |

### Slackで表示されるエラーパターン

1. **「Slackペイロードが処理できません」**
   - Request URLが設定されていない
   - Request URLが間違っている

2. **「We had trouble connecting to...」**
   - トンネルが起動していない
   - URLが到達不可能

3. **「Invalid signature」**
   - SLACK_SIGNING_SECRETが間違っている

## 🛠 デバッグモード（開発環境のみ）

署名検証を一時的にスキップしてテストする場合:

1. `.env`ファイルを編集:
   ```bash
   cd /Users/zone/Documents/work/Cursor/23_reception_mgmt
   nano .env
   ```

2. `SLACK_SIGNING_SECRET`をコメントアウト:
   ```env
   SLACK_BOT_TOKEN=xoxb-your-token-here
   # SLACK_SIGNING_SECRET=your-signing-secret-here
   ```

3. Railsサーバーを再起動:
   ```bash
   # プロセスIDを確認
   lsof -i :3000 | grep LISTEN
   
   # 停止
   kill <PID>
   
   # 再起動
   rails server -p 3000 &
   ```

4. ボタンをもう一度試す

5. **重要**: テスト後は必ずコメントを外して本番用の設定に戻してください

## 📋 チェックリスト

現在の設定を確認:

- [ ] Railsサーバーが起動している（http://localhost:3000）
- [ ] Cloudflare Tunnel / ngrok が起動している
- [ ] Slack Appの設定で Interactivity が ON
- [ ] Request URL が `https://your-tunnel.com/slack/actions` 形式
- [ ] Request URL保存時に緑のチェックマークが表示された
- [ ] .envファイルに SLACK_BOT_TOKEN が設定されている
- [ ] .envファイルに SLACK_SIGNING_SECRET が設定されている

## 🎯 現在の設定値

```bash
# 確認コマンド
cd /Users/zone/Documents/work/Cursor/23_reception_mgmt

# 1. Railsサーバーの状態
lsof -i :3000

# 2. 環境変数
grep SLACK .env

# 3. ルート設定
rails routes | grep slack

# 期待される出力:
# POST   /slack/actions   slack_actions#create
```

## 💡 次のアクション

1. **まず**: Cloudflare Tunnelを起動してURLを取得
2. **次に**: Slack AppのRequest URLを設定
3. **最後**: ボタンを押してテスト

これで解決しない場合は、ログを共有してください:

```bash
tail -50 log/development.log
```

