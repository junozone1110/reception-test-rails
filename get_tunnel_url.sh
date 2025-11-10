#!/bin/bash

echo "=== Cloudflare Tunnel URL取得方法 ==="
echo ""
echo "現在実行中のトンネルプロセスを確認中..."
echo ""

# トンネルが起動しているか確認
if ps aux | grep -E "cloudflared tunnel" | grep -v grep > /dev/null 2>&1; then
    echo "✅ Cloudflare Tunnelは起動しています"
    echo ""
    echo "⚠️  トンネルURLを確認するには、トンネルを起動したターミナルを確認してください"
    echo "   または、以下のコマンドでトンネルを再起動してURLを確認してください:"
    echo ""
    echo "   cloudflared tunnel --url http://localhost:3000"
    echo ""
    echo "   出力例:"
    echo "   Your quick Tunnel has been created! Visit it at:"
    echo "   https://abc-def-ghi.trycloudflare.com"
    echo ""
    echo "   このURLをコピーして、Slack Appの設定で以下を設定してください:"
    echo "   https://abc-def-ghi.trycloudflare.com/slack/actions"
else
    echo "❌ Cloudflare Tunnelが起動していません"
    echo ""
    echo "以下のコマンドでトンネルを起動してください:"
    echo "   cloudflared tunnel --url http://localhost:3000"
fi
