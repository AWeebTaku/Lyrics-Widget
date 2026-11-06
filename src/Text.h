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
    QStringList alt; // other names of the song (YouTube Music's title in the original script, the album): searched too
    QString lang;   // "en" / "ja" / "ko" / "zh" when the title says which language version this is, else empty
    QStringList skip;      // sources ("lrclib:12", "netease:34"...) not to pick again: lets a lookup return the next-best lyrics
    bool onlySynced = false; // ignore results without timestamps
    QString prefer; // provider that usually has this artist's lyrics ("lrclib"/"netease"/"qq"), may be empty
    bool loose = false; // second pass, after the exact artist + title search found nothing: broader guesses
};

struct Candidate {
    QString artist, title;
    bool strict = false; // title alone (no artist to check): the length has to match almost exactly
    bool boxed = false; // the song was named in 【】 of a fan upload (AMV/MAD): the video's length and channel are not the song's
    bool operator==(const Candidate &o) const { return artist == o.artist && title == o.title; }
};

namespace Text {

inline bool hasNonLatin(const QString &s);
inline QString norm(const QString &s);
inline double similarity(const QString &a, const QString &b);

inline QString cleanTitle(QString t)
{
    // Styled text ("𝗪𝗢𝗥𝗞", full-width letters) becomes plain letters, as the lyric databases have it
    t = t.normalized(QString::NormalizationForm_KC);
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
        QStringLiteral(R"(\s+(mv|m/v|official( music)? video|lyrics?( video)?|audio|hd|4k|full( song| version| audio)?)\s*$)"),
        QRegularExpression::CaseInsensitiveOption);
    // "【AMV/MAD】", "【歌ってみた】", "(MMD)": what kind of upload it is, not part of the song
    static const QRegularExpression kind(
        QStringLiteral(R"re(\s*[\(\[\{（【]\s*(?:amv|mad|mad動画|アニメmad|音mad|mmd|pv|mv|歌ってみた|弾いてみた|叩いてみた|踊ってみた|手描き|cover)(?:\s*[/／・&+,]\s*(?:amv|mad|mad動画|アニメmad|音mad|mmd|pv|mv|歌ってみた|弾いてみた|叩いてみた|踊ってみた|手描き|cover))*\s*[\)\]\}）】]\s*)re"),
        QRegularExpression::CaseInsensitiveOption);
    t.remove(site);
    t.remove(kind);
    t.remove(bracket);
    t.remove(tail);
    t.remove(dashTail);
    t.remove(ft);
    return t.simplified();
}

