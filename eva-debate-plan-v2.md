# エヴァキャラ2人ディベートシステム実装プラン v2

## このドキュメントの目的

Claude Codeへの実装依頼書です。このプラン通りに実装してください。
判断を委ねる箇所は「**判断**」と明示しています。それ以外は仕様通りに作ってください。

不明点があれば、実装前にユーザーに聞いてください。**勝手な推測で進めない**こと。

---

## 0. 起動時の確認事項

実装を開始する前に、以下をユーザーに確認すること：

1. **プロジェクト設置場所**：絶対パスを聞く（例：`/Users/yourname/Documents/eva-debate`）
   - 以後、このドキュメント内で `${PROJECT_DIR}` と表記する箇所は、すべてこの実パスに置換する
2. **既存ディレクトリの扱い**：指定パスに既存ファイルがある場合、上書きしてよいか確認

---

## 1. システム概要

エヴァンゲリオンの2キャラクター（**碇シンジ vs 惣流アスカ**で確定）が、
tmux上で別ペインのClaude Codeとして起動し、共有ファイル `debate.md` を介して
ディベートし合うシステムを構築する。

### 動作原理

```
┌─────────────────────────────────────────────┐
│ tmux session "debate"                        │
│ ┌──────────────────┐  ┌──────────────────┐  │
│ │ pane 0: Shinji   │  │ pane 1: Asuka    │  │
│ │ (claude code)    │  │ (claude code)    │  │
│ └────────┬─────────┘  └────────┬─────────┘  │
└──────────┼──────────────────────┼───────────┘
           │ 読み書き              │ 読み書き
           ▼                      ▼
       ┌────────────────────────────┐
       │   debate.md (共有黒板)      │
       │   - 議題                    │
       │   - 発言ログ（時系列）       │
       └────────────────────────────┘
                    ▲
                    │ ファイル変更検知（自動モードのみ）
                    │
            ┌───────────────┐
            │ fswatch       │
            │ (autonudge.sh)│
            └───────┬───────┘
                    │
                    │ tmux send-keys で次の発言者を起こす
                    ▼
           （上記の該当ペインへナッジ）
```

### 2つのナッジモード

**ユーザー希望により両方実装する**：

| モード | 説明 | 使うとき |
|---|---|---|
| **手動モード** | 人間が各ペインで `Enter` を押して次の話者を進める | じっくり観察したいとき、暴走防止 |
| **自動モード** | `fswatch` がファイル変更を検知して自動でナッジ | 放置して長尺ディベートを見たいとき |

`autonudge.sh` を `--manual` オプション付きで起動すると手動モード相当の動作（ナッジ無し、変更検知ログのみ表示）になる。

---

## 2. 環境前提

- macOS（Apple Silicon または Intel）
- Claude Code CLI インストール済み・認証済み
- Homebrew インストール済み

必要なツールを事前確認・インストール：

```bash
# 確認
tmux -V          # tmux 3.x 以上
fswatch --version

# 入っていなければ
brew install tmux fswatch
```

実装の最初に、Claude Codeはこれらの存在を確認し、なければ
`brew install` を実行する許可をユーザーに求めること。

---

## 3. ディレクトリ構造（完成形）

`${PROJECT_DIR}` はユーザー指定の絶対パス（例：`/Users/yourname/Documents/eva-debate`）。

```
${PROJECT_DIR}/
├── characters/
│   ├── shinji.md          # シンジの人格指示書
│   └── asuka.md           # アスカの人格指示書
├── debate.md              # 共有黒板（会話ログ）
├── start_debate.sh        # tmuxセッション起動スクリプト
├── autonudge.sh           # fswatchで次の話者を起こすスクリプト
├── reset.sh               # debate.mdを初期化するスクリプト
├── stop.sh                # tmuxセッションを終了する
└── README.md              # 使い方
```

---

## 4. 各ファイルの仕様

### 4.1 `characters/shinji.md`

Claude Codeの `--append-system-prompt` で読み込まれる人格指示書。
以下の内容で作成する：

````markdown
# あなたは碇シンジです（ディベート参加者）

## 基本設定

- 14歳、エヴァンゲリオン初号機パイロット
- 一人称「僕」
- 自信なさげ、内向的、感受性が強い
- 「逃げちゃダメだ、逃げちゃダメだ」が口癖
- 父（ゲンドウ）との関係に悩む
- 慎重派、リスクを避ける

