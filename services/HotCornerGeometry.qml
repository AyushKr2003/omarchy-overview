pragma Singleton

import QtQuick
import Quickshell

Singleton {
    // Logical rect of a monitor from `hyprctl monitors -j`.
    function rectOf(m) {
        const rotated = (m?.transform ?? 0) % 2 === 1;
        const scale = m?.scale || 1;
        const w = (rotated ? m.height : m.width) / scale;
        const h = (rotated ? m.width : m.height) / scale;
        return { x: m.x, y: m.y, w: w, h: h };
    }

    function contains(r, x, y) {
        return x >= r.x && x < r.x + r.w && y >= r.y && y < r.y + r.h;
    }

    // True when no other monitor touches this corner of `name`.
    function isOuterCorner(monitors, name, position) {
        const self = (monitors ?? []).find(m => m.name === name);
        if (!self || position === "off")
            return false;
        const r = rectOf(self);
        const right = position.endsWith("right");
        const bottom = position.startsWith("bottom");
        const cx = right ? r.x + r.w - 1 : r.x;
        const cy = bottom ? r.y + r.h - 1 : r.y;
        const dx = right ? 1 : -1;
        const dy = bottom ? 1 : -1;
        const probes = [[cx + dx, cy], [cx, cy + dy], [cx + dx, cy + dy]];
        for (const m of monitors) {
            if (m.name === name || m.disabled)
                continue;
            const other = rectOf(m);
            if (probes.some(p => contains(other, p[0], p[1])))
                return false;
        }
        return true;
    }
}
