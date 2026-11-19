// Renders every built-in look to a PNG: render.sh <ui dir> <import path> <out dir>. Needs a display (shaders).
#include <QGuiApplication>
#include <QQuickItem>
#include <QQuickView>
#include <QQuickWindow>
#include <QQmlEngine>
#include <QTimer>
#include <cstdio>

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    if (argc < 4) { std::fprintf(stderr, "usage: gallery <ui dir> <import path> <out dir>\n"); return 2; }
    QQuickView v;
    v.engine()->addImportPath(QString::fromUtf8(argv[2]));
    v.engine()->globalObject().setProperty("i18n", v.engine()->evaluate("(function(s){return s})"));
    v.setSource(QUrl::fromLocalFile(QString::fromUtf8(argv[1]) + "/gallery.qml"));
    if (v.status() != QQuickView::Ready) { for (auto &e : v.errors()) std::fprintf(stderr, "%s\n", qPrintable(e.toString())); return 2; }
    v.setResizeMode(QQuickView::SizeRootObjectToView);
    v.show();
    const int count = v.rootObject()->property("count").toInt();
    int i = 0;
    QTimer t;
    t.setInterval(1400);
    QObject::connect(&t, &QTimer::timeout, [&] {
        if (i >= count) { app.quit(); return; }
        auto *r = v.rootObject();
        r->setProperty("index", i);
        QTimer::singleShot(900, [&, k = i] {
            const QSize s(v.rootObject()->property("shotW").toInt(), v.rootObject()->property("shotH").toInt());
            v.resize(s);
            QTimer::singleShot(250, [&, k, s] {
                const QString file = QString::fromUtf8(argv[3]) + QString("/%1.png").arg(k, 2, 10, QLatin1Char('0'));
                v.grabWindow().save(file);
                std::printf("%s  %dx%d\n", qPrintable(file), s.width(), s.height());
            });
        });
        ++i;
    });
    QTimer::singleShot(1500, &t, [&] { t.start(); });
    return app.exec();
}
