---
type: ルール
status: 運用中
date: 2026-01-15
topic: 成果物デザイン（PDF）
tags: [rules, 成果物, pdf, デザイン]
---

# PDF のデザインルール

> **読むタイミング**：作る成果物が `.pdf` のときだけ。他の形式のときは読まない。
> 入口は `/deliver`（`.claude/skills/deliverable/SKILL.md`）。姉妹ルール：[[xlsx]] / [[pptx]] / [[docx]]

## 生成パイプライン（既定）

**HTML + CSS を書いて headless Chrome で PDF 化する。** 装飾を作り込めるのはこの方法だけ。

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless --disable-gpu --no-pdf-header-footer \
  --print-to-pdf="out.pdf" --virtual-time-budget=20000 "file:///絶対パス/source.html"
```

装飾が要らない箇条書き主体の資料なら `anthropic-skills:pdf` スキルでよい。

## 絶対に守る

### 1. 文字を小さくしない

| 要素 | 下限 |
|---|---|
| 本文・表のセル | **12pt** |
| 小見出し | **17pt** |
| メインタイトル | **28pt** |

> [!warning] 収まらないときは字を縮めず**ページを増やす**
> 「文字が小さくて読みにくい」の原因はたいてい A4 1枚への詰め込み。3ページになって困ることはない。

### 2. 生成後に必ず全ページを目視する

**下端の切れは繰り返し起きる。** PDF を書き出しただけで完了報告しない。

```bash
python3 -c "
from pypdf import PdfReader, PdfWriter
r = PdfReader('out.pdf')
for i, p in enumerate(r.pages):
    w = PdfWriter(); w.add_page(p); w.write(f'pg{i+1}.pdf')"
for f in pg*.pdf; do sips -s format png --resampleWidth 1000 "$f" --out "${f%.pdf}.png"; done
```

書き出した PNG を `Read` で**1枚ずつ開いて**、①要素がページ下端で切れていないか ②装飾枠と本文が重なっていないか ③意図しない改行がないか を見る。

### 3. HTML ソースを必ず残す

`outputs/deliverables/src/YYYY-MM-DD_主題.html` に保存する。次の修正はソースを直して再生成する。
（ソースを残さないと、修正依頼のたびに一から書き直しになる）

### 4. 配布物に制作の経緯を書かない

`NEW` バッジ、「◯◯から変更しました」といった**差分・変更履歴の注記を成果物に入れない**。受け取る人には関係がない。

### 5. 固有名詞・ローマ字を推測しない

人名の読み・所属の英語表記は、確証が無ければ**書く前にオーナーに確認する**。旧成果物の表記も検証せずに引き継がない。

## 作り込みの基準

「シンプルすぎる」と言われないために、最低でも次を入れる。

1. **テーマに合った装飾を1つ**（罫線・帯・アイコン・配色）
2. **情報を足す** — 本文だけで終わらせず「これは何か」の解説や一覧を添える
3. **受け取る人が手を動かせるパーツ** — チェック欄、記入欄
4. **視覚化** — 文章で並べず、カード・表・アイコンに落とす

## A4 レイアウトの型

```css
@page { size: A4; margin: 0; }
.page { width: 210mm; height: 297mm; overflow: hidden; page-break-after: always; }
```

- 装飾フレームは端から **10mm** 内側、本文は **17mm** 内側
- 本文の**下端余白は 14mm 以上**（フレームと重ならせない）
- `flex` で縦に組み、フッターは `margin-top: auto` で下に落とす

## フォント（macOS で分かっていること）

- 日本語の丸ゴシック（Zen Maru Gothic）などは**ローカル未インストール**。生成時に Google Fonts から取得する
- **ハングル・中文は和文フォントに字形が無い**。`Noto Serif KR` などを併用する
- macOS のヒラギノは PostScript アウトラインで **reportlab が読めない**
- **稀な漢字は特定のフォントに無い**ことがある。人名を入れる成果物は**必ず字化けを目視確認する**
- poppler（pdftoppm）が入っていない環境では `Read` が PDF を直接開けない。目視確認は上の **pypdf → `sips`** か PyMuPDF を使う

## 完了前チェックリスト

- [ ] 本文 12pt 以上になっているか
- [ ] 全ページを PNG 化して目視したか（切れ・重なりなし）
- [ ] 制作経緯・差分注記が入っていないか
- [ ] 日付と曜日を検算したか（`date +%Y-%m-%d`、曜日は Python で確認）
- [ ] HTML ソースを残したか
- [ ] `outputs/deliverables/YYYY-MM-DD_主題.pdf` に保存し、`ls -la` で実在を確認したか
