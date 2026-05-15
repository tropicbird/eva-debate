#!/bin/bash
# エヴァディベートを起動するスクリプト

set -e

# プロジェクトディレクトリ（スクリプトの場所基準）
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$PROJECT_DIR"

# 既存セッションがあれば削除
tmux kill-session -t debate 2>/dev/null || true

# tmuxセッション作成（左右2ペイン）
tmux new-session -d -s debate -x 240 -y 50
tmux split-window -h -t debate:0

# ペインタイトル表示を有効化（このセッション限定）
tmux set-option -t debate pane-border-status top

# pane 0: シンジ
tmux select-pane -t debate:0.0 -T "Shinji (初号機)"
tmux send-keys -t debate:0.0 \
  "cd $PROJECT_DIR && claude --dangerously-skip-permissions --append-system-prompt \"\$(cat characters/shinji.md)\"" Enter

# pane 1: アスカ
tmux select-pane -t debate:0.1 -T "Asuka (弐号機)"
tmux send-keys -t debate:0.1 \
  "cd $PROJECT_DIR && claude --dangerously-skip-permissions --append-system-prompt \"\$(cat characters/asuka.md)\"" Enter

echo "✅ ディベートセッション起動完了"
echo ""
echo "次の手順："
echo "  1. 別ターミナルで以下を実行して画面に接続："
echo "       tmux attach -t debate"
echo ""
echo "  2. 各ペインでClaude Codeの初回プロンプト（Bypass Permissions）に答える"
echo ""
echo "  3a. 自動ナッジを起動する場合（別ターミナルで）："
echo "       ./autonudge.sh"
echo ""
echo "  3b. 手動でじっくり進めたい場合："
echo "       ./autonudge.sh --manual"
echo "      （変更検知のログだけ流れる。各ペインで自分でEnterを押す）"
echo ""
echo "  4. シンジのペインで最初のキック："
echo "       debate.md を読んで、議題に対するあなた（シンジ）の意見を追記してください。"
echo ""
echo "停止するには："
echo "  ./stop.sh"
