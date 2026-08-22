#!/bin/bash
# セッション開始時に「1回の作業で読む量」を測り、重くなっているものだけ知らせる。
# 標準出力は Claude のコンテキストに追加される。正常時は何も出さない。
#
# なぜ「件数」ではなく「バイト数」か（変更）：
#   旧 rules-count.sh は "## YYYY-MM-DD" の件数を数えていたが、
#   統合すると件数は減るのに本文は1バイトも減らないため、実際のコストと一致していなかった。
#   実測例: corrections 10件=11.9KB / mistakes 12件=23.3KB。
#   同じ「上限内」でも読む量は倍違う。読むのはファイル単位なので、ファイル単位のバイト数で測る。
# 設計の記録 → docs/03_日々の回し方.md

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"

RULE_LIMIT=5000    # rules/ は「該当1ファイルだけ読む」運用なので、1ファイルの上限
WIKI_INDEX=20000   # これを超えて節索引が無いページは、質問のたびに全文が読まれる
WIKI_SPLIT=30000   # 節索引があっても、1ページとして大きすぎる
CLAUDE_LIMIT=11000 # CLAUDE.md は毎セッション全文が読まれる唯一のファイル。ここだけは常時コスト
                   # 毎セッション読まれる唯一のファイルなので、ここだけは常時コスト。

OUT=""

# --- CLAUDE.md: 毎セッション読まれるので、ここだけは常時コスト ---
CSIZE=$(wc -c < "$ROOT/CLAUDE.md" | tr -d ' ')
[ "$CSIZE" -gt "$CLAUDE_LIMIT" ] && OUT="${OUT}⚖️ **CLAUDE.md が ${CSIZE} バイト**（上限 ${CLAUDE_LIMIT}）。毎セッション全文が読まれるので、増えるほど常時ルールの密度が下がります。\n→ 卒業ルール（rules/corrections/vault.md）: 頻度の低いルールは本文をスキルへ移し、CLAUDE.md には移設先を指す1行だけ残す\n\n"

# --- rules/: 1ファイルが重すぎないか ---
RULES=""
for f in "$ROOT"/rules/corrections/*.md "$ROOT"/rules/mistakes/*.md; do
  [ -f "$f" ] || continue
  size=$(wc -c < "$f" | tr -d ' ')
  [ "$size" -gt "$RULE_LIMIT" ] || continue
  RULES="${RULES}  - ${f#"$ROOT"/} — $((size / 1000))KB\n"
done
[ -n "$RULES" ] && OUT="${OUT}📋 **rules/ に重いファイルがあります**（1ファイル ${RULE_LIMIT} バイトが上限。作業のたびに全文を読むため）\n${RULES}\n→ 卒業ルール（rules/corrections.md）: ①ドメイン限定なら wiki か <app>/CLAUDE.md へ移設 ②一般化できたら CLAUDE.md へ1行で昇格 ③同じ原因のものを統合\n**統合しても本文が減らなければ、この警告は消えません。**\n\n"

# --- wiki/: 節索引の無い大きいページ／大きすぎるページ ---
NOINDEX=""
NOPROC=""
TOOBIG=""
for f in "$ROOT"/wiki/*.md; do
  [ -f "$f" ] || continue
  size=$(wc -c < "$f" | tr -d ' ')
  # 2つは独立に判定する（修正）。以前は elif だったため、
  # 30KB を超えたページは節索引の有無が一切チェックされず、
  # いちばん重い finance_and_cards（35KB・節索引なし）が見逃されていた。
  if [ "$size" -gt "$WIKI_SPLIT" ]; then
    TOOBIG="${TOOBIG}  - $(basename "$f") — $((size / 1000))KB\n"
  fi
  # 節索引は「冒頭にある見出し」。本文で節索引の話をしているだけのページ
  # （lint-issues_log など）を索引ありと誤判定していたため、
  # 語の出現ではなく "^## 節索引" の見出しで判定する（修正）。
  if [ "$size" -gt "$WIKI_INDEX" ]; then
    if ! head -40 "$f" | grep -q "^## 節索引"; then
      NOINDEX="${NOINDEX}  - $(basename "$f") — $((size / 1000))KB\n"
    # 節索引があっても、行番号の取り方が書いていなければ読む量は減らない
    # （節名だけでは Read は全文を返す。CLAUDE.md から各ページへ移設）。
    elif ! head -40 "$f" | grep -q 'grep -n'; then
      NOPROC="${NOPROC}  - $(basename "$f") — $((size / 1000))KB\n"
    fi
  fi
done
[ -n "$NOPROC" ] && OUT="${OUT}📖 **節索引に「行番号の取り方」が無い wiki ページ**（節名だけでは Read は全文を返します）\n${NOPROC}→ 節索引の冒頭に「grep -n で節の開始行と次の見出しの行を取り、Read の offset／limit に渡す」の2手順を1行で書く\n"
[ -n "$NOINDEX" ] && OUT="${OUT}📖 **節索引の無い大きい wiki ページ**（関連する質問のたびに全文が読まれます）\n${NOINDEX}\n"
[ -n "$TOOBIG" ] && OUT="${OUT}📖 **1ページとして大きすぎる wiki ページ**（節索引があっても、節そのものが大きくなっている可能性）\n${TOOBIG}→ 節の入れ子を見直すか、テーマで2ページに分ける\n"

[ -z "$OUT" ] && exit 0

printf "%b" "$OUT"
echo ""
echo "**これは今すぐやる作業ではない。** オーナーが別の用件を話しているなら、その用件を優先すること。"
echo "該当ファイルに書き足す場面になったときに初めて、書き足す前に上を実行する。最初の返事で報告する必要もない。"
