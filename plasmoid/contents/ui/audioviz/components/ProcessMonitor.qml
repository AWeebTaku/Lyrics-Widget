import QtQuick
import org.kde.plasma.plasmoid
import "../"

Item {
    id: root

    property string command: ""
    readonly property string stdout: process.stdout ?? ""
    readonly property string stderr: process.stderr ?? ""
    readonly property bool forceFallback: false
    readonly property bool running: process.running ?? false
    property bool usingFallback: false
    property var process: null
    property bool loadingFailed: false
    property list<string> loadingErrors

    function restart() {
        if (process !== null) {
            process.restart();
        }
    }

    function start() {
        if (process !== null) {
            process.start();
        }
    }

    function stop() {
        if (process !== null) {
            process.stop();
        }
    }

    onCommandChanged: {
        if (process !== null) {
            process.command = root.command;
        }
    }

    property var logger: Logger.create(Plasmoid.configuration.debugMode ? LoggingCategory.Debug : LoggingCategory.Info)

    Component.onCompleted: {
        let component = null;
        // the Python fallback of the original widget is not needed: Process (C++) ships with this plugin
        const sources = ["ProcessMonitorPrimary.qml"];
        for (let source of sources) {
            logger.debug("Trying to load", source);
            component = Qt.createComponent(source);
            if (component.status === Component.Ready) {
                process = component.createObject(root);
                process.command = root.command;
                break;
            } else {
                logger.warn(component.errorString());
                root.loadingErrors.push(component.errorString());
            }
        }

        if (process === null) {
            root.loadingFailed = true;
        }
        root.usingFallback = component.url.toString().includes("ProcessMonitorFallback.qml");
    }
}
