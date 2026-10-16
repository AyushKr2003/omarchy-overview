import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../../common"
import "../../common/functions"
import "../../common/functions/MissionLayout.js" as MissionLayout
import "../../services"

/**
 * One window in the mission-control grid. It sits at the window's desktop
 * rect when openProgress is 0 and at its grid slot when it is 1, so opening
 * and closing the overview zooms the windows out of and back into place.
 */
Item {
    id: tile

    required property var view
    property var windowData
    property var toplevel
    property var appLibrary: null

    // Screen-local logical rects.
    property var realRect: ({ x: 0, y: 0, w: 1, h: 1 })
    property var slotRect: ({ x: 0, y: 0, w: 1, h: 1 })
    property real progress: GlobalStates.openProgress

    property bool selected: false
    property bool dimmed: false
    readonly property bool hovered: mouseArea.containsMouse
    readonly property string address: `${windowData?.address ?? ""}`

    // Drag state. dragX/dragY are the tile's top-left while it is dragged.
    property bool dragging: false
    property real dragX: 0
    property real dragY: 0
    property real pressX: 0
    property real pressY: 0
    property real pressTileX: 0
    property real pressTileY: 0
    readonly property real dragThreshold: 10
    readonly property bool overSmallTarget: dragging && view.dropTarget !== null && view.dropTarget.type !== "swap"

    // Hold-to-swap ring on the tile a dragged window hovers.
    property real swapProgress: 0
    readonly property bool swapArmed: swapProgress >= 1

    signal activated()

    // The slot glides to a new place when the grid reflows.
    property bool reflowReady: false
    property real slotX: slotRect.x
    property real slotY: slotRect.y
    property real slotW: slotRect.w
    property real slotH: slotRect.h
    Behavior on slotX { enabled: tile.reflowReady; NumberAnimation { duration: Style.duration(Config.options.missionControl.reflowMs); easing.type: Easing.OutCubic } }
    Behavior on slotY { enabled: tile.reflowReady; NumberAnimation { duration: Style.duration(Config.options.missionControl.reflowMs); easing.type: Easing.OutCubic } }
    Behavior on slotW { enabled: tile.reflowReady; NumberAnimation { duration: Style.duration(Config.options.missionControl.reflowMs); easing.type: Easing.OutCubic } }
    Behavior on slotH { enabled: tile.reflowReady; NumberAnimation { duration: Style.duration(Config.options.missionControl.reflowMs); easing.type: Easing.OutCubic } }
    Component.onCompleted: Qt.callLater(() => tile.reflowReady = true)

    x: dragging ? dragX : MissionLayout.lerp(realRect.x, slotX, progress)
    y: dragging ? dragY : MissionLayout.lerp(realRect.y, slotY, progress)
    width: MissionLayout.lerp(realRect.w, slotW, progress)
    height: MissionLayout.lerp(realRect.h, slotH, progress)
    z: dragging ? 1000 : (selected || hovered ? 2 : 1)
    opacity: dimmed ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: Style.duration(160) } }

    // Shrinks around the grab point while it is dragged over a strip cell.
    transform: Scale {
        origin.x: tile.Drag.hotSpot.x
        origin.y: tile.Drag.hotSpot.y
        xScale: tile.dragScale
        yScale: tile.dragScale
    }
    property real dragScale: overSmallTarget ? Config.options.missionControl.dragMiniScale : 1
    Behavior on dragScale { NumberAnimation { duration: Style.duration(150); easing.type: Easing.OutCubic } }

    Drag.active: dragging
    Drag.source: tile
    Drag.keys: ["omarchy-overview-window"]

    RectangularShadow {
        anchors.fill: frame
        radius: Style.cornerRadius
        offset: Qt.vector2d(0, tile.dragging ? 10 : 6)
        blur: tile.dragging ? 34 : 24
        spread: 0
        color: Qt.rgba(0, 0, 0, 0.5)
        opacity: tile.progress
        cached: true
    }

    RectangularShadow {
        anchors.fill: frame
        visible: tile.selected
        radius: Style.cornerRadius
        blur: 22
        spread: 2
        color: ColorUtils.applyAlpha(Color.accent, 0.55)
        opacity: tile.progress
    }

    Item {
        id: frame
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            radius: Style.cornerRadius
            color: Color.popups.background
        }

        ScreencopyView {
            id: preview
            readonly property real srcAspect: {
                const w = tile.windowData?.size?.[0] ?? 0;
                const h = tile.windowData?.size?.[1] ?? 0;
                return (w > 0 && h > 0) ? (w / h) : 1;
            }
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height * srcAspect)
            height: Math.min(parent.height, parent.width / srcAspect)
            captureSource: GlobalStates.surfaceVisible && Config.options.overview.previewsEnabled ? tile.toplevel : null
            live: true
            layer.enabled: Style.cornerRadius > 0
            layer.smooth: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: previewMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
        }

        Item {
            id: previewMask
            anchors.fill: preview
            visible: false
            layer.enabled: true
            layer.smooth: true
            Rectangle {
                anchors.centerIn: parent
                width: frame.width
                height: frame.height
                radius: Style.cornerRadius
            }
        }

        // Hover / selection wash and border.
        Rectangle {
            anchors.fill: parent
            radius: Style.cornerRadius
            color: tile.selected || tile.hovered ? ColorUtils.applyAlpha(Color.foreground, 0.05) : "transparent"
            border.width: tile.selected ? Math.max(3, Style.space(4)) : (tile.hovered ? Math.max(2, Style.space(3)) : Style.normalBorderWidth + 1)
            border.color: tile.selected ? Color.accent : (tile.hovered ? Style.hoverBorderColor : ColorUtils.applyAlpha(Color.launcher.border, 0.45))
            opacity: tile.progress
        }

        // Hold-to-swap: a ring that fills while a dragged window waits here.
        Rectangle {
            anchors.fill: parent
            radius: Style.cornerRadius
            visible: tile.swapProgress > 0
            color: ColorUtils.applyAlpha(Color.accent, 0.10 + 0.20 * tile.swapProgress)
            border.width: Math.max(2, Style.space(3))
            border.color: ColorUtils.applyAlpha(Color.accent, 0.35 + 0.65 * tile.swapProgress)

            StyledText {
                anchors.centerIn: parent
                visible: tile.swapArmed
                text: "Release to swap"
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                font.weight: Font.DemiBold
                color: Color.foreground
                style: Text.Outline
                styleColor: ColorUtils.applyAlpha(Color.background, 0.6)
            }
        }
    }

    // App icon centred on the tile's bottom edge.
    Image {
        id: appIcon
        readonly property real size: Math.round(Math.min(tile.view.iconSize, Math.max(16, tile.height * 0.3)))
        anchors.horizontalCenter: parent.horizontalCenter
        y: tile.height - size * 0.6
        z: 4
        width: size
        height: size
        sourceSize.width: Math.round(size * Screen.devicePixelRatio)
        sourceSize.height: Math.round(size * Screen.devicePixelRatio)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.6)
            shadowBlur: 0.6
            shadowVerticalOffset: 2
            shadowHorizontalOffset: 0
        }
        opacity: tile.dragging ? 0 : tile.progress
        visible: opacity > 0
        source: {
            DesktopEntries.applications.values;
            FallbackIcon.defaultBrowserDesktopId;
            FallbackIcon.defaultTerminalDesktopId;
            return WindowIcon.iconSourceFor(tile.windowData, tile.appLibrary);
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: !tile.dimmed && GlobalStates.overviewOpen
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: tile.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        preventStealing: true

        onPressed: mouse => {
            const p = mapToItem(tile.parent, mouse.x, mouse.y);
            tile.pressX = p.x;
            tile.pressY = p.y;
            tile.pressTileX = tile.x;
            tile.pressTileY = tile.y;
            tile.Drag.hotSpot.x = mouse.x;
            tile.Drag.hotSpot.y = mouse.y;
        }

        onPositionChanged: mouse => {
            if (!(mouse.buttons & Qt.LeftButton))
                return;
            const p = mapToItem(tile.parent, mouse.x, mouse.y);
            const dx = p.x - tile.pressX;
            const dy = p.y - tile.pressY;
            if (!tile.dragging) {
                if (Math.hypot(dx, dy) < tile.dragThreshold)
                    return;
                tile.dragX = tile.pressTileX;
                tile.dragY = tile.pressTileY;
                tile.dragging = true;
                tile.view.beginDrag(tile);
            }
            tile.dragX = tile.pressTileX + dx;
            tile.dragY = tile.pressTileY + dy;
            tile.view.dragMoved(tile, p.x, p.y);
        }

        onReleased: mouse => {
            if (!tile.dragging)
                return;
            tile.Drag.drop();
            tile.view.endDrag(tile);
            tile.dragging = false;
        }

        onCanceled: {
            if (tile.dragging) {
                tile.view.endDrag(tile, true);
                tile.dragging = false;
            }
        }

        onClicked: mouse => {
            if (tile.dragging)
                return;
            if (mouse.button === Qt.MiddleButton)
                Dispatch.closeWindow(tile.address);
            else
                tile.activated();
        }
    }

    // A dragged window hovering this one: hold to swap.
    DropArea {
        anchors.fill: parent
        keys: ["omarchy-overview-window"]
        enabled: Config.options.missionControl.holdToSwap && !tile.dragging
        onEntered: drag => {
            if (drag.source === tile)
                return;
            tile.view.setDropTarget({ type: "swap", tile: tile, address: tile.address });
            swapFill.restart();
        }
        onExited: {
            swapFill.stop();
            tile.swapProgress = 0;
            tile.view.clearDropTarget("swap", tile);
        }
        onDropped: {
            swapFill.stop();
        }
    }

    NumberAnimation {
        id: swapFill
        target: tile
        property: "swapProgress"
        from: 0
        to: 1
        duration: Math.max(1, Config.options.missionControl.holdToSwapMs)
    }

    function resetSwap() {
        swapFill.stop();
        swapProgress = 0;
    }
}
