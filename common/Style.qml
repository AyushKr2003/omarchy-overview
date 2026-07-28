pragma Singleton

import QtQuick
import qs.Commons as Shell

QtObject {
    readonly property int cornerRadius: Shell.Style.cornerRadius
    readonly property int gapsOut: Shell.Style.gapsOut

    readonly property var font: Shell.Style.font
    readonly property var spacing: Shell.Style.spacing

    readonly property color normalFill: Shell.Style.normalFill
    readonly property color hoverFill: Shell.Style.hoverFill
    readonly property color selectedFill: Shell.Style.selectedFill
    readonly property color pressedFill: Shell.Style.pressedFill
    readonly property color focusFillColor: Shell.Style.focusFillColor
    readonly property color normalBorderColor: Shell.Style.normalBorderColor
    readonly property color hoverBorderColor: Shell.Style.hoverBorderColor
    readonly property color selectedBorderColor: Shell.Style.selectedBorderColor
    readonly property color focusBorderColor: Shell.Style.focusBorderColor
    readonly property color selectedAccentFill: Shell.Style.selectedAccentFill
    readonly property color selectionFill: Shell.Style.selectionFill

    readonly property int normalBorderWidth: Shell.Style.normalBorderWidth
    readonly property int hoverBorderWidth: Shell.Style.hoverBorderWidth
    readonly property int selectedBorderWidth: Shell.Style.selectedBorderWidth
    readonly property int focusBorderWidth: Shell.Style.focusBorderWidth

    function space(px) {
        return Shell.Style.space(px);
    }

    function spaceReal(px) {
        return Shell.Style.spaceReal(px);
    }

    function controlFill(focused, hot, foreground, accent) {
        return Shell.Style.controlFill(focused, hot, foreground, accent);
    }

    function controlBorder(focused, hot, foreground, accent) {
        return Shell.Style.controlBorder(focused, hot, foreground, accent);
    }

    function controlBorderWidth(focused, hot) {
        return Shell.Style.controlBorderWidth(focused, hot);
    }

    function normalFillFor(foreground, accent, urgent) {
        return Shell.Style.normalFillFor(foreground, accent, urgent);
    }

    function hoverFillFor(foreground, accent, urgent) {
        return Shell.Style.hoverFillFor(foreground, accent, urgent);
    }

    function selectedFillFor(foreground, accent, urgent) {
        return Shell.Style.selectedFillFor(foreground, accent, urgent);
    }

    function pressedFillFor(foreground, accent, urgent) {
        return Shell.Style.pressedFillFor(foreground, accent, urgent);
    }

    function normalBorderFor(foreground, accent, urgent) {
        return Shell.Style.normalBorderFor(foreground, accent, urgent);
    }

    function hoverBorderFor(foreground, accent, urgent) {
        return Shell.Style.hoverBorderFor(foreground, accent, urgent);
    }

    function applyShellValues(values) {
        Shell.Style.applyShellValues(values);
    }

    function scheduleRefresh() {
        Shell.Style.scheduleRefresh();
    }
}
