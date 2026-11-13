// Checks for the word-timed lyric formats (src/WordTiming.h). No framework: exit code 1 on failure.
#include "WordTiming.h"

#include <cstdio>

static int failures = 0;
#define CHECK(cond) do { if (!(cond)) { ++failures; std::printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, #cond); } } while (0)

static QJsonArray wordsOf(const QString &json, const QString &line)
{
    return QJsonDocument::fromJson(json.toUtf8()).object().value(line).toArray();
}

int main()
{
    const QString lrc = QString::fromUtf8("[00:20.542]初めてのルーブルは\n[00:22.559]hello big world\n");
    // NetEase: word times are absolute, the line's own start is 20570 (28 ms off the LRC line: still the same line)
    const QString yrc = QString::fromUtf8("[20570,1900](20570,360,0)初(20930,150,0)め(21080,120,0)て(21200,170,0)の(21370,60,0)ル(21430,190,0)ー(21620,150,0)ブ(21770,170,0)ル(21940,530,0)は\n"
                                          "[22560,2000](22560,300,0)hello (23000,200,0)big (23400,300,0)world\n");
    const QString j = WordTiming::toJson(lrc, WordTiming::parse(yrc, WordTiming::Yrc));
    CHECK(wordsOf(j, QString::fromUtf8("初めてのルーブルは")).size() == 9);
    const QJsonArray en = wordsOf(j, QStringLiteral("hello big world"));
    CHECK(en.size() == 3);
    CHECK(en[1].toArray()[0].toInt() == 440 && en[1].toArray()[1].toInt() == 9); // "big" starts 440 ms in, ends at char 9
    CHECK(en[2].toArray()[1].toInt() == 15);                                    // the last word ends at the end of the text

    // Kugou: offsets are from the line's start
    const QString krc = QStringLiteral("[22560,2000]<0,300,0>hello <440,200,0>big <840,300,0>world\n");
    CHECK(wordsOf(WordTiming::toJson(lrc, WordTiming::parse(krc, WordTiming::Krc)), QStringLiteral("hello big world")) == en);

    // QQ: the time comes after its word, and "(" can be part of the text
    const QString qrc = QStringLiteral("[22560,2000]hello (22560,300)big (23000,200)(world)(23400,300)\n");
    const QJsonArray qq = wordsOf(WordTiming::toJson(QStringLiteral("[00:22.559]hello big (world)\n"), WordTiming::parse(qrc, WordTiming::Qrc)),
                                  QStringLiteral("hello big (world)"));
    CHECK(qq.size() == 3 && qq[2].toArray()[0].toInt() == 840);

    // a line whose words differ from the LRC line is skipped, not guessed
    CHECK(WordTiming::toJson(QStringLiteral("[00:22.559]something else\n"), WordTiming::parse(krc, WordTiming::Krc)).isEmpty());

    return failures ? 1 : 0;
}
