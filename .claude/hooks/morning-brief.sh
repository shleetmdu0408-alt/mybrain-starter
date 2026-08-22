#!/bin/bash
# UserPromptSubmit フック：「おはよう」と打たれたときだけ、朝のブリーフィング材料を
# Claude のコンテキストへ流し込む。それ以外のプロンプトでは黙って終了する。
#
#   1. 今日・明日の天気 ＋ 今日の時間帯別の雨（朝7-9時／夜18-21時）
#   2. 1ヶ月以内に来る記念日（wiki/life_events.md の「固定イベント」表から）
#   3. 今日／今週の予定（Claude が Google カレンダー MCP で取得する指示だけ出す）
#   4. Home.md の「進行中」テーブル
#   5. wiki/open_questions.md の問い（見出しだけ）
#   6. ニュース5本の候補（NHK の RSS。雑談ネタ／政治・経済／オーナー向けの3プール）
#
# 🔧 **セットアップ時にここを直す**：天気の地点（LAT / LON / PLACE）。
#    緯度・経度は Google マップで地点を右クリックすると出る。既定は東京駅。

LAT="35.6812"
LON="139.7671"
PLACE="東京駅"

PAYLOAD=$(cat)
PROMPT=$(printf '%s' "$PAYLOAD" | jq -r '.prompt // ""' 2>/dev/null)

# 「おはよう」「おはようございます」「オハヨウ」「good morning」に反応
printf '%s' "$PROMPT" | grep -qiE 'おはよ|オハヨ|ｵﾊﾖ|good morning' || exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
TODAY=$(date +%F)
DOW=$(date +%u)                      # 1=月 … 7=日
SUNDAY=$(date -v+$((7 - DOW))d +%F)  # 今週の日曜（今日が日曜なら今日）

cat <<EOS
☀️ おはようブリーフィング

【伝え方】挨拶 → 天気 → 記念日 → 今日の予定 → 今週の残り → 進行中 → 未解決の問い → ニュース の順。
**全体で27行以内**。表は使わず箇条書きで。詳細は聞かれてから答える。
推測の進捗評価（停滞・未着手など）は書かない。状態が「待機」の行は催促しない。

EOS

# ---------- 1. 天気（今日・明日＋今日の時間帯別の雨） ----------
echo "### 天気：${PLACE}"
WX=$(curl -s --max-time 8 "https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&hourly=precipitation_probability&timezone=Asia%2FTokyo&forecast_days=2" 2>/dev/null)

if [ -n "$WX" ]; then
  WX="$WX" python3 <<'PY'
import json, os, datetime

CODES = {
    0: "快晴", 1: "晴れ", 2: "薄曇り", 3: "曇り",
    45: "霧", 48: "霧（霧氷）",
    51: "弱い霧雨", 53: "霧雨", 55: "強い霧雨",
    56: "着氷性の霧雨", 57: "強い着氷性の霧雨",
    61: "弱い雨", 63: "雨", 65: "強い雨",
    66: "着氷性の雨", 67: "強い着氷性の雨",
    71: "弱い雪", 73: "雪", 75: "強い雪", 77: "霧雪",
    80: "にわか雨", 81: "強いにわか雨", 82: "激しいにわか雨",
    85: "にわか雪", 86: "強いにわか雪",
    95: "雷雨", 96: "雷雨（雹）", 99: "激しい雷雨（雹）",
}
WD = ["月", "火", "水", "木", "金", "土", "日"]

try:
    wx = json.loads(os.environ["WX"])
    d = wx["daily"]
    for i, label in enumerate(["今日", "明日"]):
        day = datetime.date.fromisoformat(d["time"][i])
        print("- {} {}（{}）：{} / {:.0f}〜{:.0f}℃ / 降水確率 {}%".format(
            label, day.strftime("%-m/%-d"), WD[day.weekday()],
            CODES.get(d["weather_code"][i], "不明"),
            d["temperature_2m_min"][i], d["temperature_2m_max"][i],
            d["precipitation_probability_max"][i]))

    # 今日の通勤時間帯だけ抜き出す（1日の平均より傘の判断に直結するため）
    h = wx.get("hourly", {})
    today = d["time"][0]
    windows = {"朝(7-9時)": range(7, 10), "夜(18-21時)": range(18, 22)}
    out = []
    for name, hours in windows.items():
        vals = [h["precipitation_probability"][i]
                for i, t in enumerate(h.get("time", []))
                if t.startswith(today) and int(t[11:13]) in hours
                and h["precipitation_probability"][i] is not None]
        if vals:
            out.append("{} {}%".format(name, max(vals)))
    if out:
        print("- 今日の雨（傘の判断用）：" + " ／ ".join(out))
