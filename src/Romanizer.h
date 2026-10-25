#pragma once
#include <QString>

// Local romanization fallback, used when the lyrics provider ships none.
//   Korean   : Revised Romanization, syllable by syllable (no sound-change rules)
//   Chinese  : pinyin with tone marks (ICU Han-Latin)
//   Japanese : kana only. Lines containing kanji are skipped; they need a dictionary
//              (MeCab/kuromoji). The NetEase provider covers most popular songs instead.
namespace Romanizer {
// Returns "" when the line needs no romanization or cannot be romanized.
// japaneseSong: the song has kana somewhere, so kanji-only lines are Japanese, not Chinese.
QString line(const QString &text, bool japaneseSong = false);

// Japanese text made ready for a kana/kanji converter: furigana "飛翔(はばた)" replaces the kanji it
// explains, and the particles は / へ / を are written as they are pronounced (わ / え / お).
QString prepareJapanese(const QString &text);
// Tidies converter output: drops quote/bracket marks, collapses spaces.
QString cleanRoman(QString r);
}
