pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../common"

/**
 * Resolves an icon for a Hyprland client: desktop entries, webapps/PWAs,
 * TUI apps running in a terminal, then generic browser/terminal fallbacks.
 */
Singleton {
    id: root

    // Bindings that call iconNameFor() should also read
    // DesktopEntries.applications.values and FallbackIcon's default ids so
    // they re-run when the entry index changes.

    function extractAppNameFromClass(cls) {
        if (!cls) return "";
        var str = String(cls).trim();
        var s = str.replace(/^chrome-https?___?/i, "").replace(/^chrome-http?___?/i, "").replace(/^chrome-/, "");
        s = s.replace(/_?_?app-Default$/i, "").replace(/-Default$/i, "");
        if (s.indexOf(".") >= 0) {
            var parts = s.split(".");
            if (parts.length >= 2) {
                var name = parts[parts.length - 2];
                if (name !== "com" && name !== "org" && name !== "net" && name !== "io" && name !== "app") {
                    return name;
                }
            }
        }
        return s;
    }

    // An icon name or path that will actually draw (not the "missing" gear).
    function resolves(icon, appLibrary) {
        const value = `${icon ?? ""}`.trim();
        if (!value)
            return false;
        if (value.startsWith("/") || value.startsWith("file://") || value.startsWith("image://"))
            return true;
        if (appLibrary && appLibrary.iconIndex && appLibrary.iconIndex[value])
            return true;
        return Quickshell.iconPath(value, true).length > 0;
    }

    // exact: only an entry whose id or name is the key, no fuzzy match. Words
    // pulled out of a terminal title ("work", "main") would otherwise land on
    // whatever app the heuristic likes best.
    function lookupEntryIcon(key, entries, exact) {
        if (!key) return "";
        if (!exact) {
            var h = DesktopEntries.heuristicLookup(key);
            var icon = String((h && h.icon) || "").trim();
            if (icon.length > 0) return icon;
        }

        var normKey = key.toLowerCase().replace(/\.desktop$/, "");
        for (var i = 0; i < entries.length; i++) {
            var e = entries[i];
            if (!e) continue;
            var eId = String(e.id || "").toLowerCase().replace(/\.desktop$/, "");
            var eName = String(e.name || "").toLowerCase();
            if (eId === normKey || eName === normKey) {
                var eIcon = String(e.icon || "").trim();
                if (eIcon.length > 0) return eIcon;
            }
        }
        return "";
    }

    function hasThemedIcon(name, appLibrary) {
        if (appLibrary && appLibrary.iconIndex && appLibrary.iconIndex[name])
            return true;
        // check = true: an empty string when the theme has no such icon.
        return Quickshell.iconPath(name, true).length > 0;
    }

    function findTuiAppIcon(title, initialTitle, entries, appLibrary) {
        var candidates = [];
        function addTokens(str) {
            if (!str) return;
            var tokens = String(str).trim().split(/[\s:|\-—–/\\()[\]{}]+/);
            for (var i = 0; i < tokens.length; i++) {
                var tok = tokens[i].trim().toLowerCase();
                if (tok.length > 1 && candidates.indexOf(tok) === -1) {
                    candidates.push(tok);
                }
            }
        }

        addTokens(initialTitle);
        addTokens(title);

        var ignored = [
            "bash", "zsh", "fish", "sh", "ksh", "csh", "tcsh", "nu", "nushell",
            "alacritty", "kitty", "foot", "footclient", "ghostty", "com.mitchellh.ghostty",
            "wezterm", "org.wezfurlong.wezterm", "st", "urxvt", "xterm", "terminal",
            "tui", "omarchy", "shadow", "root", "user", "home", "dev", "dotfiles",
            "tmp", "etc", "usr", "var", "bin", "opt"
        ];

        for (var k = 0; k < candidates.length; k++) {
            var cand = candidates[k];
            if (ignored.indexOf(cand) >= 0) continue;

            var icon = lookupEntryIcon(cand, entries, true);
            if (resolves(icon, appLibrary)) return icon;
            if (hasThemedIcon(cand, appLibrary)) return cand;
        }

        return "";
    }

    // Icon name (or path) for a client from `hyprctl clients -j`.
    function iconNameFor(windowData, appLibrary) {
        if (!windowData) return "";

        const entries = DesktopEntries.applications.values || [];
        const cls = String(windowData.class || "").trim();
        const initialClass = String(windowData.initialClass || "").trim();
        const title = String(windowData.title || "").trim();
        const initialTitle = String(windowData.initialTitle || "").trim();

        const isTerminalWindow = FallbackIcon.isTerminalLikeClass(cls) || FallbackIcon.isTerminalLikeClass(initialClass);
        // A step only counts when its icon will draw; otherwise the next one runs.
        const usable = value => resolves(value, appLibrary) ? value : "";
        let icon = "";

        // TUI app (yazi, nvim, btop, lazygit, ...) running in a terminal.
        if (isTerminalWindow)
            icon = findTuiAppIcon(title, initialTitle, entries, appLibrary);

        if (!icon)
            icon = usable(lookupEntryIcon(cls, entries));

        if (!icon && initialClass && initialClass !== cls)
            icon = usable(lookupEntryIcon(initialClass, entries));

        // Webapp name from the class (chrome-discord.com__app-Default -> discord).
        const extractedName = extractAppNameFromClass(cls);
        if (!icon && extractedName && extractedName !== cls)
            icon = usable(lookupEntryIcon(extractedName, entries));

        if (!icon && initialTitle)
            icon = usable(lookupEntryIcon(initialTitle, entries));

        if (!icon && title) {
            const cleanTitle = title.split(/\s+[-|–—]\s+/)[0].trim();
            if (cleanTitle)
                icon = usable(lookupEntryIcon(cleanTitle, entries));
        }

        // Direct icon-name candidates (discord, whatsapp, spotify, yazi).
        if (!icon) {
            const candidates = [extractedName, initialTitle, cls, initialClass].filter(n => n && n.length > 0);
            for (let j = 0; j < candidates.length; j++) {
                const cand = candidates[j].toLowerCase();
                if (cand === "google-chrome" || cand === "chromium" || cand === "brave-browser" || cand === "firefox")
                    continue;
                if (hasThemedIcon(cand, appLibrary)) {
                    icon = cand;
                    break;
                }
            }
        }

        if (!icon)
            icon = FallbackIcon.fallbackIconForWindow(windowData);

        const raw = `${icon ?? ""}`.trim();
        const withoutProviderPrefix = raw.replace(/^image:\/\/icon\//, "");
        return withoutProviderPrefix.split("?")[0].trim();
    }

    function sourceFor(icon, appLibrary) {
        const value = `${icon ?? ""}`.trim();
        if (appLibrary)
            return appLibrary.iconSource(value);
        if (value.length === 0)
            return Quickshell.iconPath("application-x-executable", true);
        if (value.startsWith("file://") || value.startsWith("image://") || value.startsWith("qrc:/"))
            return value;
        if (value.startsWith("/"))
            return Util.fileUrl(value);
        const themed = Quickshell.iconPath(value, true);
        if (themed.length > 0)
            return themed;
        return Quickshell.iconPath("application-x-executable", true);
    }

    function iconSourceFor(windowData, appLibrary) {
        return sourceFor(iconNameFor(windowData, appLibrary), appLibrary);
    }
}
