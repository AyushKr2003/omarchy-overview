pragma Singleton

import QtQuick
import qs.Commons as Shell

// The theme colours this plugin reads, from the shell's Commons.Color.
QtObject {
    readonly property color foreground: Shell.Color.foreground
    readonly property color background: Shell.Color.background
    readonly property color accent: Shell.Color.accent

    readonly property var popups: Shell.Color.popups
    readonly property var tooltip: Shell.Color.tooltip
    readonly property var launcher: Shell.Color.menu
}