except Exception as e:
    print("（天気データの解析に失敗：{}）".format(e))
PY
else
  echo "（天気の取得に失敗しました。オフラインの可能性あり。必要なら WebSearch で調べ直すこと）"
fi

echo ""

# ---------- 2. 記念日（7日以内のものだけ。無ければ何も出さない） ----------
FAM="$ROOT/wiki/life_events.md"
if [ -f "$FAM" ]; then
  FAM="$FAM" TODAY="$TODAY" python3 <<'PY'
import os, re, datetime

path = os.environ["FAM"]
today = datetime.date.fromisoformat(os.environ["TODAY"])
LEAD = 30  # 何日前から知らせるか（プレゼント・予約の準備が要るので1ヶ月前）
WD = ["月", "火", "水", "木", "金", "土", "日"]
WDIDX = {"月": 0, "火": 1, "水": 2, "木": 3, "金": 4, "土": 5, "日": 6}

def nth_weekday(year, month, n, wd):
    first = datetime.date(year, month, 1)
    return first + datetime.timedelta(days=(wd - first.weekday()) % 7 + 7 * (n - 1))

def upcoming(make):
    """今年の日付を作り、過ぎていたら来年の同じ日を返す"""
    for y in (today.year, today.year + 1):
        try:
            d = make(y)
        except ValueError:
            continue
        if d >= today:
            return d
    return None

hits = []
try:
    for line in open(path, encoding="utf-8"):
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 2 or cells[0] in ("月", "---"):
            continue
        when, name = cells[0], cells[1]
        memo = cells[2] if len(cells) > 2 else ""

        m = re.match(r"(\d+)月(\d+)日", when)
        if m:
            mo, da = int(m.group(1)), int(m.group(2))
            d = upcoming(lambda y: datetime.date(y, mo, da))
        else:
            m = re.match(r"(\d+)月（第(\d)([日月火水木金土])曜）", when)
            if not m:
                continue  # 「12月」のように日が特定できないものは出さない
            mo, n, wd = int(m.group(1)), int(m.group(2)), WDIDX[m.group(3)]
            d = upcoming(lambda y: nth_weekday(y, mo, n, wd))

        if d is None:
            continue
        days = (d - today).days
        if not (0 <= days <= LEAD):
            continue

        # メモに「1957年生まれ」があれば、その日に何歳になるかを添える
        age = ""
        b = re.search(r"(\d{4})年生まれ", memo)
        if b:
            age = "（{}歳）".format(d.year - int(b.group(1)))
        hits.append((days, d, name, age))

    if hits:
        print("### 記念日（1ヶ月以内）")
        for days, d, name, age in sorted(hits):
            when = "**今日**" if days == 0 else ("明日" if days == 1 else "あと{}日".format(days))
            print("- {}/{}（{}）{}{} — {}".format(d.month, d.day, WD[d.weekday()], name, age, when))
        print("→ **直近の1件だけ**を伝え、残りがあれば「他N件」と1行でまとめる。")
        print("  準備が要るもの（プレゼント・予約）や節目の歳（還暦70歳など）なら1行だけ添える。")
        print("")
except Exception:
    pass  # 記念日は出せなくても朝の進行を止めない
PY
fi

# ---------- 3. 予定（Claude が MCP で取得する） ----------
cat <<EOS
### 予定 — **これは Claude が自分で取りに行くこと**

