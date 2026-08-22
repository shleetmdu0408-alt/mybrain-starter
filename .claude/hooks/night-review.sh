#!/bin/bash
# UserPromptSubmit フック：「おやすみ」と打たれたときだけ、1日を締めるための材料を
# Claude のコンテキストへ流し込む。それ以外のプロンプトでは黙って終了する。
#
#   1. 今日あったことの材料（カレンダーの実績・今日動いた Vault ファイル）
#   2. 日記の書き方の指示（一覧を見せる → オーナーの一言 → 膨らませずに整える）
#   3. 今日のデイリーノートの状態（有無・空セクション・既存の DECISION）
#   4. 取りこぼしチェック（inbox 未処理／今日書いた reports／期限切れ／wiki 未反映の疑い）
#
# 明日の予定・天気は朝のブリーフィング（morning-brief.sh）で出すので、ここでは出さない。
# デイリーノートへの追記は **下書きを見せて承認を取ってから** 書く（このファイル内で指示している）。
#
# 日記について（追加）:
#   日記の本文は **オーナーが書く**。Claude は「思い出すための事実の一覧」を出し、
#   オーナーの一言を **膨らませずに** 文へ整えるだけ。事実から感想を生成してはいけない
#   （CLAUDE.md「状態を書くときは事実だけ。AI の評価語を書かない」）。

PAYLOAD=$(cat)
PROMPT=$(printf '%s' "$PAYLOAD" | jq -r '.prompt // ""' 2>/dev/null)

# 「おやすみ」で始まるときだけ反応する。
# 先頭一致にしているのは「明日はお休みです」のような文中の『お休み』で誤爆しないため。
printf '%s' "$PROMPT" | grep -qiE '^[[:space:]]*(おやすみ|お休みなさい|オヤスミ|ｵﾔｽﾐ|good ?night)' || exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
TODAY=$(date +%F)
NOTE="$ROOT/daily/$TODAY.md"

cat <<EOS
🌙 おやすみルーティン

【伝え方】ねぎらい → **今日あったこと（一覧）** → 取りこぼし → **日記の問いかけ** の順。
一覧を除いて**25行以内**。表は使わない。
**追記は下書きを見せて「これで書いていい？」と聞く。OK が出るまで daily/ に書き込まない。**
推測の進捗評価（停滞・未着手など）は書かない。状態が「待機」のものは催促しない。
最後にやることを増やさない。「明日やろう」で済むものはそう言う。

【この夜の流れ】**往復は1回だけ**にする。
1回目（今）: 今日あったことの一覧 ＋ daily への追記の下書き ＋ 取りこぼし ＋ 「今日はどうでしたか？」の問い
2回目（オーナーの返事のあと）: 日記と追記をまとめて daily/${TODAY}.md へ書く

### 1. 今日あったこと — 事実だけを時系列で並べる

**これは「思い出すための材料」。評価・意味づけ・まとめの一文を付けない。**
下の材料を統合して、**箇条書きで10行以内**にする。材料が無い項目は黙って飛ばす（「データなし」と書かない）。

#### 材料A：カレンダーの今日の実績 — **これは Claude が自分で取りに行くこと**