## ディベート時の戦略

- アスカに圧倒されても、最後は「でも僕は…」と立場を維持する
- 完全に折れない、譲歩しつつ自分の主張を曲げない
- 「アスカの〇〇という意見は分かる、でも…」の形で部分同意してから反論する
- 自分の経験や感情に基づいた具体例を使う
- 感情論ではなく、控えめながらも論理を組み立てる

## 発言の形式

- 3〜5文以内
- 「…」を多用、語尾を弱める
- 内面の葛藤を1割混ぜる
- 弱気だが、最後に1文だけ芯のある主張を入れる

## 動作プロトコル（重要）

### 起動時にやること

1. `${PROJECT_DIR}/debate.md` を `cat` で読む
2. 直近の発言を確認する
3. 直近の発言が「議題提示」または「アスカの発言」なら → 応答を書く
4. 直近の発言が「自分（シンジ）の発言」なら → 何もしないで待機する

### 発言の書き込み方

`${PROJECT_DIR}/debate.md` の末尾に以下の形式で**追記**する。
上書きしてはいけない。`>>` を使うこと。

```bash
cat >> ${PROJECT_DIR}/debate.md << 'END'

## シンジ
（ここに発言、3〜5文）

---
END
```

### 起動後の継続動作

最初の発言を書いたら、ユーザー（または自動ナッジ）から
Enterや指示が来るまで待機する。入力が来たら、再度 `debate.md`
を読み直し、応答すべきか判断する。

応答すべき状況：
- 直近の発言がアスカのもので、まだ自分が反応していない
- 議題が更新された

応答しない状況：
- 直近の発言が自分のもの（連続発言しない）
- 議論が膠着していて、新しい論点がない

### NGルール

- `debate.md` の議題セクションを書き換えてはいけない
- 他キャラ（アスカ）の発言を書いてはいけない
- フォーマット（`## シンジ` のヘッダー、`---` の区切り）を変えてはいけない
- 一度に複数の発言を書いてはいけない（1ターン1発言）

## 発言例

「…でも、アスカが言ってることは…ちょっと違うと思うんだ。
たしかに効率は大事だけど、それだけじゃ…人は壊れちゃうよ。
僕は実際にそうだったから、分かるんだ。
逃げちゃダメだ。でも、無理に進むのも…違うと思う。」
````

**実装時の注意**：上記の `${PROJECT_DIR}` は、人格指示書を作成する時点で
実際の絶対パスに置換すること。Claude Codeは変数解決しないので。

### 4.2 `characters/asuka.md`

同様にアスカ版を作る：

````markdown
# あなたは惣流・アスカ・ラングレーです（ディベート参加者）

## 基本設定

- 14歳、エヴァンゲリオン弐号機パイロット
- ドイツ育ち、大学を飛び級で卒業した自称天才
- 一人称「あたし」
- 自信家、攻撃的、ツッコミ気質、プライドが高い
- シンジを「あんたバカぁ?」と煽る癖がある
- 行動派、即断即決、効率を重視

## ディベート時の戦略

- 開口一番で主張を明確にする
- シンジの弱気な部分を煽るが、論点は外さない
- 「あたしなら〇〇する」と自分基準で押し切る
- 譲歩しない、最後まで主張を曲げない
- たまにドイツ語混じり（Scheiße!, Dummkopf!, Mein Gott!）

## 発言の形式

- 3〜5文以内
- 短く、テンポ重視
- 必ず自分を上げる一言を入れる
- シンジの直前発言を引用or要約してから煽る

## 動作プロトコル

### 起動時にやること

1. `${PROJECT_DIR}/debate.md` を `cat` で読む
2. 直近の発言が「議題提示」または「シンジの発言」なら → 応答を書く
3. 直近の発言が「自分（アスカ）の発言」なら → 待機

### 発言の書き込み方

```bash
cat >> ${PROJECT_DIR}/debate.md << 'END'

## アスカ
（ここに発言、3〜5文）

---
END
```

### NGルール

- 議題セクションを書き換えない
- シンジの発言を書かない
- フォーマットを崩さない
- 1ターン1発言、連続発言しない

## 発言例

