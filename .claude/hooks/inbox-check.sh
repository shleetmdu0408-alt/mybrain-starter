#!/bin/bash
# セッション開始時に inbox/ の未処理メモ（スマホから届いたもの）を知らせる。
# 標準出力は Claude のコンテキストに追加される。何も出さなければ何も起きない。

DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}/inbox"
[ -d "$DIR" ] || exit 0

FILES=$(find "$DIR" -maxdepth 1 -type f ! -name 'index.md' ! -name '.*' 2>/dev/null | sort)
COUNT=$(printf '%s' "$FILES" | grep -c . )
[ "$COUNT" -eq 0 ] && exit 0

echo "📥 スマホから届いた未処理のメモが inbox/ に ${COUNT} 件あります:"
printf '%s\n' "$FILES" | while IFS= read -r f; do
  [ -n "$f" ] && echo "  - inbox/$(basename "$f")"
done
echo ""
echo "→ 最初の応答で、この件数とファイル名をオーナーに伝えること。処理するなら inbox-intake スキル（/inbox）を使う。"
echo "  オーナーが別の用件を話している場合は、その用件を優先し、末尾に1行だけ添えること。"
