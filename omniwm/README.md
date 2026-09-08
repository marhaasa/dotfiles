# OmniWM

Config for [OmniWM](https://omniwm.app) (Niri-style scrolling tiling WM for macOS 26+, Apple Silicon).

| File | Purpose |
| --- | --- |
| `settings.toml` | Canonical config (`schemaVersion = 3`). `setup.sh` symlinks it to `~/.config/omniwm/settings.toml`. Live-reloaded on save. |
| `templates/omniwm-layout` | Layout templates over `omniwmctl` (tmux-3, split, 3-col, centered). Linked as `scripts/omniwm-layout`, which is on `PATH`. |

Regenerated 2026-09-07 for OmniWM 0.6.8 from the April 2026 config (which lived in UserDefaults and a JSON export; both formats were dropped in OmniWM 0.4.8).

## Keybinding scheme

Custom scheme kept from the old config. Option+Shift for switching/focusing, Control+Option for moving, Control+Option+Shift for column- and workspace-level moves. Chosen so that Option+digit stays free for special characters on a Norwegian layout.

| Action | Binding |
| --- | --- |
| Switch to workspace 1–9 | `Option+Shift+1–9` |
| Move window to workspace 1–9 | `Control+Option+1–9` |
| Focus left/down/up/right | `Option+Shift+Arrows` |
| Move window left/down/up/right | `Control+Option+Arrows` |
| Move column left/right | `Control+Option+Shift+Left/Right` |
| Move window to workspace up/down | `Control+Option+Shift+Up/Down` |
| Move column to workspace up/down | `Control+Option+Shift+Page Up/Down` |
| Focus column 1–9 | `Control+Option+Shift+1–9` |
| Focus previous window | `Option+Shift+Tab` |
| Workspace back-and-forth | `Control+Option+Shift+Tab` |
| Toggle fullscreen | `Option+Shift+Return` |
| Container full width | `Control+Option+F` |
| Balance sizes | `Control+Option+B` |
| Cycle size forward/backward | `Option+Shift+.` / `Option+Shift+,` |
| Toggle column tabbed | `Option+Shift+T` |
| First/last column | `Option+Shift+Home/End` |
| Next / last monitor | `Control+Command+Tab` / `` Control+Command+` `` |
| Command palette | `Control+Option+Shift+Space` |
| Menu anywhere | `Control+Option+Shift+M` |
| Raise floating windows | `Control+Option+R` |
| Quake terminal | `` Option+Shift+` `` |
| Toggle workspace layout (Niri/Dwindle) | `Control+Option+L` |
| Overview | `Control+Option+O` |

Everything else (scratchpads, workspace slots, Dwindle resize, monitor moves) is `Unassigned`. Bind in Settings → Hotkeys or by editing the `binding` value in place.

## Amethyst "fullscreen layout" equivalent

OmniWM has no monocle layout and the maintainer declined one (issue 366, May 2026: "you can get 95% of this functionality already by adjusting the Niri settings"). Three ways to get it:

- **Per workspace, on demand:** `omniwm-layout monocle` consolidates every tiled window into one full-width tabbed column; `Option+Shift+Up/Down` cycles the stack. Bind it to a key with a macOS Shortcut (Shortcuts → Run Shell Script → Details → Add Keyboard Shortcut); OmniWM hotkeys can only trigger built-in actions. `omniwm-layout split` or `tmux-3` undoes it.
- **Globally:** set `niri.defaultContainerPrimarySpan = 1.0` so every new column fills the viewport, and `Option+Shift+Left/Right` scrolls between windows. Set `general.animationsEnabled = false` if the scroll feels slow. This is the maintainer's suggestion; it applies to all workspaces.
- **One window only:** `Option+Shift+Return` (Toggle Fullscreen) fills the display with the focused window and drops back on the second press.

## Editing rules

The schema is strict. A missing required key, an unknown enum value, or a `[[hotkeys]]` array that does not list every assignable action exactly once rejects the whole file; OmniWM then runs with defaults and reports it under Diagnostics. So:

- Change values in place. Never add or remove `[[hotkeys]]` entries.
- Key names in bindings are words: `Grave`, `Period`, `Comma`, `Return`, `Left Arrow`, `Page Up`.
- Any change made in the Settings window rewrites the file sorted and without comments. The symlink target is preserved.
- After a `brew upgrade`, read the release's "Before You Upgrade" notes. Quit OmniWM first; `omniwmctl` must match the app version.

## First launch checklist

1. **Displays have separate Spaces** must be on (System Settings → Desktop & Dock → Mission Control). `setup.sh` turns it on when needed; log out and in afterwards.
2. `brew bundle` installs OmniWM (`cask 'omniwm'`, official cask since 0.6.8). Remove Amethyst from Login Items if it is still there.
3. Run `./setup.sh` or `ln -sf "$DOTFILES/omniwm/settings.toml" ~/.config/omniwm/settings.toml`.
4. Launch OmniWM, grant Accessibility and Input Monitoring. Screen Recording is optional (Overview thumbnails).
5. Settings → Monitors → **Run Monitor Setup**. Routing is left on the macOS arrangement in `settings.toml`; the assistant records display UUIDs for the current desk (MacBook + Dell P3425WE).
6. Settings → General → Startup → **Start at Login**. Remove Amethyst from Login Items and quit it.
7. Check Diagnostics for config notices. Test the CLI: `omniwmctl ping && omniwm-layout split`.

## What changed from the April 2026 config

- Action ids: `cycleColumnWidthForward/Backward` → `cycleSizeForward/Backward`; `toggleColumnFullWidth` → `toggleContainerFullPrimarySpan`; directional `resizeGrow/Shrink.*` → `.horizontal/.vertical`; single scratchpad → ten slots.
- Niri keys: `niriMaxVisibleColumns` → `niri.visibleContainerCount`; `niriColumnWidthPresets` → `containerPrimarySpanPresets`; `niriSingleWindowAspectRatio = 4:3` → `singleWindowFit = "container_primary_span"` (a lone window keeps the default column width, centered). `niriMaxWindowsPerColumn` no longer exists.
- `focus.raiseOnMouseFocus = true` keeps the pre-0.6.3 behaviour (hover also raises). OmniWM's new default is `false`.
- Mouse-warp monitor order → `routing.arrangements`, managed by Monitor Setup. The old file referenced a Dell U4924DW.
- Workspaces 8 and 9 added (OmniWM defaults) so `Option+Shift+8/9` have targets.
- CLI: `cycle-column-width` → `cycle-size`; `toggle-column-full-width` → `toggle-container-full-primary-span`; window ids are session-scoped opaque ids; already-satisfied commands return `ignored`.
