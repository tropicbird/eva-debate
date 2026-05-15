#!/bin/bash
# debate.md の変更を監視するスクリプト
#
# 使い方:
#   ./autonudge.sh           # 自動モード：次の話者ペインに自動でナッジを送る
#   ./autonudge.sh --manual  # 手動モード：変更検知のログだけ流す（ナッジしない）

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEBATE_FILE="${PROJECT_DIR}/debate.md"

# モード判定
MODE="auto"
if [[ "$1" == "--manual" ]]; then
    MODE="manual"
fi

# tmuxセッション存在チェック（自動モードのみ）
if [[ "$MODE" == "auto" ]] && ! tmux has-session -t debate 2>/dev/null; then
    echo "❌ tmuxセッション 'debate' が見つかりません。"
    echo "   まず ./start_debate.sh を実行してください。"
    exit 1
fi

# fswatchチェック
if ! command -v fswatch &> /dev/null; then
    echo "❌ fswatch がインストールされていません。"
    echo "   brew install fswatch を実行してください。"
    exit 1
fi

if [[ "$MODE" == "auto" ]]; then
    echo "🤖 自動モード：$DEBATE_FILE の変更を監視中..."
    echo "    変更を検知したら、次の話者のペインに自動でナッジを送ります。"
else
    echo "👁️  手動モード：$DEBATE_FILE の変更を監視中..."
    echo "    変更検知のログのみ表示。各ペインで自分でEnterを押してください。"
fi
echo "    停止するには Ctrl+C を押してください。"
echo ""

# ナッジ間のクールダウン（秒）
COOLDOWN=3

# 連続発言を防ぐ：最後にナッジした話者を記録
LAST_NUDGED=""

fswatch -o "$DEBATE_FILE" | while read; do
    # 最後の発言者を判定
    LAST_SPEAKER=$(grep -E "^## (シンジ|アスカ)" "$DEBATE_FILE" | tail -1)

    if [[ "$LAST_SPEAKER" == *"シンジ"* ]]; then
        NEXT_PANE="debate:0.1"
        NEXT_NAME="アスカ"
    elif [[ "$LAST_SPEAKER" == *"アスカ"* ]]; then
        NEXT_PANE="debate:0.0"
        NEXT_NAME="シンジ"
    else
        echo "📭 [$(date +%H:%M:%S)] まだ誰も発言していません。シンジのペインで最初の発言を促してください。"
        continue
    fi

    # 連続ナッジ防止
    if [[ "$LAST_NUDGED" == "$NEXT_NAME" ]]; then
        echo "⏭️  [$(date +%H:%M:%S)] $NEXT_NAME は既にナッジ済み。スキップ。"
        continue
    fi

    if [[ "$MODE" == "auto" ]]; then
        echo "🔔 [$(date +%H:%M:%S)] $NEXT_NAME のペインをナッジ ($NEXT_PANE)"
        tmux send-keys -t "$NEXT_PANE" "debate.mdが更新されました。最新の発言を読んで、あなたとして応答してください。" Enter
    else
        echo "📝 [$(date +%H:%M:%S)] 変更検知：直前の発言者は ${LAST_SPEAKER#\## }。次の話者は $NEXT_NAME。手動でEnterを押してください。"
    fi

    LAST_NUDGED="$NEXT_NAME"
    sleep "$COOLDOWN"
done
