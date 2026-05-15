#!/bin/bash
# ディベートセッションを終了する

# tmuxセッションを終了
if tmux has-session -t debate 2>/dev/null; then
    tmux kill-session -t debate
    echo "✅ tmuxセッション 'debate' を終了しました"
else
    echo "ℹ️  tmuxセッション 'debate' は既に存在しません"
fi

# autonudge.sh プロセスがあれば終了
if pgrep -f "autonudge.sh" > /dev/null; then
    pkill -f "autonudge.sh"
    echo "✅ autonudge.sh を終了しました"
fi

echo "完全停止完了。"
