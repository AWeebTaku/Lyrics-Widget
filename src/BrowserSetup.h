#pragma once
#include <QObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// Helps install the YouTube Music extension into whichever Chromium browser the user prefers:
// lists the installed ones and opens each one's extensions page.
class BrowserSetup : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QVariantList browsers READ browsers CONSTANT)  // [{name, exec, scheme}]
    Q_PROPERTY(QString extensionPath READ extensionPath CONSTANT)

public:
    explicit BrowserSetup(QObject *parent = nullptr) : QObject(parent) {}
    QVariantList browsers() const;
    QString extensionPath() const;

    Q_INVOKABLE void openExtensions(const QString &exec, const QString &scheme) const;
    Q_INVOKABLE void openFolder() const;
    Q_INVOKABLE void copyPath() const;
};
