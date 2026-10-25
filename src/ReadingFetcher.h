#pragma once
#include <QNetworkAccessManager>
#include <QObject>
#include <QStringList>
#include <functional>

// How Japanese lyrics are really read. UtaTen publishes lyrics with the reading of every kanji written
// above it (furigana), made by people, so songs with unusual readings (飛翔 sung "habata") come out right.
// Finds the song by title, checks the page really is the same song by comparing its lines with the lyrics
// we already have, and returns one line per input line as "飛翔(はばた)いたら ..." (empty = no match).
class ReadingFetcher : public QObject
{
    Q_OBJECT
public:
    explicit ReadingFetcher(QObject *parent = nullptr);
    using Cb = std::function<void(const QStringList &readings)>; // empty list = nothing found
    void fetch(const QString &title, const QStringList &lines, Cb cb);

    // exposed for the test: furigana HTML -> "漢字(かんじ)" text lines
    static QStringList parsePage(const QString &html);
    static QStringList align(const QStringList &lines, const QStringList &reading, int *matched = nullptr);

private:
    struct State;
    void tryNext(const std::shared_ptr<State> &st);

    QNetworkAccessManager m_nam;
};
