#!/bin/bash

TUNNEL_URL="https://training-importantly-phi-confidentiality.trycloudflare.com"
REQUEST_URL="${TUNNEL_URL}/slack/actions"

echo "=== Slack URL設定確認 ==="
echo ""
echo "トンネルURL: $TUNNEL_URL"
echo "Request URL: $REQUEST_URL"
echo ""
echo "このRequest URLをSlack Appの設定で使用してください"
echo ""
echo "=== エンドポイントのテスト ==="
echo ""

# ローカルエンドポイントのテスト
RESPONSE=$(curl -s -X POST http://localhost:3000/slack/actions \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "payload={\"type\":\"url_verification\",\"challenge\":\"test123\"}")

if echo "$RESPONSE" | grep -q "test123"; then
    echo "✅ ローカルエンドポイントは正常に動作しています"
    echo "   レスポンス: $RESPONSE"
else
    echo "❌ ローカルエンドポイントが正しく応答していません"
    echo "   レスポンス: $RESPONSE"
fi

echo ""
echo "=== 次のステップ ==="
echo "1. Slack Appの設定でRequest URLを設定:"
echo "   $REQUEST_URL"
echo ""
echo "2. 「Save Changes」をクリック"
echo ""
echo "3. 緑のチェックマーク ✅ が表示されることを確認"
echo ""
echo "4. ログを監視（別のターミナルで）:"
echo "   tail -f log/development.log"
echo ""
echo "5. Slack Appの設定で「Save Changes」をクリックした際に、"
echo "   ログに以下のメッセージが表示されることを確認:"
echo "   === Slack Actions Controller Called ==="
echo "   Payload type: url_verification"
