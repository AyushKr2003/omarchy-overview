pragma Singleton

import QtQuick
import qs.Commons as Shell

QtObject {
    readonly property color foreground: Shell.Color.foreground
    readonly property color background: Shell.Color.background
    readonly property color accent: Shell.Color.accent
    readonly property color urgent: Shell.Color.urgent

    readonly property var shellValues: Shell.Color.shellValues
    readonly property var bar: Shell.Color.bar
    readonly property var popups: Shell.Color.popups
    readonly property var tooltip: Shell.Color.tooltip
    readonly property var notifications: Shell.Color.notifications
    readonly property var launcher: Shell.Color.menu
    readonly property var menu: Shell.Color.menu
    readonly property var polkit: Shell.Color.polkit
    readonly property var lock: Shell.Color.lock
    readonly property var imagePicker: Shell.Color.imagePicker

    function pick(key, fallback) {
        return Shell.Color.pick(key, fallback);
    }

    function pickAlpha(key, fallback) {
        return Shell.Color.pickAlpha(key, fallback);
    }

    function composed(colorKey, alphaKey, colorFallback, alphaFallback) {
        return Shell.Color.composed(colorKey, alphaKey, colorFallback, alphaFallback);
    }

    function loadColors(raw) {
        Shell.Color.loadColors(raw);
    }

    function loadShell(raw) {
        Shell.Color.loadShell(raw);
    }
}
