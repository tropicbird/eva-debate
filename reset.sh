#!/bin/bash
# debate.md を初期化する

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# バックアップを取る
if [ -f debate.md ]; then
    cp debate.md "debate.md.backup.$(date +%Y%m%d_%H%M%S)"
    echo "✅ 既存の debate.md をバックアップしました"
fi

# 初期化
cat > debate.md << 'EOF'
# ディベートログ

## 議題

[ここに議題を書く]

シンジは慎重派の立場、アスカは行動派の立場で論じる。

## ルール

- 各発言は3〜5文以内
- 必ず相手の直前発言に言及する
- 自分の主張を曲げず、最後まで論じきる
- `## シンジ` または `## アスカ` のヘッダーで発言を始める
- 発言の最後に `---` を入れる

## 議論開始

---
EOF

echo "✅ debate.md を初期化しました"
echo "   議題を編集してから ./start_debate.sh を実行してください"
