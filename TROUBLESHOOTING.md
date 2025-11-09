# SlackインタラクティブURL設定のトラブルシューティング

## 🔍 エラー: "インタラクティブURLが設定されていない"

このエラーが表示される場合、以下の手順で確認してください。

### ステップ1: トンネルURLの確認

Cloudflare Tunnelを起動したターミナルで、以下のような出力を確認してください：

```
Your quick Tunnel has been created! Visit it at:
https://abc-def-ghi.trycloudflare.com
```

このURLをコピーしてください。

### ステップ2: Slack Appの設定を確認

1. [Slack API Apps](https://api.slack.com/apps) にアクセス
2. 使用しているアプリを選択
3. **「Interactivity & Shortcuts」** をクリック
4. 以下の項目を確認：
   - ✅ **「Interactivity」** が **ON** になっているか
   - ✅ **「Request URL」** が設定されているか
   - ✅ URLの形式が `https://[トンネルURL].trycloudflare.com/slack/actions` になっているか
   - ✅ URLの末尾に `/slack/actions` が付いているか

### ステップ3: URL検証の確認

「Request URL」を入力して「Save Changes」をクリックした際に、**緑のチェックマーク ✅** が表示される必要があります。

もし赤いエラーマーク ❌ が表示される場合：
- URLが間違っている可能性があります
- トンネルが起動していない可能性があります
- エンドポイントが正しく応答していない可能性があります

### ステップ4: エンドポイントのテスト

以下のコマンドでエンドポイントが正しく動作しているか確認できます：

```bash
curl -X POST http://localhost:3000/slack/actions \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "payload={\"type\":\"url_verification\",\"challenge\":\"test123\"}"
```

期待されるレスポンス：
```json
{"challenge":"test123"}
```

### ステップ5: ログの確認

Slackからリクエストが届いているか確認するため、ログを監視してください：

```bash
tail -f log/development.log
```

Slack Appの設定で「Save Changes」をクリックした際に、以下のようなログが表示されるはずです：

```
=== Slack Actions Controller Called ===
Request method: POST
Payload type: url_verification
Responding to url_verification challenge
```

## 🛠 よくある問題と解決方法

### 問題1: トンネルURLがわからない

**解決方法**: トンネルを再起動してURLを確認

```bash
# 既存のトンネルを停止
pkill cloudflared

# 新しいトンネルを起動
cloudflared tunnel --url http://localhost:3000
```

### 問題2: URL検証でエラーが表示される

**原因**: 
- トンネルが起動していない
- URLが間違っている
- エンドポイントが応答していない

**解決方法**:
1. トンネルが起動しているか確認: `ps aux | grep cloudflared`
2. Railsサーバーが起動しているか確認: `lsof -i :3000`
3. エンドポイントをテスト（上記のステップ4を参照）

### 問題3: ボタンを押しても反応がない

**原因**: 
- Request URLが設定されていない
- トンネルが停止している
- URLが変更されている

**解決方法**:
1. Slack Appの設定でRequest URLが正しく設定されているか確認
2. トンネルが起動しているか確認
3. ログを確認してエラーがないか確認

## 📝 チェックリスト

- [ ] Cloudflare Tunnelが起動している
- [ ] Railsサーバーが起動している（ポート3000）
- [ ] Slack Appの設定で「Interactivity」がONになっている
- [ ] Request URLが `https://[トンネルURL].trycloudflare.com/slack/actions` の形式になっている
- [ ] URL保存時に緑のチェックマークが表示された
- [ ] エンドポイントのテストが成功した
- [ ] ログでリクエストが確認できる

## 🎯 最終確認

すべての設定が完了したら、以下をテストしてください：

1. 受付アプリで新しい訪問を作成
2. Slackチャネルに通知が届くことを確認
3. 「すぐ行きます」ボタンをクリック
4. メッセージが更新され、履歴が表示されることを確認
5. ログで以下のメッセージが表示されることを確認：
   ```
   === Slack Actions Controller Called ===
   Handling Slack action: going_now
   Visit #X status updated to going_now by username
   ```

これで動作するはずです！
