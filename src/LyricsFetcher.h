#pragma once
#include <QJsonDocument>
#include <QJsonObject>
#include <QHash>
#include <QList>
#include <QUrl>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QObject>
#include <QPointer>
#include <functional>
#include <memory>

#include "Text.h"

struct LyricsResult {
    bool found = false;
    bool instrumental = false;
    bool networkError = false; // transient failure: do NOT cache
    bool degraded = false;     // usable, but a provider failed that would have added romanization: retry, don't cache
    QString synced;            // LRC
    QString plain;
    QString roman;             // LRC from the provider (NetEase romalrc); may be empty
    double srcDur = 0;         // length (s) of the version the lyrics were timed against
    QString sourceId;          // "lrclib:123", "netease:456"...: lets a lookup skip results already shown
    QString provider;          // "lrclib" / "netease" / "qq": who the chosen lyrics came from
    double conf = 0;           // how well it matched the track; the best match across providers wins
};

// Looks a track up on LRCLIB, NetEase and QQ Music in parallel. LRCLIB is the main source (huge, synced,
// community-corrected); NetEase adds the CJK catalogue plus provider romanization.
// A usable result is emitted as soon as one arrives (final=false) and upgraded when the other
// provider finishes; Latin-script lyrics from LRCLIB are final immediately.
class LyricsFetcher : public QObject
{
    Q_OBJECT
public:
    explicit LyricsFetcher(QObject *parent = nullptr);

    // Cancels any lookup in flight. Results arrive via result().
    quint64 lookup(const Track &t);
    // NetEase only: word timing and romanization for lyrics that came from another source
    quint64 lookupExtras(const Track &t);

signals:
    void result(quint64 id, const LyricsResult &r, bool final);

private:
    struct Job;
    using JobPtr = std::shared_ptr<Job>;
    using Reply = std::function<void(bool ok, bool notFound, const QByteArray &body)>;
    struct Gather { // best hit across the parallel candidate searches of one provider
        int pending = 0;
        bool failed = false;
        double score = -1, dur = 0;
        QString id;
        QJsonObject obj;
        // LRCLIB only: best original-script and best romaji-only synced versions (romaji = romanization)
        QJsonObject script, alt;
        QString plain;   // fullest plain lyrics among the good matches
        double scriptScore = -1, altScore = -1;
    };
    using SearchUrl = std::function<QUrl(const Candidate &)>;
    using SearchParse = std::function<void(const QJsonDocument &, const Candidate &, Gather &)>;
    using SearchDone = std::function<void(const Gather &)>;

    void rememberDownload(const QUrl &url, const QByteArray &body);
    void get(const JobPtr &job, const QUrl &url, Reply cb, int attempt = 0);
    void send(const JobPtr &job, const QUrl &url, Reply cb, int attempt);
    void searchAll(const JobPtr &job, int maxCands, SearchUrl url, SearchParse parse, SearchDone done);
    void start(const JobPtr &job); // runs every provider for the job
    void lrclib(const JobPtr &job);
    void netease(const JobPtr &job);
    void neteaseLyric(const JobPtr &job, qint64 songId, double conf, double dur);
    void qq(const JobPtr &job);
    void kugou(const JobPtr &job);
    void finishKugou(const JobPtr &job, const LyricsResult &r);
    void qqLyric(const JobPtr &job, const QString &mid, double conf, double dur);
    void finishLrclib(const JobPtr &job, const LyricsResult &r);
    void finishNetease(const JobPtr &job, const LyricsResult &r);
    void finishQq(const JobPtr &job, const LyricsResult &r);
    void publish(const JobPtr &job);
    void ytmusic(const JobPtr &job); // plain lyrics of the playing YouTube Music video (last resort)

    quint64 lookupTransition(const Track &t, const Track &a, const Track &b);

    QList<LyricsFetcher *> m_parts; // the two sub-lookups of a transition mix
    QNetworkAccessManager m_nam;
    static QHash<QString, qint64> &nextSlot();               // host -> earliest next request (ms)
    QHash<QUrl, QPair<qint64, QByteArray>> m_memo;          // url -> (time, body) of recent good answers
    quint64 m_nextId = 0;
    quint64 m_current = 0;
};
