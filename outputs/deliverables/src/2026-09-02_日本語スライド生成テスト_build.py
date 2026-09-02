# -*- coding: utf-8 -*-
"""テスト用の日本語デッキ（3枚）。型は「実験レポート型」（問い → 検証 → 結果）。
通しのモチーフ：判定バッジ（◯＝確認できた／要検証＝裏が取れていない）。"""
import sys
from deck_lib import *

OUT = sys.argv[1]
prs = new_deck()

# ---------------------------------------------------------------- 1枚目：表紙
s = slide_new(prs, dark=True)
box(s, ML, 2.70, 11.5, 0.80,
    "日本語スライド生成パイプラインの動作確認",
    size=36, bold=True, color=WHITE, spacing=1.22)
box(s, ML, 3.65, 11.0, 0.40,
    "mybrain-starter Vault ／ テスト出力 ／ 2026-09-02（再ビルド）",
    size=15, color=MUTED_D)
box(s, ML, 4.40, 10.6, 1.00,
    "問い：この環境で、日本語の .pptx と、同じ内容の PDF を、"
    "文字化けなしで1回の実行で出せるか。",
    size=15, color=WHITE, spacing=1.35)
pill(s, ML, 5.85, "実験レポート型 ／ 全3枚", INK_CARD, w=2.70, tcol=MUTED_D, size=11)
notes(s, "パイプラインの動作確認用のサンプル。中身の主題ではなく、"
         "日本語が崩れずに pptx と PDF の両方で出るかだけを見ている。")

# ---------------------------------------------------------------- 2枚目：検証
s = slide_new(prs)
head(s, "python-pptx と LibreOffice の組み合わせで、"
        "日本語の .pptx と PDF を同じ内容で出力できた",
     sub="検証：見出し・表・カード・記号を1枚ずつ含めて生成し、PDF に変換して突き合わせた",
     badge="◯ 3枚とも出力できた", badge_fill=GREEN)

CARDS = [
    ("生成", "python-pptx 1.0.2",
     "見出し・表・カード・バッジを\n含む3枚を .pptx として出力。"),
    ("変換", "LibreOffice 24.2.7",
     "同じファイルから3ページの\nPDF を生成。"),
    ("表示", "Noto Sans CJK JP（要設定）",
     "既定では簡体字の SC 面が\n選ばれるため JP を優先させた。"),
]
for i, (label, tool, body) in enumerate(CARDS):
    x = ML + i * 3.98
    card(s, x, 2.20, 3.72, 1.50)
    box(s, x + 0.28, 2.42, 3.16, 0.30, label, size=14, bold=True, color=GREEN)
    box(s, x + 0.28, 2.76, 3.16, 0.30, tool, size=11, color=MUTED)
    box(s, x + 0.28, 3.10, 3.16, 0.52, body, size=11.5, color=TEXT, spacing=1.25)

rows = [
    ["検証項目", "確認できたこと", "判定"],
    ["日本語のスライド生成", "見出し・表・カードが3枚とも崩れずに出た", "◯"],
    ["PDF への変換", ".pptx と同じ3ページ・同じ本文が取り出せた", "◯"],
    ["記号の表示", "◯ ※ → ─ が絵文字に化けずに出た", "◯"],
    ["フォントの字形", "既定では中国語字形の SC 面が選ばれていた（設定で修正）", "要検証"],
]
cc = {(1, 2): (GREEN, GREEN_T), (2, 2): (GREEN, GREEN_T),
      (3, 2): (GREEN, GREEN_T), (4, 2): (AMBER, AMBER_T)}
table(s, ML, 4.00, CW, rows, [3.00, 6.60, 2.233], row_h=0.47, cell_colors=cc)
footnote(s, "※ PDF の /BaseFont を実測した値は NotoSansCJKjp-Regular ／ -Bold。"
            "fontconfig を設定する前は NotoSansCJKsc（簡体字）が埋め込まれていた。")
pagenum(s, 2)
notes(s, "3枚のうち1枚は表、1枚はカード、1枚はダーク地の見出しにして、"
         "レイアウトの種類ごとに崩れが出ないかを見た。"
         "フォントだけは代替が入っているので、実機確認は別に必要。")

# ---------------------------------------------------------------- 3枚目：結論
s = slide_new(prs, dark=True)
head(s, "この環境なら、日本語の資料は .pptx と PDF の両方で納品できる",
     dark=True,
     sub="残る不確実性はフォントの字面だけ。レイアウトと文字の出方は確認済み")

CONC = [
    ("できたこと", GREEN_L,
     "3枚の .pptx と、同じ内容の PDF を\n"
     "1回の実行で生成できた。\n"
     "見出し・表・カード・バッジ・\n"
     "脚注・ページ番号のいずれも、\n"
     "はみ出しや重なりは出ていない。"),
    ("できていないこと", AMBER_L,
     "指定フォントの Yu Gothic は\n"
     "この環境に無い。fontconfig を\n"
     "設定するまで、PDF には簡体字の\n"
     "NotoSansCJKsc が埋め込まれていた。\n"
     "PowerPoint 実機での字面は未確認。"),
    ("次の一手", MUTED_D,
     "本番の資料は、この手順のまま\n"
     "中身だけ差し替えればよい。\n"
     "渡す前に一度、受け取る相手の\n"
     "PowerPoint で開いて\n"
     "改行位置だけ見てもらう。"),
]
for i, (label, col, body) in enumerate(CONC):
    x = ML + i * 3.98
    card(s, x, 2.55, 3.72, 2.00, fill=INK_CARD)
    box(s, x + 0.28, 2.76, 3.16, 0.32, label, size=14, bold=True, color=col)
    box(s, x + 0.28, 3.18, 3.16, 1.20, body, size=11.5, color=WHITE, spacing=1.32)

box(s, ML, 5.20, CW, 0.55,
    "結論：日本語デッキの生成から PDF 化までは、この環境だけで完結する。",
    size=18, bold=True, color=GREEN_L, spacing=1.2)
footnote(s, "※ このデッキはパイプライン確認用のサンプル。内容そのものに主張は無い。",
         dark=True, y=6.35)
pagenum(s, 3, dark=True)
notes(s, "締め。できたことと、できていないこと（フォントの実機確認）を分けて置いた。")

prs.save(OUT)
print("saved:", OUT, "slides:", len(prs.slides.__iter__.__self__._sldIdLst))
