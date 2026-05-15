#!/bin/bash
# エヴァディベートを起動するスクリプト
#
# 使い方:
#   ./start_debate.sh                    # デフォルト：shinji vs asuka
#   ./start_debate.sh shinji conan       # 左ペイン=shinji, 右ペイン=conan
#   ./start_debate.sh asuka conan        # 左ペイン=asuka,  右ペイン=conan
#
# 引数は characters/<名前>.md のファイル名（拡張子なし）。
# 各キャラファイルの先頭に必要なメタデータ：
#   <!-- header: <ヘッダー名> -->
#   <!-- title:  <ペインタイトル> -->

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# --- 引数とキャラ存在チェック ---

CHAR_LEFT="${1:-shinji}"
CHAR_RIGHT="${2:-asuka}"

if [ "$CHAR_LEFT" = "$CHAR_RIGHT" ]; then
    echo "❌ 同じキャラクターは指定できません: $CHAR_LEFT"
    exit 1
fi

for c in "$CHAR_LEFT" "$CHAR_RIGHT"; do
    if [ ! -f "characters/$c.md" ]; then
        echo "❌ characters/$c.md が見つかりません。"
        echo "   利用可能なキャラクター："
        ls characters/ | sed 's/\.md$//' | sed 's/^/     - /'
        exit 1
    fi
done

# --- キャラファイル先頭のメタデータを抽出 ---

get_meta() {
    local file="characters/$1.md"
    local key="$2"
    grep -m1 "^<!-- $key:" "$file" | sed -E "s/^<!-- $key: *//; s/ *-->\$//"
}

HEADER_LEFT=$(get_meta "$CHAR_LEFT" "header")
HEADER_RIGHT=$(get_meta "$CHAR_RIGHT" "header")
TITLE_LEFT=$(get_meta "$CHAR_LEFT" "title")
TITLE_RIGHT=$(get_meta "$CHAR_RIGHT" "title")

if [ -z "$HEADER_LEFT" ] || [ -z "$HEADER_RIGHT" ]; then
    echo "❌ メタデータが見つかりません。"
    echo "   各キャラファイル先頭に以下が必要です："
    echo "     <!-- header: <ヘッダー名> -->"
    echo "     <!-- title:  <ペインタイトル> -->"
    exit 1
fi

# --- 状態ファイル（autonudge.sh が読む） ---

cat > .debate_state << EOF
CHAR_LEFT=$CHAR_LEFT
CHAR_RIGHT=$CHAR_RIGHT
HEADER_LEFT=$HEADER_LEFT
HEADER_RIGHT=$HEADER_RIGHT
TITLE_LEFT=$TITLE_LEFT
TITLE_RIGHT=$TITLE_RIGHT
EOF

# --- tmux セッション起動 ---

tmux kill-session -t debate 2>/dev/null || true

tmux new-session -d -s debate -x 240 -y 50
tmux split-window -h -t debate:0

tmux set-option -t debate pane-border-status top

# 左ペイン
tmux select-pane -t debate:0.0 -T "$TITLE_LEFT"
tmux send-keys -t debate:0.0 \
  "cd $PROJECT_DIR && claude --dangerously-skip-permissions --append-system-prompt \"\$(cat characters/$CHAR_LEFT.md)\"" Enter

# 右ペイン
tmux select-pane -t debate:0.1 -T "$TITLE_RIGHT"
tmux send-keys -t debate:0.1 \
  "cd $PROJECT_DIR && claude --dangerously-skip-permissions --append-system-prompt \"\$(cat characters/$CHAR_RIGHT.md)\"" Enter

echo "✅ ディベートセッション起動完了"
echo "    左ペイン (debate:0.0)：$TITLE_LEFT   [ヘッダ: ## $HEADER_LEFT]"
echo "    右ペイン (debate:0.1)：$TITLE_RIGHT  [ヘッダ: ## $HEADER_RIGHT]"
echo ""
echo "次の手順："
echo "  1. tmux attach -t debate"
echo "  2. 各ペインで Claude Code の初回プロンプト（Bypass Permissions）に答える"
echo "  3a. 自動ナッジ：./autonudge.sh"
echo "  3b. 手動：       ./autonudge.sh --manual"
echo "  4. 左ペイン（$HEADER_LEFT）で最初のキック："
echo "       debate.md を読んで、議題に対するあなた（$HEADER_LEFT）の意見を追記してください。"
echo ""
echo "停止：./stop.sh"
