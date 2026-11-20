// Checks for src/LocalFiles.h: lyric files, lyrics inside MP3 and FLAC files, chapter files. Files are made in a temp folder.
#include "LocalFiles.h"

#include <QCoreApplication>
#include <QTemporaryDir>
#include <cstdio>

static int failures = 0;
#define CHECK(cond) do { if (!(cond)) { ++failures; std::printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, #cond); } } while (0)

static QByteArray B(std::initializer_list<int> v) { QByteArray b; for (int x : v) b.append(char(x & 0xff)); return b; }
static void write(const QString &path, const QByteArray &data) { QFile f(path); (void)f.open(QIODevice::WriteOnly); f.write(data); }
static QByteArray ss(quint32 n) { return B({int((n >> 21) & 0x7f), int((n >> 14) & 0x7f), int((n >> 7) & 0x7f), int(n & 0x7f)}); }
static QByteArray b32(quint32 n) { return B({int(n >> 24), int(n >> 16), int(n >> 8), int(n)}); }
static QByteArray frame(const QByteArray &id, const QByteArray &data, bool v24) { return id + (v24 ? ss(data.size()) : b32(data.size())) + QByteArray(2, '\0') + data; }
static QByteArray tag(int ver, const QByteArray &frames) { return QByteArray("ID3") + char(ver) + char(0) + char(0) + ss(frames.size()) + frames; }

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    QTemporaryDir dir;
    const QString d = dir.path();

    // a sidecar .lrc: same name, or "name.ext.lrc"; a lyrics folder by "Artist - Title"
    write(d + "/a.mp3", "x"); write(d + "/a.lrc", "[00:01.00]hi\n");
    CHECK(LocalFiles::findLrc(d + "/a.mp3", {}, "T", "A") == d + "/a.lrc");
    write(d + "/b.flac", "x"); write(d + "/b.flac.lrc", "[00:01.00]hi\n");
    CHECK(LocalFiles::findLrc(d + "/b.flac", {}, "T", "A") == d + "/b.flac.lrc");
    QDir().mkpath(d + "/lyr"); write(d + "/lyr/Some Artist - Some Song.lrc", "[00:01.00]hi\n");
    CHECK(LocalFiles::findLrc({}, d + "/lyr", "Some Song", "Some Artist").endsWith("Some Artist - Some Song.lrc"));
    CHECK(LocalFiles::findLrc({}, d + "/lyr", "Other", "X").isEmpty() && LocalFiles::findLrc(d + "/nothing.mp3", {}, "T", "A").isEmpty());
    write(d + "/a.romaji.lrc", "[00:01.00]hello\n");
    CHECK(LocalFiles::findReading(d + "/a.lrc") == d + "/a.romaji.lrc");

    // ID3v2.4: plain lyrics (UTF-8) and timed lyrics; the timed ones win and become LRC
    QByteArray uslt = QByteArray(1, 3) + "eng" + QByteArray(1, '\0') + "first line\nsecond line";   // empty descriptor, then the text
    QByteArray sylt = QByteArray(1, 3) + "eng" + char(2) + char(1) + QByteArray(1, '\0');
    auto entry = [](const QByteArray &t, quint32 ms) { return t + QByteArray(1, '\0') + b32(ms); };
    sylt += entry("Hello ", 1000) + entry("world", 1500) + entry("\nSecond line", 4000);
    CHECK(LocalFiles::id3Lyrics(tag(4, frame("USLT", uslt, true))) == "first line\nsecond line");
    const QString lrc = LocalFiles::id3Lyrics(tag(4, frame("USLT", uslt, true) + frame("SYLT", sylt, true)));
    CHECK(lrc == QString::fromUtf8("[00:01.00]Hello world\n[00:04.00]Second line\n"));
    // ID3v2.3, UTF-16 with a byte order mark
    QByteArray u16 = QByteArray(1, 1) + "eng" + QByteArray(2, '\0') + QByteArray("\xFF\xFE", 2) + QByteArray("h\0i\0", 4);
    CHECK(LocalFiles::id3Lyrics(tag(3, frame("USLT", u16, false))) == "hi");
    CHECK(LocalFiles::id3Lyrics("not a tag").isEmpty());
    // from a file
    write(d + "/song.mp3", tag(4, frame("USLT", uslt, true)) + QByteArray(100, '\x55'));
    CHECK(LocalFiles::embeddedLyrics(d + "/song.mp3") == "first line\nsecond line");

    // FLAC: a Vorbis comment block holds LYRICS
    auto le32 = [](quint32 n) { return B({int(n), int(n >> 8), int(n >> 16), int(n >> 24)}); };
    const QByteArray c1 = "TITLE=Song", c2 = "LYRICS=[00:02.00]flac line";
    QByteArray vc = le32(3) + "abc" + le32(2) + le32(c1.size()) + c1 + le32(c2.size()) + c2;
    QByteArray flac = QByteArray("fLaC") + char(0x84) + B({int(vc.size() >> 16), int(vc.size() >> 8), int(vc.size())}) + vc;
    write(d + "/song.flac", flac);
    CHECK(LocalFiles::embeddedLyrics(d + "/song.flac") == "[00:02.00]flac line");
    CHECK(LocalFiles::embeddedLyrics(d + "/a.lrc").isEmpty());

    // chapters: OGM text and a cue sheet; sorted, duplicates dropped, cut to the length
    write(d + "/ch.mp3", "x");
    write(d + "/ch.chapters", "CHAPTER02=00:02:00.000\nCHAPTER02NAME=Second\nCHAPTER01=00:00:00.000\nCHAPTER01NAME=First\nCHAPTER03=00:09:00.000\n");
    auto ch = LocalFiles::chaptersFor(d + "/ch.mp3", 300);
    CHECK(ch.size() == 2 && ch[0].title == "First" && ch[1].start == 120 && ch[1].title == "Second");
    write(d + "/cd.mp3", "x");
    write(d + "/cd.cue", "FILE \"cd.mp3\" MP3\n  TRACK 01 AUDIO\n    TITLE \"One\"\n    INDEX 01 00:00:00\n  TRACK 02 AUDIO\n    TITLE \"Two\"\n    INDEX 01 03:30:37\n");
    auto cue = LocalFiles::chaptersFor(d + "/cd.mp3");
    CHECK(cue.size() == 2 && cue[1].title == "Two" && std::abs(cue[1].start - (210 + 37 / 75.0)) < 1e-6);
    CHECK(LocalFiles::chaptersFor(d + "/none.mp3").isEmpty());
    CHECK(std::abs(LocalFiles::clock("01:02:03.5") - 3723.5) < 1e-9 && LocalFiles::clock("83.5") == 83.5);

    return failures ? 1 : 0;
}
