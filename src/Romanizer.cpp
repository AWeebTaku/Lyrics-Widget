#include "Romanizer.h"

#include <QHash>
#include <QRegularExpression>
#include <unicode/ustring.h>
#include <unicode/utrans.h>

namespace {

enum Script { Latin, Korean, Japanese, Chinese };

bool isHangul(char16_t c) { return (c >= 0xAC00 && c <= 0xD7A3); }
bool isKana(char16_t c) { return c >= 0x3041 && c <= 0x30FF; }
bool isHan(char16_t c) { return (c >= 0x4E00 && c <= 0x9FFF) || (c >= 0x3400 && c <= 0x4DBF); }

QString hangul(const QString &s)
{
    static const char *const L[] = {"g", "kk", "n", "d", "tt", "r", "m", "b", "pp", "s",
                                    "ss", "", "j", "jj", "ch", "k", "t", "p", "h"};
    static const char *const V[] = {"a", "ae", "ya", "yae", "eo", "e", "yeo", "ye", "o", "wa", "wae",
                                    "oe", "yo", "u", "wo", "we", "wi", "yu", "eu", "ui", "i"};
    static const char *const T[] = {"", "k", "k", "ks", "n", "nj", "nh", "t", "l", "lk", "lm", "lb",
                                    "ls", "lt", "lp", "lh", "m", "p", "ps", "t", "t", "ng", "t", "t",
                                    "k", "t", "p", "t"};
    QString out;
    for (const QChar ch : s) {
        if (!isHangul(ch.unicode())) {
            out += ch;
            continue;
        }
        const int n = ch.unicode() - 0xAC00;
        out += QLatin1String(L[n / 588]);
        out += QLatin1String(V[(n % 588) / 28]);
        out += QLatin1String(T[n % 28]);
    }
    return out;
}

// Opening a transliterator is the expensive part; keep one per rule set for the process lifetime.
QString transliterate(const char16_t *id, const QString &s)
{
    static QHash<const char16_t *, UTransliterator *> cache;
    UTransliterator *t = cache.value(id);
    if (!t) {
        UErrorCode err = U_ZERO_ERROR;
        t = utrans_openU(reinterpret_cast<const UChar *>(id), -1, UTRANS_FORWARD, nullptr, 0, nullptr, &err);
        if (U_FAILURE(err))
            return {};
        cache.insert(id, t);
    }
    UErrorCode err = U_ZERO_ERROR;
    QString buf = s;
    buf.resize(s.size() * 4 + 16); // transliteration can grow the text
    int32_t len = s.size(), limit = s.size();
    utrans_transUChars(t, reinterpret_cast<UChar *>(buf.data()), &len, buf.size(), 0, &limit, &err);
    if (U_FAILURE(err))
        return {};
    buf.resize(len);
    return buf;
}

} // namespace

QString Romanizer::prepareJapanese(const QString &in)
{
    // 飛翔(はばた)いたら -> はばたいたら: the author gave the reading, so use it
    static const QRegularExpression furigana(
        QStringLiteral(R"([\x{4E00}-\x{9FFF}\x{3005}]+[(（]([\x{3040}-\x{30FF}ー]+)[)）])"));
    QString t = in;
    t.replace(furigana, QStringLiteral("\\1"));

    // Particles. は/へ/を only read wa/e/o as particles; as part of a word (はな, へや) they keep
    // their sound. Without a dictionary the best signal is the character before: after a kanji or
    // katakana word it is nearly always a particle, and so is "には/では/とは/へと".
    auto isKanjiOrKata = [](QChar c) {
        const ushort u = c.unicode();
        return (u >= 0x4E00 && u <= 0x9FFF) || (u >= 0x30A1 && u <= 0x30FF);
    };
    for (qsizetype i = 1; i < t.size(); ++i) {
        const QChar c = t[i], p = t[i - 1];
        const QChar n = i + 1 < t.size() ? t[i + 1] : QChar();
        if (c == QChar(0x3092)) { // を
            t[i] = QChar(0x304A);
        } else if (c == QChar(0x306F)) { // は
            const bool after = isKanjiOrKata(p) || (!p.isLetter() && p != QLatin1Char(' ')) || p == QChar(0x306B) || p == QChar(0x3067) || p == QChar(0x3068)
                               || n == QChar() || n == QLatin1Char(' ') || !n.isLetter();
            if (after)
                t[i] = QChar(0x308F);
        } else if (c == QChar(0x3078)) { // へ
            if (isKanjiOrKata(p) || (!p.isLetter() && p != QLatin1Char(' ')) || n == QChar(0x3068) || n == QChar(0x3082) || n == QChar() || !n.isLetter())
                t[i] = QChar(0x3048);
        }
    }
    return t;
}

QString Romanizer::cleanRoman(QString r)
{
    static const QRegularExpression marks(QStringLiteral(R"([“”"「」『』（）()\[\]【】《》〈〉])"));
    r.remove(marks);
    return r.simplified();
}

QString Romanizer::line(const QString &textIn, bool japaneseSong)
{
    const QString text = textIn;
    bool ko = false, kana = false, han = false;
    for (const QChar c : text) {
        ko |= isHangul(c.unicode());
        kana |= isKana(c.unicode());
        han |= isHan(c.unicode());
    }
    QString r;
    if (ko)
        r = hangul(text);
    else if (kana && !han)
        r = cleanRoman(transliterate(u"Katakana-Latin; Hiragana-Latin", prepareJapanese(text)));
    else if (han && !kana && !japaneseSong)
        r = transliterate(u"Han-Latin", text);
    r = r.simplified();
    return r == text ? QString() : r;
}
