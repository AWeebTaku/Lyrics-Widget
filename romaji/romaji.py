#!/usr/bin/env python3
"""Romanizes Japanese lyric lines: one line in on stdin -> one line of Hepburn romaji on stdout (UTF-8).
MeCab + UniDic (fugashi/cutlet) reads kanji in context and gets particles right (は=wa, へ=e, を=wo)."""
import re
import sys
import warnings

warnings.filterwarnings("ignore")
import cutlet

# UniDic prefers formal readings; songs almost never use them
FIX = {"私": "わたし", "明日": "あした", "貴方": "あなた", "貴女": "あなた", "僕": "ぼく", "俺": "おれ",
       "君": "きみ", "何": "なに", "今日": "きょう", "昨日": "きのう", "大人": "おとな",
       "一人": "ひとり", "二人": "ふたり", "笑顔": "えがお"}
FIX_RE = re.compile("|".join(sorted(map(re.escape, FIX), key=len, reverse=True)))
FURIGANA = re.compile(r"[一-鿿々]+[(（]([぀-ヿー]+)[)）]")  # 飛翔(はばた) -> はばた
MARKS = re.compile(r'[“”"「」『』（）()\[\]【】《》〈〉・]')

k = cutlet.Cutlet()
k.use_foreign_spelling = False

lines = sys.stdin.read().split("\n")
if lines and lines[-1] == "":
    lines.pop()
for raw in lines:
    t = FIX_RE.sub(lambda m: FIX[m.group()], FURIGANA.sub(r"\1", raw))
    r = MARKS.sub(" ", k.romaji(t)) if t.strip() else ""
    print(re.sub(r"\s+", " ", r).strip())
