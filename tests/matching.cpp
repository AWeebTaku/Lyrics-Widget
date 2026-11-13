// Table-driven checks for the lyric matching in src/Text.h and the LRC helpers. No framework: exit code 1 on failure.
// Build and run:  cmake -B build -S . -G Ninja -DBUILD_TESTS=ON && cmake --build build && ctest --test-dir build --output-on-failure
#include "LrcParser.h"
#include "Text.h"

#include <cstdio>

static int failures = 0;
#define CHECK(cond) do { if (!(cond)) { ++failures; std::printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, #cond); } } while (0)

static Track track(const QString &title, const QString &artist, const QString &album = {}, int sec = 0)
{
    Track t;
    t.title = title; t.artist = artist; t.album = album; t.durationSec = sec;
    return t;
}
static bool has(const QVector<Candidate> &c, const QString &artist, const QString &title, int within = 99)
{
    for (int i = 0; i < c.size() && i < within; ++i)
        if (c[i].artist == artist && c[i].title == title)
            return true;
    return false;
}
static bool titleOnly(const QVector<Candidate> &c)
{
    for (const Candidate &x : c)
        if (x.artist.isEmpty())
            return true;
    return false;
}

int main()
{
    // where the singing starts: credits and the title banner do not count
    CHECK(Text::firstVocalMs(QStringLiteral("[00:00.00]Loco Papi (Extended Mix) - Sevenn\n[00:12.96]Composed by\uFF1AKevin\n[00:25.92]Go loco loco\n")) == 25920);
    CHECK(Text::firstVocalMs(QStringLiteral("[00:02.06] Go loco loco\n[00:06.12] Go loco loco\n")) == 2060);
    CHECK(Text::firstVocalMs(QStringLiteral("no stamps")) == -1);

    // a TV-size opening: the song is the quote after "OPテーマ：", the show's name is not a song, and the 90 s video
    // may match the full 200 s lyrics (the length is ignored for a cut)
    {
        const Track t = track(QString::fromUtf8("TVアニメ『呪術廻戦』第2期「懐玉・玉折」ノンクレジットOPムービー／OPテーマ：キタニタツヤ「青のすみか」｜毎週木曜夜11時56分～MBS/TBS系列全国28局にて放送中!!"), QString(), QString(), 90);
        const auto c = Text::candidates(t);
        CHECK(has(c, QString::fromUtf8("キタニタツヤ"), QString::fromUtf8("青のすみか"), 2));
        bool allBoxed = !c.isEmpty();
        for (const Candidate &x : c)
            allBoxed &= x.boxed;
        CHECK(allBoxed);
        const Candidate &first = c.first();
        CHECK(Text::score(first, 90, QString::fromUtf8("青のすみか"), QString::fromUtf8("キタニタツヤ"), 200) > 0.5);
        CHECK(Text::shortCut(QStringLiteral("Artist - Song (TV Size)")));
        CHECK(!Text::shortCut(QStringLiteral("Artist - Song (Official Audio)")));
    }

    using namespace Text;

    // ---- which names get searched ----
    {   // a song entry: the player's artist and title, nothing else needed
        const auto c = candidates(track("Heat Waves (Official Video)", "Glass Animals", "Dreamland", 238));
        CHECK(c.size() == 1 && has(c, "Glass Animals", "Heat Waves"));
    }
    {   // an upload by a channel: "Song - Artist" and "Artist - Song" are both tried, early
        const auto c = candidates(track("Come With Me Now - Kongos (High Audio Quality)", "ImMusicFanMusicLover - MusicForLife"));
        CHECK(has(c, "Kongos", "Come With Me Now", 2));
        CHECK(!has(c, "Come", "Kongos", 2)); // "with" is not an artist separator inside a title
    }
    {   // "Song Full Song | Film | Cast | Composer | Singers": the song is the first part
        const auto c = candidates(track("\"Subha Hone Na De Full Song\"| Desi Boyz | Akshay Kumar ,John Abraham | Pritam | Mika Singh, Kumaar",
                                        "Shefali Alvares, Mika Singh, Kumaar and Pritam"));
        CHECK(c.first().title == "Subha Hone Na De");
        CHECK(has(c, "Mika Singh", "Subha Hone Na De"));
    }
    CHECK(cleanTitle("Love Song") == "Love Song"); // only "Full/Video/Lyrical Song" is a label
    {   // another artist's song of the same name must not pass for an album track's
        Track t = track("Can't Get You off My Mind", "K E T N E L", "Can't Get You off My Mind", 168);
        CHECK(!titleOnly(candidates(t)));
        t.loose = true; // second pass: the letters joined, and the title alone with a tight length check
        const auto c = candidates(t);
        CHECK(has(c, "KETNEL", "Can't Get You off My Mind"));
        CHECK(titleOnly(c));
    }
    {   // a vocaloid version: every guess carries the singer's name, which a hit must mention
        const auto c = candidates(track("AROUND THE WORLD (MIKU VERSION)", "MIMU"));
        CHECK(!c.isEmpty() && c.first().title == "AROUND THE WORLD");
        for (const Candidate &x : c)
            CHECK(x.hint == "miku");
    }
    {   // "Hatsune Miku" as the artist of her own song is not a "version": no hint
        for (const Candidate &x : candidates(track("Senbonzakura", "Hatsune Miku")))
            CHECK(x.hint.isEmpty());
    }
    {
        Track a, b;
        CHECK(splitTransition(track("guilty as sin x about you || taylor swift & the 1975 (transition)", ""), a, b));
        CHECK(a.title == "guilty as sin" && a.artist == "taylor swift" && b.title == "about you" && b.artist == "the 1975");
        CHECK(!splitTransition(track("Alright - Kendrick Lamar", ""), a, b));
    }

    // ---- how a provider's hit is scored ----
    {
        const Candidate exact{"Glass Animals", "Heat Waves"};
        CHECK(score(exact, 238, "Heat Waves", "Glass Animals", 238) > 1.0);
        CHECK(score(exact, 238, "Heat Waves (Instrumental)", "Glass Animals", 238) < 0);       // no vocals: skipped
        CHECK(score(exact, 238, "Something Else Entirely", "Glass Animals", 238) < 0);
        // same title and artist, a version 20 s longer: still usable, but ranked lower
        CHECK(score(exact, 238, "Heat Waves", "Glass Animals", 258) < score(exact, 238, "Heat Waves", "Glass Animals", 238));
    }
    {   // another artist, same title, 4 s apart: not the same song
        const Candidate c{"K E T N E L", "Can't Get You off My Mind"};
        CHECK(score(c, 168, "Can't Get You off My Mind", "Tones and I", 172) < 0);
        // the same title and length (to the second) is believable across scripts: "ヨルシカ" vs "Yorushika"
        CHECK(score({"Yorushika", "Hitchcock"}, 214, "Hitchcock", "ヨルシカ", 214) > 0.5);
    }
    {   // title alone: the length has to vouch (6 s), or 2 s in the second pass
        Candidate plain{"", "Some Song"};
        CHECK(score(plain, 200, "Some Song", "Anyone", 204) > 0.5);
        CHECK(score(plain, 200, "Some Song", "Anyone", 215) < 0);
        Candidate strict{"", "Some Song"};
        strict.strict = true;
        CHECK(score(strict, 200, "Some Song", "Anyone", 204) < 0);
        CHECK(score(strict, 200, "Some Song", "Anyone", 201) > 0.5);
    }
    {   // a vocaloid version: the hit has to be a vocaloid's too, whatever its length
        Candidate v{"", "Around the World"};
        v.boxed = true;
        v.hint = "miku";
        CHECK(score(v, 231, "Around The World", "Tsukino Mito", 230) < 0);
        CHECK(score(v, 231, "Around The World", "Hatsune Miku", 206) > 0.5); // length is not compared
    }

    // ---- LRC and text helpers ----
    {
        const QString lrc = "[00:01.00] one\n[00:05.50] two\n[00:09.00] three\n[00:12.00] four";
        CHECK(usableLrc(lrc));
        CHECK(!usableLrc("[00:00.00] instrumental"));
        const auto p = Lrc::parse("[00:05.00][00:01.50] chorus\n[00:03.00] verse");
        CHECK(p.size() == 3 && p[0].timeMs == 1500 && p[1].timeMs == 3000 && p[2].timeMs == 5000);
        CHECK(Lrc::stamp(61250) == "[01:01.25]");
        CHECK(Lrc::mapStamps("[00:10.00] a", [](qint64 ms) { return ms + 500; }) == "[00:10.50] a");
        CHECK(incompleteLrc("[00:00.00] a\n[00:01.00] b\n[01:30.00] c")); // a 90 s hole: a verse is missing
    }
    CHECK(tempoVariant("Song (Sped Up)") > 0 && tempoVariant("Song (Slowed + Reverb)") < 0 && tempoVariant("Song") == 0);
    CHECK(langMismatch(QString::fromUtf8("太陽のキスは甘かった 目に受け入れた 夢のように ラジオが知らない曲を流している"), "en"));
    CHECK(!langMismatch("The kisses of the sun were sweet, I didn't blink, I let it in my eyes", "en"));

    std::printf(failures ? "%d check(s) failed\n" : "all checks passed\n", failures);
    return failures ? 1 : 0;
}
