pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Shell
import "../common"
import "../common/functions/Calc.js" as Calc

/**
 * Type-to-search for the overview: open windows, apps, a calculator,
 * Omarchy menu actions, and (opt-in) files and GNOME search providers.
 *
 * Each result is { kind, key, title, subtitle, category, icon, glyph,
 * glyphFont, data }. The synchronous sources answer on every keystroke; files
 * and providers run in the background and keep their last answer on screen
 * until the next one lands.
 */
Singleton {
    id: root

    property var appLibrary: null
    property var shell: null
    property string query: GlobalStates.query
    readonly property string trimmedQuery: query.trim()

    property bool filesEnabled: Config.asBool(Config.setting("searchFiles", false), false)
    property bool providersEnabled: Config.asBool(Config.setting("searchProviders", false), false)
    property bool menuEnabled: Config.asBool(Config.setting("searchMenu", true), true)

    readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
    readonly property string pluginDir: Qt.resolvedUrl("..").toString().replace(/^file:\/\//, "")

    property var menuEntries: []
    property var fileResults: []
    property var providerResults: []

    readonly property var results: {
        const q = trimmedQuery;
        if (q.length === 0)
            return [];
        return [].concat(calculatorResults(q), windowResults(q), appResults(q), menuResults(q), fileResults, providerResults);
    }

    function words(text) {
        return `${text ?? ""}`.toLowerCase().split(/\s+/).filter(w => w.length > 0);
    }

    function matchScore(haystack, primary, terms) {
        const hay = `${haystack ?? ""}`.toLowerCase();
        for (const term of terms) {
            if (hay.indexOf(term) < 0)
                return -1;
        }
        const head = `${primary ?? ""}`.toLowerCase();
        const first = terms[0] ?? "";
        if (head.startsWith(first))
            return 3;
        if (head.split(/[^a-z0-9]+/).some(w => w.startsWith(first)))
            return 2;
        return 1;
    }

    function calculatorResults(q) {
        const value = Calc.evaluate(q);
        if (value === null)
            return [];
        const text = Calc.format(value);
        return [{
            kind: "calc",
            key: "calc",
            title: `= ${text}`,
            subtitle: "Enter copies the result",
            category: "Calculator",
            icon: "",
            glyph: "󰃬",
            glyphFont: "",
            data: { value: text }
        }];
    }

    function windowResults(q) {
        const terms = words(q);
        const out = [];
        for (const win of HyprlandData.windowList ?? []) {
            if (!win?.mapped && win?.mapped !== undefined)
                continue;
            const hay = [win.title, win.class, win.initialTitle, win.initialClass].join(" ");
            const score = matchScore(hay, win.title, terms);
            if (score < 0)
                continue;
            const ws = `${win.workspace?.name ?? win.workspace?.id ?? ""}`;
            out.push({
                kind: "window",
                key: `window:${win.address}`,
                title: win.title || win.class || "Window",
                subtitle: `${win.class ?? ""} · ${ws.startsWith("special:") ? ws.slice(8) : "workspace " + ws}`,
                category: "Windows",
                icon: WindowIcon.iconSourceFor(win, root.appLibrary),
                glyph: "",
                glyphFont: "",
                score: score,
                data: { address: win.address }
            });
        }
        out.sort((a, b) => b.score - a.score);
        return out.slice(0, 6);
    }

    function appResults(q) {
        if (!root.appLibrary)
            return [];
        // Ranked rows: { entry, score, key, name }.
        const rows = root.appLibrary.sortedEntries(q) ?? [];
        const out = [];
        for (let i = 0; i < rows.length && out.length < 8; i++) {
            const entry = rows[i]?.entry ?? rows[i];
            if (!entry?.id)
                continue;
            out.push({
                kind: "app",
                key: `app:${entry.id}`,
                title: root.appLibrary.entryName(entry),
                subtitle: root.appLibrary.entrySubtext(entry) || entry.comment || "",
                category: "Apps",
                icon: root.appIconSource(entry),
                glyph: "",
                glyphFont: "",
                data: { id: entry.id, name: root.appLibrary.entryName(entry) }
            });
        }
        return out;
    }

    // The entry's own icon, else one named after its id or name, so an entry
    // pointing at a missing icon still gets a real one before the gear.
    function appIconSource(entry) {
        const id = `${entry?.id ?? ""}`.replace(/\.desktop$/, "");
        const candidates = [entry?.icon, id, id.toLowerCase(), id.split(".").pop().toLowerCase(), `${entry?.name ?? ""}`.toLowerCase()];
        for (const candidate of candidates) {
            if (WindowIcon.resolves(candidate, root.appLibrary))
                return root.appLibrary.iconSource(candidate);
        }
        return root.appLibrary.iconSource("");
    }

    function menuResults(q) {
        if (!root.menuEnabled)
            return [];
        const terms = words(q);
        const out = [];
        for (const entry of root.menuEntries) {
            const score = matchScore(entry.searchText, entry.label, terms);
            if (score < 0)
                continue;
            out.push({
                kind: "menu",
                key: `menu:${entry.id}`,
                title: entry.label,
                subtitle: entry.path,
                category: "Omarchy menu",
                icon: "",
                glyph: entry.icon,
                glyphFont: entry.iconFont,
                score: score,
                data: { action: entry.action }
            });
        }
        out.sort((a, b) => b.score - a.score);
        return out.slice(0, 6);
    }

    // ── Omarchy menu ────────────────────────────────────────────────────
    // Read-only: the shell's menu JSONC (defaults + the user's extension),
    // flattened to its runnable leaves.

    function stripJsonc(raw) {
        return String(raw || "")
            .replace(/^\s*\/\/[^\n]*(\n|$)/gm, "")
            .replace(/,(\s*[}\]])/g, "$1");
    }

    function parseMenu(raw) {
        try {
            const parsed = JSON.parse(stripJsonc(raw) || "{}");
            const items = (parsed && parsed.items && typeof parsed.items === "object") ? parsed.items : parsed;
            return (items && typeof items === "object" && !Array.isArray(items)) ? items : ({});
        } catch (e) {
            return ({});
        }
    }

    function rebuildMenu() {
        const merged = ({});
        for (const source of [parseMenu(defaultMenuFile.text()), parseMenu(userMenuFile.text())]) {
            for (const id in source) {
                const prev = merged[id] ?? ({});
                const next = ({});
                for (const k in prev) next[k] = prev[k];
                for (const k in source[id]) next[k] = source[id][k];
                merged[id] = next;
            }
        }

        const labelFor = id => `${merged[id]?.label ?? id.split(".").pop()}`;
        const entries = [];
        for (const id in merged) {
            const item = merged[id];
            // Rows guarded by a shell condition only make sense where the
            // menu itself evaluates it.
            if (!item || !item.action || item.provider || item.when || item.disabled)
                continue;
            const parents = [];
            const parts = id.split(".");
            for (let i = 1; i < parts.length; i++)
                parents.push(labelFor(parts.slice(0, i).join(".")));
            const aliases = Array.isArray(item.aliases) ? item.aliases.join(" ") : `${item.aliases ?? ""}`;
            const terms = Array.isArray(item.searchTerms) ? item.searchTerms.join(" ") : "";
            entries.push({
                id: id,
                label: `${item.label ?? parts[parts.length - 1]}`,
                path: parents.length > 0 ? parents.join(" › ") : "Omarchy menu",
                icon: `${item.icon ?? ""}`,
                iconFont: `${item.iconFont ?? ""}`,
                action: `${item.action}`,
                searchText: [item.label, aliases, terms, item.description ?? "", parents.join(" ")].join(" ")
            });
        }
        root.menuEntries = entries;
    }

    FileView {
        id: defaultMenuFile
        path: root.omarchyPath + "/default/omarchy/omarchy-menu.jsonc"
        watchChanges: true
        printErrors: false
        onLoaded: root.rebuildMenu()
        onFileChanged: reload()
    }

    FileView {
        id: userMenuFile
        path: Quickshell.env("HOME") + "/.config/omarchy/extensions/omarchy-menu.jsonc"
        watchChanges: true
        printErrors: false
        onLoaded: root.rebuildMenu()
        onFileChanged: reload()
    }

    // ── Background sources ──────────────────────────────────────────────

    onTrimmedQueryChanged: {
        if (trimmedQuery.length < 2) {
            fileResults = [];
            providerResults = [];
            asyncTimer.stop();
            return;
        }
        asyncTimer.restart();
    }

    Timer {
        id: asyncTimer
        interval: 180
        repeat: false
        onTriggered: {
            const q = root.trimmedQuery;
            if (root.filesEnabled) {
                fileProc.running = false;
                fileProc.forQuery = q;
                fileProc.command = ["fd", "--ignore-case", "--max-results", "8", "--max-depth", "6", "--fixed-strings", "--", q, Quickshell.env("HOME")];
                fileProc.running = true;
            }
            if (root.providersEnabled) {
                providerProc.running = false;
                providerProc.forQuery = q;
                providerProc.command = ["python3", "-I", root.pluginDir + "/scripts/search-providers.py", "search", q, "5"];
                providerProc.running = true;
            }
        }
    }

    Process {
        id: fileProc
        property string forQuery: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (fileProc.forQuery !== root.trimmedQuery)
                    return;
                const home = Quickshell.env("HOME");
                const out = [];
                for (const line of text.split("\n")) {
                    const path = line.trim();
                    if (!path)
                        continue;
                    const isDir = path.endsWith("/");
                    const clean = isDir ? path.slice(0, -1) : path;
                    const name = clean.split("/").pop();
                    const dir = clean.slice(0, clean.length - name.length - 1);
                    out.push({
                        kind: "file",
                        key: `file:${clean}`,
                        title: name,
                        subtitle: dir.startsWith(home) ? "~" + dir.slice(home.length) : dir,
                        category: "Files",
                        icon: Quickshell.iconPath(isDir ? "folder" : "text-x-generic", true),
                        glyph: "",
                        glyphFont: "",
                        data: { path: clean }
                    });
                }
                root.fileResults = out;
            }
        }
    }

    Process {
        id: providerProc
        property string forQuery: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (providerProc.forQuery !== root.trimmedQuery)
                    return;
                let parsed = [];
                try {
                    parsed = JSON.parse(text || "[]");
                } catch (e) {
                    return;
                }
                const out = [];
                for (const r of parsed) {
                    const icon = `${r.icon ?? ""}`;
                    out.push({
                        kind: "provider",
                        key: `provider:${r.bus}:${r.id}`,
                        title: r.name || r.id,
                        subtitle: r.description || "",
                        category: `${r.desktopId ?? ""}`.replace(/\.desktop$/, "").split(".").pop() || "Search",
                        icon: icon.startsWith("/") ? Util.fileUrl(icon) : Quickshell.iconPath(icon || "system-search", true),
                        glyph: "",
                        glyphFont: "",
                        data: r
                    });
                }
                root.providerResults = out;
            }
        }
    }

    // ── Activation ──────────────────────────────────────────────────────

    function runAction(action) {
        const command = `${action ?? ""}`;
        if (!command)
            return;
        const summon = /^omarchy-shell shell summon ([A-Za-z0-9._-]+)(?: '([^']*)')?$/.exec(command);
        if (summon && root.shell && root.shell.summon(summon[1], summon[2] || "{}"))
            return;
        Shell.Util.execDetached(command);
    }

    // Runs a result. Window results are handled by the overview, which owns
    // the close animation and cursor warp.
    function activate(result) {
        if (!result)
            return;
        const data = result.data ?? ({});
        if (result.kind === "app") {
            if (root.appLibrary)
                root.appLibrary.launch(data.id, data.name);
        } else if (result.kind === "calc") {
            Shell.Util.execArgv(["wl-copy", "--", `${data.value}`]);
        } else if (result.kind === "menu") {
            runAction(data.action);
        } else if (result.kind === "file") {
            Shell.Util.execArgv(["uwsm-app", "--", "xdg-open", data.path]);
        } else if (result.kind === "provider") {
            Shell.Util.execArgv(["python3", "-I", root.pluginDir + "/scripts/search-providers.py", "activate", data.bus, data.path, data.id, root.trimmedQuery]);
        }
    }
}
