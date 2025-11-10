#!/bin/bash

echo "=== Slack設定確認ツール ==="
echo ""

# 1. Railsサーバーの状態
echo "1. Railsサーバーの状態:"
if lsof -i :3000 > /dev/null 2>&1; then
    echo "   ✅ Railsサーバーは起動しています"
else
    echo "   ❌ Railsサーバーが起動していません"
fi
echo ""

# 2. トンネルの状態
echo "2. Cloudflare Tunnelの状態:"
if ps aux | grep -E "cloudflared tunnel" | grep -v grep > /dev/null 2>&1; then
    echo "   ✅ Cloudflare Tunnelは起動しています"
    TUNNEL_URL=$(ps aux | grep "cloudflared tunnel" | grep -v grep | head -1 | awk '{print $NF}')
    echo "   コマンド: $TUNNEL_URL"
else
    echo "   ❌ Cloudflare Tunnelが起動していません"
fi
echo ""

# 3. エンドポイントのテスト
echo "3. エンドポイントのテスト:"
RESPONSE=$(curl -s -X POST http://localhost:3000/slack/actions \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "payload={\"type\":\"url_verification\",\"challenge\":\"test123\"}")
if echo "$RESPONSE" | grep -q "test123"; then
    echo "   ✅ エンドポイントは正常に動作しています"
    echo "   レスポンス: $RESPONSE"
else
    echo "   ❌ エンドポイントが正しく応答していません"
    echo "   レスポンス: $RESPONSE"
fi
echo ""

# 4. 環境変数の確認
echo "4. 環境変数の確認:"
if [ -f .env ]; then
    if grep -q "SLACK_BOT_TOKEN" .env; then
        echo "   ✅ SLACK_BOT_TOKENが設定されています"
    else
        echo "   ❌ SLACK_BOT_TOKENが設定されていません"
    fi
    
    if grep -q "SLACK_CHANNEL_ID" .env; then
        CHANNEL_ID=$(grep "SLACK_CHANNEL_ID" .env | cut -d'=' -f2 | tr -d ' ')
        echo "   ✅ SLACK_CHANNEL_IDが設定されています: $CHANNEL_ID"
    else
        echo "   ❌ SLACK_CHANNEL_IDが設定されていません"
    fi
    
    if grep -q "SLACK_SIGNING_SECRET" .env; then
        echo "   ✅ SLACK_SIGNING_SECRETが設定されています"
    else
        echo "   ⚠️  SLACK_SIGNING_SECRETが設定されていません（開発環境では問題ありません）"
    fi
else
    echo "   ❌ .envファイルが見つかりません"
fi
echo ""

# 5. ルートの確認
echo "5. ルートの確認:"
ROUTE=$(rails routes | grep slack | head -1)
if [ -n "$ROUTE" ]; then
    echo "   ✅ Slackルートが設定されています:"
    echo "   $ROUTE"
else
    echo "   ❌ Slackルートが見つかりません"
fi
echo ""

echo "=== 次のステップ ==="
echo "1. Cloudflare TunnelのURLを確認してください"
echo "2. Slack Appの設定で以下のURLを設定してください:"
echo "   https://[あなたのトンネルURL].trycloudflare.com/slack/actions"
echo "3. 「Save Changes」をクリックして、緑のチェックマークが表示されることを確認してください"
