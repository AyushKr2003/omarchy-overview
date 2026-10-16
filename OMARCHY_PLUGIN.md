# Omarchy plugin install

This directory is packaged as a third-party Omarchy shell plugin.

Install it at:

```text
~/.config/omarchy/plugins/omarchy-overview/
```

Then run:

```bash
omarchy plugin rescan
omarchy plugin enable omarchy-overview
```

Toggle it with:

```bash
omarchy-shell shell toggle omarchy-overview
```

For a Hyprland keybind, use:

```conf
bind = SUPER, TAB, exec, omarchy-shell shell toggle omarchy-overview
```

Settings are read inline from `~/.config/omarchy/shell.json`, inside the
`plugins` entry for `omarchy-overview`:

```json
{
  "id": "omarchy-overview",
  "rows": "2",
  "columns": "5",
  "hideEmptyRows": "true",
  "showSpecialWorkspaces": "false",
  "specialWorkspaceColumns": "5",
  "showIcons": "false",
  "layout": "missionControl"
}
```

`layout` is `"missionControl"` (the default: window grid, workspace strip,
type-to-search) or `"grid"` (the workspace grid). See README.md for every
setting. The file is watched, so edits apply without a restart.

The shell does not pass overlay plugins their settings, so the overview
reads its entry from `shell.json` itself. Its local `Color` and `Style` wrappers delegate to Omarchy
`qs.Commons`, so it uses the active shell theme.
