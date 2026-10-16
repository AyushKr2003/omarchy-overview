pragma Singleton

import QtQuick
import qs.Commons as Shell

// The theme tokens this plugin reads, from the shell's Commons.Style.
QtObject {
    readonly property int cornerRadius: Shell.Style.cornerRadius

    readonly property var font: Shell.Style.font
    readonly property var spacing: Shell.Style.spacing

    readonly property color normalFill: Shell.Style.normalFill
    readonly property color hoverFill: Shell.Style.hoverFill
    readonly property color selectedFill: Shell.Style.selectedFill
    readonly property color pressedFill: Shell.Style.pressedFill
    readonly property color normalBorderColor: Shell.Style.normalBorderColor
    readonly property color hoverBorderColor: Shell.Style.hoverBorderColor

    readonly property int normalBorderWidth: Shell.Style.normalBorderWidth

    readonly property bool reduceMotion: Shell.Style.reduceMotion

    // Every animation runs for duration(ms): 0 while Hyprland animations are off.
    function duration(ms) {
        return Shell.Style.duration(ms);
    }

    function space(px) {
        return Shell.Style.space(px);
    }

    function spaceReal(px) {
        return Shell.Style.spaceReal(px);
    }

    function controlBorder(focused, hot, foreground, accent) {
        return Shell.Style.controlBorder(focused, hot, foreground, accent);
    }

    function controlBorderWidth(focused, hot) {
        return Shell.Style.controlBorderWidth(focused, hot);
    }
}