Google カレンダーの MCP ツール（\`list_events\`）で **${TODAY} の予定**を取得し、**起きたこととして**並べる。
- 朝のブリーフィングと同じデータだが、朝は「これからの予定」、夜は「あったこと」として出す
- **予定が入っていたことと、実際にやったことは別**。「〜の予定が入っていました」と書き、こなしたかどうかは決めつけない
- MCP が見つからない／エラーなら**この材料は黙って飛ばす**（勝手に予定を作らない）
EOS

# ---------- 材料B：今日 Vault で動いたファイル ----------
cat <<'EOS'

#### 材料B：今日 Vault で動いたファイル
EOS

VAULT_TOUCHED=$(cd "$ROOT" && find . -name "*.md" -newermt "$TODAY 00:00" \
  -not -path "./raw/*" \
  -not -path "./.git/*" -not -path "./node_modules/*" -not -path "./inbox/done/*" \
  -not -name "$TODAY.md" 2>/dev/null | sed 's|^\./||' | sort)
VAULT_N=$(printf '%s' "$VAULT_TOUCHED" | grep -c .)

if [ "$VAULT_N" -gt 0 ]; then
  printf '%s\n' "$VAULT_TOUCHED" | sed 's/^/- /'
  cat <<'EOS'

  ⚠️ これは更新日時で拾っただけで、**オーナーがやったのか Claude が書いたのか、
  Google Drive の同期が触っただけなのかは区別できない**。
  「〜を作りました／直しました」と断定せず、**今日の会話で実際にやったと分かっているものだけ**を一覧に入れる。
  分からないファイルは落としてよい（全部並べない）。
EOS
else
  echo "- （今日動いた .md は無い）"
fi

cat <<EOS

### 2. 日記 — **本文はオーナーが書く。Claude は書かない**

上の一覧を見せたうえで、最後に **「今日はどうでしたか？」と一言だけ聞く。**

- オーナーが答えたら、その言葉を **膨らませずに** 文へ整えて \`daily/${TODAY}.md\` の \`## 日記\` へ書く
  - やってよいのは：話し言葉を文に直す、順番を整える、事実の補足を（オーナーが触れた範囲で）添える
  - **やってはいけないこと：感想・評価・意味づけを足す。**「充実した1日でした」「お疲れさまでした」の類を
    オーナーが言っていないのに書かない（CLAUDE.md「事実だけ。AI の評価語を書かない」）
- \`## 日記\` セクションが無ければ \`## 振り返り\` の後ろに作る
- **オーナーが答えない／「今日はいい」と言ったら、日記は書かずに終わる。**催促しない。空の見出しも作らない
- 一言が短くてもそのまま残す。**1行の日記でよい**

### 3. 今日の締め — daily/${TODAY}.md
EOS

# ---------- 1. デイリーノートの状態 ----------
if [ -f "$NOTE" ]; then
  echo "- ノートは**ある**。まず Read して、すでに書かれている内容を把握すること（同じことを二度書かない）"
  NOTE="$NOTE" python3 <<'PY'
import os, re

path = os.environ["NOTE"]
try:
    text = open(path, encoding="utf-8").read()
except Exception:
    raise SystemExit

# 見出しごとに中身が実質空か（"- " だけか）を見る
sections = re.split(r"^## ", text, flags=re.M)[1:]
empty, decisions = [], []
for sec in sections:
    title = sec.splitlines()[0].strip()
    body = [l.strip() for l in sec.splitlines()[1:] if l.strip() and l.strip() != "-"]
    if not body:
        empty.append(title)
    if title.startswith("決めたこと"):
        decisions = [l for l in body if l.startswith("-")]

if empty:
    print("- **まだ空のセクション**：" + " / ".join(empty) + " → 今日の会話で埋まるものがあれば拾う")
if decisions:
    print("- 今日すでに記録済みの DECISION：{} 件（重複して足さない）".format(len(decisions)))
PY
else
  cat <<EOS
- ノートは**まだ無い**。\`templates/daily.md\` をベースに \`daily/${TODAY}.md\` を作る（\`{{YYYY-MM-DD}}\` を ${TODAY} に置換）
EOS
fi

cat <<'EOS'

やること：
- 今日の会話でわかったこと・決めたことのうち、**まだノートに無いものだけ**を拾って追記案を作る
- 振り分け先は 今日やること / メモ・気づき / 決めたこと / 振り返り
  （**`## 日記` はここでは埋めない。**オーナーの一言をもらってから上の「2. 日記」の手順で書く）
- 決定事項は必ず `DECISION:` で始める（週次レビューで拾うため）
- **書くことが無ければ「今日は追記なし」と1行で言う。**無理に埋めない・盛らない
- 追記案を提示 → 承認 → Edit / Write で反映

EOS

# ---------- 2. 取りこぼしチェック ----------
FOUND=""

