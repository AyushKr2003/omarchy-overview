pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string defaultBrowserDesktopId: "chromium.desktop"
    property string defaultTerminalDesktopId: "Alacritty.desktop"
    readonly property var fallbackBrowserIds: [
        defaultBrowserDesktopId,
        "google-chrome.desktop",
        "google-chrome-stable.desktop",
        "brave-browser.desktop",
        "brave.desktop",
        "microsoft-edge.desktop",
        "microsoft-edge-stable.desktop",
        "opera.desktop",
        "vivaldi-stable.desktop",
        "vivaldi.desktop",
        "helium.desktop",
        "chromium.desktop",
        "chromium-browser.desktop"
    ]
    readonly property var fallbackTerminalIds: [
        defaultTerminalDesktopId,
        "Alacritty.desktop",
        "foot.desktop",
        "footclient.desktop",
        "com.mitchellh.ghostty.desktop",
        "kitty.desktop",
        "org.wezfurlong.wezterm.desktop"
    ]

    function normalizeDesktopId(value) {
        var id = String(value || "").trim().toLowerCase()
        if (id.indexOf("/") >= 0)
            id = id.split("/").pop()
        if (id.slice(-8) === ".desktop")
            id = id.slice(0, -8)
        return id
    }

    function supportedBrowserDesktopId(value) {
        var id = String(value || "").trim()
        var normalized = normalizeDesktopId(id)
        if (normalized.indexOf("google-chrome") === 0 ||
            normalized.indexOf("brave") === 0 ||
            normalized.indexOf("microsoft-edge") === 0 ||
            normalized.indexOf("opera") === 0 ||
            normalized.indexOf("vivaldi") === 0 ||
            normalized.indexOf("helium") === 0 ||
            normalized.indexOf("chromium") === 0)
            return id.length > 0 ? id : "chromium.desktop"
        return "chromium.desktop"
    }

    function isBrowserLikeClass(value) {
        var cls = normalizeDesktopId(value)
        if (!cls)
            return false
        return cls.indexOf("chrom") >= 0 ||
            cls.indexOf("brave") >= 0 ||
            cls.indexOf("vivaldi") >= 0 ||
            cls.indexOf("microsoft-edge") >= 0 ||
            cls.indexOf("opera") >= 0 ||
            cls.indexOf("helium") >= 0 ||
            cls.indexOf("crx_") === 0 ||
            cls.indexOf("webapp") >= 0
    }

    function isTerminalLikeClass(value) {
        var cls = normalizeDesktopId(value)
        if (!cls)
            return false
        return cls === "org.omarchy.terminal" ||
            cls === "org.omarchy.screensaver" ||
            cls.indexOf("org.omarchy.") === 0 ||
            cls === "tui.float" ||
            cls === "tui.tile" ||
            cls === "kitty" ||
            cls === "alacritty" ||
            cls === "foot" ||
            cls === "footclient" ||
            cls === "ghostty" ||
            cls === "com.mitchellh.ghostty" ||
            cls === "wezterm" ||
            cls === "org.wezfurlong.wezterm" ||
            cls === "st" ||
            cls === "urxvt" ||
            cls === "xterm" ||
            cls === "rio" ||
            cls === "konsole" ||
            cls === "gnome-terminal"
    }

    function iconForDesktopId(desktopId) {
        var target = normalizeDesktopId(desktopId)
        if (!target)
            return ""

        var entries = DesktopEntries.applications.values || []
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i]
            if (normalizeDesktopId(entry && entry.id) === target)
                return String((entry && entry.icon) || "").trim()
        }

        var heuristic = DesktopEntries.heuristicLookup(target)
        return String((heuristic && heuristic.icon) || "").trim()
    }

    function firstAvailableIcon(desktopIds) {
        for (var i = 0; i < desktopIds.length; i++) {
            var icon = iconForDesktopId(desktopIds[i])
            if (icon.length > 0)
                return icon
        }
        return ""
    }

    function browserIconForWindow(windowData) {
        var cls = windowData?.class
        var initialClass = windowData?.initialClass
        if (!isBrowserLikeClass(cls) && !isBrowserLikeClass(initialClass))
            return ""

        return firstAvailableIcon(fallbackBrowserIds)
    }

    function terminalIconForWindow(windowData) {
        var cls = windowData?.class
        var initialClass = windowData?.initialClass
        if (!isTerminalLikeClass(cls) && !isTerminalLikeClass(initialClass))
            return ""

        return firstAvailableIcon(fallbackTerminalIds)
    }

    function fallbackIconForWindow(windowData) {
        var terminalIcon = terminalIconForWindow(windowData)
        if (terminalIcon.length > 0)
            return terminalIcon

        return browserIconForWindow(windowData)
    }

    Process {
        id: defaultBrowserProcess
        command: ["sh", "-lc", "xdg-settings get default-web-browser 2>/dev/null || true"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.defaultBrowserDesktopId = root.supportedBrowserDesktopId(text)
            }
        }
    }

    Process {
        id: defaultTerminalProcess
        command: ["sh", "-lc", "xdg-terminal-exec --print-id 2>/dev/null || grep -vE '^($|#)' \"$HOME/.config/xdg-terminals.list\" 2>/dev/null | head -n 1 || true"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var id = String(text || "").trim()
                if (id.length > 0)
                    root.defaultTerminalDesktopId = id
            }
        }
    }

    Component.onCompleted: {
        defaultBrowserProcess.running = true
        defaultTerminalProcess.running = true
    }
}
