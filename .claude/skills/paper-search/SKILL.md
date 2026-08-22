---
name: paper-search
description: 医学・臨床・生命科学の疑問を、記憶や一般 Web 検索ではなく一次文献（PubMed）から答える。検索式を組み、PMID と DOI を確定し、結果を reports/ に検索式つきで残す。「〇〇のエビデンスは？」「最新の論文を探して」「この治療の効果は？」「論文まとめて」「PubMed で」で発動。臨床の疑問・研究テーマの文献調査・抄読会の準備のいずれにも使う。
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch
---

# paper-search — 一次文献から答える

> **医学的な質問に、記憶と一般 Web 検索だけで答えない。** 必ず一次文献に当たり、**PMID と DOI を併記**する。
> これは「正確さのため」であると同時に、**後から自分で検証できる形にするため**。

## Step 0: このスキルを使うか判断する

| 質問 | 使う？ |
|---|---|
| 疾患の治療効果・診断精度・予後 | **使う** |
| ガイドラインの推奨内容 | ガイドライン本体を当たる（`WebSearch`）＋ 根拠論文を `/paper` で確認 |
| 用量・添付文書・保険適用 | **使わない**（公式情報を当たる。論文より添付文書・厚労省が正本） |
| 研究テーマの文献調査・抄読会 | **使う** |
| 「〇〇という言葉の意味」 | 使わない |

## Step 1: 検索の経路を決める（最初の1回だけ確認する）

**優先順位①：MCP ツール**（`bio-research` プラグインが有効なら使える）
- `search_articles` — 論文検索
- `get_article_metadata` — 書誌情報
- `convert_article_ids` → `get_full_text_article` — PMC にある論文の全文
- `find_related_articles` — 関連論文

ツール一覧に見当たらなければ、プラグインが未導入。**そのときは②へ進む**（`docs/02_PubMedの使い方.md` に導入手順）。

**優先順位②：同梱スクリプト**（設定不要。ネットさえ繋がれば必ず動く）

```bash
bash .claude/skills/paper-search/pubmed.sh '<検索式>' 20
```

NCBI E-utilities（PubMed の公式 API）を叩き、**PMID / 年 / 雑誌 / タイトル / DOI / PMC番号 / 研究デザイン**を表で返す。
`①` が使える環境でも、**引用の最終確認はこのスクリプトで行う**（理由は Step 4）。

## Step 2: 検索式を組む（ここが本体）

**いきなり自然文で検索しない。** PICO に分解してから組む。

1. **P**（対象）・**I**（介入）・**C**（比較）・**O**（アウトカム）を1行ずつ書き出し、オーナーに見せる
2. 各要素を **MeSH 用語**（PubMed の統制語彙）と自由語の OR で組む
3. 要素どうしを AND で繋ぐ
4. 研究デザインで絞る：`randomized controlled trial[pt]` / `meta-analysis[pt]` / `systematic review[pt]`
5. 必要なら期間・言語：`AND 2020:2026[dp]` / `AND (english[la] OR japanese[la])`

```
"osteoarthritis, knee"[MeSH Terms]
  AND ("exercise therapy"[MeSH Terms] OR "resistance training"[MeSH Terms])
  AND (randomized controlled trial[pt] OR meta-analysis[pt])
  AND 2020:2026[dp]
```

- **ヒット数を見て調整する。** 0〜5件なら広げすぎ／狭すぎを疑い、500件超なら要素を足す。**目標は20〜80件**
- スクリプトが出す「PubMed 変換後」を必ず読む。**意図と違う語に展開されていたら組み直す**（例：略語が別の意味に展開される）
- **検索式は必ず記録する。** これが無い文献調査は再現できない

## Step 3: 絞り込む

1. 表のタイトル・雑誌・研究デザインで**明らかに外れるものを落とす**（理由を1行）
2. 残ったものの抄録を読む（MCP の `get_article_metadata`、または PubMed の URL を `WebFetch`）
3. **全文が要るものだけ**全文に進む。PMC 番号がある論文は無料で本文まで読める
   - MCP：`convert_article_ids` で PMCID に変換 → `get_full_text_article`
   - 無ければ `https://www.ncbi.nlm.nih.gov/pmc/articles/PMC<番号>/` を `WebFetch`
4. 資料が3件以上で全文まで読むなら、**読み込みを `/nlm` に外注することを先に提案する**（読んでから重いと気づいても遅い）

## Step 4: 引用情報を確定する（ここを飛ばさない）

> [!warning] 年を間違える罠が2つある
> ① **電子版公開日と印刷版の巻号年がずれる。** 論文検索ツールが返す `publication_date` は電子版の日付のことがあり、
>    そのまま書くと年を間違える（実例：PMID 25414475 は epub 2014-11-20 だが、正しくは Emerg Med J 32(8) **2015 Aug**）。
>    **引用に使うのは `pubdate`。** 同梱スクリプトはずれている行に `※epub` を付けて警告する。
> ② **PMID・DOI を記憶や推測で書かない。** 1桁違っても別の論文になる。必ずツールの出力からコピーする。

- **PubMed のページを `WebFetch` しても本文は取れない**（`Cookies must be enabled` が返る）。
  `doi.org` は出版社サイトへリダイレクトし、そこで 403 になることが多い。**E-utilities が唯一まっすぐ通る経路**
- 1本だけ確認したいときは：
  ```bash
  curl -s "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=pubmed&id=<PMID>&retmode=json" | python3 -m json.tool
  ```

## Step 5: 答えを書く

- **結論を先に。** そのうえで根拠の強さ（研究デザイン・n数・追跡期間・利益相反）を1行で添える
- **抄録だけで断定しない。** 抄録に無い数値を書かない。読んでいない全文の中身を推測で書かない
- **孫引きをしない。** 他の論文やレビューが引用していた内容は、**その原著の PMID を自分で確認する**
- 引用の形式：`著者ら. 雑誌 年;巻(号):頁. PMID: xxxxxxx / DOI: 10.xxxx/xxxxx`
- **見つからなかったことも結果**。「PubMed で〇件、条件を満たす RCT は無かった」と書く（無いものを有ることにしない）

## Step 6: reports/ に残す

`reports/YYYY-MM-DD-調査-主題.md` に、`rules/naming.md` の型で保存する。**必ず入れるもの：**

```markdown
## 検索の記録
- 検索日：2026-01-15
- データベース：PubMed（E-utilities）
- 検索式：`（実際に使った式をそのまま）`
- ヒット数：695件 → タイトル/抄録で20件 → 全文で6件
- 除外理由：動物実験（12件）、対象年齢が不一致（3件）…
```

- **結論そのものは `wiki/` の正本ページへ統合**する。`reports/` に残すのは経緯・出典・判断の根拠
- 臨床知識のページなら `wiki/clinical_*.md`、研究テーマなら `wiki/research_*.md`

## やらないこと

- 記憶で論文を挙げる（**存在しない論文を作ってしまう最大の原因**）
- PMID / DOI / 著者名 / 年 の推測
- 患者情報を検索語やレポートに書く
- 抄録の数値を「だいたいこのくらい」と丸めて書く
