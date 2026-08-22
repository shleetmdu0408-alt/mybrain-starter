---
description: raw/ の素材（論文・PPTX・XLSX・DOCX・PDF）を読んで wiki に構造化する
argument-hint: [対象ファイル名や観点（省略可）]
---

`raw-intake` スキルを実行して、`raw/` の素材を `wiki/` に構造化する。

対象の指定: $ARGUMENTS （空なら `wiki/raw_inventory.md` と突き合わせて**未構造化のファイルすべて**を対象にする）

**Step 2（何のために入れたかの確認）を飛ばさない。** `raw/` は読み取り専用。削除・改名・上書きをしない。
処理後は `wiki/raw_inventory.md` と `wiki/index.md` の更新まで必ず行うこと。
