#include "ReadingFetcher.h"

#include "Text.h"

#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QUrl>
#include <QUrlQuery>
#include <memory>

struct ReadingFetcher::State {
    QString title;
    QStringList lines, links;
    int next = 0;
    Cb cb;
};

namespace {
QString unescape(QString s)
{
    s.replace(QLatin1String("&amp;"), QLatin1String("&")).replace(QLatin1String("&lt;"), QLatin1String("<"))
        .replace(QLatin1String("&gt;"), QLatin1String(">")).replace(QLatin1String("&quot;"), QLatin1String("\""))
        .replace(QLatin1String("&#039;"), QLatin1String("'")).replace(QLatin1String("&#39;"), QLatin1String("'"))
        .replace(QLatin1String("&nbsp;"), QLatin1String(" "));
    return s;
}

QNetworkRequest request(const QUrl &u)
{
    QNetworkRequest r(u);
    r.setHeader(QNetworkRequest::UserAgentHeader,
                QStringLiteral("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120 Safari/537.36"));
    r.setTransferTimeout(8000);
    return r;
}
}

ReadingFetcher::ReadingFetcher(QObject *parent) : QObject(parent) {}

QStringList ReadingFetcher::parsePage(const QString &html)
{
    static const QRegularExpression block(QStringLiteral(R"(<div class="hiragana"[^>]*>(.*?)</div>)"),
                                          QRegularExpression::DotMatchesEverythingOption);
    static const QRegularExpression ruby(
        QStringLiteral(R"(<span class="ruby"><span class="rb">(.*?)</span><span class="rt">(.*?)</span></span>)"),
        QRegularExpression::DotMatchesEverythingOption);
    static const QRegularExpression br(QStringLiteral(R"(<br\s*/?>)"));
    static const QRegularExpression tag(QStringLiteral(R"(<[^>]+>)"));
    const auto m = block.match(html);
    if (!m.hasMatch())
        return {};
    QString t = m.captured(1);
    t.replace(ruby, QStringLiteral("\\1(\\2)"));
    t.replace(br, QStringLiteral("\n"));
    t.remove(tag);
    QStringList out;
    for (const QString &l : unescape(t).split(QLatin1Char('\n')))
        out << l.simplified();
    return out;
}

// Matches each of our lyric lines to the reading text, in order. The pages break lines differently
// (one of ours can be half a line of theirs, or two joined), so both sides are compared as runs of
// space-separated pieces: a lyric line takes the shortest run of pieces that reads the same once the
// "(かな)" is removed. That also proves the page is the same song.
QStringList ReadingFetcher::align(const QStringList &lines, const QStringList &reading, int *matched)
{
    static const QRegularExpression kana(QStringLiteral(R"(\([\x{3040}-\x{30FF}ー]+\))"));
    QStringList seg, segPlain;
    for (const QString &l : reading)
        for (const QString &p : l.split(QLatin1Char(' '), Qt::SkipEmptyParts)) {
            seg << p;
            QString q = p;
            segPlain << q.remove(kana);
        }
    QStringList out;
    out.resize(lines.size());
    int pos = 0, hit = 0, total = 0;
    for (qsizetype i = 0; i < lines.size(); ++i) {
        const QString want = Text::norm(lines[i]);
        if (want.size() < 2)
            continue;
        ++total;
        double best = 0.9;
        int bs = -1, bk = 0;
        for (int s = pos; s < std::min<int>(seg.size(), pos + 10); ++s) {
            QString cat;
            for (int k = 0; k < 14 && s + k < seg.size(); ++k) {
                cat += segPlain[s + k];
                const QString have = Text::norm(cat);
                const double sim = Text::similarityRaw(lines[i], cat);
                if (sim > best + 1e-9) {
                    best = sim;
                    bs = s;
                    bk = k + 1;
                }
                if (have.size() > want.size() * 1.3)
                    break;
            }
        }
        if (bs >= 0) {
            out[i] = seg.mid(bs, bk).join(QLatin1Char(' '));
            pos = bs + bk;
            ++hit;
        }
    }
    if (matched)
        *matched = total ? hit * 100 / total : 0;
    return out;
}

void ReadingFetcher::fetch(const QString &title, const QStringList &lines, Cb cb)
{
    auto st = std::make_shared<State>();
    st->title = title;
    st->lines = lines;
    st->cb = std::move(cb);
    QUrl u(QStringLiteral("https://utaten.com/search"));
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("sort"), QStringLiteral("popular_sort_asc"));
    q.addQueryItem(QStringLiteral("title"), title);
    u.setQuery(q);
    QNetworkReply *r = m_nam.get(request(u));
    connect(r, &QNetworkReply::finished, this, [this, r, st] {
        r->deleteLater();
        static const QRegularExpression link(QStringLiteral(R"re(href="(/lyric/[^"]+)")re"));
        const QString html = QString::fromUtf8(r->readAll());
        for (auto it = link.globalMatch(html); it.hasNext() && st->links.size() < 4;) {
            const QString l = it.next().captured(1);
            if (!st->links.contains(l))
                st->links << l;
        }
        tryNext(st);
    });
}

void ReadingFetcher::tryNext(const std::shared_ptr<State> &st)
{
    if (st->next >= st->links.size()) {
        st->cb({});
        return;
    }
    QNetworkReply *r = m_nam.get(request(QUrl(QStringLiteral("https://utaten.com") + st->links[st->next++])));
    connect(r, &QNetworkReply::finished, this, [this, r, st] {
        r->deleteLater();
        const QStringList reading = parsePage(QString::fromUtf8(r->readAll()));
        int pct = 0;
        const QStringList aligned = align(st->lines, reading, &pct);
        if (pct >= 60) {
            st->cb(aligned);
            return;
        }
        tryNext(st);
    });
}
