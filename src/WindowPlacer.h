#pragma once
#include <QObject>
#include <QtQml/qqmlregistration.h>

// Centers a window the widget has just opened on its screen. A window cannot place itself on Wayland, and KWin centers a new
// window in the area the panels leave free, which is off the true center of the screen when a panel sits at one side. So the
// widget asks KWin to do it: it loads a tiny KWin script (plasmoid/contents/kwin/center.js) that centers the active window
// if it is one of ours, runs it, and unloads it. Nothing happens when KWin is not there (the window stays where it opened).
class WindowPlacer : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit WindowPlacer(QObject *parent = nullptr) : QObject(parent) {}
    // scriptUrl: the script as a file URL or a path
    Q_INVOKABLE void center(const QString &scriptUrl);

private:
    int m_count = 0;
};