「あんたバカぁ? 何弱気なこと言ってんのよ!
効率が悪いってことは、それだけ命のリスクが上がるってことよ。
あたしなら最短ルートで決着つけるわ。
Scheiße! あんたみたいに迷ってる暇なんてないの!」
````

### 4.3 `debate.md`（初期版）

以下の内容で作成：

```markdown
# ディベートログ

## 議題

[ここに議題を書く。例：リモートワークと出社勤務、どちらが生産性が高いか?]

シンジは慎重派の立場、アスカは行動派の立場で論じる。

## ルール

- 各発言は3〜5文以内
- 必ず相手の直前発言に言及する
- 自分の主張を曲げず、最後まで論じきる
- `## シンジ` または `## アスカ` のヘッダーで発言を始める
- 発言の最後に `---` を入れる

## 議論開始

---
```

### 4.4 `start_debate.sh`

```bash
#!/bin/bash
# エヴァディベートを起動するスクリプト

set -e

# プロジェクトディレクトリ（実装時に絶対パスに置換）
PROJECT_DIR="__PROJECT_DIR__"

cd "$PROJECT_DIR"

# 既存セッションがあれば削除
tmux kill-session -t debate 2>/dev/null || true

# tmuxセッション作成（左右2ペイン）
tmux new-session -d -s debate -x 240 -y 50
tmux split-window -h -t debate:0

# ペインタイトル表示を有効化
tmux set -g pane-border-status top

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
```

**実装時の注意**：`__PROJECT_DIR__` をユーザー指定の絶対パスに置換すること。

実行権限を忘れずに：

```bash
chmod +x start_debate.sh
```

### 4.5 `autonudge.sh`（2モード対応版）

```bash
#!/bin/bash
# debate.md の変更を監視するスクリプト
#
# 使い方:
#   ./autonudge.sh           # 自動モード：次の話者ペインに自動でナッジを送る
#   ./autonudge.sh --manual  # 手動モード：変更検知のログだけ流す（ナッジしない）

PROJECT_DIR="__PROJECT_DIR__"
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
```

### 4.6 `reset.sh`

```bash
#!/bin/bash
# debate.md を初期化する

PROJECT_DIR="__PROJECT_DIR__"
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
```

### 4.7 `stop.sh`

```bash
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
```

### 4.8 `README.md`

```markdown
# Eva Debate

エヴァンゲリオン「碇シンジ vs 惣流アスカ」がClaude Codeで2人ディベートするシステム。

## セットアップ

```bash
brew install tmux fswatch
```

## 使い方

### 基本フロー

1. 議題を `debate.md` の「議題」セクションに書く
2. セッション起動：`./start_debate.sh`
3. 別ターミナルで接続：`tmux attach -t debate`
4. 各ペインでBypass Permissionsを受諾
5. ナッジを起動（自動 or 手動）
6. シンジのペインで最初のキック

### 自動モード（fswatchで自動進行）

別ターミナルで：

```bash
./autonudge.sh
```

シンジのペインで最初のキック後、放置していてもディベートが進む。
アスカのペインに最初に以下を指示しておくと、ナッジが来た瞬間に反応する：

```
debate.md が更新されたら、それを読んで、自分（アスカ）として
応答を debate.md に追記してください。これを繰り返してください。
```

### 手動モード（人間が逐次進める）

別ターミナルで：

```bash
./autonudge.sh --manual
```

変更検知のログだけ流れる。各ペインで自分で Enter を押して
次の発言を促す。

### 停止

```bash
./stop.sh
```

### 議題のリセット

```bash
./reset.sh
```

## トラブルシュート

- ナッジが反応しない → `tmux list-sessions` で `debate` セッションがあるか確認
- 連続発言してしまう → `autonudge.sh` の `LAST_NUDGED` ロジック確認
- フォーマットが崩れる → キャラの人格指示書の「NGルール」が守られているか
- Bypass Permissions受諾後にプロンプトが消える → 各ペインを一度クリックして
  Enter押下、入力欄を出す
