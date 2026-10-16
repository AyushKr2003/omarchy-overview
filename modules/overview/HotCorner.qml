import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../common"
import "../../services"

/**
 * A one-pixel layer in a screen corner. Resting the pointer there for
 * hotCornerDelayMs toggles the overview. Only outer corners get one: a corner
 * another monitor touches is one the pointer just crosses.
 */
PanelWindow {
    id: corner

    required property var modelData
    required property var controller
    readonly property string position: Config.options.missionControl.hotCorner
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)
    readonly property bool outer: HotCornerGeometry.isOuterCorner(HyprlandData.monitors, `${monitor?.name ?? ""}`, position)
    property bool armed: true

    screen: modelData
    visible: position !== "off" && outer
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-overview-hot-corner"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: corner.position.startsWith("top")
        bottom: corner.position.startsWith("bottom")
        left: corner.position.endsWith("left")
        right: corner.position.endsWith("right")
    }
    implicitWidth: 1
    implicitHeight: 1

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: dwell.restart()
        onExited: {
            dwell.stop();
            corner.armed = true;
        }
    }

    Timer {
        id: dwell
        interval: Math.max(0, Config.options.missionControl.hotCornerDelayMs)
        repeat: false
        onTriggered: {
            if (!corner.armed)
                return;
            corner.armed = false;
            corner.controller.toggleOverview();
        }
    }
}
