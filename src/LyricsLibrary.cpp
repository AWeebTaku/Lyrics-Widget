#include "LyricsLibrary.h"

#include "Keys.h"
#include "LrcParser.h"

#include <QTimer>
#include <algorithm>
#include <cmath>

LyricsLibrary::LyricsLibrary(QObject *parent) : QObject(parent), m_watcher(this), m_fetcher(this)
{
    connect(&m_watcher, &PlayerWatcher::trackChanged, this, &LyricsLibrary::onTrack);
    connect(&m_fetcher, &LyricsFetcher::result, this, [this](quint64 id, const LyricsResult &r, bool final) {
        if (id != m_searchId || !final)
            return;
        m_searchId = 0;
        QString text = !r.synced.isEmpty() ? r.synced : r.plain;
        if (text.isEmpty()) {
            setStatus(tr("Nothing found for that title and artist."));
            return;
        }
        QString note = tr("Found %1 lyrics from %2.").arg(!r.synced.isEmpty() ? tr("timed") : tr("untimed"), r.provider);
        // A remix or edit has the original's lyrics over a different length: spread them over this song's
        const double k = (r.srcDur > 0 && m_track.durationSec > 0) ? m_track.durationSec / r.srcDur : 1;
        if (m_stretchToSong && !r.synced.isEmpty() && k > 0.3 && k < 3.2 && std::abs(k - 1) > 0.03) {
            text = Lrc::mapStamps(text, [k](qint64 ms) { return qint64(ms * k); });
            note += tr(" Stretched by %1% to fit this song's length: use Fit to line them up.").arg(int(k * 100 + 0.5));
        } else {
            note += tr(" Check them, then save.");
        }
        setStatus(note);
        emit found(text, r.provider);
    });
    QTimer::singleShot(0, this, [this] { m_watcher.start(); });
}

void LyricsLibrary::setStatus(const QString &s, bool busy)
{
    m_status = s;
    m_busy = busy;
    emit statusChanged();
}

void LyricsLibrary::onTrack()
{
    const MprisPlayer *p = m_watcher.active();
    Track t;
    if (p && !p->title().isEmpty()) {
        t.title = p->title();
        t.artist = p->artist();
        t.album = p->album();
        t.id = Keys::trackId(p->url());
        t.durationSec = int(p->lengthUs() / 1'000'000);
    }
    const QString key = t.title.isEmpty() ? QString() : Keys::songKey(t);
    m_track = t;
    if (key == m_key && !key.isEmpty()) {
        emit trackChanged();
        return;
    }
    m_key = key;
    const bool had = m_saved;
    m_saved = !key.isEmpty() && m_store.library(key).has_value();
    emit trackChanged();
    if (had != m_saved)
        emit savedChanged();
}

QString LyricsLibrary::load()
{
    if (m_key.isEmpty())
        return {};
    if (const auto e = m_store.library(m_key))
        return !e->synced.isEmpty() ? e->synced : e->plain;
    if (const auto c = m_store.get(m_key))
        return !c->synced.isEmpty() ? c->synced : c->plain;
    return {};
}

void LyricsLibrary::search(const QString &title, const QString &artist)
{
    Track t = m_track;
    t.title = title.trimmed();
    t.artist = artist.trimmed();
    // An edit names the original ("Alright by Kendrick Lamar, but ..."): look that song up instead
    QString song, by;
    if (Text::splitBy(t.title, song, by)) {
        t.title = song;
        t.artist = by;
    }
    m_stretchToSong = Text::editLike(title) || Text::tempoVariant(title) != 0;
    t.id.clear();  // a search by name, not tied to the playing video
    t.prefer.clear();
    if (t.title.isEmpty()) {
        setStatus(tr("Enter a title first."));
        return;
    }
    setStatus(tr("Searching…"), true);
    m_searchId = m_fetcher.lookup(t);
}

bool LyricsLibrary::save(const QString &text, const QString &title, const QString &artist)
{
    if (m_key.isEmpty()) {
        setStatus(tr("Play the song first: lyrics are saved for the song that is playing."));
        return false;
    }
    if (text.trimmed().isEmpty()) {
        setStatus(tr("There are no lyrics to save."));
        return false;
    }
    LibraryEntry e;
    e.key = m_key;
    e.title = title.trimmed().isEmpty() ? m_track.title : title.trimmed();
    e.artist = artist.trimmed().isEmpty() ? m_track.artist : artist.trimmed();
    e.album = m_track.album;
    e.durationSec = m_track.durationSec;
    e.lang = Text::languageHint(m_track.title);
    e.source = QStringLiteral("edited");
    if (Text::usableLrc(text)) {
        e.synced = text;
        for (const LyricLine &l : Lrc::parse(text))
            e.plain += l.text + QLatin1Char('\n');
    } else {
        e.plain = text;
    }
    m_store.putLibrary(e);
    m_saved = true;
    emit savedChanged();
    setStatus(e.synced.isEmpty() ? tr("Saved as untimed lyrics.") : tr("Saved. The widget uses it now."));
    return true;
}

void LyricsLibrary::remove()
{
    if (m_key.isEmpty())
        return;
    m_store.removeLibrary(m_key);
    m_saved = false;
    emit savedChanged();
    setStatus(tr("Removed from the library. The widget looks the song up again."));
}

QString LyricsLibrary::retime(const QString &text, double percent, int shiftMs) const
{
    const double k = percent / 100.0;
    return Lrc::mapStamps(text, [k, shiftMs](qint64 ms) { return qint64(ms * k) + shiftMs; });
}

QVariantMap LyricsLibrary::timing(const QString &text) const
{
    const auto lines = Lrc::parse(text);
    if (lines.isEmpty())
        return {{QStringLiteral("lines"), 0}, {QStringLiteral("first"), 0.0}, {QStringLiteral("last"), 0.0}};
    return {{QStringLiteral("lines"), int(lines.size())}, {QStringLiteral("first"), lines.first().timeMs / 1000.0},
            {QStringLiteral("last"), lines.last().timeMs / 1000.0}};
}

QString LyricsLibrary::fit(const QString &text, double firstSec, double lastSec) const
{
    const auto lines = Lrc::parse(text);
    if (lines.size() < 2 || lastSec <= firstSec)
        return text;
    const double a = lines.first().timeMs, b = lines.last().timeMs;
    if (b <= a)
        return text;
    const double na = firstSec * 1000, nb = lastSec * 1000;
    return Lrc::mapStamps(text, [=](qint64 ms) { return qint64(na + (ms - a) * (nb - na) / (b - a)); });
}
