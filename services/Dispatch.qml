pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland

/**
 * Every compositor action the overview takes, with the Lua / legacy
 * dispatcher split written once.
 */
Singleton {
    id: root

    // Values end up inside a single-quoted Lua string or a legacy argument.
    function clean(value) {
        return `${value ?? ""}`.replace(/['\\\n\r]/g, "");
    }

    function addr(address) {
        return `address:${clean(address)}`;
    }

    function focusWorkspace(id) {
        const ws = clean(id);
        if (!ws)
            return;
        if (Hyprland.usingLua)
            Hyprland.dispatch(`hl.dsp.focus({ workspace = '${ws}' })`);
        else
            Hyprland.dispatch(`workspace ${ws}`);
    }

    function focusWindow(address) {
        if (!address)
            return;
        if (Hyprland.usingLua)
            Hyprland.dispatch(`hl.dsp.focus({ window = '${addr(address)}' })`);
        else
            Hyprland.dispatch(`focuswindow ${addr(address)}`);
    }

    function closeWindow(address) {
        if (!address)
            return;
        if (Hyprland.usingLua)
            Hyprland.dispatch(`hl.dsp.window.close('${addr(address)}')`);
        else
            Hyprland.dispatch(`closewindow ${addr(address)}`);
    }

    // workspace: a numeric id or a "special:name" string.
    function moveWindow(address, workspace, follow) {
        const ws = clean(workspace);
        if (!address || !ws)
            return;
        if (Hyprland.usingLua)
            Hyprland.dispatch(`hl.dsp.window.move({ workspace = '${ws}', follow = ${follow ? "true" : "false"}, window = '${addr(address)}' })`);
        else
            Hyprland.dispatch(`${follow ? "movetoworkspace" : "movetoworkspacesilent"} ${ws}, ${addr(address)}`);
    }

    function toggleSpecial(name) {
        const ws = clean(name);
        if (Hyprland.usingLua)
            Hyprland.dispatch(`hl.dsp.workspace.toggle_special('${ws}')`);
        else
            Hyprland.dispatch(`togglespecialworkspace ${ws}`);
    }

    // Swap two windows. On one workspace the layout swaps them in place; on
    // two workspaces each window is moved to the other's workspace.
    function swapWindows(a, b) {
        if (!a || !b || a.address === b.address)
            return;
        const wsA = a.workspace?.name ?? `${a.workspace?.id ?? ""}`;
        const wsB = b.workspace?.name ?? `${b.workspace?.id ?? ""}`;
        if (wsA === wsB) {
            if (Hyprland.usingLua)
                Hyprland.dispatch(`hl.dsp.window.swap({ window = '${addr(a.address)}', target = '${addr(b.address)}' })`);
            else
                Hyprland.dispatch(`swapwindow ${addr(b.address)}`);
            return;
        }
        moveWindow(a.address, wsB, false);
        moveWindow(b.address, wsA, false);
    }

    // Global logical coordinates.
    function warpCursor(x, y) {
        if (!Number.isFinite(x) || !Number.isFinite(y))
            return;
        if (Hyprland.usingLua)
            Hyprland.dispatch(`hl.dsp.cursor.move({ x = ${Math.round(x)}, y = ${Math.round(y)} })`);
        else
            Hyprland.dispatch(`movecursor ${Math.round(x)} ${Math.round(y)}`);
    }

    // Focus a window and put the pointer in the middle of it. Moving the
    // cursor in also hands a game back its pointer lock.
    function activateWindow(windowData) {
        if (!windowData?.address)
            return;
        focusWindow(windowData.address);
        const at = windowData.at ?? [];
        const size = windowData.size ?? [];
        if (at.length === 2 && size.length === 2)
            warpCursor(at[0] + size[0] / 2, at[1] + size[1] / 2);
    }
}
