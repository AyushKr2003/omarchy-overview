pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../common"

/**
 * Window, workspace and monitor data from `hyprctl ... -j`, refreshed
 * (debounced) on Hyprland events. Quickshell.Hyprland does not expose window
 * geometry, focus history or workspace rules.
 */
Singleton {
    id: root
    property var windowList: []
    property var windowByAddress: ({})
    property var allWorkspaces: []
    property var workspaceIds: []
    property var monitors: []
    property var workspaceRules: []
    // Emitted after each `hyprctl clients` refresh lands.
    signal windowsUpdated()

    property bool pendingWindowsUpdate: false
    property bool pendingMonitorsUpdate: false
    property bool pendingWorkspacesUpdate: false

    function updateAll() {
        scheduleUpdates(true, true, true);
    }

    function scheduleUpdates(windows, monitors, workspaces) {
        pendingWindowsUpdate = pendingWindowsUpdate || !!windows;
        pendingMonitorsUpdate = pendingMonitorsUpdate || !!monitors;
        pendingWorkspacesUpdate = pendingWorkspacesUpdate || !!workspaces;

        const debounceMs = Math.max(0, Config.options.hacks.hyprlandEventDebounceMs);
        if (debounceMs === 0) {
            flushPendingUpdates();
        } else {
            eventDebounceTimer.interval = debounceMs;
            eventDebounceTimer.restart();
        }
    }

    function flushPendingUpdates() {
        if (pendingWindowsUpdate) {
            pendingWindowsUpdate = false;
            getClients.running = true;
        }
        if (pendingMonitorsUpdate) {
            pendingMonitorsUpdate = false;
            getMonitors.running = true;
            getWorkspaceRules.running = true;
        }
        if (pendingWorkspacesUpdate) {
            pendingWorkspacesUpdate = false;
            getWorkspaces.running = true;
        }
    }

    Component.onCompleted: {
        scheduleUpdates(true, true, true);
        flushPendingUpdates();
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            const eventName = `${event?.name ?? event?.event ?? event?.type ?? ""}`;
            if (["openlayer", "closelayer", "screencast"].includes(eventName))
                return;

            if (eventName === "openwindow" || eventName === "closewindow" || eventName === "movewindow" || eventName === "movewindowv2" || eventName === "windowtitle") {
                scheduleUpdates(true, false, true);
                return;
            }

            if (eventName === "workspace" || eventName === "workspacev2" || eventName === "focusedmon" || eventName === "focusedmonv2" || eventName === "activewindow" || eventName === "activewindowv2") {
                scheduleUpdates(false, false, true);
                return;
            }

            scheduleUpdates(true, true, true);
        }
    }

    Timer {
        id: eventDebounceTimer
        interval: Math.max(0, Config.options.hacks.hyprlandEventDebounceMs)
        repeat: false
        onTriggered: root.flushPendingUpdates()
    }

    Process {
        id: getClients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            id: clientsCollector
            onStreamFinished: {
                root.windowList = JSON.parse(clientsCollector.text);
                let tempWinByAddress = {};
                for (var i = 0; i < root.windowList.length; ++i) {
                    var win = root.windowList[i];
                    tempWinByAddress[win.address] = win;
                }
                root.windowByAddress = tempWinByAddress;
                root.windowsUpdated();
            }
        }
    }

    Process {
        id: getMonitors
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            id: monitorsCollector
            onStreamFinished: {
                root.monitors = JSON.parse(monitorsCollector.text);
            }
        }
    }

    Process {
        id: getWorkspaceRules
        command: ["hyprctl", "workspacerules", "-j"]
        stdout: StdioCollector {
            id: workspaceRulesCollector
            onStreamFinished: {
                try {
                    root.workspaceRules = JSON.parse(workspaceRulesCollector.text);
                } catch (e) {
                    root.workspaceRules = [];
                }
            }
        }
    }

    Process {
        id: getWorkspaces
        command: ["hyprctl", "workspaces", "-j"]
        stdout: StdioCollector {
            id: workspacesCollector
            onStreamFinished: {
                root.allWorkspaces = JSON.parse(workspacesCollector.text);
                root.workspaceIds = root.allWorkspaces.filter(ws => ws.id >= 1 && ws.id <= 100).map(ws => ws.id);
            }
        }
    }
}
