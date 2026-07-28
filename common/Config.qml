pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    property var settings: ({})

    function flatKeyFor(path) {
        if (path === "overview.rows")
            return "rows";
        if (path === "overview.columns")
            return "columns";
        if (path === "overview.hideEmptyRows")
            return "hideEmptyRows";
        if (path === "overview.showSpecialWorkspaces")
            return "showSpecialWorkspaces";
        if (path === "overview.specialWorkspaceColumns")
            return "specialWorkspaceColumns";
        if (path === "windowPreview.showIcons")
            return "showIcons";
        return "";
    }

    // Same inline shell.json helper shape used by Omarchy panels.
    function setting(name, fallback) {
        var value = settings ? settings[name] : undefined;
        return value === undefined || value === null ? fallback : value;
    }

    function read(path, fallback) {
        const parts = path.split(".");
        let current = settings;

        for (const part of parts) {
            if (current === null || current === undefined || typeof current !== "object" || !(part in current)) {
                const flatKey = root.flatKeyFor(path);
                if (flatKey)
                    return root.setting(flatKey, fallback);
                return fallback;
            }
            current = current[part];
        }

        return current === undefined || current === null ? fallback : current;
    }

    function readInt(path, fallback) {
        const value = read(path, fallback);
        return asInt(value, fallback);
    }

    function asInt(value, fallback) {
        const parsed = Number(value);
        return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
    }

    function readReal(path, fallback) {
        const value = read(path, fallback);
        const parsed = Number(value);
        return Number.isFinite(parsed) ? parsed : fallback;
    }

    function readBool(path, fallback) {
        const value = read(path, fallback);
        return asBool(value, fallback);
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

    function readString(path, fallback) {
        const value = read(path, fallback);
        if (typeof value !== "string")
            return fallback;

        const trimmed = value.trim();
        return trimmed.length > 0 ? trimmed : fallback;
    }

    property QtObject options: QtObject {
        property QtObject appearance: QtObject {
            property string colorSource: "default"
            property bool useMatugenColors: colorSource === "matugen"
            property QtObject caelestia: QtObject {
                property bool autoRefresh: true
                property int refreshInterval: 2000
                property string accentProfile: "vibrant"
            }

            property QtObject rounding: QtObject {
                property int unsharpen: root.readInt("appearance.rounding.unsharpen", 2)
                property int verysmall: root.readInt("appearance.rounding.verysmall", 8)
                property int small: root.readInt("appearance.rounding.small", 12)
                property int normal: root.readInt("appearance.rounding.normal", 17)
                property int large: root.readInt("appearance.rounding.large", 23)
                property int full: root.readInt("appearance.rounding.full", 9999)
                property int screenRounding: root.readInt("appearance.rounding.screenRounding", large)
                property int windowRounding: root.readInt("appearance.rounding.windowRounding", 18)
            }

            property QtObject font: QtObject {
                property QtObject family: QtObject {
                    property string main: root.readString("appearance.font.family.main", "sans-serif")
                    property string title: root.readString("appearance.font.family.title", "sans-serif")
                    property string expressive: root.readString("appearance.font.family.expressive", "sans-serif")
                }

                property QtObject pixelSize: QtObject {
                    property int smaller: root.readInt("appearance.font.pixelSize.smaller", 12)
                    property int small: root.readInt("appearance.font.pixelSize.small", 15)
                    property int normal: root.readInt("appearance.font.pixelSize.normal", 16)
                    property int larger: root.readInt("appearance.font.pixelSize.larger", 19)
                    property int huge: root.readInt("appearance.font.pixelSize.huge", 22)
                }
            }

            property QtObject animation: QtObject {
                property QtObject duration: QtObject {
                    property int elementMove: root.readInt("appearance.animation.duration.elementMove", 500)
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
            property string previewMode: "live"
            property bool includeInactiveMonitorPreviews: root.readBool("overview.includeInactiveMonitorPreviews", true)
            property int previewRecaptureDelayMs: root.readInt("overview.previewRecaptureDelayMs", 60)
            property bool showSpecialWorkspaces: root.asBool(root.setting("showSpecialWorkspaces", false), false)
            property var specialWorkspaces: root.read("overview.specialWorkspaces", [])
            property int specialWorkspaceColumns: root.asInt(root.setting("specialWorkspaceColumns", columns), columns)
            property string emptyWorkspaceWallpaper: ""
            property string specialEmptyWorkspaceWallpaper: ""
            property real workspaceSpacing: root.readReal("overview.workspaceSpacing", 5)
            property real backgroundPadding: root.readReal("overview.backgroundPadding", 10)
            property real workspaceNumberBaseSize: root.readReal("overview.workspaceNumberBaseSize", 250)
            property QtObject effects: QtObject {
                property bool enableBackdrop: root.readBool("overview.effects.enableBackdrop", false)
                property real backdropOpacity: root.readReal("overview.effects.backdropOpacity", 0.28)
                property real panelOpacity: root.readReal("overview.effects.panelOpacity", 0.92)
                property real workspaceOpacity: root.readReal("overview.effects.workspaceOpacity", 0.86)
                property real emptyWorkspaceWallpaperOverlayOpacity: root.readReal("overview.effects.emptyWorkspaceWallpaperOverlayOpacity", 0.18)
                property real windowOverlayOpacity: root.readReal("overview.effects.windowOverlayOpacity", 0.22)
                property bool enableBlur: root.readBool("overview.effects.enableBlur", false)
                property bool glassMode: root.readBool("overview.effects.glassMode", false)
                property real glassTintStrength: root.readReal("overview.effects.glassTintStrength", 0.35)
                property real glassBorderOpacity: root.readReal("overview.effects.glassBorderOpacity", 0.72)
                property real glassShineOpacity: root.readReal("overview.effects.glassShineOpacity", 0.14)
            }
        }

        property QtObject position: QtObject {
            property int topMargin: root.readInt("position.topMargin", 100)
        }

        property QtObject windowPreview: QtObject {
            property bool showIcons: root.asBool(root.setting("showIcons", false), false)
            property real iconToWindowRatio: root.readReal("windowPreview.iconToWindowRatio", 0.25)
            property real iconToWindowRatioCompact: root.readReal("windowPreview.iconToWindowRatioCompact", 0.45)
            property real xwaylandIndicatorToIconRatio: root.readReal("windowPreview.xwaylandIndicatorToIconRatio", 0.35)
            property real inactiveMonitorOpacity: root.readReal("windowPreview.inactiveMonitorOpacity", 0.4)
            property bool cropToFill: root.readBool("windowPreview.cropToFill", false)
        }

        property QtObject hacks: QtObject {
            property int arbitraryRaceConditionDelay: root.readInt("hacks.arbitraryRaceConditionDelay", 150)
            property int hyprlandEventDebounceMs: root.readInt("hacks.hyprlandEventDebounceMs", 40)
        }
    }
}
