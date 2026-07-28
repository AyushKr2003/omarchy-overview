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
    property int recaptureToken: 0
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
    property var xwaylandIndicatorToIconRatio: Config.options.windowPreview.xwaylandIndicatorToIconRatio
    property var iconToWindowRatioCompact: Config.options.windowPreview.iconToWindowRatioCompact
    property bool cropToFill: Config.options.windowPreview.cropToFill
    property bool previewsEnabled: Config.options.overview.previewsEnabled
    property bool includeInactiveMonitorPreviews: Config.options.overview.includeInactiveMonitorPreviews
    property int previewRecaptureDelayMs: Config.options.overview.previewRecaptureDelayMs
    property real windowOverlayOpacity: Math.max(0, Math.min(1, Config.options.overview.effects.windowOverlayOpacity))
    property real effectiveWindowOverlayOpacity: windowOverlayOpacity
    property string previewModeRaw: Config.options.overview.previewMode
    property string previewMode: {
        const mode = `${previewModeRaw ?? "live"}`.trim().toLowerCase();
        return (mode === "event" || mode === "snapshot") ? "event" : "live";
    }
    property bool livePreviewEnabled: previewsEnabled && previewMode === "live"
    property bool shouldCapturePreview: {
        if (!GlobalStates.overviewOpen || !previewsEnabled || !previewCaptureEnabled)
            return false;
        if (includeInactiveMonitorPreviews)
            return true;
        return (windowData?.monitor ?? -1) === widgetMonitorId;
    }
    function extractAppNameFromClass(cls) {
        if (!cls) return "";
        var str = String(cls).trim();
        var s = str.replace(/^chrome-https?___?/i, "").replace(/^chrome-http?___?/i, "").replace(/^chrome-/, "");
        s = s.replace(/_?_?app-Default$/i, "").replace(/-Default$/i, "");
        if (s.indexOf(".") >= 0) {
            var parts = s.split(".");
            if (parts.length >= 2) {
                var name = parts[parts.length - 2];
                if (name !== "com" && name !== "org" && name !== "net" && name !== "io" && name !== "app") {
                    return name;
                }
            }
        }
        return s;
    }

    function lookupEntryIcon(key, entries) {
        if (!key) return "";
        var h = DesktopEntries.heuristicLookup(key);
        var icon = String((h && h.icon) || "").trim();
        if (icon.length > 0) return icon;

        var normKey = key.toLowerCase().replace(/\.desktop$/, "");
        for (var i = 0; i < entries.length; i++) {
            var e = entries[i];
            if (!e) continue;
            var eId = String(e.id || "").toLowerCase().replace(/\.desktop$/, "");
            var eName = String(e.name || "").toLowerCase();
            if (eId === normKey || eName === normKey) {
                var eIcon = String(e.icon || "").trim();
                if (eIcon.length > 0) return eIcon;
            }
        }
        return "";
    }

    function findTuiAppIcon(title, initialTitle, entries) {
        var candidates = [];
        function addTokens(str) {
            if (!str) return;
            var tokens = String(str).trim().split(/[\s:|\-—–/\\()[\]{}]+/);
            for (var i = 0; i < tokens.length; i++) {
                var tok = tokens[i].trim().toLowerCase();
                if (tok.length > 1 && candidates.indexOf(tok) === -1) {
                    candidates.push(tok);
                }
            }
        }

        addTokens(initialTitle);
        addTokens(title);

        var ignored = [
            "bash", "zsh", "fish", "sh", "ksh", "csh", "tcsh", "nu", "nushell",
            "alacritty", "kitty", "foot", "footclient", "ghostty", "com.mitchellh.ghostty",
            "wezterm", "org.wezfurlong.wezterm", "st", "urxvt", "xterm", "terminal",
            "tui", "omarchy", "shadow", "root", "user", "home", "dev", "dotfiles",
            "tmp", "etc", "usr", "var", "bin", "opt"
        ];

        for (var k = 0; k < candidates.length; k++) {
            var cand = candidates[k];
            if (ignored.indexOf(cand) >= 0) continue;

            var icon = lookupEntryIcon(cand, entries);
            if (icon && icon.length > 0) return icon;

            if (root.appLibrary && root.appLibrary.iconIndex && root.appLibrary.iconIndex[cand]) {
                return cand;
            }
            var testThemed = Quickshell.iconPath(cand, false);
            if (testThemed && testThemed.length > 0) {
                return cand;
            }
        }

        return "";
    }

    property string iconName: {
        DesktopEntries.applications.values; // re-run when entry index updates
        FallbackIcon.defaultBrowserDesktopId;
        FallbackIcon.defaultTerminalDesktopId;

        if (!windowData) return "";

        const entries = DesktopEntries.applications.values || [];
        const cls = String(windowData.class || "").trim();
        const initialClass = String(windowData.initialClass || "").trim();
        const title = String(windowData.title || "").trim();
        const initialTitle = String(windowData.initialTitle || "").trim();

        const isTerminalWindow = FallbackIcon.isTerminalLikeClass(cls) || FallbackIcon.isTerminalLikeClass(initialClass);
        let icon = "";

        // Check for TUI app icon (e.g. yazi, nvim, btop, lazygit, ranger) if running in a terminal
        if (isTerminalWindow) {
            icon = findTuiAppIcon(title, initialTitle, entries);
        }

        // 1. Try class directly
        if (!icon) {
            icon = lookupEntryIcon(cls, entries);
        }

        // 2. Try initialClass if different
        if (!icon && initialClass && initialClass !== cls) {
            icon = lookupEntryIcon(initialClass, entries);
        }

        // 3. Extract webapp name from class (e.g. chrome-discord.com__app-Default -> discord)
        const extractedName = extractAppNameFromClass(cls);
        if (!icon && extractedName && extractedName !== cls) {
            icon = lookupEntryIcon(extractedName, entries);
        }

        // 4. Try initialTitle (e.g. "Discord", "WhatsApp")
        if (!icon && initialTitle) {
            icon = lookupEntryIcon(initialTitle, entries);
        }

        // 5. Try clean title
        if (!icon && title) {
            const cleanTitle = title.split(/\s+[-|–—]\s+/)[0].trim();
            if (cleanTitle) {
                icon = lookupEntryIcon(cleanTitle, entries);
            }
        }

        // 6. Direct candidate icon name check (e.g. "discord", "whatsapp", "spotify", "yazi")
        if (!icon) {
            const candidates = [extractedName, initialTitle, cls, initialClass].filter(n => n && n.length > 0);
            for (let j = 0; j < candidates.length; j++) {
                const cand = candidates[j].toLowerCase();
                if (cand !== "google-chrome" && cand !== "chromium" && cand !== "brave-browser" && cand !== "firefox") {
                    if (root.appLibrary && root.appLibrary.iconIndex && root.appLibrary.iconIndex[cand]) {
                        icon = cand;
                        break;
                    }
                    const testThemed = Quickshell.iconPath(cand, false);
                    if (testThemed && testThemed.length > 0) {
                        icon = cand;
                        break;
                    }
                }
            }
        }

        // 7. Fallback to generic browser/terminal icon if no specific app icon was found
        if (!icon) {
            icon = FallbackIcon.fallbackIconForWindow(windowData);
        }

        const raw = `${icon ?? ""}`.trim();
        const withoutProviderPrefix = raw.replace(/^image:\/\/icon\//, "");
        const withoutQuery = withoutProviderPrefix.split("?")[0].trim();
        return withoutQuery;
    }

    function resolveIconSource(icon) {
        const value = `${icon ?? ""}`.trim();
        if (root.appLibrary)
            return root.appLibrary.iconSource(value);
        if (value.length === 0)
            return Quickshell.iconPath("application-x-executable", true);
        if (value.startsWith("file://") || value.startsWith("image://") || value.startsWith("qrc:/"))
            return value;
        if (value.startsWith("/"))
            return Util.fileUrl(value);
        const themed = Quickshell.iconPath(value, true);
        if (themed.length > 0)
            return themed;
        return Quickshell.iconPath("application-x-executable", true);
    }

    property var iconPath: resolveIconSource(iconName)
    property bool compactMode: Style.font.caption * 4 > targetWindowHeight || Style.font.caption * 4 > targetWindowWidth

    property bool indicateXWayland: windowData?.xwayland ?? false
    property bool previewCaptureEnabled: true
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
        live: livePreviewEnabled
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
        color: pressed ? ColorUtils.applyAlpha(Style.pressedFill, Math.min(1, root.effectiveWindowOverlayOpacity + 0.30)) :
            hovered ? ColorUtils.applyAlpha(Style.hoverFill, Math.min(1, root.effectiveWindowOverlayOpacity + 0.20)) :
            ColorUtils.applyAlpha(Color.popups.background, root.effectiveWindowOverlayOpacity)
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

    function refreshCapture() {
        if (!GlobalStates.overviewOpen || livePreviewEnabled || !previewsEnabled)
            return;

        root.previewCaptureEnabled = false;
        previewResetTimer.restart();
    }

    Timer {
        id: previewResetTimer
        interval: Math.max(1, previewRecaptureDelayMs)
        repeat: false
        onTriggered: root.previewCaptureEnabled = true
    }

    onRecaptureTokenChanged: {
        if (recaptureToken > 0)
            root.refreshCapture();
    }
}
