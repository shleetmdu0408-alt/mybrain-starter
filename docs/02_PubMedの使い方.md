# PubMed の使い方 — 論文検索を Claude Code から回す

医療者にとって、この Vault のいちばんの実用機能です。
**まず「1. プラグインを入れる」をやってください。** ここを入れるかどうかで使い勝手がかなり変わります。

---

## 1. プラグインを入れる（最初に1回だけ）

Claude Code の「プラグイン」は、AI に外部サービスを触らせる部品の詰め合わせです。
**このテンプレートは次の2つが入っている前提で作ってあります。**

| プラグイン | 何が入るか | 無いとどうなるか |
|---|---|---|
| **`bio-research`** | PubMed 検索・全文取得・臨床試験検索・論文横断検索 | `/paper` は同梱スクリプトで動くが、**対話の中で AI が自分で検索し直せなくなる** |
| **`anthropic-skills`** | PDF / Word / Excel / PowerPoint を作る機能 | **`/deliver` が動かない**（成果物を作れない） |

### 入れ方

Claude Code を開いて、こう打ちます。

```
/plugin
```

プラグインの一覧が開くので、**`bio-research`** と **`anthropic-skills`** を探して有効化します。

> `/plugin` で一覧が出てこない、または目的のプラグインが見つからない場合は、
> AI に直接こう聞いてください。**AI が自分の環境を調べて案内してくれます。**
>
> ```
> bio-research と anthropic-skills のプラグインを使いたい。
> いま入っているか確認して、入っていなければ入れ方を教えて
> ```

### 入ったか確かめる

```
論文検索に使えるツールを一覧して。search_articles は使える？
```

`search_articles` `get_full_text_article` などのツール名が挙がれば成功です。

---

## 2. `bio-research` で使えるようになるもの

**コマンドは要りません。日本語で頼めば AI が勝手に使います。**

| ツール | できること | 頼み方の例 |
|---|---|---|
| `search_articles` | **PubMed 検索**。PubMed の検索構文（`[MeSH Terms]` `[pt]` など）も自然文も通る | 「膝OAの運動療法の RCT を2020年以降で探して」 |
| `get_article_metadata` | 書誌情報（著者・雑誌・巻号・抄録・各種 ID） | 「PMID 33591346 の詳細を出して」 |
| `get_full_text_article` | **PMC にある論文の全文**を取得（約600万本） | 「PMC7887656 の全文を読んで方法を要約して」 |
| `convert_article_ids` | PMID ⇄ PMCID ⇄ DOI の相互変換 | 「この PMID の全文があるか調べて」 |
| `find_related_articles` | 関連論文をたぐる | 「この論文に近い研究をあと5本」 |
| `lookup_article_by_citation` | 引用情報から論文を特定する | 「"Lancet 2023;401:1..." これ何の論文？」 |
| **臨床試験の検索** | ClinicalTrials.gov の進行中／終了した試験 | 「この薬剤の進行中の第III相試験は？」 |
| **論文横断検索** | Semantic Scholar・PubMed・Scopus・arXiv を横断（2億本超）。**被引用数と雑誌の格付け付き**で返る | 「〇〇にエビデンスはある？」 |

> [!NOTE]
> **PubMed 系と横断検索の使い分け**
> - **系統的に調べる／再現性が要る**（抄録の準備・論文の背景）→ **PubMed**。検索式が残せる
> - **「そもそもエビデンスあるの？」を素早く見る** → **横断検索**。被引用数と質のスコアで当たりが付く
> - 横断検索は**プレプリントも含む**ので、診療の判断に使うなら「査読済みのみ」と指定する

> [!IMPORTANT]
> **引用の義務があります。** PubMed のツールは「使ったら PubMed を出典として示し、DOI を併記すること」が利用条件です。
> 横断検索のツールは「本文中に番号付きで引用し、末尾に文献リストを出すこと」が条件です。
> このテンプレートのルール（`rules/corrections/medical.md`）でも **PMID と DOI の併記を必須**にしてあります。

---

## 3. いちばん短い使い方

```
/paper 変形性膝関節症に運動療法は有効か
```

AI が、

1. 質問を **PICO**（対象・介入・比較・アウトカム）に分解し、
2. **MeSH 用語**を使った検索式を組み立て、
3. 実際に PubMed を検索して、
4. **PMID・DOI・出版年・雑誌・研究デザイン・全文の有無**を表にして返し、
5. `reports/YYYY-MM-DD-調査-主題.md` に **検索式ごと**保存します。

見本 → [`reports/2026-01-15-調査-変形性膝関節症に対する運動療法のエビデンス.md`](../reports/2026-01-15-調査-変形性膝関節症に対する運動療法のエビデンス.md)

---

## 4. プラグインが入らなかったときの保険（同梱スクリプト）

