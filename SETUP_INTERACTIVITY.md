# SlackインタラクティブURL設定ガイド

## 🎯 目的

Slackのボタン（「すぐ行きます」「お待ちいただく」「心当たりがない」）を動作させるために、インタラクティブURLを設定する必要があります。

## 📋 設定手順

### ステップ1: Cloudflare Tunnelを起動

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

### ステップ2: Slack Appの設定

1. **[Slack API Apps](https://api.slack.com/apps)** にアクセス
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
7. 緑のチェックマーク ✅ が表示されれば成功です

### ステップ3: テスト

1. 受付アプリで新しい訪問を作成
2. Slackチャネルに通知が届くことを確認
3. 「すぐ行きます」「お待ちいただく」「心当たりがない」のいずれかのボタンをクリック
4. メッセージが更新され、履歴が表示されることを確認

## ⚠️ 注意事項

- **トンネルURLは再起動のたびに変わります**
  - トンネルを再起動したら、必ずSlack Appの設定も更新してください
- **開発環境でのみ使用**
  - 本番環境では、固定のドメインを使用してください
- **トンネルは常に起動しておく必要があります**
  - ボタンを押すたびにSlackからリクエストが送信されるため、トンネルが起動していないとエラーになります

## 🔍 トラブルシューティング

### エラー: "インタラクティブURLが設定されていない"

**原因**: Slack Appの設定でRequest URLが設定されていない、または無効

**解決方法**:
1. Slack Appの設定で「Interactivity & Shortcuts」を確認
2. 「Interactivity」がONになっているか確認
3. 「Request URL」が正しく設定されているか確認（`/slack/actions`が付いているか）
4. トンネルが起動しているか確認

### エラー: "Slackペイロードが処理できません"

**原因**: トンネルが起動していない、またはURLが間違っている

**解決方法**:
1. トンネルが起動しているか確認
2. Slack Appの設定でRequest URLが正しいか確認
3. ログを確認: `tail -f log/development.log`

### ボタンを押しても反応がない

**原因**: トンネルが停止している、またはURLが変更されている

**解決方法**:
1. トンネルを再起動
2. 新しいURLをSlack Appの設定に反映
3. 「Save Changes」をクリック

## 📝 確認コマンド

```bash
# 1. Railsサーバーが起動しているか確認
lsof -i :3000

# 2. トンネルが起動しているか確認（別ターミナルで）
ps aux | grep cloudflared

# 3. ルートが正しく設定されているか確認
rails routes | grep slack
# 期待される出力: POST   /slack/actions   slack_actions#create

# 4. ログをリアルタイムで確認
tail -f log/development.log
```

## 🎉 成功の確認

以下のログが表示されれば成功です：

```
✅ Slack request signature verified successfully
Handling Slack action: going_now
Visit #X status updated to going_now by username
Slack message updated successfully for visit #X
```