inline QString cleanArtist(QString a)
{
    a = a.normalized(QString::NormalizationForm_KC);
    // Some uploads write a name in decorative letters from an unrelated script (Yi syllables standing in for
    // Latin letters): nobody can search for that, and the real names are usually in the same credit
    auto plausible = [](const QString &name) {
        for (const QChar ch : name) {
            if (!ch.isLetter())
                continue;
            switch (ch.script()) {
            case QChar::Script_Latin: case QChar::Script_Han: case QChar::Script_Hiragana: case QChar::Script_Katakana:
            case QChar::Script_Hangul: case QChar::Script_Cyrillic: case QChar::Script_Greek: case QChar::Script_Arabic:
            case QChar::Script_Hebrew: case QChar::Script_Thai: case QChar::Script_Devanagari:
                break;
            default:
                return false;
            }
        }
        return true;
    };
    if (a.contains(QLatin1Char(','))) {
        QStringList keep;
        for (const QString &part : a.split(QLatin1Char(','))) // ponytail: names containing a comma are not split further
            if (plausible(part))
                keep << part.trimmed();
        if (!keep.isEmpty())
            a = keep.join(QStringLiteral(", "));
    } else if (!plausible(a)) {
        a.clear();
    }
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

    // Fan uploads: "Anime【Song】" (after the upload-kind tag is gone): the song is in the brackets
    static const QRegularExpression boxed(QStringLiteral(R"(^(.+?)\s*【(.+?)】\s*$)"));
    const auto bm = boxed.match(title);
    if (bm.hasMatch() && !bm.captured(2).simplified().isEmpty()) {
        const Candidate c{QString(), bm.captured(2).simplified(), true}; // the channel is the uploader, not the singer
        if (!out.contains(c))
            out.push_back(c);
    }

    // Japanese uploads: "Artist「Song」"
    static const QRegularExpression kakko(QStringLiteral(R"(^(.*?)\s*[「『](.+?)[」』])"));
    const auto km = kakko.match(title);
    // "Artist - Song" where the player's artist is neither side of the dash is an upload by a channel (a
    // slowed/sped-up edit, a cover): the dash split is the real credit, even when the player lists an album
    const bool uploader = split && !artist.isEmpty() && similarity(artist, left) < 0.5 && similarity(artist, right) < 0.5;
    const bool videoLike = t.album.isEmpty() || uploader;
    if (km.hasMatch() && !km.captured(2).isEmpty()) {
        add(cleanArtist(km.captured(1)), km.captured(2).simplified());
        if (!km.captured(1).isEmpty() && videoLike)
            add(QString(), km.captured(2).simplified());
    }
    if (split && videoLike) {
        add(left, right);
        add(right, left); // "Song - Artist" ordering
    }
    // "W●R K - WORK" on the album WORK: the part after the dash is the real title, the first part is styling
    if (split && !t.album.isEmpty() && norm(right) == norm(cleanTitle(t.album)))
        add(artist, right);
    add(artist, title);
    if (split)
        add(artist, right);
    if (split && !videoLike) {
        add(left, right);
        add(right, left);
    }
    // Title alone is a first guess only when the player gave no usable artist: otherwise another artist's song of
    // the same name and about the same length passes for this one. The loose pass (nothing found yet) tries it,
    // with the length having to match almost exactly, and the artist with its letters joined ("K E T N E L").
    if (artist.isEmpty() || videoLike)
        add(QString(), title);
    if (t.loose) {
        QVector<Candidate> extra;
        const QStringList letters = artist.split(QLatin1Char(' '), Qt::SkipEmptyParts);
        const bool spaced = letters.size() >= 3 && std::all_of(letters.cbegin(), letters.cend(), [](const QString &w) { return w.size() == 1; });
        if (spaced)
            extra.push_back({letters.join(QString()), title});
        if (!artist.isEmpty() && !videoLike)
            extra.push_back({QString(), title, true});
        for (int i = int(extra.size()) - 1; i >= 0; --i)
            if (!out.contains(extra[i]))
                out.push_front(extra[i]); // the strict guesses already failed: these are searched first
    }

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
    // The song's other names (e.g. the Japanese title behind an English one): right after the first guess
    for (const QString &a : t.alt) {
        const QString at = cleanTitle(a);
        bool known = at.isEmpty();
        for (const Candidate &c : std::as_const(out))
            known |= norm(c.title) == norm(at);
        if (!known)
            out.insert(std::min<qsizetype>(1, out.size()), {artist, at});
    }
    // several artists ("A, B", "A & B", "A feat. B", "A × B"): the databases often list only the first or the
    // main one, so each of the first two is also tried alone, right after the full credit
    static const QRegularExpression artistSep(
        QStringLiteral(R"(\s*(?:,|&|、|／|/|×|;|\s+x\s+|\s+and\s+|\s+with\s+|\s+(?:feat|ft)\.?\s+)\s*)"),
        QRegularExpression::CaseInsensitiveOption);
    for (qsizetype i = 0; i < out.size() && out.size() < 8; ++i) {
        const QStringList parts = out[i].artist.split(artistSep, Qt::SkipEmptyParts);
        if (parts.size() < 2)
            continue;
        qsizetype at = i + 1;
        // "Artist - Song" vs "Song - Artist" is a guess whose swapped twin follows: the pieces go after the twin
        // ("Come With Me Now" is a title, not "Come" + "Me Now")
        if (at < out.size() && out[at].artist == out[i].title && out[at].title == out[i].artist)
            ++at;
        for (int k = 0; k < 2; ++k) {
            const Candidate c{parts[k].simplified(), out[i].title};
            if (!c.artist.isEmpty() && !out.contains(c))
                out.insert(at++, c);
        }
        i = at - 1;
    }
    if (out.size() > 8)
        out.resize(8);
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
    if (want.boxed && ts < 0.9)
        return -1; // nothing but the name vouches for it: it has to be (nearly) exact
    if (want.artist.isEmpty() && !want.boxed && !(wantSec > 0 && durSec > 0 && std::abs(durSec - wantSec) <= (want.strict ? 2 : 6)))
        return -1;
    double s = 0.6 * ts + 0.4 * as;
    if (wantSec > 0 && durSec > 0) {
        const double d = std::abs(durSec - wantSec);
        s += d <= 2 ? 0.2 : d <= 6 ? 0.1 : d > 15 && !want.boxed ? -0.3 : 0; // an AMV is a cut of the song: no penalty
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

// "guilty as sin x about you || taylor swift & the 1975 (transition)": a mix of two songs played back to back.
// Fills a and b with the two tracks (title + artist each), in playing order.
inline bool splitTransition(const Track &t, Track &a, Track &b)
{
    static const QRegularExpression re(
        QStringLiteral(R"(^(.+?)\s+x\s+(.+?)\s*\|\|\s*(.+?)\s*(?:&|\bx\b)\s*(.+?)\s*[\(\[]transition[\)\]])"),
        QRegularExpression::CaseInsensitiveOption);
    const auto m = re.match(t.title.simplified());
    if (!m.hasMatch())
        return false;
    a = b = Track();
    a.title = m.captured(1).simplified(); a.artist = m.captured(3).simplified();
    b.title = m.captured(2).simplified(); b.artist = m.captured(4).simplified();
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
