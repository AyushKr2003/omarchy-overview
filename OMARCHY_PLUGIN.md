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
  "showIcons": "false"
}
```

The plugin follows the same shape as Omarchy panels: it exposes `settings`
and `setting(name, fallback)`, and the overview config reads the fields from
there. Its local `Color` and `Style` wrappers delegate to Omarchy
`qs.Commons`, so it uses the active shell theme.
