#!/bin/bash
# lint-scan.sh — 週次 lint の「機械点検」パート（rules/lint.md 第1段）
#
# フックではない。`/weekly` の Step 4 が最初に1回だけ走らせる。
#
# なぜこれがあるか（決定）:
#   「wiki/ 全体を読む」方式は、wiki が数百 KB になると
#   1セッションに収まらなくなる。実際、過去の指摘の過半は「読まなくても機械で出せるもの」
#   （リンク切れ・孤立・frontmatter の語彙崩れ・見出しの重複・index の取りこぼし）なので、
#   そこはスクリプトに任せ、Claude が本文を読むのは「前回からの差分」だけにしてある。
#   設計の記録 → docs/03_日々の回し方.md
#
# 出力は数十行。ここに出たものが lint の「未対応」候補になる。
# ただし **出たものが全部おかしいわけではない**（孤立・古い date は一覧を出すだけ）。
# 判断は Claude とオーナーが行い、勝手に直さない。

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$ROOT" || exit 1

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

STALE_DAYS=90     # これより古い date: の wiki ページを「読み直す候補」として一覧に出す
SNAP=".claude/state/lint-snapshot"   # 前回 lint したときの wiki の写し（差分を出すため）
#   **gzip で持つ（変更）。** 生の .md で置くと Vault 全体の grep が本体と写しの
#   両方に当たり、検索結果が倍になるうえ「古い内容」が混じって誤読の原因になっていた。
#   grep はバイナリを飛ばすので、圧縮しておけば写しは検索に出てこない（実測 520KB→約130KB）。
DIFF_MAX=500      # 差分がこの行数を超えたページは、行数だけ出して中身は出さない

# `--snapshot` で「今の wiki を次回の基準として保存」する。lint が終わってから走らせる。
# 引数なしのときは保存しない（何度でも同じ差分を見返せる）。
if [ "$1" = "--snapshot" ]; then
  mkdir -p "$SNAP"
  rm -f "$SNAP"/*.md "$SNAP"/*.md.gz 2>/dev/null
  for f in wiki/*.md wiki/moc/*.md Home.md Memory.md; do
    [ -f "$f" ] && gzip -c "$f" > "$SNAP/$(echo "$f" | tr '/' '_').gz"
  done
  echo "次回の基準として $(ls "$SNAP" | wc -l | tr -d ' ') ファイルを保存しました（$SNAP・gzip）"
  exit 0
fi

# ── 走査対象を2種類つくる ───────────────────────────────────────────────
# targets = リンクの行き先として成立するもの。**archive も raw も含める**
#           （除外は「読まない」という意味であって、「存在しない」ではない）
# sources = リンクを書いている側。設定とテンプレートは除く
#           （.claude/ と templates/ は [[wikilink]] のような**書き方の例**を含むため、
#            ここを入れると存在しないページ名が毎回大量に出て使い物にならない）

# `.claude/state/` は lint 自身が持つ wiki の写し。行き先としても数えない（実物と二重になる）
find . -name "*.md" -not -path "./.trash/*" -not -path "./.obsidian/*" \
  -not -path "./.claude/state/*" \
  | sed 's|^\./||' | sort > "$TMP/all.txt"

grep -v -e '^\.claude/' -e '^templates/' \
        -e '^raw/' \
        -e '^reports/archive/' -e '^rules/archive/' "$TMP/all.txt" > "$TMP/sources.txt"

# 行き先として成立する名前。Obsidian は末尾からの部分パスでも解決するので、
# wiki/moc/マネー.md → 「wiki/moc/マネー」「moc/マネー」「マネー」を全部登録する（.md 付きも）
while IFS= read -r f; do
  p="${f%.md}"
  while :; do
    echo "$p"; echo "$p.md"
    case "$p" in */*) p="${p#*/}" ;; *) break ;; esac
  done
done < "$TMP/all.txt" | sort -u > "$TMP/targets.txt"

# 説明文の中の「書き方の例」。実在しなくて当たり前なので数えない
cat > "$TMP/placeholders.txt" <<'EOF'
wikilink
リンク
パス
二重角括弧
ページ
ページ名
ページA
ページB
ページX
ページY
ページZ
関連する概念
対立する概念
EOF

# 全 [[リンク]] を「元ファイル<TAB>行き先」で書き出す
#   `|別名` と `#節` は落とす。表の中では `\|` とエスケープされるので `\` も一緒に落とす
while IFS= read -r f; do
  grep -o '\[\[[^]]*\]\]' "$f" 2>/dev/null \
    | sed -e 's/^\[\[//' -e 's/\]\]$//' \
          -e 's/\\*|.*$//' -e 's/#.*$//' -e 's/\\*$//' \
          -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
    | grep -v '^$' | grep -v '…' \
    | grep -vxFf "$TMP/placeholders.txt" \
    | sed "s|^|$f\t|"
done < "$TMP/sources.txt" > "$TMP/links.txt"

echo "🔍 lint 機械点検 — $(date +%Y-%m-%d)"
echo "   走査 $(wc -l < "$TMP/sources.txt" | tr -d ' ') ファイル / リンク $(wc -l < "$TMP/links.txt" | tr -d ' ') 本"
echo ""

