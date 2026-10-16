.pragma library

// Mission-control layout: lay a workspace's windows out as a grid of tiles
// that keep their relative sizes and do not overlap.
//
// windows: [{ key, w, h, cx, cy }] -- logical size and on-screen centre
// area:    { x, y, w, h }          -- where the tiles may go
// opts:    { gap, labelHeight, maxScale }
//
// Returns { scale, slots: { key: { x, y, w, h } } }. Every row count from 1
// to n is tried, and the one that lets the windows be drawn largest wins
// (ties go to fewer rows). Windows are put in rows by their vertical centre
// and ordered within a row by their horizontal centre, so the grid reads in
// the same order as the desktop.
function layout(windows, area, opts) {
    const gap = Math.max(0, opts?.gap ?? 24);
    const labelHeight = Math.max(0, opts?.labelHeight ?? 0);
    const maxScale = opts?.maxScale ?? 1;
    const result = { scale: 1, rows: 0, slots: {} };
    const n = windows.length;
    if (n === 0 || area.w <= 0 || area.h <= 0)
        return result;

    const byY = windows.slice().sort((a, b) => (a.cy - b.cy) || (a.cx - b.cx));

    let best = null;
    for (let rowCount = 1; rowCount <= n; rowCount++) {
        const rows = splitRows(byY, rowCount);
        let scale = maxScale;
        let sumHeights = 0;
        for (const row of rows) {
            const widths = row.reduce((acc, w) => acc + Math.max(1, w.w), 0);
            const available = area.w - gap * (row.length - 1);
            scale = Math.min(scale, available / widths);
            sumHeights += Math.max(...row.map(w => Math.max(1, w.h)));
        }
        const availableHeight = area.h - gap * (rows.length - 1) - labelHeight * rows.length;
        scale = Math.min(scale, availableHeight / sumHeights);
        if (!(scale > 0))
            continue;
        if (!best || scale > best.scale * 1.0001)
            best = { scale, rows };
    }
    if (!best)
        return result;

    const scale = best.scale;
    const rowHeights = best.rows.map(row => Math.max(...row.map(w => Math.max(1, w.h))) * scale);
    const totalHeight = rowHeights.reduce((a, b) => a + b, 0) + gap * (best.rows.length - 1) + labelHeight * best.rows.length;
    let y = area.y + (area.h - totalHeight) / 2;

    best.rows.forEach((row, index) => {
        const rowHeight = rowHeights[index];
        const rowWidth = row.reduce((acc, w) => acc + Math.max(1, w.w) * scale, 0) + gap * (row.length - 1);
        let x = area.x + (area.w - rowWidth) / 2;
        for (const win of row) {
            const w = Math.max(1, win.w) * scale;
            const h = Math.max(1, win.h) * scale;
            result.slots[win.key] = {
                x: Math.round(x),
                y: Math.round(y + (rowHeight - h) / 2),
                w: Math.round(w),
                h: Math.round(h),
                row: index
            };
            x += w + gap;
        }
        y += rowHeight + labelHeight + gap;
    });

    result.scale = scale;
    result.rows = best.rows.length;
    return result;
}

// Contiguous runs of the y-sorted windows, as even in count as possible,
// each one ordered left to right.
function splitRows(sorted, rowCount) {
    const rows = [];
    const base = Math.floor(sorted.length / rowCount);
    let extra = sorted.length % rowCount;
    let index = 0;
    for (let r = 0; r < rowCount; r++) {
        const count = base + (extra > 0 ? 1 : 0);
        if (extra > 0)
            extra--;
        const row = sorted.slice(index, index + count).sort((a, b) => a.cx - b.cx);
        index += count;
        if (row.length > 0)
            rows.push(row);
    }
    return rows;
}

// Index of the rect nearest to `from` in a direction ("left", "right", "up",
// "down"), or -1. Off-axis distance counts double, so the pick stays in line.
function neighbour(rects, from, direction) {
    const origin = rects[from];
    if (!origin)
        return rects.length > 0 ? 0 : -1;
    const ox = origin.x + origin.w / 2;
    const oy = origin.y + origin.h / 2;
    let bestIndex = -1;
    let bestScore = Infinity;
    for (let i = 0; i < rects.length; i++) {
        if (i === from)
            continue;
        const r = rects[i];
        const dx = r.x + r.w / 2 - ox;
        const dy = r.y + r.h / 2 - oy;
        let along, across;
        if (direction === "left") { along = -dx; across = dy; }
        else if (direction === "right") { along = dx; across = dy; }
        else if (direction === "up") { along = -dy; across = dx; }
        else { along = dy; across = dx; }
        if (along <= 1)
            continue;
        const score = along + 2 * Math.abs(across);
        if (score < bestScore) {
            bestScore = score;
            bestIndex = i;
        }
    }
    return bestIndex;
}

// Lowest workspace id that no monitor uses and no workspace rule binds to
// another monitor, so "new desktop" never lands on someone else's id.
function firstFreeWorkspaceId(workspaces, rules, monitorName) {
    const taken = new Set();
    for (const ws of workspaces ?? []) {
        if (Number.isFinite(ws?.id) && ws.id > 0)
            taken.add(ws.id);
    }
    for (const rule of rules ?? []) {
        const id = Number(rule?.workspaceString);
        const boundMonitor = `${rule?.monitor ?? ""}`;
        if (Number.isInteger(id) && id > 0 && boundMonitor && boundMonitor !== monitorName)
            taken.add(id);
    }
    let id = 1;
    while (taken.has(id))
        id++;
    return id;
}

function lerp(a, b, t) {
    return a + (b - a) * t;
}
