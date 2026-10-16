import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../common"
import "../../common/functions"
import "../../common/functions/MissionLayout.js" as MissionLayout
import "../../services"

/**
 * One monitor's mission control: the workspace strip across the top, the
 * search pill under it, and the focused workspace's windows laid out as a
 * grid. While there is a query, the monitor that opened the overview shows
 * the results panel in place of the grid.
 */
Item {
    id: mc

    required property var panelWindow
    required property var controller
    property var shell: null
    property var appLibrary: null

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
    readonly property string monitorName: `${monitor?.name ?? ""}`
    readonly property var monitorData: HyprlandData.monitors.find(m => m.name === monitorName) ?? null
    readonly property real screenWidth: panelWindow.width
    readonly property real screenHeight: panelWindow.height
    readonly property int activeWorkspaceId: monitor?.activeWorkspace?.id ?? monitorData?.activeWorkspace?.id ?? 1

    readonly property bool isPrimary: GlobalStates.selectionMonitor === monitorName
    readonly property bool searchEnabled: Config.options.missionControl.searchEnabled
    readonly property bool showResults: isPrimary && searchEnabled && GlobalStates.query.length > 0
    readonly property real progress: GlobalStates.openProgress

    // ── Geometry ────────────────────────────────────────────────────────
    readonly property var reserved: monitorData?.reserved ?? [0, 0, 0, 0]
    readonly property real gap: Math.max(8, Style.spaceReal(Config.options.missionControl.gap) * 0.5)
    readonly property real marginX: Math.max(24, screenWidth * 0.04)
    readonly property real stripTop: (reserved[1] ?? 0) + gap
    readonly property real stripHeight: Config.options.missionControl.showStrip ? Math.round(screenHeight * Config.options.missionControl.stripHeightPct / 100) : 0
    readonly property real searchTop: stripTop + stripHeight + (stripHeight > 0 ? gap : 0)
    readonly property real searchHeight: searchEnabled ? searchPill.implicitHeight : 0
    readonly property real gridTop: searchTop + searchHeight + gap * 1.5
    readonly property real gridBottom: screenHeight - (reserved[3] ?? 0) - gap * 1.5
    // App icons sit on each tile's bottom edge; the layout leaves room for
    // the part that hangs below it.
    readonly property real iconSize: Math.round(Style.spacing.controlHeight * 1.8)
    readonly property real labelHeight: Math.round(iconSize * 0.4)
    readonly property var gridArea: ({
        x: marginX + (reserved[0] ?? 0),
        y: gridTop,
        w: Math.max(1, screenWidth - marginX * 2 - (reserved[0] ?? 0) - (reserved[2] ?? 0)),
        h: Math.max(1, gridBottom - gridTop)
    })

    // ── Windows ─────────────────────────────────────────────────────────
    property string draggingAddress: ""
    property var dropTarget: null

    readonly property var toplevelByAddress: {
        const map = ({});
        for (const toplevel of ToplevelManager.toplevels.values) {
            const address = toplevel?.HyprlandToplevel?.address;
            if (address)
                map[`0x${address}`] = toplevel;
        }
        return map;
    }

    function toplevelFor(address) {
        return toplevelByAddress[address] ?? null;
    }

    function windowData(address) {
        return HyprlandData.windowByAddress[address] ?? null;
    }

    function isGridWindow(win) {
        if (!win || `${win.workspace?.name ?? ""}`.startsWith("special:"))
            return false;
        if (win.mapped === false || win.hidden === true)
            return false;
        return (win.workspace?.id ?? -1) === activeWorkspaceId;
    }

    // Back to front, so a window keeps its stacking while it zooms out.
    readonly property var gridAddresses: {
        const wins = (HyprlandData.windowList ?? []).filter(w => isGridWindow(w) || w.address === draggingAddress);
        wins.sort((a, b) => {
            if (!!a.pinned !== !!b.pinned)
                return a.pinned ? 1 : -1;
            if (!!a.floating !== !!b.floating)
                return a.floating ? 1 : -1;
            return (b.focusHistoryID ?? 0) - (a.focusHistoryID ?? 0);
        });
        return wins.map(w => w.address);
    }

    function realRect(win) {
        if (!win)
            return { x: 0, y: 0, w: 1, h: 1 };
        // A window carried in from another desktop has no place on this one.
        if (!isGridWindow(win))
            return slots[win.address] ?? { x: screenWidth / 2, y: screenHeight / 2, w: 1, h: 1 };
        return {
            x: (win.at?.[0] ?? 0) - (monitorData?.x ?? 0),
            y: (win.at?.[1] ?? 0) - (monitorData?.y ?? 0),
            w: Math.max(1, win.size?.[0] ?? 1),
            h: Math.max(1, win.size?.[1] ?? 1)
        };
    }

    readonly property var layoutResult: {
        const input = [];
        for (const address of gridAddresses) {
            const win = windowData(address);
            if (!win || !isGridWindow(win))
                continue;
            const w = Math.max(1, win.size?.[0] ?? 1);
            const h = Math.max(1, win.size?.[1] ?? 1);
            input.push({
                key: address,
                w: w,
                h: h,
                cx: (win.at?.[0] ?? 0) + w / 2,
                cy: (win.at?.[1] ?? 0) + h / 2
            });
        }
        return MissionLayout.layout(input, gridArea, {
            gap: Style.spaceReal(Config.options.missionControl.gap),
            labelHeight: labelHeight,
            maxScale: Config.options.missionControl.maxScale
        });
    }
    readonly property var slots: layoutResult.slots

    // Grid tiles in reading order, for the keyboard.
    readonly property var orderedAddresses: {
        const keys = Object.keys(slots);
        keys.sort((a, b) => (slots[a].row - slots[b].row) || (slots[a].x - slots[b].x));
        return keys;
    }

    // ── Strip ───────────────────────────────────────────────────────────
    readonly property var monitorWorkspaces: {
        const ids = [];
        for (const ws of HyprlandData.allWorkspaces ?? []) {
            if (`${ws?.monitor ?? ""}` === monitorName && Number.isFinite(ws?.id) && ws.id > 0)
                ids.push(ws.id);
        }
        if (activeWorkspaceId > 0 && !ids.includes(activeWorkspaceId))
            ids.push(activeWorkspaceId);
        ids.sort((a, b) => a - b);
        return ids;
    }

    readonly property var specialNames: {
        const names = [];
        for (const ws of HyprlandData.allWorkspaces ?? []) {
            const name = `${ws?.name ?? ""}`;
            if (!name.startsWith("special:") || (ws.windows ?? 0) === 0)
                continue;
            if (`${ws?.monitor ?? ""}` !== monitorName)
                continue;
            names.push(name.slice(8));
        }
        for (const configured of Config.options.overview.specialWorkspaces ?? []) {
            const name = `${configured ?? ""}`.trim();
            if (name && !names.includes(name))
                names.push(name);
        }
        return names;
    }

    // Keys for the strip cells, in keyboard order: workspaces, "new", specials.
    readonly property var stripKeys: {
        const keys = monitorWorkspaces.map(id => `ws:${id}`);
        keys.push("new");
        for (const name of specialNames)
            keys.push(`special:${name}`);
        return keys;
    }

    function specialLabel(name) {
        const raw = `${name ?? ""}`.trim();
        return raw.length === 0 ? "Special" : raw.replace(/[-_]+/g, " ");
    }

    readonly property real stripCellGap: Math.max(4, Style.spaceReal(5))
    readonly property real stripDetachGap: stripCellGap * 6
    readonly property real stripCellWidth: {
        const count = stripKeys.length;
        if (count === 0 || stripHeight <= 0)
            return 0;
        const natural = stripHeight * screenWidth / Math.max(1, screenHeight);
        const gaps = (count - 1) * stripCellGap + (specialNames.length > 0 ? stripDetachGap : 0);
        const available = screenWidth - marginX * 2 - gaps;
        return Math.max(24, Math.min(natural, available / count));
    }
    readonly property real stripCellHeight: stripCellWidth * screenHeight / Math.max(1, screenWidth)

    function freeWorkspaceId() {
        return MissionLayout.firstFreeWorkspaceId(HyprlandData.allWorkspaces, HyprlandData.workspaceRules, monitorName);
    }

    // ── Actions ─────────────────────────────────────────────────────────

    function activateTile(address) {
        const win = windowData(address);
        if (win)
            controller.activateWindow(win);
    }

    // commit: also close the overview (double-click, Enter).
    function activateStripCell(index, commit) {
        const key = stripKeys[index];
        if (!key)
            return;
        if (key.startsWith("special:")) {
            controller.closeOverview(() => Dispatch.toggleSpecial(key.slice(8)));
            return;
        }
        const id = key === "new" ? freeWorkspaceId() : Number(key.slice(3));
        if (commit) {
            controller.closeOverview(() => {});
            Dispatch.focusWorkspace(id);
            return;
        }
        Dispatch.focusWorkspace(id);
        GlobalStates.selectionMonitor = monitorName;
    }

    function stepWorkspace(delta, createPastEnd) {
        const ids = monitorWorkspaces;
        const index = ids.indexOf(activeWorkspaceId);
        const next = index + delta;
        if (next >= 0 && next < ids.length)
            Dispatch.focusWorkspace(ids[next]);
        else if (createPastEnd && next >= ids.length && windowData(draggingAddress) !== null)
            Dispatch.focusWorkspace(freeWorkspaceId());
    }

    // ── Keyboard selection (driven by Overview.qml) ────────────────────

    function tileRects() {
        return orderedAddresses.map(a => slots[a]);
    }

    function selectedAddress() {
        if (GlobalStates.selectionMonitor !== monitorName || GlobalStates.selectionRegion !== "grid")
            return "";
        return orderedAddresses[GlobalStates.selectionIndex] ?? "";
    }

    function focusedTileIndex() {
        const active = HyprlandData.windowList.filter(w => isGridWindow(w)).sort((a, b) => (a.focusHistoryID ?? 0) - (b.focusHistoryID ?? 0))[0];
        const index = active ? orderedAddresses.indexOf(active.address) : -1;
        return index >= 0 ? index : (orderedAddresses.length > 0 ? 0 : -1);
    }

    // Screen-local rects of the tiles and strip cells (IPC `info`).
    function geometry() {
        const rowWidth = stripKeys.length * stripCellWidth + (stripKeys.length - 1) * stripCellGap;
        const rowX = (width - rowWidth) / 2;
        return {
            monitor: monitorName,
            workspace: activeWorkspaceId,
            tiles: orderedAddresses.map(a => ({ address: a, x: slots[a].x, y: slots[a].y, w: slots[a].w, h: slots[a].h })),
            strip: stripKeys.map((key, i) => ({
                key: key,
                x: Math.round(rowX + i * (stripCellWidth + stripCellGap) + (key.startsWith("special:") ? stripDetachGap - stripCellGap : 0)),
                y: Math.round(stripTop),
                w: Math.round(stripCellWidth),
                h: Math.round(stripCellHeight)
            }))
        };
    }

    // ── Drag and drop ───────────────────────────────────────────────────

    function setDropTarget(target) {
        if (dropTarget?.tile && dropTarget.tile !== target?.tile)
            dropTarget.tile.resetSwap();
        dropTarget = target;
    }

    function clearDropTarget(type, item) {
        if (!dropTarget)
            return;
        if (dropTarget.cell === item || dropTarget.tile === item)
            dropTarget = null;
    }

    function beginDrag(tile) {
        draggingAddress = tile.address;
        GlobalStates.keyboardActive = false;
    }

    function dragMoved(tile, x, y) {
        if (!Config.options.missionControl.springEdges)
            return;
        const edge = Math.max(12, screenWidth * 0.015);
        const dir = x < edge ? -1 : (x > screenWidth - edge ? 1 : 0);
        if (dir !== springTimer.direction) {
            springTimer.direction = dir;
            if (dir === 0)
                springTimer.stop();
            else
                springTimer.restart();
        }
    }

    function endDrag(tile, canceled) {
        springTimer.stop();
        springTimer.direction = 0;
        const target = dropTarget;
        const win = windowData(tile.address);
        dropTarget = null;
        draggingAddress = "";
        if (target?.tile)
            target.tile.resetSwap();
        if (canceled || !win)
            return;

        const fromWorkspace = win.workspace?.id ?? -1;
        if (!target) {
            // Carried to another desktop by the screen edge: drop it here.
            if (!isGridWindow(win) && !`${win.workspace?.name ?? ""}`.startsWith("special:"))
                Dispatch.moveWindow(win.address, activeWorkspaceId, false);
            return;
        }
        if (target.type === "workspace") {
            if (target.workspaceId !== fromWorkspace)
                Dispatch.moveWindow(win.address, target.workspaceId, false);
        } else if (target.type === "new") {
            Dispatch.moveWindow(win.address, freeWorkspaceId(), false);
        } else if (target.type === "special") {
            Dispatch.moveWindow(win.address, `special:${target.specialName}`, false);
        } else if (target.type === "swap") {
            if (target.tile?.swapArmed)
                Dispatch.swapWindows(win, windowData(target.address));
        }
        HyprlandData.updateAll();
    }

    Timer {
        id: springTimer
        property int direction: 0
        interval: Math.max(200, Config.options.missionControl.springDelayMs)
        repeat: true
        onTriggered: mc.stepWorkspace(direction, true)
    }

    // ── Background: clicking empty space closes the overview ───────────

    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        enabled: GlobalStates.overviewOpen
        onClicked: mc.controller.closeOverview(() => {})
    }

    WheelHandler {
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        enabled: GlobalStates.overviewOpen && !mc.showResults
        property real accumulated: 0
        onWheel: event => {
            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : -event.angleDelta.x;
            accumulated += delta;
            if (Math.abs(accumulated) < 120)
                return;
            mc.stepWorkspace(accumulated > 0 ? -1 : 1, false);
            accumulated = 0;
        }
    }

    // ── Strip ───────────────────────────────────────────────────────────

    Item {
        id: strip
        visible: mc.stripHeight > 0
        opacity: mc.progress
        y: mc.stripTop - (1 - mc.progress) * (mc.stripHeight + mc.stripTop)
        width: mc.width
        height: mc.stripCellHeight
        z: 2

        Row {
            id: stripRow
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: mc.stripCellGap

            Repeater {
                model: ScriptModel {
                    values: mc.stripKeys
                }
                delegate: StripCell {
                    id: stripCell
                    required property string modelData
                    required property int index
                    view: mc
                    cellIndex: index
                    kind: modelData === "new" ? "new" : (modelData.startsWith("special:") ? "special" : "workspace")
                    workspaceId: kind === "workspace" ? Number(modelData.slice(3)) : -1
                    specialName: kind === "special" ? modelData.slice(8) : ""
                    active: kind === "workspace" && workspaceId === mc.activeWorkspaceId
                    selected: GlobalStates.keyboardActive && GlobalStates.selectionMonitor === mc.monitorName
                        && GlobalStates.selectionRegion === "strip" && GlobalStates.selectionIndex === index
                    width: mc.stripCellWidth
                    height: mc.stripCellHeight
                    // Detach the special workspaces to the right.
                    transform: Translate {
                        x: stripCell.kind === "special" ? mc.stripDetachGap - mc.stripCellGap : 0
                    }
                }
            }
        }
    }

    // ── Search ──────────────────────────────────────────────────────────

    RectangularShadow {
        anchors.fill: searchPill
        visible: searchPill.visible
        z: 1
        radius: searchPill.radius
        offset: Qt.vector2d(0, 4)
        blur: 18
        color: Qt.rgba(0, 0, 0, 0.45)
        scale: searchPill.scale
        opacity: searchPill.opacity
    }

    RectangularShadow {
        anchors.fill: results
        visible: results.visible
        z: 2
        radius: results.radius
        offset: Qt.vector2d(0, 8)
        blur: 30
        color: Qt.rgba(0, 0, 0, 0.5)
    }

    SearchPill {
        id: searchPill
        visible: mc.searchEnabled
        anchors.horizontalCenter: parent.horizontalCenter
        // Drops in behind the strip, growing into place, and leaves the same
        // way on close.
        y: mc.searchTop - (1 - mc.progress) * (mc.stripHeight + mc.searchHeight + mc.gap * 2)
        scale: 0.9 + 0.1 * mc.progress
        z: 2
        opacity: mc.progress * mc.progress
        focused: mc.isPrimary && GlobalStates.query.length > 0
    }

    SearchResults {
        id: results
        visible: mc.showResults
        z: 3
        x: (mc.width - width) / 2
        y: mc.gridTop
        width: Math.min(mc.width - mc.marginX * 2, Math.max(520, mc.width * 0.42))
        height: Math.min(mc.gridBottom - mc.gridTop, results.results.length > 0 ? contentHeightHint : rowHeight + Style.spacing.popupPadding * 2)
        onActivated: result => mc.controller.activateResult(result)
    }

    // ── Grid ────────────────────────────────────────────────────────────

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        y: mc.gridTop + (mc.gridBottom - mc.gridTop) / 2 - height / 2
        visible: mc.orderedAddresses.length === 0 && !mc.showResults
        opacity: mc.progress * 0.6
        text: "No windows on this desktop"
        font.family: Style.font.family
        font.pixelSize: Style.font.heading
        color: Color.launcher.text
    }

    Item {
        id: tileLayer
        anchors.fill: parent
        z: 4

        Repeater {
            model: ScriptModel {
                values: mc.gridAddresses
            }
            delegate: MissionTile {
                id: tileDelegate
                required property string modelData
                view: mc
                appLibrary: mc.appLibrary
                windowData: mc.windowData(modelData)
                toplevel: mc.toplevelFor(modelData)
                realRect: mc.realRect(windowData)
                slotRect: mc.slots[modelData] ?? realRect
                dimmed: mc.showResults
                selected: GlobalStates.keyboardActive && mc.selectedAddress() === modelData
                onActivated: mc.activateTile(modelData)
            }
        }
    }
}
