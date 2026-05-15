# Eva Debate

[Claude Code](https://docs.claude.com/en/docs/claude-code/overview) を **2インスタンス並列起動** し、エヴァンゲリオンの「碇シンジ vs 惣流アスカ」が指定された議題で日本語ディベートをするデモプロジェクト。

2つの Claude が `debate.md` という1つのファイルを共有メモリとして使い、`tmux` のペインで隣り合いながら交互に追記していく。司会役（`autonudge.sh`）が「次はあなたの番ですよ」と次の話者のペインを `fswatch` ベースで自動で叩く。

完走例：[`debate.example.md`](./debate.example.md) を見るとアウトプットの雰囲気が掴める。

## 前提

- macOS（`tmux`, `fswatch` を使う構成のため。Linux でも `fswatch` が動けば走るはず）
- [Claude Code](https://docs.claude.com/en/docs/claude-code/setup) がインストール済みでログイン済みであること
- Homebrew で以下：

  ```bash
  brew install tmux fswatch
  ```

> **⚠️ 注意**: 起動スクリプトは `claude --dangerously-skip-permissions` を使う。各 Claude インスタンスがプロジェクトディレクトリ内で `cat` / `>>` 追記をパーミッション確認なしに実行できるようにするため。**信頼できる作業ディレクトリでのみ実行すること。**

## セットアップ

```bash
git clone <このリポジトリのURL>
cd eva-debate
chmod +x *.sh   # 必要なら
```

## 使い方

### 1. 議題を決める

`debate.md` を開き、`## 議題` セクションを書き換える：

```markdown
## 議題

リモートワークの是非について議論する。
シンジは慎重派の立場、アスカは行動派の立場で論じる。
```

> 立場は自由に組み替えてOK。シンジは弱気・慎重なキャラ、アスカは攻撃的・行動派なキャラなので、それに合った役回りを与えると噛み合う。

> **URL や固有名詞を議題に含めてもよい**。例えば「このリポジトリ https://github.com/.../foo の設計の是非について議論せよ」と書くと、両キャラは最初の発言を書く前に `WebFetch` / `WebSearch` で内容を確認した上で論じる（`characters/*.md` の動作プロトコルに組み込み済み）。

### 2. ディベートセッション起動

```bash
./start_debate.sh
```

裏で `tmux` セッション `debate` が左右2ペインで立ち上がる。

### 3. 別ターミナルから接続

```bash
tmux attach -t debate
```

各ペインで Claude Code の初回プロンプト（Bypass Permissions の確認など）に答えておく。

### 4. ナッジ（自動進行）を起動

さらに別ターミナルで：

```bash
./autonudge.sh           # 自動モード
# または
./autonudge.sh --manual  # 手動モード（変更ログだけ流す、Enterは自分で押す）
```

自動モードでは `debate.md` の更新を検知するたびに、最後に発言した人と**反対側**のペインに「あなたの番です」と自動で送信される。

### 5. キックオフ

シンジのペインで以下を打つ：

```
debate.md を読んで、議題に対するあなた（シンジ）の意見を追記してください。
```

これで最初の発言が書かれ、`fswatch` が発火し、アスカ側にナッジが入り、ループが回り始める。

### 6. 適当なところで止める

```bash
./stop.sh   # tmux セッションと autonudge.sh を終了
```

### 議題のリセット

別の議題で再戦したいとき：

```bash
./reset.sh
```

過去の `debate.md` は `debate.md.backup.<タイムスタンプ>` として残る（gitignore 対象）。

## 仕組み

```
┌──────────────────┐       ┌──────────────────┐
│  tmux pane 0.0   │       │  tmux pane 0.1   │
│  Claude (シンジ) │       │  Claude (アスカ) │
│  人格: shinji.md │       │  人格: asuka.md  │
└────────┬─────────┘       └────────┬─────────┘
         │ cat >> debate.md          │ cat >> debate.md
         ▼                           ▼
       ┌─────────────────────────────────┐
       │          debate.md              │
       │  （共有状態 = 議事録）          │
       └────────────────┬────────────────┘
                        │ fswatch -o
                        ▼
             ┌─────────────────────┐
             │   autonudge.sh      │
             │  次の話者を判定     │
             │  tmux send-keys     │
             └─────────────────────┘
```

- **人格付与**: `start_debate.sh` が `claude --append-system-prompt "$(cat characters/<name>.md)"` で各インスタンスに人格＋動作プロトコルを注入。
- **ターン制御**: `autonudge.sh` が `## シンジ` / `## アスカ` ヘッダ行を grep し、最後の発言者と反対側にナッジを送る。連続発言は `LAST_NUDGED` でブロック、`COOLDOWN=3` 秒。
- **構造の固定**: `debate.md` の発言フォーマット（`## <名前>` ヘッダ + `---` 区切り）が崩れると判定ロジックが壊れる。人格ファイル側のプロンプトでフォーマット遵守を強く指示してある。

## カスタマイズ

- **別キャラで動かしたい**: `characters/` に新しい `.md` を追加 → `start_debate.sh` の `--append-system-prompt` 部分と、`autonudge.sh` のヘッダ判定（`## シンジ|## アスカ` の部分）を差し替える。
- **3人以上にしたい**: tmux ペインを増やし、`autonudge.sh` のターン制御をラウンドロビンに書き換える必要がある（現状は2人前提）。
- **議論の長さや口調**: `characters/*.md` の「発言の形式」セクションを編集。

## トラブルシュート

| 症状 | 確認ポイント |
|---|---|
| ナッジが反応しない | `tmux list-sessions` に `debate` があるか / `autonudge.sh` が動いているか |
| 連続発言してしまう | `autonudge.sh` の `LAST_NUDGED` ロジック / 人格ファイルの「連続発言しない」ルールが守られているか |
| フォーマットが崩れる | `## <名前>` ヘッダや `---` 区切りが正しく書かれているか（崩れると次の話者判定が失敗する） |
| 初回プロンプトが消える | tmux ペインを一度クリックして Enter、入力欄を再表示 |
| `fswatch` が動かない | macOS 以外なら inotify 系への置き換えが必要 |

## 免責 / クレジット

本リポジトリは [新世紀エヴァンゲリオン](https://www.evangelion.co.jp/) のキャラクター名・口調を借りた**非営利のファン・教育プロジェクト**であり、株式会社カラー / khara および関連権利者とは一切関係がない。商用利用や公式コンテンツとしての取り扱いは想定していない。

LLM の対話制御・マルチエージェント連携のおもちゃとして遊ぶ目的で公開している。
