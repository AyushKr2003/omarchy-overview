pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root
    // Requested state: true from the moment the overview opens until a close
    // starts.
    property bool overviewOpen: false
    // True while anything of the overview is on screen, including the close
    // animation after overviewOpen went false.
    property bool surfaceVisible: false
    // 0 = windows at their desktop positions, 1 = laid out in the overview.
    property real openProgress: 0

    // Search text, shared by every monitor.
    property string query: ""

    // Keyboard selection, shared by every monitor so Tab can walk across
    // them. region: "strip" | "grid".
    property string selectionMonitor: ""
    property string selectionRegion: "grid"
    property int selectionIndex: -1
    property int resultIndex: 0
    // True once the keyboard moved the selection; until then the pointer's
    // hover is the only highlight.
    property bool keyboardActive: false

    function resetSelection(monitorName) {
        selectionMonitor = monitorName ?? "";
        selectionRegion = "grid";
        selectionIndex = -1;
        resultIndex = 0;
        keyboardActive = false;
    }
}
