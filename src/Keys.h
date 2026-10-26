#pragma once
#include <QUrl>
#include <QUrlQuery>

#include "Text.h"

// How a song is identified in the cache and the lyrics library: the same recording always gets the same key.
namespace Keys {

// YouTube: watch?v=ID. Spotify: /track/ID. Stable per recording, so a song and its music video
// (different uploads, different timing) never share an entry.
inline QString trackId(const QString &url)
{
    const QUrl u(url);
    if (u.host().contains(QLatin1String("youtube")))
        return QUrlQuery(u).queryItemValue(QStringLiteral("v"));
    if (u.host().contains(QLatin1String("spotify")))
        return u.path().section(QLatin1Char('/'), -1);
    return {};
}

inline QString songKey(const Track &t)
{
    return !t.id.isEmpty() ? QStringLiteral("id:") + t.id
                           : Text::norm(t.artist) + QLatin1Char('|') + Text::norm(t.title) + QLatin1Char('|')
                                 + QString::number(t.durationSec);
}

} // namespace Keys