`.claude/skills/paper-search/pubmed.sh` を同梱してあります。
**NCBI E-utilities**（PubMed の公式 API。無料・登録不要・鍵不要）を叩くだけのスクリプトなので、
**プラグインが1つも無くても論文検索はできます。**

```bash
bash .claude/skills/paper-search/pubmed.sh '"osteoarthritis, knee"[MeSH Terms] AND exercise therapy[MeSH Terms] AND randomized controlled trial[pt]' 20
```

返ってくるもの：

```
| PMID | 年 | 雑誌 | タイトル | DOI | 全文(PMC) | 種別 |
```

**プラグインが入っている場合も、引用の最終確認はこのスクリプトでやってください**（理由は下の「引き際に気をつけること ①」）。

---

## 5. 検索式の組み方（ここが一番効きます）

**自然文をそのまま投げない。** ヒット数が数万になるか、逆に0になります。

### 型

```
（対象の MeSH）AND（介入の MeSH）AND（研究デザイン）AND（期間）
```

### 実例

```
"osteoarthritis, knee"[MeSH Terms]
  AND ("exercise therapy"[MeSH Terms] OR "resistance training"[MeSH Terms])
  AND (randomized controlled trial[pt] OR meta-analysis[pt])
  AND 2020:2026[dp]
```

### 覚えておくと便利なタグ

| 書き方 | 意味 |
|---|---|
| `[MeSH Terms]` | 統制語彙で検索（表記ゆれを吸収してくれる） |
| `[pt]` | 論文の種類。`randomized controlled trial[pt]` `meta-analysis[pt]` `systematic review[pt]` |
| `[dp]` | 出版年。`2020:2026[dp]` |
| `[la]` | 言語。`english[la]` |
| `[ti]` `[tiab]` | タイトルのみ／タイトル＋抄録 |
| `[au]` | 著者名。`Smith J[au]` |

**MeSH 用語が分からないときは AI に聞いてください。**「膝OA の MeSH 用語は？」で出てきます。

### ヒット数の目安

| ヒット数 | どうするか |
|---|---|
| 0〜5件 | 絞りすぎ。MeSH を自由語の OR に広げる／期間を延ばす |
| **20〜80件** | ちょうどよい。タイトルで絞れる |
| 500件超 | 要素を足す（研究デザイン・期間・アウトカム） |

---

## 6. 全文を読む

- **PMC 番号がある論文は無料で全文が読めます**（スクリプトの「全文(PMC)」列）
- プラグインがあれば `get_full_text_article` で直接取れます
- 無ければ `https://www.ncbi.nlm.nih.gov/pmc/articles/PMC<番号>/` を読ませます
- **論文を3本以上まとめて読むときは `/nlm`**（NotebookLM への外注）を検討してください。全文を全部 AI に読ませるとすぐ容量が尽きます

---

## 7. 引き際に気をつけること（実際に間違えたところ）

> [!WARNING]
> ### ① 出版年を間違える
> 検索ツールが返す日付は **電子版の公開日** のことがあり、印刷版の巻号年とずれます。
> 例：`epub 2022年12月` だが、正しくは `Ir J Med Sci 2023 Oct`。
> **引用に使うのは `pubdate`。** 同梱スクリプトは、ずれている行に `※epub` を付けて警告します。
>
> ### ② PMID・DOI を推測で書かせない
> 1桁違えば別の論文です。**必ずツールの出力からコピーさせてください。**
> AI が記憶で論文を挙げると、**実在しない論文を作ってしまう**ことがあります（この Vault のルールで禁止してあります）。
>
> ### ③ PubMed の Web ページを直接読ませても取れない
> AI に読ませると `Cookies must be enabled` が返ります。`doi.org` も出版社サイトで弾かれることが多い。
> **E-utilities（＝プラグインと同梱スクリプトが使っている経路）が唯一まっすぐ通る経路**です。
>
> 1本だけ確認したいとき：
> ```bash
> curl -s "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=pubmed&id=25414475&retmode=json" | python3 -m json.tool
> ```

---

## 8. やってはいけないこと

- **患者情報を検索語やレポートに書かない**（氏名・ID・生年月日・施設名）
- **抄録だけで断定しない。** 抄録に無い数値を書かせない
- **孫引きしない。** 他の論文が引用していた内容は、その原著の PMID を自分で確認する
- **用量・添付文書・保険適用は PubMed ではなく公式情報**（PMDA・厚労省・学会ガイドライン）を当たる

---

## 9. 調べたあと（ここまでやって完成）

1. 結論は **`wiki/` の疾患ページ**（例：`wiki/clinical_knee_oa.md`）に統合する
2. `reports/` には**経緯・検索式・出典**を残す
3. 次に同じことを聞かれたら、AI は PubMed ではなく **Vault から答えます**

これをやらないと、毎回ゼロから調べ直すことになります。
