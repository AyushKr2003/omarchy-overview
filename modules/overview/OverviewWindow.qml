import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../../common"
import "../../common/functions"
import "../../services"

Item { // Window
    id: root
    property var toplevel
    property var windowData
    property var monitorData
    property var widgetMonitorData
    property var scale
    property var availableWorkspaceWidth
    property var availableWorkspaceHeight
    property real positionBaseX: (monitorData?.x ?? 0) + (monitorData?.reserved?.[0] ?? 0)
    property real positionBaseY: (monitorData?.y ?? 0) + (monitorData?.reserved?.[1] ?? 0)
    property bool restrictToWorkspace: true
    property real widthRatio: {
        if (!widgetMonitorData || !monitorData)
            return 1;

        const widgetWidth = (widgetMonitorData.transform % 2 === 1) ? (widgetMonitorData.height ?? 1) : (widgetMonitorData.width ?? 1);
        const sourceWidth = (monitorData.transform % 2 === 1) ? (monitorData.height ?? 1) : (monitorData.width ?? 1);
        const sourceScale = monitorData.scale ?? 1;
        const widgetScale = widgetMonitorData.scale ?? 1;
        return (widgetWidth * sourceScale) / (sourceWidth * widgetScale);
    }
    property real heightRatio: {
        if (!widgetMonitorData || !monitorData)
            return 1;

        const widgetHeight = (widgetMonitorData.transform % 2 === 1) ? (widgetMonitorData.width ?? 1) : (widgetMonitorData.height ?? 1);
        const sourceHeight = (monitorData.transform % 2 === 1) ? (monitorData.width ?? 1) : (monitorData.height ?? 1);
        const sourceScale = monitorData.scale ?? 1;
        const widgetScale = widgetMonitorData.scale ?? 1;
        return (widgetHeight * sourceScale) / (sourceHeight * widgetScale);
    }
    property real initX: Math.max(((windowData?.at[0] ?? 0) - positionBaseX) * root.scale * geometryScaleX, 0) + xOffset
    property real initY: Math.max(((windowData?.at[1] ?? 0) - positionBaseY) * root.scale * geometryScaleY, 0) + yOffset
    property real xOffset: 0
    property real yOffset: 0
    property int widgetMonitorId: 0
    property real geometryScaleX: widthRatio
    property real geometryScaleY: heightRatio
    
    property var targetWindowWidth: (windowData?.size[0] ?? 100) * scale * geometryScaleX
    property var targetWindowHeight: (windowData?.size[1] ?? 100) * scale * geometryScaleY
    property bool hovered: false
    property bool pressed: false

    property var appLibrary: null
    property bool showIcons: Config.options.windowPreview.showIcons
    property var iconToWindowRatio: Config.options.windowPreview.iconToWindowRatio
    property var iconToWindowRatioCompact: Config.options.windowPreview.iconToWindowRatioCompact
    property bool cropToFill: Config.options.windowPreview.cropToFill
    property bool previewsEnabled: Config.options.overview.previewsEnabled
    property bool includeInactiveMonitorPreviews: Config.options.overview.includeInactiveMonitorPreviews
    property real windowOverlayOpacity: Math.max(0, Math.min(1, Config.options.overview.effects.windowOverlayOpacity))
    property bool shouldCapturePreview: {
        if (!GlobalStates.overviewOpen || !previewsEnabled)
            return false;
        if (includeInactiveMonitorPreviews)
            return true;
        return (windowData?.monitor ?? -1) === widgetMonitorId;
    }
    property string iconName: {
        DesktopEntries.applications.values; // re-run when entry index updates
        FallbackIcon.defaultBrowserDesktopId;
        FallbackIcon.defaultTerminalDesktopId;
        return WindowIcon.iconNameFor(windowData, root.appLibrary);
    }

    function resolveIconSource(icon) {
        return WindowIcon.sourceFor(icon, root.appLibrary);
    }

    property var iconPath: resolveIconSource(iconName)
    property bool compactMode: Style.font.caption * 4 > targetWindowHeight || Style.font.caption * 4 > targetWindowWidth

    property bool initialized: false
    property bool dragInProgress: false
    property bool suspendPositionAnimation: false
    property bool animateSize: true
    
    x: initX
    y: initY
    width: Math.min(targetWindowWidth, availableWorkspaceWidth)
    height: Math.min(targetWindowHeight, availableWorkspaceHeight)
    opacity: (windowData?.monitor ?? -1) == widgetMonitorId ? 1 : Config.options.windowPreview.inactiveMonitorOpacity
    visible: {
        const thisWsId = windowData?.workspace?.id;
        const isFullscreen = (windowData?.fullscreen ?? 0) > 0;
        if (isFullscreen || thisWsId === undefined) return true;
        return !HyprlandData.windowList.some(w => w.workspace?.id === thisWsId && (w.fullscreen ?? 0) > 0);
    }

    clip: true
    Component.onCompleted: Qt.callLater(() => root.initialized = true)

    Behavior on x {
        enabled: root.initialized && !root.dragInProgress && !root.suspendPositionAnimation
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }
    Behavior on y {
        enabled: root.initialized && !root.dragInProgress && !root.suspendPositionAnimation
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }
    Behavior on width {
        enabled: root.initialized && root.animateSize && !root.dragInProgress && !root.suspendPositionAnimation
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }
    Behavior on height {
        enabled: root.initialized && root.animateSize && !root.dragInProgress && !root.suspendPositionAnimation
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }

    // Opaque background for windows on the active monitor.
    // The simplest solution for making those windows fully opaque and not interacting with actual
    // windows behind the overview, e.g., applying blur to them.
    Rectangle {
        visible: (root.windowData?.monitor ?? -1) === root.widgetMonitorId
        anchors.fill: parent
        radius: Style.cornerRadius
        color: Color.popups.background
    }

    ScreencopyView {
        id: windowPreview
        readonly property real srcAspect: {
            const w = root.windowData?.size?.[0] ?? 0;
            const h = root.windowData?.size?.[1] ?? 0;
            return (w > 0 && h > 0) ? (w / h) : 1;
        }
        anchors.centerIn: parent
        width: root.cropToFill
            ? Math.max(parent.width, parent.height * srcAspect)
            : Math.min(parent.width, parent.height * srcAspect)
        height: root.cropToFill
            ? Math.max(parent.height, parent.width / srcAspect)
            : Math.min(parent.height, parent.width / srcAspect)
        captureSource: shouldCapturePreview ? root.toplevel : null
        live: true
        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: previewMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Style.cornerRadius
        color: pressed ? ColorUtils.applyAlpha(Style.pressedFill, Math.min(1, root.windowOverlayOpacity + 0.30)) :
            hovered ? ColorUtils.applyAlpha(Style.hoverFill, Math.min(1, root.windowOverlayOpacity + 0.20)) :
            ColorUtils.applyAlpha(Color.popups.background, root.windowOverlayOpacity)
        border.color: hovered || pressed ? Style.hoverBorderColor : Style.normalBorderColor
        border.width: Style.normalBorderWidth

        ColumnLayout {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Style.spacing.sm

            Image {
                id: windowIcon
                visible: root.showIcons
                property var iconSize: {
                    const renderedSize = Math.min(root.width, root.height);
                    return renderedSize * (root.compactMode ? root.iconToWindowRatioCompact : root.iconToWindowRatio) / (root.monitorData?.scale ?? 1);
                }
                Layout.alignment: Qt.AlignHCenter
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                source: root.iconPath
                width: iconSize
                height: iconSize
                sourceSize.width: Math.max(1, Math.round(iconSize * Screen.devicePixelRatio))
                sourceSize.height: Math.max(1, Math.round(iconSize * Screen.devicePixelRatio))
            }
        }
    }

    Item {
        id: previewMask
        width: windowPreview.width
        height: windowPreview.height
        anchors.centerIn: parent
        visible: false
        layer.enabled: true
        layer.smooth: true
        Rectangle {
            anchors.centerIn: parent
            width: root.width
            height: root.height
            radius: Style.cornerRadius
        }
    }
}