Google カレンダーの MCP ツール（\`list_events\`）を使って、以下2つを取得して伝える:

1. **今日**：${TODAY}
2. **今週の残り**：${TODAY} 〜 ${SUNDAY}（今日の分を除いて、日付ごとに1行）

- 終日予定は時刻を書かない。予定が0件なら「予定なし」と1行だけ。
- カレンダーの MCP ツールが見つからない／エラーなら「カレンダー未接続」と1行書いて先へ進む（勝手に予定を作らない）。
- **天気と予定を突き合わせて役に立つことがあれば1行だけ添える**（例：外出の時間帯に雨→傘、猛暑日→水分）。無理に書かない。

EOS

# ---------- 4. 進行中 ----------
if [ -f "$ROOT/Home.md" ]; then
  awk '/^## 進行中/{f=1} f && /^## / && !/^## 進行中/{exit} f' "$ROOT/Home.md"
  echo "→ この表は Home.md の正本そのまま。**期限が近い順に3件程度**に絞って伝える（全部並べない）。"
  echo ""
fi

# ---------- 5. 未解決の問い ----------
Q="$ROOT/wiki/open_questions.md"
if [ -f "$Q" ]; then
  echo "### 未解決の問い（[[open_questions]] が正本）"
  # **太字の問いだけを出す（変更）。** 以前は行全体を出していたので毎朝 16.4KB が入り、
  # そのうち使うのは1〜2件だけだった（新方式 4.8KB）。背景が要る問いは open_questions.md を読めばよい。
  awk '/^## /{cat=$2}
       /^- \*\*/{line=$0; sub(/^- /,"",line);
                 if (match(line, /\*\*[^*]+\*\*/)) print "- ["cat"] " substr(line, RSTART, RLENGTH);
                 else print "- ["cat"] " line}' "$Q"
  echo ""
  echo "→ **全部並べないこと。** 今日の予定・天気・進行中に照らして**今日つつけそうな1〜2件だけ**挙げ、"
  echo "  残りは「他 N 件（[[open_questions]]）」と1行でまとめる。"
  echo "  ここには問いの見出ししか無い。背景まで話すなら [[open_questions]] の該当節だけを読む。"
  echo ""
fi

# ---------- 6. ニュース（NHK の RSS から候補を渡す。選ぶのは Claude） ----------
python3 <<'PY'
import concurrent.futures as cf, datetime, urllib.request, xml.etree.ElementTree as ET
from email.utils import parsedate_to_datetime

# NHK の RSS。3つのプールに分けて渡し、どれを採るかは Claude が決める。
POOLS = [
    ("政治・経済", ["cat4", "cat5"]),
    ("オーナー向け（科学・医療・国際）", ["cat3", "cat6"]),
    ("雑談ネタ（主要・社会・文化・スポーツ）", ["cat0", "cat1", "cat2", "cat7"]),
]
FRESH_HOURS = 36  # これより古い記事は候補に出さない
PER_POOL = 6
SKIP = ("【動画】", "【LIVE", "【詳細", "ライフライン")  # まとめ・動画枠は話題にならないので落とす

def fetch(cat):
    url = "https://www.nhk.or.jp/rss/news/{}.xml".format(cat)
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=6) as r:
        return ET.fromstring(r.read()).find("channel").findall("item")

try:
    cats = [c for _, cs in POOLS for c in cs]
    with cf.ThreadPoolExecutor(max_workers=len(cats)) as ex:
        got = {}
        futs = {c: ex.submit(fetch, c) for c in cats}
        for c, f in futs.items():
            try:
                got[c] = f.result()
            except Exception:
                got[c] = []

    now = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9)))
    seen = set()
    lines = []
    for label, cs in POOLS:
        picks = []
        for c in cs:
            for it in got.get(c, []):
                title = (it.findtext("title") or "").strip()
                if not title or title in seen or title.startswith(SKIP):
                    continue
                try:
                    pub = parsedate_to_datetime(it.findtext("pubDate"))
                    if (now - pub).total_seconds() / 3600 > FRESH_HOURS:
                        continue
                except Exception:
                    pass
                desc = (it.findtext("description") or "").strip().replace("\n", "")
                if len(desc) > 70:
                    desc = desc[:70] + "…"
                seen.add(title)
                picks.append("  - {}（{}）{}".format(title, desc, it.findtext("link") or ""))
                if len(picks) >= PER_POOL:
                    break
            if len(picks) >= PER_POOL:
                break
        if picks:
            lines.append("- **{}**".format(label))
            lines += picks

    if lines:
        print("### ニュース候補（NHK。ここから Claude が選ぶ）")
        print("\n".join(lines))
        print("→ **5本だけ**選んで最後に出す。まず3プールから1本ずつ：")
        print("  ① 雑談ネタ（職場や家庭で話題にしやすいもの）")
        print("  ② 政治・経済（家計・制度・為替など生活に効くものを優先）")
        print("  ③ オーナー向け（医療・研究・AI/ツール・お金・育児に引っかかるもの。無ければ国際情勢）")
        print("  残り2本は**その日いちばん読む価値のあるもの**をプール不問で足す（同じプールから2本でよい）。")
        print("- 1本1行。**見出し＋「なぜ気になるか」を半行**。リンクは Markdown で貼る。")
        print("- 同じ話題を2本に使わない。候補が薄い日は減らしてよい。**論評や煽りは書かない**。")
        print("- 医療・健康の記事を扱うときは、記事にない断定を足さない。")
        print("")
except Exception:
    pass  # ニュースが取れなくても朝の進行は止めない
PY