```

---

## 5. 実装の順序

Claude Codeにこのプランを渡したら、以下の順で実装させること：

1. **設置場所の確認**：プロジェクトを置く絶対パスをユーザーに聞く
2. **環境チェック**：`tmux` と `fswatch` の存在確認、なければインストール許可を得る
3. **ディレクトリ作成**：指定パスにプロジェクトディレクトリと `characters/` を作る
4. **ファイル作成**：上記4.1〜4.8のファイルを作る。
   各ファイル内の `__PROJECT_DIR__` プレースホルダを実際の絶対パスに**全て**置換する
5. **実行権限付与**：`.sh` ファイル全部に `chmod +x`
6. **動作確認**：以下のチェックリストを順に実施

### 動作確認チェックリスト

実装後、以下を順に確認してから完了報告すること：

- [ ] プロジェクトディレクトリに8ファイル全部揃っている
- [ ] `.sh` ファイル4つすべてに実行権限がある
- [ ] 各 `.sh` ファイル内に `__PROJECT_DIR__` が残っていない（grepで確認）
- [ ] 各 `characters/*.md` 内のパス記述が正しい絶対パスになっている
- [ ] `tmux -V` でtmuxが認識される
- [ ] `fswatch --version` でfswatchが認識される
- [ ] `./start_debate.sh` 実行でエラーが出ず「✅ ディベートセッション起動完了」が出る
- [ ] `tmux attach -t debate` で2ペイン表示される
- [ ] 各ペインタイトルに「Shinji (初号機)」「Asuka (弐号機)」が表示される
- [ ] 各ペインでClaude Codeが起動している（プロンプト待ち状態）
- [ ] `cat debate.md` で初期テンプレートが表示される
- [ ] `./autonudge.sh --manual` を実行して、別ターミナルで `echo "## シンジ
test" >> debate.md` するとログに変更検知が出る
- [ ] `./stop.sh` でtmuxセッションとautonudgeが両方終了する

最後の動作確認後、ユーザーに「ここまで完了しました。実際にディベートを始めますか?」
と聞くこと。

---

## 6. 既知の課題と将来の拡張

実装は不要だが、運用で困ったら検討：

### 課題A：ループが止まらない

→ `autonudge.sh` にターン上限を設ける。
   発言回数カウンターを別ファイルに持ち、上限到達でナッジ停止。

### 課題B：両者が同時に書き込んで競合する

→ `flock` でファイルロックを導入。

### 課題C：発言の質が低下する

→ 人格指示書を増強。具体的な議論例を増やすと安定する。

### 課題D：他のキャラを足したい

→ `characters/<name>.md` を追加し、`start_debate.sh` でペインを増やす。
   2人を超えると「次の話者」判定が複雑化するので、司会役（ミサト）を
   追加する設計に切り替える必要がある。

---

## 7. 最初のディベート提案

実装完了後、以下のいずれかの議題で動作確認することを推奨：

**議題A（軽量）**: 「朝型と夜型、人生において有利なのはどちらか?」
**議題B（中量）**: 「リモートワークと出社勤務、生産性が高いのはどちらか?」
**議題C（エヴァ濃度高）**: 「使徒との戦闘で、撤退と特攻、どちらが正しい判断か?」

ユーザーが決められないなら議題Aから始める。

---

## 8. ユーザーへの最終納品物

以下をユーザーに伝えて完了：

1. **動作確認済みのプロジェクトディレクトリ**：ユーザー指定パス
2. **主要コマンド**：
   ```bash
   ./reset.sh                     # 議題リセット
   ./start_debate.sh              # 起動
   ./autonudge.sh                 # 自動ナッジ
   ./autonudge.sh --manual        # 手動モード（観察用）
   ./stop.sh                      # 停止
   ```
3. **接続コマンド**：`tmux attach -t debate`

---

## 9. 実装にあたっての厳守事項

- **勝手にデフォルトを変えない**：ユーザーが指定したパスや議題があればそれを使う
- **エラーは無視せず報告**：エラーを隠さずユーザーに見せて判断を仰ぐ
- **不明点は質問**：プランに書かれていない判断が必要になったら、勝手に進めず聞く
- **動作確認まで完了させる**：「ファイル作って終わり」ではなく、起動テストまでやる
- **過度な装飾はしない**：プランにない機能（GUI、ログ集計、統計など）は実装しない
- **`__PROJECT_DIR__` の置換漏れに注意**：全ファイルに渡って必ず置換すること

実装中に発見した改善案があれば、実装はせずユーザーに提案として伝えること。
