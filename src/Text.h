#pragma once
#include <algorithm>
#include <QRegularExpression>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QVector>
#include <cmath>

#include "Romanizer.h"

struct Track {
    QString title, artist, album, id; // id: YouTube video id / Spotify track id (may be empty)
    int durationSec = 0;
    QString lang;   // "en" / "ja" / "ko" / "zh" when the title says which language version this is, else empty
    QString prefer; // provider that usually has this artist's lyrics ("lrclib"/"netease"/"qq"), may be empty
};

struct Candidate {
    QString artist, title;
    bool operator==(const Candidate &o) const { return artist == o.artist && title == o.title; }
};

namespace Text {

inline bool hasNonLatin(const QString &s);

inline QString cleanTitle(QString t)
{
    // Chrome's own MPRIS player appends the site name: "Happier | YouTube Music".
    static const QRegularExpression site(QStringLiteral(R"(\s*[|｜-]\s*YouTube( Music)?\s*$)"),
                                         QRegularExpression::CaseInsensitiveOption);
    // "(Official Video)", "[Lyrics]", "【MV】", "(feat. X)", "(Remastered 2011)" ...
    static const QRegularExpression bracket(
        QStringLiteral(R"re(\s*[\(\[\{（【][^\)\]\}）】]*\b(official|video|audio|lyrics?|mv|m/v|hd|hq|4k|remaster(?:ed)?|visuali[sz]er|live|sub|eng|romaji|color coded|feat|ft|featuring|clip|version|ver)\b[^\)\]\}）】]*[\)\]\}）】])re"),
        QRegularExpression::CaseInsensitiveOption);
    // "Song - Remastered 2011", "Song - Radio Edit"
    static const QRegularExpression dashTail(
        QStringLiteral(R"(\s+-\s+(remaster(ed)?|live|radio edit|single version|album version|.*\bversion)\b.*$)"),
        QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression ft(QStringLiteral(R"(\s+(ft|feat)\.?\s+.*$)"),
                                       QRegularExpression::CaseInsensitiveOption);
    // bare trailing noise: "Good Day MV", "Song Official Video"
    static const QRegularExpression tail(
        QStringLiteral(R"(\s+(mv|m/v|official( music)? video|lyrics?( video)?|audio|hd|4k)\s*$)"),
        QRegularExpression::CaseInsensitiveOption);
    t.remove(site);
    t.remove(bracket);
    t.remove(tail);
    t.remove(dashTail);
    t.remove(ft);
    return t.simplified();
}

inline QString cleanArtist(QString a)
{
    static const QRegularExpression suffix(QStringLiteral(R"(\s*(-\s*Topic|VEVO|\s+Official)\s*$)"),
                                           QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression ft(QStringLiteral(R"(\s+(ft|feat)\.?\s+.*$)"),
                                       QRegularExpression::CaseInsensitiveOption);
    a.remove(suffix);
    a.remove(ft);
    return a.simplified();
}

// Channels that are companies, not artists ("Sony Music Japan", "HYBE LABELS", "xyzVEVO").
inline bool isLabel(const QString &a)
{
    static const QRegularExpression re(
        QStringLiteral(R"((records?|music|entertainment|labels?|vevo|studios?|inc\.?|ltd\.?|company|network|media|channel|\btv\b|ent\.))"),
        QRegularExpression::CaseInsensitiveOption);
    return re.match(a).hasMatch();
}

// "Song (Sped Up)", "Song - Artist Remix", "Song (Nightcore)" -> "Song": the original track is
// what the lyric databases hold. Empty when there is nothing to strip.
inline QString stripVariant(QString t)
{
    static const QRegularExpression br(
        QStringLiteral(R"(\s*[\(\[\{（【][^\)\]\}）】]*\b(remix|mix|mashup|sped\s*up|slowed|reverb|nightcore|cover|acoustic|instrumental|edit|bootleg|vip|flip|rework|live|ver\.?|version|short|full)\b[^\)\]\}）】]*[\)\]\}）】])"),
        QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression tail(
        QStringLiteral(R"(\s+-\s+.*\b(remix|mix|mashup|sped\s*up|slowed|nightcore|cover|acoustic|edit|bootleg|flip|rework)\b.*$)"),
        QRegularExpression::CaseInsensitiveOption);
    const QString before = t;
    t.remove(br);
    t.remove(tail);
    t = t.simplified();
    return t == before.simplified() ? QString() : t;
}

// Search guesses, best first. Music videos are titled "Artist - Song" with the channel as
// artist, so the dash split is tried first when the player gave no album (= not a song entry).
inline QVector<Candidate> candidates(const Track &t)
{
    const QString title = cleanTitle(t.title);
    QString artist = cleanArtist(t.artist);
    if (isLabel(artist))
        artist.clear(); // a company, not the singer: rely on the title ("Artist - Song") instead

    QVector<Candidate> out;
    auto add = [&out](const QString &a, const QString &ti) {
        if (ti.isEmpty())
            return;
        const Candidate c{a, ti};
        if (!out.contains(c))
            out.push_back(c);
    };

    static const QRegularExpression sep(QStringLiteral(R"(\s+[-–—]\s+|\s*[|｜]\s*)"));
    const auto m = sep.match(title);
    const bool split = m.hasMatch() && m.capturedStart() > 0;
    const QString left = split ? cleanArtist(title.left(m.capturedStart())) : QString();
    const QString right = split ? cleanTitle(title.mid(m.capturedEnd())) : QString();

    // Japanese uploads: "Artist「Song」"
    static const QRegularExpression kakko(QStringLiteral(R"(^(.*?)\s*[「『](.+?)[」』])"));
    const auto km = kakko.match(title);
    const bool videoLike = t.album.isEmpty();
    if (km.hasMatch() && !km.captured(2).isEmpty()) {
        add(cleanArtist(km.captured(1)), km.captured(2).simplified());
        if (!km.captured(1).isEmpty() && videoLike)
            add(QString(), km.captured(2).simplified());
    }
    if (split && videoLike) {
        add(left, right);
        add(right, left); // "Song - Artist" ordering
    }
    add(artist, title);
    if (split && !videoLike) {
        add(left, right);
        add(right, left);
    }
    add(QString(), title);

    // "Good Day (좋은날)": also try without the parenthetical, and the parenthetical alone
    // when it is in another script. Inserted right after the candidate they came from.
    static const QRegularExpression paren(QStringLiteral(R"(\s*[\(（]([^\)）]*)[\)）])"));
    for (qsizetype i = 0; i < out.size() && out.size() < 6; i += 1) {
        const auto pm = paren.match(out[i].title);
        if (!pm.hasMatch() || out[i].artist.isEmpty())
            continue;
        QString plain = out[i].title;
        plain.remove(paren);
        const Candidate base = out[i];
        qsizetype at = i + 1;
        if (!plain.simplified().isEmpty() && !out.contains({base.artist, plain.simplified()}))
            out.insert(at++, {base.artist, plain.simplified()});
        const QString inner = pm.captured(1).simplified();
        if (hasNonLatin(inner) && !out.contains({base.artist, inner}))
            out.insert(at, {base.artist, inner});
        i = at; // skip the variants just added
    }
    // remix / sped-up / mashup tags: also try the original track
    for (qsizetype i = 0, n = out.size(); i < n; ++i) {
        const QString v = stripVariant(out[i].title);
        if (!v.isEmpty() && !out.contains({out[i].artist, v}))
            out.push_back({out[i].artist, v});
    }
    if (out.size() > 6)
        out.resize(6);
    return out;
}

// Letters/digits only, lower-cased, diacritics folded. CJK survives unchanged.
inline QString norm(const QString &s)
{
    const QString d = s.normalized(QString::NormalizationForm_KD).toLower();
    QString o;
    o.reserve(d.size());
    for (const QChar c : d)
        if (c.isLetterOrNumber())
            o += c;
    return o;
}

// 0..1. Containment counts nearly as much as equality ("marshmello" vs "marshmello and bastille").
inline double similarityRaw(const QString &a, const QString &b);

// Also compares romanized forms, so "ぼくらの" matches "Bokurano" and "ヨルシカ" matches "Yorushika".
inline double similarity(const QString &a, const QString &b)
{
    double s = similarityRaw(a, b);
    if (s >= 1 || !(hasNonLatin(a) || hasNonLatin(b)))
        return s;
    const QString ra = hasNonLatin(a) ? Romanizer::line(a) : a;
    const QString rb = hasNonLatin(b) ? Romanizer::line(b) : b;
    if (ra.isEmpty() || rb.isEmpty() || hasNonLatin(ra) || hasNonLatin(rb))
        return s; // kanji can't be romanized locally
    return std::max(s, similarityRaw(ra, rb));
}

inline double similarityRaw(const QString &a, const QString &b)
{
    const QString x = norm(a), y = norm(b);
    if (x.isEmpty() || y.isEmpty())
        return 0;
    if (x == y)
        return 1;
    const QString &shortS = x.size() < y.size() ? x : y;
    const QString &longS = x.size() < y.size() ? y : x;
    if (shortS.size() >= 2 && longS.contains(shortS))
        return 0.85;
    // character-bigram overlap for the rest (typos, "&" vs "and", spacing)
    auto grams = [](const QString &s) {
        QSet<QString> g;
        for (qsizetype i = 0; i + 1 < s.size(); ++i)
            g.insert(s.mid(i, 2));
        return g;
    };
    const auto gx = grams(x), gy = grams(y);
    if (gx.isEmpty() || gy.isEmpty())
        return 0;
    return double(QSet<QString>(gx).intersect(gy).size()) / std::min(gx.size(), gy.size()) * 0.8;
}

// How well a provider's (title, artist, duration) matches what the player says it is playing.
// Returns <0 when it is clearly a different song.
inline double score(const Candidate &want, int wantSec, const QString &title,
                    const QString &artist, double durSec, const QString &wantAlbum = {},
                    const QString &album = {})
{
    const double ts = similarity(want.title, title);
    if (ts < 0.6)
        return -1;
    // "-Instrumental-", "(Karaoke)", "off vocal" listings have no lyrics: skip unless asked for
    static const QRegularExpression noVocals(
        QStringLiteral(R"((instrumental|inst\.|karaoke|off\s*vocal|backing track|伴奏|纯音乐|カラオケ))"),
        QRegularExpression::CaseInsensitiveOption);
    if (noVocals.match(title).hasMatch() && !noVocals.match(want.title).hasMatch())
        return -1;
    const double as = want.artist.isEmpty() ? 0.5 : similarity(want.artist, artist);
    // Different artist: only believable when it's the same title *and* the same length
    // (providers spell artists differently: "Yorushika" vs "ヨルシカ"). Stops "Fallen" by one
    // band matching "Fallen" by another.
    if (as < 0.5 && !(ts == 1 && wantSec > 0 && std::abs(durSec - wantSec) <= 2))
        return -1;
    // Title alone (no artist to check): the length has to vouch for it.
    if (want.artist.isEmpty() && !(wantSec > 0 && durSec > 0 && std::abs(durSec - wantSec) <= 6))
        return -1;
    double s = 0.6 * ts + 0.4 * as;
    if (wantSec > 0 && durSec > 0) {
        const double d = std::abs(durSec - wantSec);
        s += d <= 2 ? 0.2 : d <= 6 ? 0.1 : d > 15 ? -0.3 : 0;
    }
    if (!wantAlbum.isEmpty() && !album.isEmpty() && similarity(wantAlbum, album) >= 0.8)
        s += 0.1; // same release: strongest sign it is the same recording
    return s;
}

// A real synced lyric: several timed lines and not a "this is instrumental" placeholder.
inline bool usableLrc(const QString &lrc)
{
    static const QRegularExpression stamp(QStringLiteral(R"(\[\d+:\d+)"));
    static const QRegularExpression placeholder(
        QStringLiteral(R"(纯音乐|没有填词|暂无歌词|歌词正在制作|instrumental|no lyrics)"),
        QRegularExpression::CaseInsensitiveOption);
    qsizetype n = 0;
    for (auto it = stamp.globalMatch(lrc); it.hasNext() && n < 4; it.next())
        ++n;
    return n >= 4 && !(n < 8 && placeholder.match(lrc).hasMatch());
}

// Podcasts, gameplay, tutorials, hour-long mixes...: nothing to look up. YouTube Music and Spotify
// tracks are songs; only plain YouTube videos and Spotify episodes need the check.
inline bool notASong(const Track &t, const QString &url)
{
    if (url.contains(QLatin1String("/episode/")))
        return true;
    if (!url.contains(QLatin1String("youtube.com")) || url.contains(QLatin1String("music.youtube.com")))
        return false;
    static const QRegularExpression words(
        QStringLiteral(R"(podcast|gameplay|walkthrough|tutorial|trailer|reaction|review|vlog|live ?stream|episode|interview|asmr|unboxing|news|\bfull (album|movie|episode)\b)"),
        QRegularExpression::CaseInsensitiveOption);
    return t.durationSec > 15 * 60 || words.match(t.title).hasMatch();
}

// Sped-up / slowed uploads of a song: the lyrics keep their order but run faster or slower. +1 faster,
// -1 slower, 0 normal. The controller rescales the timestamps by (playing length / matched length).
inline int tempoVariant(const QString &title)
{
    static const QRegularExpression fast(QStringLiteral(R"(nightcore|sped[ -]?up|speed ?up|\b1\.?[2-9]x\b)"),
                                         QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression slow(QStringLiteral(R"(slowed|\breverb\b|\b0?\.[5-9]x\b)"),
                                         QRegularExpression::CaseInsensitiveOption);
    return fast.match(title).hasMatch() ? 1 : slow.match(title).hasMatch() ? -1 : 0;
}

// "... -English version-", "(Japanese ver.)", "日本語版": which language version of a song this is. Songs
// released in several languages share a title; the lyrics' language has to agree with this.
inline QString languageHint(const QString &title)
{
    static const QRegularExpression re(
        QStringLiteral(R"((english|japanese|korean|chinese|mandarin)\s*(ver\.?|version)|\b(eng|jp|kr)\s*ver\b|(日本語|英語|韓国語|中国語)\s*(版|ver)|\((english|japanese|korean|chinese)\))"),
        QRegularExpression::CaseInsensitiveOption);
    const auto m = re.match(title);
    if (!m.hasMatch())
        return {};
    const QString t = m.captured().toLower();
    if (t.contains(QLatin1String("english")) || t.contains(QLatin1String("eng")) || t.contains(QStringLiteral("英語")))
        return QStringLiteral("en");
    if (t.contains(QLatin1String("japanese")) || t.contains(QLatin1String("jp")) || t.contains(QStringLiteral("日本語")))
        return QStringLiteral("ja");
    if (t.contains(QLatin1String("korean")) || t.contains(QLatin1String("kr")) || t.contains(QStringLiteral("韓国語")))
        return QStringLiteral("ko");
    return QStringLiteral("zh");
}

// Does this lyric text contradict the language version asked for? A Japanese song often has English
// lines mixed in, so "ja" only needs some kana; "en" allows only a few CJK characters (names, a quote).
inline bool langMismatch(const QString &text, const QString &lang)
{
    if (lang.isEmpty() || text.isEmpty())
        return false;
    double kana = 0, hangul = 0, han = 0, letters = 0;
    for (const QChar c : text) {
        if (!c.isLetter())
            continue;
        ++letters;
        const ushort u = c.unicode();
        kana += (u >= 0x3040 && u <= 0x30FF);
        hangul += (u >= 0xAC00 && u <= 0xD7A3);
        han += ((u >= 0x4E00 && u <= 0x9FFF) || (u >= 0x3400 && u <= 0x4DBF));
    }
    if (letters < 20)
        return false;
    if (lang == QLatin1String("en"))
        return (kana + hangul + han) / letters > 0.08;
    if (lang == QLatin1String("ja"))
        return kana / letters < 0.05;
    if (lang == QLatin1String("ko"))
        return hangul / letters < 0.05;
    return han / letters < 0.2 || kana / letters > 0.05; // zh
}

// "Alright by Kendrick Lamar, but it will change your life": the song and artist named in an edit's title.
inline bool splitBy(const QString &title, QString &song, QString &artist)
{
    static const QRegularExpression by(
        QStringLiteral(R"(^(.+?)\s+by\s+([^,(\[|]{3,}?)\s*(?:[,(\[|]|\s-\s|$))"), QRegularExpression::CaseInsensitiveOption);
    const auto m = by.match(title.simplified());
    if (!m.hasMatch() || !m.captured(2).front().isUpper())
        return false;
    song = m.captured(1).simplified();
    artist = m.captured(2).simplified();
    return true;
}

// A remix, edit, mashup or fan edit of another song: its length and structure differ from the original.
inline bool editLike(const QString &title)
{
    static const QRegularExpression words(
        QStringLiteral(R"(\b(remix|re-?edit|mashup|mash-up|edit|bootleg|rework|flip|vip|extended|fan ?(made|edit)|nightcore|sped[ -]?up|slowed)\b)"),
        QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression byComma(QStringLiteral(R"(\sby\s[^,]+,\s)"), QRegularExpression::CaseInsensitiveOption);
    return words.match(title).hasMatch() || byComma.match(title).hasMatch();
}

// Longest stretch (s) between two stamps. Community-uploaded copies sometimes lack a whole verse,
// leaving the last line stuck on screen; real instrumental breaks are rarely over ~45 s.
inline double maxStampGap(const QString &lrc)
{
    static const QRegularExpression stamp(QStringLiteral(R"(\[(\d+):(\d+(?:\.\d+)?)\])"));
    double prev = -1, best = 0;
    for (auto it = stamp.globalMatch(lrc); it.hasNext();) {
        const auto m = it.next();
        const double s = m.captured(1).toInt() * 60 + m.captured(2).toDouble();
        if (prev >= 0)
            best = std::max(best, s - prev);
        prev = s;
    }
    return best;
}
inline bool incompleteLrc(const QString &lrc) { return maxStampGap(lrc) > 50; }

// Mostly Japanese / Chinese / Korean text (not just an emoji or a fullwidth punctuation mark).
inline bool isCjk(const QString &s)
{
    int n = 0;
    for (const QChar c : s) {
        const ushort u = c.unicode();
        n += (u >= 0x3040 && u <= 0x30FF) || (u >= 0x4E00 && u <= 0x9FFF) || (u >= 0xAC00 && u <= 0xD7A3);
    }
    return n >= 8;
}

inline bool hasNonLatin(const QString &s)
{
    for (const QChar c : s)
        if (c.unicode() >= 0x3040)
            return true; // kana, Hangul, Han and everything above Latin/Greek/Cyrillic ranges
    return false;
}

} // namespace Text