FOUND=0

# ── 1. 行き先の無いリンク（＝「欠落」観点。作るべきページか、書き間違いか）────────
cut -f2 "$TMP/links.txt" | sort -u > "$TMP/linked.txt"
comm -23 "$TMP/linked.txt" "$TMP/targets.txt" > "$TMP/dangling.txt"
if [ -s "$TMP/dangling.txt" ]; then
  FOUND=1
  echo "## 行き先の無いリンク（欠落 or 書き間違い）"
  while IFS= read -r t; do
    n=$(awk -F'\t' -v t="$t" '$2==t{print $1}' "$TMP/links.txt" | sort -u | tr '\n' ' ')
    echo "- [[$t]] ← $n"
  done < "$TMP/dangling.txt"
  echo "  → 2ページ以上から張られているものは、専用ページを立てる候補"
  echo ""
fi

# ── 2. どこからもリンクされていない wiki ページ（孤立）─────────────────────────
ORPHAN=""
for f in wiki/*.md wiki/moc/*.md; do
  [ -f "$f" ] || continue
  base=$(basename "${f%.md}")
  rel="${f%.md}"
  awk -F'\t' -v a="$base" -v b="$rel" -v self="$f" \
    '$1!=self && ($2==a || $2==b){found=1} END{exit !found}' "$TMP/links.txt" && continue
  ORPHAN="${ORPHAN}- $f\n"
done
if [ -n "$ORPHAN" ]; then
  FOUND=1
  echo "## どこからもリンクされていない wiki ページ"
  printf "%b" "$ORPHAN"
  echo "  → index / MOC / 関連ページのどれかから張る。**張らないと決めているものは無視してよい**"
  echo ""
fi

# ── 3. frontmatter の語彙ずれ（rules/naming.md の表に無い語）──────────────────
#   naming.md の語彙表が対象にしているのは wiki / reports / daily / Home / Memory だけ。
#   outputs/blog/ の `公開済み` や projects/ の `done` はそれぞれの運用の語なので見ない。
VOCAB=""
while IFS= read -r f; do
  case "$f" in
    wiki/moc/*) ok_ty="MOC" ;;
    wiki/*)    ok_ty="概念 リファレンス 管理" ;;
    reports/*) ok_ty="調査 手順書 計画 検討 週次レビュー 会議録 提案 意思決定" ;;
    daily/*)   ok_ty="daily" ;;
    Home.md)   ok_ty="home" ;;
    Memory.md) ok_ty="memory" ;;
    *) continue ;;
  esac
  ty=$(awk 'NR<=12 && /^type:/{sub(/^type:[[:space:]]*/,""); print; exit}' "$f")
  st=$(awk 'NR<=12 && /^status:/{sub(/^status:[[:space:]]*/,""); print; exit}' "$f")
  if [ -n "$ty" ] && ! echo " $ok_ty " | grep -q " $ty "; then
    VOCAB="${VOCAB}- $f — type: $ty（許容: $ok_ty）\n"
  fi
  if [ -n "$st" ] && ! echo " 常時更新 運用中 参照用 進行中 保留 完了 " | grep -q " $st "; then
    VOCAB="${VOCAB}- $f — status: $st（許容: 常時更新 運用中 参照用 進行中 保留 完了）\n"
  fi
done < "$TMP/sources.txt"
if [ -n "$VOCAB" ]; then
  FOUND=1
  echo "## frontmatter が語彙表の外（grep で引けなくなる）"
  printf "%b" "$VOCAB"
  echo "  → rules/naming.md の表に寄せる。**表に無い語を使いたいなら、先に表へ足す**"
  echo ""
fi

# ── 4. 同じ見出しが1ページ内に2つ（[[ページ#節]] のアンカーが曖昧になる）──────
DUPH=""
while IFS= read -r f; do
  d=$(grep '^#\{1,6\} ' "$f" 2>/dev/null | sed 's/[[:space:]]*$//' | sort | uniq -d)
  [ -n "$d" ] && DUPH="${DUPH}- $f\n$(echo "$d" | sed 's/^/    /')\n"
done < "$TMP/sources.txt"
if [ -n "$DUPH" ]; then
  FOUND=1
  echo "## 同じ見出しが1ページに2つ以上"
  printf "%b" "$DUPH"
  echo "  → 節索引と [[ページ#節]] が効かなくなる。片方を言い換える"
  echo ""
fi

