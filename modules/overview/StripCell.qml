import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../../common"
import "../../common/functions"
import "../../services"

/**
 * One cell of the workspace strip: a live thumbnail of a workspace, the
 * empty "new desktop" cell, or a special workspace.
 */
Rectangle {
    id: cell

    required property var view
    // "workspace" | "new" | "special"
    property string kind: "workspace"
    property int workspaceId: -1
    property string specialName: ""
    property int cellIndex: -1
    property bool active: false
    property bool selected: false

    readonly property bool hovered: cellArea.containsMouse
    readonly property bool dropHovered: view.dropTarget !== null && view.dropTarget.cell === cell
    readonly property real thumbScale: width / Math.max(1, view.screenWidth)

    readonly property string label: kind === "new" ? "+" : (kind === "special" ? view.specialLabel(specialName) : `${workspaceId}`)

    readonly property var cellWindows: {
        const out = [];
        for (const win of HyprlandData.windowList ?? []) {
            if ((win?.monitor ?? -1) !== (view.monitorData?.id ?? -2) && kind !== "special")
                continue;
            const wsName = `${win?.workspace?.name ?? ""}`;
            if (kind === "special") {
                if (wsName === `special:${specialName}`)
                    out.push(win);
            } else if (kind === "workspace" && (win?.workspace?.id ?? -1) === workspaceId && !wsName.startsWith("special:")) {
                out.push(win);
            }
        }
        // Back to front: floating above tiled, most recently focused last.
        out.sort((a, b) => {
            if (!!a.floating !== !!b.floating)
                return a.floating ? 1 : -1;
            return (b.focusHistoryID ?? 0) - (a.focusHistoryID ?? 0);
        });
        return out.map(win => win.address);
    }

    radius: Style.cornerRadius
    clip: true
    color: ColorUtils.applyAlpha(Color.launcher.background, 0.72)
    scale: (hovered || dropHovered) && !Style.reduceMotion ? 1.04 : 1
    z: hovered || dropHovered ? 1 : 0
    Behavior on scale { NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic } }

    // The desktop's wallpaper; the "new desktop" cell shows it faintly.
    Image {
        anchors.fill: parent
        visible: Config.options.missionControl.wallpaperBackdrop && status === Image.Ready
        source: Wallpaper.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize.width: Math.round(cell.width * Screen.devicePixelRatio)
        sourceSize.height: Math.round(cell.height * Screen.devicePixelRatio)
        opacity: cell.kind === "new" ? 0.3 : 0.85
    }

    Item {
        anchors.fill: parent
        visible: cell.kind !== "new"

        Repeater {
            model: ScriptModel {
                values: cell.cellWindows
            }
            delegate: Item {
                id: mini
                required property string modelData
                readonly property var windowData: HyprlandData.windowByAddress[modelData]
                readonly property var toplevel: cell.view.toplevelFor(modelData)
                readonly property var monitor: HyprlandData.monitors.find(m => m.id === windowData?.monitor) ?? cell.view.monitorData
                x: Math.round(((windowData?.at?.[0] ?? 0) - (monitor?.x ?? 0)) * cell.thumbScale)
                y: Math.round(((windowData?.at?.[1] ?? 0) - (monitor?.y ?? 0)) * cell.thumbScale)
                width: Math.max(2, Math.round((windowData?.size?.[0] ?? 0) * cell.thumbScale))
                height: Math.max(2, Math.round((windowData?.size?.[1] ?? 0) * cell.thumbScale))

                Rectangle {
                    anchors.fill: parent
                    radius: 2
                    color: ColorUtils.applyAlpha(Color.foreground, 0.08)
                    border.width: 1
                    border.color: ColorUtils.applyAlpha(Color.foreground, 0.18)
                }

                ScreencopyView {
                    anchors.fill: parent
                    captureSource: GlobalStates.surfaceVisible && Config.options.overview.previewsEnabled ? mini.toplevel : null
                    live: true
                }
            }
        }
    }

    // Workspace number / "+" / special name.
    Rectangle {
        visible: cell.kind !== "new"
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Style.spacing.sm
        width: numberText.implicitWidth + Style.spacing.lg * 2
        height: numberText.implicitHeight + Style.spacing.xs * 2
        // Hyprland's window rounding (square on Omarchy's default).
        radius: Math.min(Style.cornerRadius, height / 2)
        color: cell.active ? Color.accent : ColorUtils.applyAlpha(Color.launcher.background, 0.9)

        StyledText {
            id: numberText
            anchors.centerIn: parent
            text: cell.label
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.weight: Font.DemiBold
            color: cell.active ? Color.background : Color.launcher.text
        }
    }

    // "+" on a badge so it reads over any wallpaper; "New desktop" while a
    // window is held over it. Rounded like Hyprland's windows.
    Rectangle {
        visible: cell.kind === "new"
        anchors.centerIn: parent
        width: cell.dropHovered ? newLabel.implicitWidth + Style.spacing.controlPaddingX * 2 : Math.round(Math.min(cell.height * 0.42, 44))
        height: Math.round(Math.min(cell.height * 0.42, 44))
        radius: Math.min(Style.cornerRadius, height / 2)
        color: cell.dropHovered ? Color.accent : ColorUtils.applyAlpha(Color.background, cell.hovered ? 0.92 : 0.75)
        border.width: Style.normalBorderWidth
        border.color: ColorUtils.applyAlpha(Color.foreground, cell.hovered ? 0.5 : 0.25)
        Behavior on width { NumberAnimation { duration: Style.duration(120) } }

        StyledText {
            id: newLabel
            anchors.centerIn: parent
            text: cell.dropHovered ? "New desktop" : "+"
            font.family: Style.font.family
            font.pixelSize: cell.dropHovered ? Style.font.bodySmall : Math.round(parent.height * 0.6)
            font.weight: Font.DemiBold
            color: cell.dropHovered ? Color.background : Color.foreground
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: cell.radius
        color: cell.dropHovered ? ColorUtils.applyAlpha(Color.accent, 0.22)
            : (cell.hovered || cell.selected) ? ColorUtils.applyAlpha(Color.foreground, 0.06) : "transparent"
        border.width: (cell.active || cell.selected || cell.dropHovered) ? Math.max(3, Style.space(3)) : Style.normalBorderWidth + 1
        border.color: cell.dropHovered || cell.selected ? Color.accent
            : cell.active ? ColorUtils.applyAlpha(Color.accent, 0.75)
            : cell.hovered ? Style.hoverBorderColor : ColorUtils.applyAlpha(Color.launcher.border, 0.6)
        Behavior on color { ColorAnimation { duration: Style.duration(120) } }
    }

    MouseArea {
        id: cellArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: cell.view.activateStripCell(cell.cellIndex)
        onDoubleClicked: cell.view.activateStripCell(cell.cellIndex, true)
    }

    DropArea {
        anchors.fill: parent
        keys: ["omarchy-overview-window"]
        onEntered: cell.view.setDropTarget({ type: cell.kind, cell: cell, workspaceId: cell.workspaceId, specialName: cell.specialName })
        onExited: cell.view.clearDropTarget(cell.kind, cell)
    }
}
