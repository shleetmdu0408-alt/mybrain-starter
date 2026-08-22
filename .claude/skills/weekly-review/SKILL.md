---
name: weekly-review
description: Vault の週次レビュー。過去7日のデイリーノートを振り返り、重要情報を wiki/Memory に反映し、lint チェックと翌週の Next Action 提案を行い reports/ にレポートを残す。「週次レビュー」「weekly review」「今週のまとめ」「今週を振り返って」で発動。
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, WebSearch
---

# weekly-review — 週次レビュースキル

> 振り返り → 反映 → lint → Next Action → レポート、を一気に行う。
> **Step 1〜7 を最初にタスク化**し、順に進める（途中で脱落しやすいため）。

## Step 1: デイリーノートの振り返り

`daily/` から過去7日分を読み、以下を抽出する。

- **決定事項**（`DECISION:` で始まる行を最優先。`grep -rn "DECISION:" daily/` で拾う）
- **新しい事実**（前提が変わったもの）
- **未解決のまま残っている問い**
- **進捗があった項目**

## Step 2: wiki / Memory.md への反映

`vault-sync` スキルの Step 2〜6 の手順に従って反映する。
前提・進行中・判断基準に変化があれば `Memory.md` も更新する。

## Step 3: 今週の成果物の確認

> [!warning] `-mtime`（更新日時）で判定しない
> Vault をクラウドドライブ（Google ドライブ・iCloud・Dropbox）に置いていると、
> **同期のたびにファイルの更新日時が書き換わる**。`find -mtime -7` は数ヶ月前のファイルまで
> 「今週更新」として拾ってしまい、使えない。
> **ファイル名の日付**（`reports/` は `YYYY-MM-DD` 始まり）と **frontmatter の `date:`** で判定する。

```bash
# 過去7日の日付を作り、ファイル名の日付と突き合わせる（macOS の date）
DATES=$(for i in $(seq 0 6); do date -v-${i}d +%F; done)
ls reports 2>/dev/null | grep -E "^($(echo $DATES | tr ' ' '|'))"
```

```bash
# wiki は frontmatter の date: で見る（ファイル名に日付が無いため）
grep -l -E "^date: ($(for i in $(seq 0 6); do date -v-${i}d +%F; done | tr '\n' '|' | sed 's/|$//'))" wiki/*.md
```

**`wiki/` の `date:` は更新のたびに手で書き換える運用**なので、直し忘れると漏れる。
`grep` の結果が体感より少ないときは、デイリーノートの記述と突き合わせて補う。

## Step 4: lint チェック（`rules/lint.md` 準拠）

> [!warning] `wiki/` 全体を読まない
> wiki が育つと全読みは1セッションに収まらなくなる。**前回の lint からの差分**を読む方式にしてある。
> 全読みには戻さないこと。

`rules/lint.md` の手順をそのまま実行する。要点だけ再掲：

1. **機械点検** — `./.claude/hooks/lint-scan.sh` を1回走らせ、出力を読む
2. **重複・新規候補** — `wiki/index.md` と全ページの**冒頭12行だけ**を読む
3. **古い情報** — 1 が出した差分を読む。**消えた行（`-`）を特に見る**
4. **矛盾** — 差分の数値・固有名詞を `wiki/` に `grep` して、古い側が残っていないか見る

問題は `wiki/lint-issues.md` に記録する。**勝手に直さず提案のみ**。優先度の高い3件をオーナーに提示する。

**最後に必ず基準を更新する**（忘れると次回の差分が2週間分になる）:

```bash
./.claude/hooks/lint-scan.sh --snapshot
```

## Step 5: 翌週の Next Action 提案（3〜5件、優先度順）

判断材料：

- `Home.md` の「進行中」と `wiki/open_questions.md`
- 期限が近いイベント（`wiki/life_events.md`）
- 止まっている TODO — `grep -rn "^- \[ \]" wiki/ reports/` で走査

**状態が `待機` のものは出さない**（オーナーが対応中。催促しない）。

## Step 6: レポート作成

`reports/YYYY-MM-DD-週次レビュー.md` に残す。

- 今週のハイライト
- 反映した情報の一覧
- lint の結果（問題があれば）
- 来週の Next Action（優先度順）
- 根拠にした `wiki/` ページへの `[[リンク]]`

## Step 7: Home.md の「進行中」を最新化

完了項目の削除、新規項目の追加。**完了したかどうかを推測で決めない**。分からない行はオーナーに聞く。

## 注意

- 制度・価格・ガイドラインに触れる場合は、**必ず WebSearch でファクトチェック**してから書く
- 医学的な主張を書くなら `/paper` で一次文献を引き、PMID / DOI を併記する
- 週次レポートは `reports/`（.md）に置く。清書版が必要なときだけ `deliverable` スキルで PDF 等にする