# ── 5. wiki/index.md の取りこぼし ──────────────────────────────────────────
awk -F'\t' '$1=="wiki/index.md"{print $2}' "$TMP/links.txt" | sort -u > "$TMP/in_index.txt"
MISS=""
for f in wiki/*.md; do
  base=$(basename "${f%.md}")
  case "$base" in index|lint-issues|open_questions) continue ;; esac
  grep -qx "$base" "$TMP/in_index.txt" || MISS="${MISS}- $base\n"
done
if [ -n "$MISS" ]; then
  FOUND=1
  echo "## wiki/index.md から辿れないページ"
  printf "%b" "$MISS"
  echo "  → index が目次として機能しなくなる。1行要約（80字以内）を足す"
  echo ""
fi

# ── 6. 長く触られていない wiki ページ（「古い情報」の候補。悪いとは限らない）────
TODAY=$(date +%s)
STALE=""
for f in wiki/*.md wiki/moc/*.md; do
  [ -f "$f" ] || continue
  d=$(awk 'NR<=12 && /^date:/{sub(/^date:[[:space:]]*/,""); print; exit}' "$f")
  [ -n "$d" ] || { STALE="${STALE}- $f — date: なし\n"; continue; }
  ts=$(date -j -f "%Y-%m-%d" "$d" +%s 2>/dev/null) || continue
  days=$(( (TODAY - ts) / 86400 ))
  [ "$days" -gt "$STALE_DAYS" ] && STALE="${STALE}- $f — $d（${days}日前）\n"
done
if [ -n "$STALE" ]; then
  FOUND=1
  echo "## ${STALE_DAYS}日以上 date: が動いていない wiki ページ"
  printf "%b" "$STALE"
  echo "  → **一覧を出すだけ。古い＝悪いではない。** 内容が変わったはずのページだけオーナーに確認する"
  echo ""
fi

# ── 7. wiki に残っている未完了 TODO ────────────────────────────────────────
#   `wiki/` だけ見る。`reports/` のチェックリストはその日の記録の写しなので、
#   両方出すと同じ項目が二重に並ぶ
#   `lint-issues.md` 自身も除く（あれは lint の出力であって TODO ではない）。
TODOS=$(grep -rn '^- \[ \]' wiki 2>/dev/null | grep -v '^wiki/lint-issues.md:')
if [ -n "$TODOS" ]; then
  FOUND=1
  echo "## 未完了の TODO"
  echo "$TODOS" | sed 's/^/- /'
  echo ""
fi

[ "$FOUND" -eq 0 ] && echo "機械点検で出たものはありません。"

# ── 8. 前回の lint からの差分（rules/lint.md 第3段の入力）────────────────────
#   `date:` で絞る方式は、活動が多い週だと 21/27 ページが該当して 375KB になり機能しなかった
#   （実測）。この Vault は git 管理外で比較対象が無いのが原因なので、
#   lint 専用に前回の写しを持ち、**ページではなく差分を読む**ようにした。
#   `date:` の上げ忘れにも影響されない（naming.md の積年の穴がここでは効かない）。
echo ""
if [ ! -d "$SNAP" ]; then
  echo "## 前回からの差分"
  echo '  基準がまだありません。**今回は差分を出せない**ので、第3段は `date:` が過去7日のページで代用する。'
  echo '  lint が終わったら `./.claude/hooks/lint-scan.sh --snapshot` を走らせて基準を作ること。'
else
  # gzip の写しを $TMP へ展開してから比較する（$TMP は起動時に作り、終了時に消える）
  SNAPR="$TMP/snap"
  mkdir -p "$SNAPR"
  for g in "$SNAP"/*.md.gz; do
    [ -f "$g" ] && gunzip -c "$g" > "$SNAPR/$(basename "$g" .gz)"
  done
  for g in "$SNAP"/*.md; do   # 旧形式（非圧縮）が残っていても読めるようにしておく
    [ -f "$g" ] && cp "$g" "$SNAPR/$(basename "$g")"
  done

  CHANGED=""
  for f in wiki/*.md wiki/moc/*.md Home.md Memory.md; do
    [ -f "$f" ] || continue
    old="$SNAPR/$(echo "$f" | tr '/' '_')"
    if [ ! -f "$old" ]; then
      CHANGED="${CHANGED}${f}\t新規\n"
    elif ! cmp -s "$f" "$old"; then
      n=$(diff "$old" "$f" | grep -c '^[<>]')
      CHANGED="${CHANGED}${f}\t${n}行\n"
    fi
  done
  echo "## 前回からの差分（第3段はここだけ読む）"
  if [ -z "$CHANGED" ]; then
    echo "  変更なし。"
  else
    printf "%b" "$CHANGED" | sed 's/^/- /'
    echo ""
    printf "%b" "$CHANGED" | while IFS=$'\t' read -r f n; do
      [ -n "$f" ] || continue
      old="$SNAPR/$(echo "$f" | tr '/' '_')"
      echo "### $f"
      if [ ! -f "$old" ]; then
        echo "（新規ページ。全文を読む）"
      else
        lines=$(diff -u "$old" "$f" | tail -n +3 | grep -c '')
        if [ "$lines" -gt "$DIFF_MAX" ]; then
          echo "（差分 ${lines} 行。多すぎるのでこのページは全文を読む）"
        else
          diff -u "$old" "$f" | tail -n +3
        fi
      fi
      echo ""
    done
  fi
  echo "→ **消えた行（-）を特に見る。** 数値・日付・固有名詞が書き換わっていたら第4段で grep する"
fi

echo ""
echo "— 機械点検ここまで。この後は rules/lint.md の第2〜4段（冒頭12行の通読 → 差分の精読 → grep 突合）へ"
echo '— lint が終わったら `./.claude/hooks/lint-scan.sh --snapshot` で次回の基準を更新する'
