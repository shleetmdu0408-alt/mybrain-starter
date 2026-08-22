#!/bin/bash
# pubmed.sh — PubMed を検索して、引用に必要な情報だけを表で返す。
#
#   使い方: bash .claude/skills/paper-search/pubmed.sh "<検索式>" [件数] [並び順]
#     例:   bash .claude/skills/paper-search/pubmed.sh '"osteoarthritis, knee"[MeSH] AND exercise therapy[MeSH] AND randomized controlled trial[pt]' 20
#     並び順: relevance（既定）/ date（新しい順）
#
# なぜこれがあるか:
#   ① MCP（bio-research プラグイン）が無い環境でも論文検索ができるようにするため。
#      NCBI E-utilities は公開 API で、登録も鍵も要らない。
#   ② **出版年の取り違えを防ぐため。** 論文検索ツールが返す日付は「電子版の公開日」のことがあり、
#      印刷版の巻号年とずれる（例 PMID 25414475: epub 2014-11-20 だが Emerg Med J 32(8) 2015 Aug）。
#      このスクリプトは pubdate（引用に使う年）を主に出し、ずれている行に epub を併記する。
#
# 出典: NCBI E-utilities（https://www.ncbi.nlm.nih.gov/books/NBK25501/）
#   礼儀として1秒に3リクエストを超えない。大量に回すなら NCBI の API キーを取る。

QUERY="${1:?検索式を渡してください}"
RETMAX="${2:-20}"
SORT="${3:-relevance}"

Q="$QUERY" N="$RETMAX" S="$SORT" python3 <<'PY'
import json, os, sys, time, urllib.parse, urllib.request

BASE = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils"
query, retmax, sort = os.environ["Q"], os.environ["N"], os.environ["S"]

def get(endpoint, **params):
    params["db"] = "pubmed"
    params["retmode"] = "json"
    url = f"{BASE}/{endpoint}.fcgi?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": "mybrain-starter/1.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())

try:
    res = get("esearch", term=query, retmax=retmax, sort=sort)["esearchresult"]
except Exception as e:
    sys.exit(f"検索に失敗しました: {e}")

print("検索式:", query)
print("PubMed 変換後:", res.get("querytranslation", "(なし)"))
ids = res.get("idlist", [])
print(f"ヒット総数: {res.get('count')} ／ 取得: {len(ids)} 件（並び順: {sort}）")
if not ids:
    sys.exit("（該当なし。検索式を緩めるか、MeSH 用語を確認する）")

time.sleep(0.4)
r = get("esummary", id=",".join(ids))["result"]

print()
print("| PMID | 年 | 雑誌 | タイトル | DOI | 全文(PMC) | 種別 |")
print("|---|---|---|---|---|---|---|")
for uid in r.get("uids", []):
    a = r[uid]
    aid = {i["idtype"]: i["value"] for i in a.get("articleids", [])}
    title = a.get("title", "").replace("|", "/").rstrip(".")
    if len(title) > 90:
        title = title[:88] + "…"
    year = a.get("pubdate", "")
    epub = a.get("epubdate", "")
    if epub and epub[:4] != year[:4]:
        year += f" ※epub {epub}"
    types = [t for t in a.get("pubtype", []) if t != "Journal Article"][:2]
    row = [uid, year, a.get("source", ""), title,
           aid.get("doi", "—"), aid.get("pmc", "—"), "/".join(types) or "—"]
    print("| " + " | ".join(row) + " |")

print()
print("※ 引用に使う年は **pubdate**。`※epub` が付いた行は電子版が別の年に出ているので、年を書き間違えやすい。")
print("※ 全文(PMC) に番号がある論文は本文まで無料で読める。")
PY
