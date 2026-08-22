# PubMed の使い方 — 論文検索を Claude Code から回す

医療者にとって、この Vault のいちばんの実用機能です。
**設定ゼロでも動く経路が入っている**ので、まず使ってみてください。

---

## いちばん短い使い方

Claude Code でこう打つだけです。

```
/paper 変形性膝関節症に運動療法は有効か
```

すると AI が、

1. 質問を **PICO**（対象・介入・比較・アウトカム）に分解し、
2. **MeSH 用語**（PubMed の統制語彙）を使った検索式を組み立て、
3. 実際に PubMed を検索して、
4. **PMID・DOI・出版年・雑誌・研究デザイン・全文の有無**を表にして返し、
5. `reports/YYYY-MM-DD-調査-主題.md` に **検索式ごと**保存します。

見本が入っています → [`reports/2026-01-15-調査-変形性膝関節症に対する運動療法のエビデンス.md`](../reports/2026-01-15-調査-変形性膝関節症に対する運動療法のエビデンス.md)

---

## 2つの経路（片方だけでも十分使えます）

### 経路①：同梱スクリプト（設定不要・必ず動く）

`.claude/skills/paper-search/pubmed.sh` が入っています。
これは **NCBI E-utilities**（PubMed の公式 API。無料・登録不要）を叩くだけのスクリプトです。

自分で直接打つこともできます。

```bash
bash .claude/skills/paper-search/pubmed.sh '"osteoarthritis, knee"[MeSH Terms] AND exercise therapy[MeSH Terms] AND randomized controlled trial[pt]' 20
```

返ってくるもの：

```
| PMID | 年 | 雑誌 | タイトル | DOI | 全文(PMC) | 種別 |
```

**この経路だけで、検索・書誌情報の確定・全文の有無の確認まで完結します。**

### 経路②：`bio-research` プラグイン（あるとさらに便利）

Claude Code には「プラグイン」という拡張の仕組みがあり、**`bio-research`** を有効にすると、
論文検索・全文取得・臨床試験の検索などのツールが AI から直接使えるようになります。

**有効になっているか確かめる：**

```
論文検索に使えるツールが今この環境にあるか、一覧して教えて
```

`search_articles` や `get_full_text_article` といったツール名が挙がれば、有効になっています。

**入れ方：** Claude Code で `/plugin` と打つとプラグインの一覧が開くので、`bio-research` を探して有効化します。

> 一覧に見当たらない場合、その環境ではまだ配布されていない可能性があります。
> **その場合は経路①だけで進めて構いません。** できることはほとんど変わりません。
> （経路②の利点は、AI がツールを直接呼べるぶん、対話の中で自然に何度も検索し直せることです）

---

## 検索式の組み方（ここが一番効きます）

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
| `[pt]` | 論文の種類。`randomized controlled trial[pt]` `meta-analysis[pt]` `systematic review[pt]` `review[pt]` |
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

## 全文を読む

- **PMC 番号がある論文は無料で全文が読めます**（スクリプトの「全文(PMC)」列）
- URL は `https://www.ncbi.nlm.nih.gov/pmc/articles/PMC<番号>/`
- AI に「PMC12614259 の全文を読んで、対象と介入と主要アウトカムを表にして」と頼めます
- **論文を3本以上まとめて読むときは `/nlm`**（NotebookLM への外注）を検討してください。全文を全部 AI に読ませるとすぐ容量が尽きます

---

## 引き際に気をつけること（実際に間違えたところ）

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
> ### ③ PubMed のページを直接読ませても取れない
> PubMed の Web ページを AI に読ませると `Cookies must be enabled` が返ります。
> `doi.org` も出版社サイトで弾かれることが多い。**E-utilities が唯一まっすぐ通る経路**です。
>
> 1本だけ確認したいとき：
> ```bash
> curl -s "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=pubmed&id=25414475&retmode=json" | python3 -m json.tool
> ```

---

## やってはいけないこと

- **患者情報を検索語やレポートに書かない**（氏名・ID・生年月日・施設名）
- **抄録だけで断定しない。** 抄録に無い数値を書かせない
- **孫引きしない。** 他の論文が引用していた内容は、その原著の PMID を自分で確認する
- **用量・添付文書・保険適用は PubMed ではなく公式情報**（PMDA・厚労省・学会ガイドライン）を当たる

---

## 調べたあと（ここまでやって完成）

1. 結論は **`wiki/` の疾患ページ**（例：`wiki/clinical_knee_oa.md`）に統合する
2. `reports/` には**経緯・検索式・出典**を残す
3. 次に同じことを聞かれたら、AI は PubMed ではなく **Vault から答えます**

これをやらないと、毎回ゼロから調べ直すことになります。
