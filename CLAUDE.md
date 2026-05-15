# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## このプロジェクトの概要

tmux 上で **Claude Code を2インスタンス並行起動** し（pane 0 にシンジ、pane 1 にアスカ）、共有ファイルへの追記を介して日本語ディベートをさせるハーネス。アプリケーションコードは存在せず、シェルスクリプトとキャラクター用プロンプトファイルだけで構成される。

## コマンド

```bash
./start_debate.sh          # tmux セッション `debate` を立ち上げ、claude --dangerously-skip-permissions を2ペインで起動
tmux attach -t debate      # 別ターミナルから接続
./autonudge.sh             # 自動モード：debate.md を監視し、変更があれば次の話者ペインに send-keys
./autonudge.sh --manual    # 検知ログのみ出力。Enter は人間が押す
./reset.sh                 # debate.md をバックアップしてから空テンプレートで書き直す
./stop.sh                  # tmux セッション終了 + autonudge.sh を pkill
```

前提（Homebrew）：`tmux`, `fswatch`。

## アーキテクチャ

システム全体が、1つのファイルを介したフィードバックループとして回る。

1. **共有状態**：`debate.md`。各話者は `## シンジ\n…\n---` または `## アスカ\n…\n---` 形式のブロックを追記する。**上書きは禁止** — キャラクター側プロンプトで `cat >>` + ヒアドキュメント追記が義務付けられている。
2. **話者の人格付与**：`start_debate.sh:24,29` で claude 起動時に `--append-system-prompt "$(cat characters/<name>.md)"` として注入される。`characters/` 配下の各ファイルは、人格設定だけでなく**動作プロトコル**（`debate.md` を読み、自分の番か判定し、1ターンだけ追記して待機する）も含む。
3. **ターン制御**：`autonudge.sh` がホスト側で `fswatch -o debate.md` を回す。変更ごとに `## シンジ|## アスカ` の末尾ヘッダを grep し、対になる側のペイン（`debate:0.0` = シンジ、`debate:0.1` = アスカ）を選んで `tmux send-keys` でナッジ文字列 + Enter を送る。`LAST_NUDGED` で同一話者への二重ナッジを防止し、`COOLDOWN=3` でスロットリング。
4. **キックオフ**：人間がシンジのペインに最初のプロンプトを手で入力する（彼が最初のターンを書く → `debate.md` が更新される → fswatch が発火する → アスカにナッジが入る → ループ開始）。

tmux のペイン番号は仕様上ロックされている：`debate:0.0` がシンジ、`debate:0.1` がアスカでなければならない。`autonudge.sh:51-56` がヘッダ内の話者名に対してこのマッピングをハードコードしているため。

## 編集前に知っておくべきこと

- **パスはスクリプト相対 / カレントディレクトリ相対**。`*.sh` は `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)` で自分の置かれた場所を解決する。`characters/*.md` 内のプロトコルはカレントディレクトリの `debate.md` を前提とする（`start_debate.sh` が `cd "$PROJECT_DIR"` してから claude を起動するため担保される）。これらの規約を崩すと壊れる。
- **キャラクタープロンプト内のルールは契約の一部**：人格ファイルは、議題セクションの書き換え、相手キャラのターンの代筆、`## <名前>` / `---` フォーマットの破壊、1ターンに複数発言を書くこと、を禁じている。これらを緩めると `autonudge.sh` のヘッダ grep ロジックが破綻する。
- **`debate.md` はデータ兼テンプレート**：初期構造（議題、ルール、議論開始セクション）の唯一の正本は `reset.sh`。フォーマットを変えるときは `reset.sh` と各人格ファイル内の追記スニペットも合わせて更新すること。
- **`debate.example.md`** は過去の完走ログ（公開デモ用）。実行中の状態ではないので編集不要。
- `eva-debate-plan-v2.md` は設計ドキュメントであり、実行されるコードではない。
