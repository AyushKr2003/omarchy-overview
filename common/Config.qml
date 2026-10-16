pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/**
 * Settings from this plugin's entry in ~/.config/omarchy/shell.json. Flat keys
 * ("rows", "layout") are read with setting(); nested ones
 * ({"overview": {"scale": 0.2}}) with read("overview.scale").
 */
Singleton {
    id: root

    property var settings: ({})

    function setting(name, fallback) {
        var value = settings ? settings[name] : undefined;
        return value === undefined || value === null ? fallback : value;
    }

    function read(path, fallback) {
        let current = settings;
        for (const part of path.split(".")) {
            if (current === null || current === undefined || typeof current !== "object" || !(part in current))
                return fallback;
            current = current[part];
        }
        return current === undefined || current === null ? fallback : current;
    }

    // An integer of at least `min` (default 1), else the fallback.
    function asInt(value, fallback, min) {
        const parsed = Number(value);
        return Number.isInteger(parsed) && parsed >= (min ?? 1) ? parsed : fallback;
    }

    function asBool(value, fallback) {
        if (typeof value === "boolean")
            return value;
        if (typeof value === "string") {
            const normalized = value.trim().toLowerCase();
            if (normalized === "true")
                return true;
            if (normalized === "false")
                return false;
        }
        return fallback;
    }

    function readInt(path, fallback) {
        return asInt(read(path, fallback), fallback);
    }

    function readReal(path, fallback) {
        const parsed = Number(read(path, fallback));
        return Number.isFinite(parsed) ? parsed : fallback;
    }

    function readBool(path, fallback) {
        return asBool(read(path, fallback), fallback);
    }

    property QtObject options: QtObject {
        property QtObject appearance: QtObject {
            property QtObject animation: QtObject {
                property QtObject duration: QtObject {
                    property int elementMoveEnter: root.readInt("appearance.animation.duration.elementMoveEnter", 400)
                    property int elementMoveFast: root.readInt("appearance.animation.duration.elementMoveFast", 200)
                }
            }

            property QtObject sizes: QtObject {
                property real elevationMargin: root.readReal("appearance.sizes.elevationMargin", 10)
            }
        }

        property QtObject overview: QtObject {
            property int rows: root.asInt(root.setting("rows", 2), 2)
            property int columns: root.asInt(root.setting("columns", 5), 5)
            property real scale: root.readReal("overview.scale", 0.16)
            property bool enable: root.readBool("overview.enable", true)
            property bool hideEmptyRows: root.asBool(root.setting("hideEmptyRows", true), true)
            property bool closeOnFocusLoss: root.readBool("overview.closeOnFocusLoss", true)
            property bool useWorkspaceMap: root.readBool("overview.useWorkspaceMap", false)
            property var workspaceMap: root.read("overview.workspaceMap", [])
            property bool orderRightLeft: root.readBool("overview.orderRightLeft", false)
            property bool orderBottomUp: root.readBool("overview.orderBottomUp", false)
            property bool previewsEnabled: root.readBool("overview.previewsEnabled", true)
            property bool includeInactiveMonitorPreviews: root.readBool("overview.includeInactiveMonitorPreviews", true)
            property bool showSpecialWorkspaces: root.asBool(root.setting("showSpecialWorkspaces", false), false)
            property var specialWorkspaces: root.read("overview.specialWorkspaces", [])
            property int specialWorkspaceColumns: root.asInt(root.setting("specialWorkspaceColumns", columns), columns)
            property real workspaceSpacing: root.readReal("overview.workspaceSpacing", 5)
            property real backgroundPadding: root.readReal("overview.backgroundPadding", 10)
            property real workspaceNumberBaseSize: root.readReal("overview.workspaceNumberBaseSize", 250)
            property QtObject effects: QtObject {
                property real windowOverlayOpacity: root.readReal("overview.effects.windowOverlayOpacity", 0.22)
                property bool enableBlur: root.readBool("overview.effects.enableBlur", false)
            }
        }

        // Hyprdrive-style mission control: the focused workspace's windows as
        // a grid, a workspace strip on top, and type-to-search.
        property QtObject missionControl: QtObject {
            // "missionControl" or "grid" (the workspace grid).
            property string layout: {
                const value = `${root.setting("layout", "missionControl")}`.trim();
                return value === "grid" ? "grid" : "missionControl";
            }
            property int gap: root.asInt(root.setting("missionControlGap", 32), 32, 0)
            property real maxScale: root.readReal("missionControl.maxScale", 0.85)
            property bool showStrip: root.asBool(root.setting("showStrip", true), true)
            property int stripHeightPct: Math.min(30, root.asInt(root.setting("stripHeightPct", 17), 17))
            property int reflowMs: root.asInt(root.setting("reflowMs", 300), 300, 0)
            property bool openAnimation: root.asBool(root.setting("openAnimation", true), true)
            property int openMs: root.asInt(root.setting("openAnimationMs", 280), 280)
            property bool holdToSwap: root.asBool(root.setting("holdToSwap", true), true)
            property int holdToSwapMs: root.asInt(root.setting("holdToSwapMs", 1500), 1500)
            property real dragMiniScale: root.readReal("missionControl.dragMiniScale", 0.45)
            property bool springEdges: root.asBool(root.setting("springEdges", true), true)
            property int springDelayMs: root.asInt(root.setting("springDelayMs", 1500), 1500)
            property real backdropOpacity: Math.max(0, Math.min(1, root.readReal("backdropOpacity", 0.9)))
            property bool wallpaperBackdrop: root.asBool(root.setting("wallpaperBackdrop", true), true)
            property bool wallpaperBlur: root.asBool(root.setting("wallpaperBlur", true), true)
            property real wallpaperDim: Math.max(0, Math.min(1, root.readReal("wallpaperDim", 0.45)))
            property bool searchEnabled: root.asBool(root.setting("searchEnabled", true), true)
            // "off", "top-left", "top-right", "bottom-left" or "bottom-right".
            property string hotCorner: {
                const value = `${root.setting("hotCorner", "off")}`.trim();
                return ["top-left", "top-right", "bottom-left", "bottom-right"].includes(value) ? value : "off";
            }
            property int hotCornerDelayMs: root.asInt(root.setting("hotCornerDelayMs", 150), 150, 0)
        }

        property QtObject position: QtObject {
            property int topMargin: root.readInt("position.topMargin", 100)
        }

        property QtObject windowPreview: QtObject {
            property bool showIcons: root.asBool(root.setting("showIcons", false), false)
            property real iconToWindowRatio: root.readReal("windowPreview.iconToWindowRatio", 0.25)
            property real iconToWindowRatioCompact: root.readReal("windowPreview.iconToWindowRatioCompact", 0.45)
            property real inactiveMonitorOpacity: root.readReal("windowPreview.inactiveMonitorOpacity", 0.4)
            property bool cropToFill: root.readBool("windowPreview.cropToFill", false)
        }

        property QtObject hacks: QtObject {
            property int arbitraryRaceConditionDelay: root.readInt("hacks.arbitraryRaceConditionDelay", 150)
            property int hyprlandEventDebounceMs: root.asInt(root.read("hacks.hyprlandEventDebounceMs", 40), 40, 0)
        }
    }
}
