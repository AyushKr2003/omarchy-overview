import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../common"
import "../../common/functions"
import "../../common/functions/MissionLayout.js" as MissionLayout
import "../../services"
import "."

Scope {
    id: overviewScope
    property var shell: null
    readonly property var appLibrary: shell ? shell.appLibrary : null
    property var manifest: null
    property var settings: ({})
    readonly property string pluginId: String(manifest?.id || "omarchy-overview")
    readonly property bool missionMode: Config.options.missionControl.layout === "missionControl"

    // The shell hands overlay plugins no settings, so read this plugin's
    // inline entry from shell.json directly and follow edits to it.
    function entrySettings() {
        let config = null;
        try {
            config = JSON.parse(shellConfigFile.text() || "{}");
        } catch (e) {
            return settings || ({});
        }
        const plugins = config?.plugins || [];
        if (!Array.isArray(plugins))
            return ({});
        for (const entry of plugins) {
            if (String(entry?.id || "") === pluginId)
                return entry;
        }
        return ({});
    }

    function syncSettings() {
        const next = entrySettings() || ({});
        settings = next;
        Config.settings = next;
    }

    FileView {
        id: shellConfigFile
        path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
        watchChanges: true
        printErrors: false
        onLoaded: overviewScope.syncSettings()
        onFileChanged: reload()
    }

    onManifestChanged: syncSettings()
    onShellChanged: SearchService.shell = shell
    onAppLibraryChanged: SearchService.appLibrary = appLibrary
    Component.onCompleted: {
        SearchService.shell = shell;
        SearchService.appLibrary = appLibrary;
    }

    // ── Host lifecycle (omarchy-shell shell toggle/summon/hide) ────────

    function open(payloadJson) {
        openOverview();
    }

    function close() {
        closeOverview(null);
    }

    function toggle(payloadJson) {
        toggleOverview();
    }

    // ── Open / close ────────────────────────────────────────────────────

    function toggleOverview() {
        if (GlobalStates.overviewOpen)
            closeOverview(null);
        else
            openOverview();
    }

    function openOverview() {
        if (GlobalStates.overviewOpen)
            return;
        closeAnim.stop();
        GlobalStates.resetSelection(`${Hyprland.focusedMonitor?.name ?? ""}`);
        GlobalStates.query = "";
        GlobalStates.overviewOpen = true;
    }

    // after: run once the close has started, after keyboard focus is let go.
    function closeOverview(after) {
        if (GlobalStates.overviewOpen)
            GlobalStates.overviewOpen = false;
        if (typeof after === "function")
            after();
    }

    function activateWindow(win) {
        closeOverview(() => Dispatch.activateWindow(win));
    }

    function activateResult(result) {
        if (!result)
            return;
        if (result.kind === "window") {
            const win = HyprlandData.windowByAddress[result.data?.address];
            if (win)
                activateWindow(win);
            return;
        }
        closeOverview(() => SearchService.activate(result));
    }

    readonly property int openMs: Config.options.missionControl.openAnimation ? Config.options.missionControl.openMs : 0

    // Start with the active desktop's strip cell selected, never a window.
    function preselect() {
        if (!missionMode || GlobalStates.keyboardActive)
            return;
        const view = currentView();
        if (view && view.stripHeight > 0)
            selectStrip(view, stripIndexOfActive(view));
    }

    function startOpenAnimation() {
        openReadyTimer.stop();
        if (!GlobalStates.overviewOpen)
            return;
        preselect();
        const duration = Style.duration(overviewScope.missionMode ? overviewScope.openMs : Math.min(overviewScope.openMs, 160));
        if (duration <= 0) {
            GlobalStates.openProgress = 1;
            return;
        }
        openAnim.duration = duration * (1 - GlobalStates.openProgress);
        openAnim.restart();
    }

    function finishClose() {
        if (GlobalStates.overviewOpen)
            return;
        GlobalStates.openProgress = 0;
        GlobalStates.surfaceVisible = false;
        GlobalStates.query = "";
        GlobalStates.keyboardActive = false;
    }

    Connections {
        target: GlobalStates
        function onOverviewOpenChanged() {
            if (GlobalStates.overviewOpen) {
                if (overviewScope.appLibrary)
                    overviewScope.appLibrary.refreshIcons();
                Wallpaper.refresh();
                GlobalStates.surfaceVisible = true;
                // Start from where the windows really are: wait for a fresh
                // client list, or a moment at most.
                HyprlandData.updateAll();
                HyprlandData.flushPendingUpdates();
                openReadyTimer.restart();
            } else {
                openAnim.stop();
                openReadyTimer.stop();
                const duration = Style.duration(Math.round(overviewScope.openMs * 0.8));
                if (duration <= 0 || GlobalStates.openProgress <= 0) {
                    overviewScope.finishClose();
                } else {
                    closeAnim.duration = duration * GlobalStates.openProgress;
                    closeAnim.restart();
                }
            }
            overviewScope.syncHostState();
        }
    }

    // The shell keeps its own open flag for `shell toggle`. Keep it in step
    // when the overview opens or closes itself (a click, Escape, the hot
    // corner), so the next toggle is not swallowed.
    function syncHostState() {
        if (!shell || typeof shell.isPluginOpen !== "function")
            return;
        const hostOpen = shell.isPluginOpen(pluginId);
        if (GlobalStates.overviewOpen && !hostOpen)
            shell.summon(pluginId, "");
        else if (!GlobalStates.overviewOpen && hostOpen)
            shell.hide(pluginId);
    }

    Connections {
        target: HyprlandData
        function onWindowsUpdated() {
            if (openReadyTimer.running)
                overviewScope.startOpenAnimation();
        }
    }

    Timer {
        id: openReadyTimer
        interval: 90
        repeat: false
        onTriggered: overviewScope.startOpenAnimation()
    }

    NumberAnimation {
        id: openAnim
        target: GlobalStates
        property: "openProgress"
        to: 1
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
    }

    NumberAnimation {
        id: closeAnim
        target: GlobalStates
        property: "openProgress"
        to: 0
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.3, 0, 0.8, 0.15, 1, 1]
        onFinished: overviewScope.finishClose()
    }

    // ── Keyboard ────────────────────────────────────────────────────────

    function views() {
        const out = [];
        for (const panel of overviewVariants.instances) {
            if (panel?.missionView)
                out.push(panel.missionView);
        }
        out.sort((a, b) => ((a.monitorData?.x ?? 0) - (b.monitorData?.x ?? 0)) || ((a.monitorData?.y ?? 0) - (b.monitorData?.y ?? 0)));
        return out;
    }

    function viewFor(name) {
        return views().find(v => v.monitorName === name) ?? null;
    }

    function currentView() {
        return viewFor(GlobalStates.selectionMonitor) ?? viewFor(`${Hyprland.focusedMonitor?.name ?? ""}`) ?? views()[0] ?? null;
    }

    function isPrintable(event) {
        const mods = event.modifiers;
        if (mods & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return false;
        const text = `${event.text ?? ""}`;
        if (text.length === 0)
            return false;
        const code = text.charCodeAt(0);
        return code >= 32 && code !== 127;
    }

    // Keys while there is a query. Returns true when handled.
    function handleSearchKey(event) {
        const results = SearchService.results;
        const key = event.key;
        if (key === Qt.Key_Escape) {
            GlobalStates.query = "";
            GlobalStates.resultIndex = 0;
            return true;
        }
        if (key === Qt.Key_Up || key === Qt.Key_Backtab || (key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
            GlobalStates.resultIndex = Math.max(0, GlobalStates.resultIndex - 1);
            return true;
        }
        if (key === Qt.Key_Down || key === Qt.Key_Tab) {
            GlobalStates.resultIndex = Math.min(Math.max(0, results.length - 1), GlobalStates.resultIndex + 1);
            return true;
        }
        if (key === Qt.Key_PageDown) {
            GlobalStates.resultIndex = Math.min(Math.max(0, results.length - 1), GlobalStates.resultIndex + 6);
            return true;
        }
        if (key === Qt.Key_PageUp) {
            GlobalStates.resultIndex = Math.max(0, GlobalStates.resultIndex - 6);
            return true;
        }
        if (key === Qt.Key_Return || key === Qt.Key_Enter) {
            activateResult(results[Math.min(GlobalStates.resultIndex, results.length - 1)]);
            return true;
        }
        if (key === Qt.Key_Backspace) {
            const q = GlobalStates.query;
            GlobalStates.query = (event.modifiers & Qt.ControlModifier) ? q.replace(/\S*\s*$/, "") : q.slice(0, -1);
            GlobalStates.resultIndex = 0;
            return true;
        }
        if (key === Qt.Key_U && (event.modifiers & Qt.ControlModifier)) {
            GlobalStates.query = "";
            return true;
        }
        if (isPrintable(event)) {
            GlobalStates.query += event.text;
            GlobalStates.resultIndex = 0;
            return true;
        }
        return false;
    }

    function startSearch(event) {
        if (!Config.options.missionControl.searchEnabled || !isPrintable(event))
            return false;
        if (event.text === " " && GlobalStates.query.length === 0)
            return false;
        GlobalStates.query = event.text;
        GlobalStates.resultIndex = 0;
        // Results show on the monitor the keyboard is on.
        if (!GlobalStates.selectionMonitor)
            GlobalStates.selectionMonitor = `${Hyprland.focusedMonitor?.name ?? ""}`;
        return true;
    }

    function stripIndexOfActive(view) {
        return Math.max(0, view.stripKeys.indexOf(`ws:${view.activeWorkspaceId}`));
    }

    function selectGrid(view, index) {
        GlobalStates.selectionMonitor = view.monitorName;
        GlobalStates.selectionRegion = "grid";
        GlobalStates.selectionIndex = index;
        GlobalStates.keyboardActive = true;
    }

    function selectStrip(view, index) {
        GlobalStates.selectionMonitor = view.monitorName;
        GlobalStates.selectionRegion = "strip";
        GlobalStates.selectionIndex = index;
        GlobalStates.keyboardActive = true;
    }

    // The neighbouring monitor's view in a direction, by monitor position.
    function neighbourView(view, direction) {
        const all = views();
        const rects = all.map(v => HotCornerGeometry.rectOf(v.monitorData ?? {}));
        const index = all.indexOf(view);
        const next = MissionLayout.neighbour(rects, index, direction);
        return next >= 0 ? all[next] : null;
    }

    // Moving the strip selection onto a desktop switches to it, so the grid
    // below shows that desktop's windows. "+" and special workspaces are
    // only switched to when picked with Enter.
    function showStripWorkspace(view, index) {
        const key = view.stripKeys[index] ?? "";
        if (key.startsWith("ws:"))
            Dispatch.focusWorkspace(Number(key.slice(3)));
    }

    function navigate(direction) {
        const view = currentView();
        if (!view)
            return;
        if (!GlobalStates.keyboardActive || GlobalStates.selectionMonitor !== view.monitorName) {
            const index = view.focusedTileIndex();
            if (index >= 0)
                selectGrid(view, index);
            else if (view.stripHeight > 0)
                selectStrip(view, stripIndexOfActive(view));
            return;
        }

        if (GlobalStates.selectionRegion === "strip") {
            const count = view.stripKeys.length;
            if (direction === "left" || direction === "right") {
                const next = GlobalStates.selectionIndex + (direction === "left" ? -1 : 1);
                if (next >= 0 && next < count) {
                    GlobalStates.selectionIndex = next;
                    showStripWorkspace(view, next);
                } else {
                    const other = neighbourView(view, direction);
                    if (other) {
                        const index = direction === "left" ? other.stripKeys.length - 1 : 0;
                        selectStrip(other, index);
                        showStripWorkspace(other, index);
                    }
                }
            } else if (direction === "down" && view.orderedAddresses.length > 0) {
                selectGrid(view, view.focusedTileIndex());
            }
            return;
        }

        const next = MissionLayout.neighbour(view.tileRects(), GlobalStates.selectionIndex, direction);
        if (next >= 0) {
            GlobalStates.selectionIndex = next;
        } else if (direction === "up" && view.stripHeight > 0) {
            selectStrip(view, stripIndexOfActive(view));
        } else {
            const other = neighbourView(view, direction);
            if (other) {
                const index = other.focusedTileIndex();
                if (index >= 0)
                    selectGrid(other, index);
                else if (other.stripHeight > 0)
                    selectStrip(other, stripIndexOfActive(other));
            }
        }
    }

    // Tab: each monitor's strip, then its grid, then the next monitor.
    function cycleRegion(delta) {
        const stops = [];
        for (const view of views()) {
            if (view.stripHeight > 0)
                stops.push({ view: view, region: "strip" });
            if (view.orderedAddresses.length > 0)
                stops.push({ view: view, region: "grid" });
        }
        if (stops.length === 0)
            return;
        let current = stops.findIndex(s => s.view.monitorName === GlobalStates.selectionMonitor && s.region === GlobalStates.selectionRegion);
        if (!GlobalStates.keyboardActive)
            current = delta > 0 ? -1 : stops.length;
        const stop = stops[(current + delta + stops.length) % stops.length];
        if (stop.region === "strip")
            selectStrip(stop.view, stripIndexOfActive(stop.view));
        else
            selectGrid(stop.view, stop.view.focusedTileIndex());
    }

    function activateSelection() {
        const view = currentView();
        if (!view || !GlobalStates.keyboardActive) {
            closeOverview(null);
            return;
        }
        if (GlobalStates.selectionRegion === "strip") {
            view.activateStripCell(GlobalStates.selectionIndex, true);
            return;
        }
        const address = view.selectedAddress();
        if (address)
            view.activateTile(address);
        else
            closeOverview(null);
    }

    function handleMissionKey(event) {
        const key = event.key;
        const mods = event.modifiers;
        const view = currentView();

        // Escape leaves for whatever is selected: a highlighted window is
        // focused; a desktop picked in the strip is already the one shown.
        if (key === Qt.Key_Escape) {
            const address = GlobalStates.keyboardActive ? (view?.selectedAddress() ?? "") : "";
            if (address)
                view.activateTile(address);
            else
                closeOverview(null);
            return true;
        }
        // Super+digit still focuses a workspace; the overview stays open.
        if ((mods & Qt.MetaModifier) && key >= Qt.Key_0 && key <= Qt.Key_9) {
            Dispatch.focusWorkspace(key === Qt.Key_0 ? 10 : key - Qt.Key_0);
            return true;
        }
        if ((mods & (Qt.ControlModifier | Qt.MetaModifier)) && (key === Qt.Key_Left || key === Qt.Key_Right)) {
            if (view)
                view.stepWorkspace(key === Qt.Key_Left ? -1 : 1, false);
            return true;
        }
        if (key === Qt.Key_PageUp || key === Qt.Key_PageDown) {
            if (view)
                view.stepWorkspace(key === Qt.Key_PageUp ? -1 : 1, false);
            return true;
        }
        if (key === Qt.Key_Left || key === Qt.Key_Right || key === Qt.Key_Up || key === Qt.Key_Down) {
            navigate(key === Qt.Key_Left ? "left" : key === Qt.Key_Right ? "right" : key === Qt.Key_Up ? "up" : "down");
            return true;
        }
        if (key === Qt.Key_Tab || key === Qt.Key_Backtab) {
            cycleRegion(key === Qt.Key_Backtab || (mods & Qt.ShiftModifier) ? -1 : 1);
            return true;
        }
        if (key === Qt.Key_Return || key === Qt.Key_Enter) {
            activateSelection();
            return true;
        }
        if (key === Qt.Key_Delete || (key === Qt.Key_W && (mods & Qt.ControlModifier))) {
            const address = view?.selectedAddress() ?? "";
            if (address)
                Dispatch.closeWindow(address);
            return true;
        }
        return startSearch(event);
    }

    function handleKey(event, panel) {
        if (!GlobalStates.overviewOpen)
            return;
        let handled = false;
        if (GlobalStates.query.length > 0)
            handled = handleSearchKey(event);
        else if (missionMode)
            handled = handleMissionKey(event);
        else
            handled = handleGridKey(event, panel);
        event.accepted = handled;
    }

    // The workspace-grid layout's keys: arrows/hjkl/digits move between
    // workspaces, Escape/Enter close, anything else starts a search.
    function handleGridKey(event, panel) {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return) {
            closeOverview(null);
            return true;
        }

        const workspacesPerGroup = Config.options.overview.rows * Config.options.overview.columns;
        const currentId = Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1;
        const useWorkspaceMap = Config.options.overview.useWorkspaceMap;
        const workspaceMap = Config.options.overview.workspaceMap ?? [];
        const focusedMonitorId = Hyprland.focusedMonitor?.id ?? panel.monitor?.id ?? 0;
        const workspaceOffset = useWorkspaceMap ? Number(workspaceMap[focusedMonitorId] ?? 0) : 0;
        const currentGroup = Math.floor((currentId - workspaceOffset - 1) / workspacesPerGroup);
        const minWorkspaceId = currentGroup * workspacesPerGroup + 1 + workspaceOffset;
        const maxWorkspaceId = minWorkspaceId + workspacesPerGroup - 1;

        const rows = Config.options.overview.rows;
        const columns = Config.options.overview.columns;
        const reverseColumns = Config.options.overview.orderRightLeft;
        const reverseRows = Config.options.overview.orderBottomUp;

        const clampedIndex = Math.max(0, Math.min(workspacesPerGroup - 1, currentId - minWorkspaceId));
        const currentNormalRow = Math.floor(clampedIndex / columns);
        const currentNormalColumn = clampedIndex % columns;
        const flipRow = r => reverseRows ? (rows - r - 1) : r;
        const flipColumn = c => reverseColumns ? (columns - c - 1) : c;

        let targetVisualRow = flipRow(currentNormalRow);
        let targetVisualColumn = flipColumn(currentNormalColumn);
        let targetId = null;
        const key = event.key;
        const isLeft = key === Qt.Key_Left || key === Qt.Key_H;
        const isRight = key === Qt.Key_Right || key === Qt.Key_L;
        const isUp = key === Qt.Key_Up || key === Qt.Key_K;
        const isDown = key === Qt.Key_Down || key === Qt.Key_J;

        if (isLeft)
            targetVisualColumn = (targetVisualColumn - 1 + columns) % columns;
        else if (isRight)
            targetVisualColumn = (targetVisualColumn + 1) % columns;
        else if (isUp)
            targetVisualRow = (targetVisualRow - 1 + rows) % rows;
        else if (isDown)
            targetVisualRow = (targetVisualRow + 1) % rows;
        else if (key >= Qt.Key_1 && key <= Qt.Key_9) {
            // 1-9 map to positions 1-9 of the current group, 0 to 10.
            const position = key - Qt.Key_0;
            if (position <= workspacesPerGroup)
                targetId = minWorkspaceId + position - 1;
        } else if (key === Qt.Key_0) {
            if (workspacesPerGroup >= 10)
                targetId = minWorkspaceId + 9;
        } else {
            return startSearch(event);
        }

        if (targetId === null && (isLeft || isRight || isUp || isDown))
            targetId = minWorkspaceId + flipRow(targetVisualRow) * columns + flipColumn(targetVisualColumn);

        if (targetId !== null)
            Dispatch.focusWorkspace(Math.max(minWorkspaceId, Math.min(maxWorkspaceId, targetId)));
        return true;
    }

    // ── Surfaces ────────────────────────────────────────────────────────

    Variants {
        id: overviewVariants
        model: Quickshell.screens
        PanelWindow {
            id: root
            required property var modelData
            readonly property var shell: overviewScope.shell
            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)
            readonly property var missionView: overviewScope.missionMode ? (contentLoader.item ?? null) : null
            property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)
            property bool blurEnabled: Config.options.overview.effects.enableBlur
            property bool closeOnFocusLoss: Config.options.overview.closeOnFocusLoss ?? true
            screen: modelData
            visible: GlobalStates.surfaceVisible

            WlrLayershell.namespace: blurEnabled ? "quickshell:overview-blur" : "quickshell:overview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: GlobalStates.overviewOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            HyprlandFocusGrab {
                id: grab
                windows: [root]
                property bool canBeActive: root.monitorIsFocused
                active: false
                onCleared: () => {
                    // Only the monitor that owns the grab may close the overview
                    if (root.closeOnFocusLoss && !active && canBeActive)
                        overviewScope.closeOverview(null);
                }
            }

            Connections {
                target: GlobalStates
                function onOverviewOpenChanged() {
                    if (GlobalStates.overviewOpen)
                        delayedGrabTimer.start();
                    else
                        grab.active = false;
                }
            }

            // Re-evaluate grab ownership when focused monitor changes
            Connections {
                target: Hyprland
                function onFocusedMonitorChanged() {
                    if (!GlobalStates.overviewOpen)
                        return;
                    // Transfer the grab to the newly focused monitor
                    if (root.monitorIsFocused && !grab.active) {
                        grab.active = true;
                    } else if (!root.monitorIsFocused && grab.active) {
                        grab.active = false;
                    }
                }
            }

            Timer {
                id: delayedGrabTimer
                interval: Config.options.hacks.arbitraryRaceConditionDelay
                repeat: false
                onTriggered: {
                    if (!grab.canBeActive)
                        return;
                    grab.active = GlobalStates.overviewOpen;
                }
            }

            Item {
                id: keyHandler
                anchors.fill: parent
                focus: GlobalStates.surfaceVisible
                Keys.onPressed: event => overviewScope.handleKey(event, root)

                // Mission control sits on the wallpaper, blurred and dimmed,
                // like the desktop zoomed out under it. Without a wallpaper
                // (or with it turned off) it falls back to a solid dim. The
                // workspace grid keeps the theme's scrim.
                Item {
                    id: backdropLayer
                    anchors.fill: parent
                    opacity: GlobalStates.openProgress
                    readonly property bool useWallpaper: overviewScope.missionMode
                        && Config.options.missionControl.wallpaperBackdrop
                        && wallpaperImage.status === Image.Ready

                    Rectangle {
                        anchors.fill: parent
                        visible: !backdropLayer.useWallpaper
                        color: overviewScope.missionMode
                            ? ColorUtils.applyAlpha(Color.background, Config.options.missionControl.backdropOpacity)
                            : Color.launcher.scrim
                    }

                    // Opaque base: a blur fades the image out at its edges.
                    Rectangle {
                        anchors.fill: parent
                        visible: backdropLayer.useWallpaper
                        color: Color.background
                    }

                    Image {
                        id: wallpaperImage
                        anchors.fill: parent
                        visible: false
                        source: overviewScope.missionMode && Config.options.missionControl.wallpaperBackdrop ? Wallpaper.source : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        sourceSize.width: Math.round(root.width / 4)
                        sourceSize.height: Math.round(root.height / 4)
                    }

                    MultiEffect {
                        anchors.fill: parent
                        visible: backdropLayer.useWallpaper
                        source: wallpaperImage
                        blurEnabled: Config.options.missionControl.wallpaperBlur
                        blur: 1.0
                        blurMax: 64
                        blurMultiplier: 2.5
                        saturation: -0.15
                        // Oversized so the blur's soft edges sit off-screen;
                        // it settles a touch as it fades in, as if the
                        // desktop stepped back.
                        scale: 1.18 - 0.06 * GlobalStates.openProgress
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: backdropLayer.useWallpaper
                        color: ColorUtils.applyAlpha(Color.background, Config.options.missionControl.wallpaperDim)
                    }
                }

                // Workspace-grid layout: clicking outside the panel closes.
                MouseArea {
                    anchors.fill: parent
                    visible: !overviewScope.missionMode
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    enabled: root.closeOnFocusLoss && GlobalStates.overviewOpen
                    onPressed: mouse => {
                        overviewScope.closeOverview(null);
                        mouse.accepted = true;
                    }
                }

                Loader {
                    id: contentLoader
                    anchors.fill: parent
                    active: Config.options.overview.enable ?? true
                    sourceComponent: overviewScope.missionMode ? missionComponent : gridComponent
                }

                // Resting in the hot corner while the overview is up closes it.
                MouseArea {
                    readonly property string position: Config.options.missionControl.hotCorner
                    visible: position !== "off"
                    width: 1
                    height: 1
                    x: position.endsWith("right") ? parent.width - 1 : 0
                    y: position.startsWith("bottom") ? parent.height - 1 : 0
                    z: 100
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onEntered: cornerDwell.restart()
                    onExited: cornerDwell.stop()

                    Timer {
                        id: cornerDwell
                        interval: Math.max(0, Config.options.missionControl.hotCornerDelayMs)
                        onTriggered: overviewScope.closeOverview(null)
                    }
                }
            }

            Component {
                id: missionComponent
                MissionControl {
                    panelWindow: root
                    controller: overviewScope
                    shell: overviewScope.shell
                    appLibrary: overviewScope.appLibrary
                }
            }

            Component {
                id: gridComponent
                Item {
                    id: gridRoot
                    readonly property bool primary: GlobalStates.selectionMonitor === `${root.monitor?.name ?? ""}`
                        || (GlobalStates.selectionMonitor === "" && root.monitorIsFocused)
                    readonly property bool searching: primary && GlobalStates.query.length > 0

                    ColumnLayout {
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            top: parent.top
                            topMargin: Config.options.position.topMargin
                        }
                        spacing: Style.spacing.panelGap
                        opacity: GlobalStates.openProgress

                        SearchPill {
                            visible: gridRoot.searching
                            Layout.alignment: Qt.AlignHCenter
                            focused: true
                        }

                        OverviewWidget {
                            visible: !gridRoot.searching
                            panelWindow: root
                            shell: overviewScope.shell
                        }

                        SearchResults {
                            visible: gridRoot.searching
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: Math.max(520, root.width * 0.42)
                            Layout.preferredHeight: Math.min(root.height * 0.6, results.length > 0 ? contentHeightHint : rowHeight + Style.spacing.popupPadding * 2)
                            onActivated: result => overviewScope.activateResult(result)
                        }
                    }
                }
            }
        }
    }

    Variants {
        model: Config.options.missionControl.hotCorner !== "off" ? Quickshell.screens : []
        HotCorner {
            controller: overviewScope
        }
    }

    IpcHandler {
        target: "overview"

        function toggle(): string {
            overviewScope.toggleOverview();
            return "ok";
        }
        function close(): string {
            overviewScope.closeOverview(null);
            return "ok";
        }
        function open(): string {
            overviewScope.openOverview();
            return "ok";
        }
        function state(): string {
            return GlobalStates.overviewOpen ? "open" : "closed";
        }
        function ping(): string {
            return "ok";
        }
        // Open with text already in the search pill.
        function search(text: string): string {
            overviewScope.openOverview();
            GlobalStates.query = text;
            GlobalStates.resultIndex = 0;
            return "ok";
        }
        function info(): string {
            return JSON.stringify({
                open: GlobalStates.overviewOpen,
                progress: GlobalStates.openProgress,
                query: GlobalStates.query,
                results: SearchService.results.map(r => `${r.category}: ${r.title}`),
                views: overviewScope.views().map(v => v.geometry()),
                selection: {
                    monitor: GlobalStates.selectionMonitor,
                    region: GlobalStates.selectionRegion,
                    index: GlobalStates.selectionIndex,
                    keyboard: GlobalStates.keyboardActive
                }
            });
        }
    }
}