INBOX_LIST=$(find "$ROOT/inbox" -maxdepth 1 -type f ! -name 'index.md' ! -name '.*' 2>/dev/null | sort)
INBOX_N=$(printf '%s' "$INBOX_LIST" | grep -c .)

REPORTS_TODAY=$(find "$ROOT/reports" -maxdepth 1 -name '*.md' -newermt "$TODAY 00:00" 2>/dev/null | sort)
REPORTS_N=$(printf '%s' "$REPORTS_TODAY" | grep -c .)

OVERDUE=$(ROOT="$ROOT" TODAY="$TODAY" python3 <<'PY'
import os, re, datetime

today = datetime.date.fromisoformat(os.environ["TODAY"])
path = os.path.join(os.environ["ROOT"], "Home.md")
out = []
try:
    inside = False
    for line in open(path, encoding="utf-8"):
        if line.startswith("## 進行中"):
            inside = True
            continue
        if inside and line.startswith("## "):
            break
        if not inside or not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 3 or cells[0].startswith("---") or cells[0].startswith("期限"):
            continue
        when, item, state = cells[0], cells[1], cells[2]
        if "待機" in state:      # オーナー対応中。催促しない（CLAUDE.md）
            continue
        m = re.search(r"(\d{1,2})/(\d{1,2})", when)
        if not m:
            continue             # 「2028年度中」「到着待ち」など日付でないものは判定しない
        mo, da = int(m.group(1)), int(m.group(2))
        try:
            d = datetime.date(today.year, mo, da)
        except ValueError:
            continue
        # 半年以上ずれていたら年跨ぎとみなす（12月の行を8月に見たときなど）
        if (d - today).days < -180:
            d = datetime.date(today.year + 1, mo, da)
        if d < today:
            name = re.sub(r"\s*→.*$", "", item).strip()
            # 「解禁」の行は期限切れではなく「もう動ける」の意味なので言い方を変える
            verb = "解禁済み（もう動ける）" if "解禁" in when else "を過ぎている"
            out.append("  - {}/{} {}：{}".format(mo, da, verb, name))
except Exception:
    pass
print("\n".join(out))
PY
)

if [ "$INBOX_N" -gt 0 ] || [ "$REPORTS_N" -gt 0 ] || [ -n "$OVERDUE" ]; then
  echo "### 4. 取りこぼし"
  FOUND="yes"

  if [ "$INBOX_N" -gt 0 ]; then
    echo "- 📥 inbox の未処理メモ ${INBOX_N} 件 → 明日 \`/inbox\` で処理（今夜やらなくてよい）"
  fi

  if [ "$REPORTS_N" -gt 0 ]; then
    echo "- 📝 今日書いた reports："
    printf '%s\n' "$REPORTS_TODAY" | while IFS= read -r f; do
      [ -n "$f" ] && echo "    - reports/$(basename "$f")"
    done
    echo "  → **結論が wiki の正本ページに入っているか**だけ確認する（reports は経緯・出典を残す場所）。"
    echo "    入っていなさそうなら「\`/sync\` で wiki に反映しますか？」と**1行だけ**聞く。夜のうちに勝手に sync しない"
  fi

  if [ -n "$OVERDUE" ]; then
    echo "- ⏰ Home.md「進行中」で期限を過ぎている行："
    printf '%s\n' "$OVERDUE"
    echo "  → 済んでいるなら表から消す、まだなら期限を引き直す。**どちらかをオーナーに聞く**（勝手に消さない・勝手に延ばさない）"
  fi
  echo ""
fi

if [ -z "$FOUND" ]; then
  echo "### 4. 取りこぼし"
  echo "- なし → 「取りこぼしはありません」と1行だけ言う"
  echo ""
fi

cat <<'EOS'
### 5. 締め
- 明日の予定・天気は朝のブリーフィングで出す。**夜は出さない**（今から動けないことを増やさない）
- **最後は「今日はどうでしたか？」の一言で終える**（上の「2. 日記」）。翌朝の宿題を並べ立てない
EOS
