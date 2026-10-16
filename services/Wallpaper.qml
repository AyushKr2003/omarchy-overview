pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * The current Omarchy wallpaper. The shell keeps it behind a symlink that a
 * theme switch repoints, so the target is resolved again on every open:
 * reading the link's own path would let the image cache serve the old file.
 */
Singleton {
    id: root

    readonly property string link: Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
    property string path: ""
    readonly property string source: path.length > 0 ? `file://${path}` : ""

    function refresh() {
        resolver.running = false;
        resolver.running = true;
    }

    Process {
        id: resolver
        command: ["readlink", "-e", root.link]
        stdout: StdioCollector {
            onStreamFinished: root.path = text.trim()
        }
    }

    Component.onCompleted: refresh()
}
